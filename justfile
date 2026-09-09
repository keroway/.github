# keroway/.github 自身のローカル検証入口。CI（reusable-workflow-lint.yml）と同じ4項目を
# ローカルで実行する。CIとの違いはツールのバージョン固定をしない点（ローカルに入っている
# ものをそのまま使う）。未インストールのツールは案内して抜ける（keroway/.github#31）。

default:
    @just --list

check: lint-workflows lint-shell lint-typos

# actionlint: .github/workflows/ + templates/workflow-*.yml（未展開 placeholder を含めて検査する）
lint-workflows:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v actionlint >/dev/null 2>&1 || { echo "actionlint が見つかりません（brew install actionlint）"; exit 1; }
    shopt -s nullglob
    files=(.github/workflows/*.yml templates/workflow-*.yml)
    actionlint "${files[@]}"

lint-shell:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v shellcheck >/dev/null 2>&1 || { echo "shellcheck が見つかりません（brew install shellcheck）"; exit 1; }
    shopt -s nullglob
    files=(templates/*.sh)
    [ "${#files[@]}" -eq 0 ] && { echo "対象 .sh なし"; exit 0; }
    shellcheck "${files[@]}"

lint-typos:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v typos >/dev/null 2>&1 || { echo "typos が見つかりません（brew install typos-cli）"; exit 1; }
    typos
