# keroway/.github

keroway の全リポジトリで共有する CI 基盤と標準テンプレート。

## Reusable workflows

| workflow | 用途 | 呼び出し元テンプレ |
|---|---|---|
| `reusable-remove-in-progress-on-close.yml` | Issue/PR クローズ時に `in-progress` ラベルを外す | `templates/workflow-remove-in-progress-on-close.yml` |
| `reusable-gitleaks.yml` | gitleaks による secret スキャン | `templates/workflow-gitleaks.yml` |

呼び出し元は `uses: keroway/.github/.github/workflows/<name>.yml@main` で参照する。

## テンプレート（`templates/`）

新規リポジトリ作成時・均質化作業時にコピーして使う標準設定:

- `renovate.json5` — weekly + minor/patch grouping（npm / github-actions）。リポジトリ固有の
  ignore・追加ルール（cargo 等）は必ず保持
- `lefthook.yml` — pre-commit: biome check (staged) + typecheck、pre-push: test
- `mise.toml` — Node 24 + pnpm 11 ピン（bun リポジトリは bun をピン）
- `justfile` — 標準動詞 `build / test / lint / format / check` の薄い委譲
- `biome.json` — lint/format 標準設定（recommended preset、double quote）
- `.editorconfig` — 共通エディタ設定

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
| jdx/mise-action | v4.2.1 | `dad1bfd3df957f44999b559dd69dc1671cb4e9ea` |

### ツールチェーン標準

- **Lint/format**: Biome（`.astro` / `.md` 等 Biome 非対応部分のみ補助 Prettier）
- **PM**: pnpm（例外: obsidian-clipper は bun）
- **Node**: 24（mise でピン、CI の setup-node も 24）
- **hooks**: lefthook
- **タスクランナー**: justfile（標準動詞 `build / test / lint / format / check`）
