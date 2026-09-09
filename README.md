# keroway/.github

keroway の全リポジトリで共有する CI 基盤と標準テンプレート。

## Reusable workflows

| workflow | 用途 | 呼び出し元テンプレ |
|---|---|---|
| `reusable-remove-in-progress-on-close.yml` | Issue/PR クローズ時に `in-progress` ラベルを外す | `templates/workflow-remove-in-progress-on-close.yml` |
| `reusable-gitleaks.yml` | gitleaks による secret スキャン（user 所有リポジトリ向け、PR コメント付き） | `templates/workflow-gitleaks.yml` |
| `reusable-gitleaks-cli.yml` | gitleaks CLI による secret スキャン（organization 所有リポジトリ向け、ライセンス不要） | `templates/workflow-gitleaks-cli.yml` |
| `reusable-workflow-lint.yml` | actionlint / zizmor / shellcheck / typos の静的検査 | `templates/workflow-lint.yml` |
| `reusable-osv-scan.yml` | osv-scanner による依存脆弱性の横断監査（cargo/npm/pnpm/bun 対応） | `templates/workflow-osv-scan.yml` |
| `reusable-ci-failure-issue.yml` | 監視対象workflowが失敗したら決定的にissueを起票/コメント追記（LLMポーリングの代替） | `templates/workflow-ci-failure-issue.yml` |

呼び出し元は `uses: keroway/.github/.github/workflows/<name>.yml@main` で参照する
（テンプレート上の既定値。個々のリポジトリは keroway/.github#17 の方針でコミット SHA へ
ピンし直すのが標準）。

**既知のトレードオフ**: テンプレートの既定は `@main`（ブランチ参照、未ピン）だが、
`keroway/.github` の `main` が侵害された場合の波及範囲が全リポジトリの CI に及ぶため、
各リポジトリで `docs/reusable-workflow-sha-pinning.md` の手順に沿ってコミット SHA へ
ピンする（keroway/.github#17）。新規リポジトリ作成時にテンプレをコピーした直後は
`@main` のままなので、SHA ピン化を忘れないこと。

## このリポジトリ自身の検証

共有 CI 基盤を配る側自身の構文・shell・綴りが未検査だと、他リポジトリへ壊れた設定を配ることになる。
`.github/workflows/workflow-lint.yml` が `reusable-workflow-lint.yml` を自身に対して呼び、
`.github/workflows/` に加えて `templates/workflow-*.yml`（`<対象workflow名>` のような
未展開 placeholder を含むテンプレートも意図的に対象へ含める）と `templates/*.sh` を検査する
（keroway/.github#31）。ローカルでは同じ4項目を `just check` で実行できる（`justfile` 参照）。
リポジトリ固有ルールは [CLAUDE.md](./CLAUDE.md)（`AGENTS.md` はそこへの symlink）。

## テンプレート（`templates/`）

新規リポジトリ作成時・均質化作業時にコピーして使う標準設定:

- `renovate.json5` — `github>keroway/.github` の共有プリセット（`default.json5`）を
  `extends` する薄い呼び出し元。リポジトリ固有の ignore・追加ルール（cargo 等）は
  この呼び出し元側の `packageRules` に追記する（共有プリセット本体は変更しない）
- `workflow-lint.yml` — actionlint / zizmor / shellcheck / typos の呼び出し元
- `workflow-osv-scan.yml` — osv-scanner の呼び出し元（週次 + push）
- `workflow-ci-failure-issue.yml` — 監視対象workflow失敗時のissue起票/更新の呼び出し元。
  `<対象workflow名>` を実際のCI workflow名に置き換えて使う
- `lefthook.yml` — pre-commit: biome check (staged) + typecheck、pre-push: test
- `mise.toml` — Node 26 + pnpm 11 ピン（bun リポジトリは bun をピン）。
  **ローカル開発専用のツールチェーンピン**であり、CI はこれを読まない
  （volta は開発終了予定のため 2026-07-28 に mise へ移行済み、
  https://github.com/volta-cli/volta/issues/2080）。CI 側は
  `actions/setup-node` / `pnpm/action-setup` / `dtolnay/rust-toolchain` /
  `oven-sh/setup-bun` で別系統にバージョンをピンしており、mise.toml とは
  手動で同期する（`jdx/mise-action` は導入していない）
- `justfile` — 標準動詞 `build / test / lint / format / check` の薄い委譲
- `biome.json` — lint/format 標準設定（recommended preset、double quote）
- `.editorconfig` — 共通エディタ設定
- `post-stop-check.sh` — Claude Code の Stop hook テンプレート。「リポジトリ固有」と
  マークされた箇所（スキップ環境変数名、変更スコープの判定パターン、実行する検証コマンド）
  を埋めて `.claude/hooks/` にコピーする。jq 非依存フォールバック・
  `stop_hook_active` によるループ防止・未 push 範囲の3段 degrade（`@{u}` →
  `origin/main..HEAD` → 空）は共通部分としてそのまま使う
- `claude-readme.md` — `.claude/README.md` のテンプレート。ディレクトリ構成図・依存ツール表・
  hook の発火条件と失敗時挙動（ブロックするか否か）・slash command・agent 役割分担・
  rules 参照階層・移植性を網羅する。`<...>` の箇所を実際のプロジェクトに合わせて埋める
  （`keroway/reflectorbit/.claude/README.md` が実例）
- `gitignore-claude.txt` — `.claude/` の allowlist 型 `.gitignore` テンプレート。
  settings.json / agents / commands / rules / hooks / skills / claude-security-guidance.md /
  README.md はチーム共有としてトラッキングし、settings.local.json / agent-memory / `.pi/` /
  `.pi-subagents/` は ignore する。skills 配下でもう一段絞る必要があるリポジトリ
  （自作 skill だけコミットし、ベンダリング物は除外する等）はテンプレートに手を加えた上で
  理由をコメントで残す（`timeline-dsl-lp` が実例）。**`.claude/` を意図的に全除外している
  リポジトリ（未共有の個人設定用途）には無理に適用しない**

## Renovate 共有プリセット（`default.json5`）

リポジトリ側の renovate 設定は次の形に縮める:

```json5
{
  $schema: "https://docs.renovatebot.com/renovate-schema.json",
  extends: ["github>keroway/.github"],
  packageRules: [
    // リポジトリ固有の追加ルールのみここに書く
  ],
}
```

`config:recommended` + `schedule:weekly` + `:semanticCommitTypeAll(chore)` と
npm/github-actions の minor/patch グルーピングは `default.json5` 側が持つ。
配置先は各リポジトリ `.github/renovate.json5` に統一する。

## アカウント既定のコミュニティヘルスファイル

`ISSUE_TEMPLATE/` / `PULL_REQUEST_TEMPLATE.md` / `SECURITY.md` をリポジトリ直下に
一切持たないリポジトリに対する GitHub の既定フォールバックとして機能する
（[Creating a default community health file](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file)）。
リポジトリ側に同種のファイルがあればそちらが優先されるため、リポジトリ固有の
チェックリストやセキュリティポリシー（`code-tactics/SECURITY.md` 等）には影響しない。

## 規約

### GitHub Actions のバージョンピン

サードパーティ / 公式問わず、action は **コミット SHA でピンし、コメントでバージョンを明記**する:

```yaml
uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
```

追従は各リポジトリの renovate（`matchManagers: ["github-actions"]`）に任せる。
renovate は SHA ピン + コメントの形式を認識して両方更新する。

（2026-07 に dependabot から renovate へ全リポジトリ移行済み。renovate の方が
グルーピング・lockstep 依存の扱いで柔軟なため、こちらを標準とする。）

現行の標準ピン（2026-07 時点）:

| action | version | SHA |
|---|---|---|
| actions/checkout | v7.0.1 | `3d3c42e5aac5ba805825da76410c181273ba90b1` |
| actions/setup-node | v7.0.0 | `820762786026740c76f36085b0efc47a31fe5020` |
| actions/cache | v6.1.0 | `55cc8345863c7cc4c66a329aec7e433d2d1c52a9` |
| actions/upload-artifact | v7.0.1 | `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` |
| actions/github-script | v9.0.0 | `3a2844b7e9c422d3c10d287c895573f7108da1b3` |
| pnpm/action-setup | v6.0.9 | `0ebf47130e4866e96fce0953f49152a61190b271` |
| gitleaks/gitleaks-action | v3.0.0 | `e0c47f4f8be36e29cdc102c57e68cb5cbf0e8d1e` |
| oven-sh/setup-bun | v2.2.0 | `0c5077e51419868618aeaa5fe8019c62421857d6` |

### ツールチェーン標準

- **Lint/format**: Biome（`.astro` / `.md` 等 Biome 非対応部分のみ補助 Prettier）
- **PM**: pnpm（例外: obsidian-clipper は bun）
- **Node**: 26（ローカルは mise でピン、CI は `actions/setup-node` / `.nvmrc` でピン。
  両者は mise を CI から参照する形ではなく手動同期）
- **hooks**: lefthook
- **タスクランナー**: justfile（標準動詞 `build / test / lint / format / check`）
