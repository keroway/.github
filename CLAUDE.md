# keroway/.github

全リポジトリが参照する共有 CI 基盤（reusable workflows）とテンプレート配布元。
正典は [README.md](./README.md)（reusable workflow 一覧・テンプレート一覧・SHA ピン規約）。

## このリポジトリ固有のルール

- `.github/workflows/` を変更したら `.github/workflows/reusable-*.yml` を呼ぶ側
  （`templates/workflow-*.yml` や他リポジトリの呼び出し元）との入出力互換を壊していないか確認する。
  `workflow_call` の `inputs` はデフォルト値を持たせ、既存呼び出し元が無変更で動く形を保つ
  （破壊的変更をする場合は影響を受けるリポジトリを洗い出してから進める）。
- `templates/` はコピー用テンプレートであり、`<...>` のような未展開 placeholder を含むファイルがある
  （`templates/workflow-ci-failure-issue.yml` の `<対象workflow名>` 等）。これは意図的な状態であり、
  「plaseholder があるから」という理由で検査を skip しない。
- コミット前のローカル検証は `just check`（actionlint / shellcheck / typos。テンプレートの
  workflow ファイル・shell script も対象に含む）。CI と同じ4項目を実行する
  reusable workflow は `reusable-workflow-lint.yml`。
- `.github/workflows/workflow-lint.yml` はこのリポジトリ自身の lint ゲート（`templates/workflow-lint.yml`
  は配布用の別ファイルで、他リポジトリへの呼び出し元テンプレート）。両者を混同しない。
- branch protection の required checks 変更や、`main` への直接的な破壊的変更は、
  影響範囲（全リポジトリの CI）を確認してから行う。
