# <REPO> — Claude Code Setup

このディレクトリは Claude Code / Cursor 等の AI コーディングエージェントの動作をこのプロジェクト用に
整える共有設定です。`CLAUDE.md`（リポジトリルート）と一緒に読んでください。

これはコピー用テンプレートであり、`<...>` とマークされた箇所を実際のプロジェクトに合わせて埋めること。
存在しないセクション（agents / skills 等）は削除してよい。

## 構成

```
.claude/
├── agents/                    # プロジェクト専用エージェント定義（無ければ省略）
│   └── <agent-name>.md
├── commands/                  # スラッシュコマンド（無ければ省略）
│   └── <command-name>.md
├── rules/                     # 実装規約の詳細（無ければ省略）
│   └── <rule-name>.md
├── hooks/                     # 自動実行スクリプト
│   └── <hook-script>.sh
├── skills/                    # プロジェクト専用 skill（無ければ省略）
│   └── <skill-name>/
├── settings.json              # 共有設定（hook 登録・許可プラグイン等、コミット対象）
├── settings.local.json        # 個人設定（.gitignore で除外）
└── agent-memory/              # エージェントの観察ログ（.gitignore で除外）
```

## 依存ツール

| ツール | 用途 | 必須？ |
|---|---|---|
| `<tool>` | <用途> | <必須 / 任意（hook 使用時のみ 等）> |
| `jq` | hook 内 JSON 抽出 | 無い環境では非依存フォールバックで動作（テンプレ側で担保） |

hook が要求するツールが PATH に無い環境での挙動（**silent-pass するか、exit 2 で通知するか**）を明記する。

## Hooks の挙動

<hook ごとに以下を埋める:>

### <イベント名（PostToolUse 等）>: `<script-name>.sh`

- 発火条件: <matcher（Edit/Write/MultiEdit 等）と対象ファイルパターン>
- 動作: <何を実行するか>
- 失敗時: <Claude をブロックするか（exit 2）、ユーザーへの通知のみか（exit 1 / exit 0）>
- 成功時 / 対象なし: <exit 0 で何もしない、等>

> hook が遅すぎる／不要な場合の無効化方法（環境変数によるスキップ、`settings.local.json` での上書き等）をここに書く。

## Slash Commands

<コマンドごとに以下を埋める:>

### `/<command-name> [引数]`

<何をするコマンドか、引数の意味、詳細ファイルへのポインタ>

## Agents の役割分担

| Agent | 担当領域 |
|---|---|
| `<agent-name>` | <担当領域> |

<Agent 間で判断が割れた場合にどちらを優先するかを明記する（例: スコープ責任者が最終判断）。>

## Rules の参照階層

`CLAUDE.md`（最上位） → `.claude/rules/*.md`（詳細）の順で参照。
矛盾があれば <どちらが優先か。リポジトリごとに逆向きでもよいが必ず明示する> が優先。

## 他環境への移植

このディレクトリは macOS / Linux いずれでも動作するように書かれています:

- hook スクリプトは `#!/usr/bin/env bash`
- 絶対パスは `$CLAUDE_PROJECT_DIR` で解決する（相対パスは cwd 依存で壊れるため使わない）
- `.claude/agent-memory/` は `.gitignore` で除外（個人のメモ）

新しい開発者がリポジトリをクローンした場合、追加でやることはありません。Claude Code が
`settings.json` を読み込めば hook が有効になります。
