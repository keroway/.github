#!/usr/bin/env bash
# Stop hook テンプレート: Claude の応答完了時に、変更された領域だけ検証コマンドを実行する。
#
# これはコピー用テンプレートであり、そのままでは動かない。
# 「リポジトリ固有」とマークされた箇所を実際のプロジェクトに合わせて埋めること。
#
# 位置づけ:
#   codex stop review gate は無効。機械的に判定できる誤りはこの hook がターン終了ごとに
#   潰し、設計レビューが必要なときだけ /code-review を手動で起動する。
#   lefthook の pre-commit は staged ファイルにしか効かないため、未コミット状態で
#   ターンが終わるケースをここで拾う。
#
# 動作:
#   1. 変更ファイル（uncommitted + untracked + 未 push の commit）を分類する
#   2. 変更スコープに応じた検証コマンドを実行する（リポジトリ固有）
#   3. 失敗時は stderr に内容を出力し exit 2 で Claude にフィードバックする
#   4. 検証コマンドが見つからないのに対象変更がある場合も FAIL として通知する
#      （silent-pass しない = 「検証できない」を「成功」と扱わない）
#
# 実行するコマンドは CI の対応ジョブと一致させる。ここで緑なら CI でも緑になる、
# という関係を保つこと。
#
# 無限ループ防止:
#   stop_hook_active=true の場合（hook 由来の再起動）はスキップ。
#   jq が無い環境でもこの判定が丸ごと無効化されないよう、jq 非依存フォールバックを持つ
#   （jq は macOS 標準搭載ではない環境がある。macOS 26+ には /usr/bin/jq が入っているが、
#   ポータビリティのため常にフォールバックを実装しておく）。
#
# スキップしたい場合:
#   <REPO>_SKIP_STOP_HOOK=1 を設定する（環境変数名はリポジトリ固有）

set -u

INPUT="$(cat || true)"

if command -v jq >/dev/null 2>&1; then
  STOP_HOOK_ACTIVE="$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)"
else
  # jq 非依存フォールバック: 空白を除いた生 JSON を直接照合する。
  COMPACT_INPUT="$(printf '%s' "$INPUT" | tr -d ' \t\n\r')"
  case "$COMPACT_INPUT" in
    *'"stop_hook_active":true'*) STOP_HOOK_ACTIVE="true" ;;
    *) STOP_HOOK_ACTIVE="false" ;;
  esac
fi

if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# --- リポジトリ固有: スキップ環境変数名 ---
if [ "${REPO_SKIP_STOP_HOOK:-}" = "1" ]; then
  exit 0
fi

# silent-pass 禁止: cd / git 確認に失敗したら exit 2 で Claude に通知する。
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
if ! cd "$PROJECT_DIR" 2>/dev/null; then
  {
    echo "Stop hook: PROJECT_DIR ($PROJECT_DIR) に cd できません。検証をスキップしました。"
    echo "  CLAUDE_PROJECT_DIR=${CLAUDE_PROJECT_DIR:-(unset)}"
    echo "hook の設定 (.claude/settings.json) と作業ディレクトリを確認してください。"
  } >&2
  exit 2
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  {
    echo "Stop hook: $(pwd) は git リポジトリではありません。変更ファイルを判定できないため検証をスキップしました。"
    echo "（一時的に止めたい場合は環境変数 REPO_SKIP_STOP_HOOK=1）"
  } >&2
  exit 2
fi

# 変更ファイル一覧（unstaged + staged + untracked + 未 push の commit）。
# 未 push 範囲の決め方は上流ブランチ → origin/main → 空、の順に degrade する。
# push 前の新規ブランチでは @{u} が無いため、origin/main からの分岐点を使う
# （直近 N commit を見る fallback は、そのターンで触っていない main の変更まで
#   拾ってしまい、毎ターン全ステップが走る原因になる。デフォルトブランチ名が
#   main でないリポジトリは下記を差し替えること）。
UPSTREAM="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
if [ -n "$UPSTREAM" ]; then
  UNPUSHED_RANGE="${UPSTREAM}..HEAD"
elif git rev-parse --verify origin/main >/dev/null 2>&1; then
  UNPUSHED_RANGE="origin/main..HEAD"
else
  UNPUSHED_RANGE=""
fi

CHANGED_FILES="$(
  {
    git diff --name-only
    git diff --cached --name-only
    git ls-files --others --exclude-standard
    if [ -n "$UNPUSHED_RANGE" ]; then
      git log --name-only --pretty=format: "$UNPUSHED_RANGE" 2>/dev/null || true
    fi
  } | sed '/^$/d' | sort -u
)"

if [ -z "$CHANGED_FILES" ]; then
  exit 0
fi

# --- リポジトリ固有: 変更スコープの判定フラグ ---
# 例: CODE_CHANGED / UNIT_CHANGED / CONTENT_CHANGED など、検証ステップの単位で用意する。
CODE_CHANGED=0

while IFS= read -r file; do
  [ -z "$file" ] && continue

  # --- リポジトリ固有: パターンマッチで各フラグを立てる ---
  if [[ "$file" == src/* ]]; then
    CODE_CHANGED=1
  fi
done <<< "$CHANGED_FILES"

# --- リポジトリ固有: 何も変更がなければ即終了する条件 ---
if [ "$CODE_CHANGED" -eq 0 ]; then
  exit 0
fi

FAILED=0
REPORT=""

append_report() {
  REPORT="${REPORT}$1"$'\n'
}

# 関数内で FAILED / REPORT を書き換えるためサブシェルは作らない。
run_step() {
  local label="$1"
  shift
  echo "→ [stop-hook] $label" >&2

  local output
  local rc=0
  output="$("$@" 2>&1)" || rc=$?

  if [ "$rc" -ne 0 ]; then
    FAILED=1
    append_report ""
    append_report "❌ $label が失敗しました (rc=$rc)"
    append_report "コマンド: $*"
    append_report "$output"
  fi
}

# --- リポジトリ固有: 検証コマンドが実行できるか確認する（silent-pass 禁止） ---
if ! command -v pnpm >/dev/null 2>&1; then
  {
    echo "Stop hook: pnpm が見つかりません。変更があるのに検証できませんでした。"
    echo "  PATH=$PATH"
  } >&2
  exit 2
fi

# --- リポジトリ固有: 実行する検証ステップ（CI の対応ジョブと一致させる） ---
if [ "$CODE_CHANGED" -eq 1 ]; then
  run_step "lint" pnpm run --silent lint
  run_step "typecheck" pnpm run --silent typecheck
fi

if [ "$FAILED" -eq 1 ]; then
  {
    echo "Stop hook: 検証に失敗があります。下記を修正してから完了してください。"
    echo "（再実行をスキップしたい場合は環境変数 REPO_SKIP_STOP_HOOK=1）"
    echo "$REPORT"
  } >&2
  exit 2
fi

exit 0
