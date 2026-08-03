# Obsidian CLI は公式のみ使用、WSL は Windows ネイティブ版を interop 経由で操作

## 検討した代替

- コミュニティ製 CLI(`notesmd-cli` 等)
- WSL 内に Linux 版 Obsidian を入れ、WSLg 経由で GUI を出す(vault を Linux FS 側に置ける構成)

## 選んだ理由

- コミュニティ製ではなく公式 CLI(`obsidian` コマンド)を使う。macOS / ネイティブ Linux はそのまま公式 CLI を使う(macOS: `/usr/local/bin/obsidian` → アプリバンドル内 `obsidian-cli`。Linux: `~/.local/bin/obsidian`)。
- WSL には Linux 版 CLI を入れない。入れると WSLg 経由の Linux 版 Obsidian を操作してしまうため、WSL からは Windows ネイティブの Obsidian を interop 経由で操作する(Windows 側の `Obsidian.com` を叩く)。既存の `ov`(URI 起動)/ `cdov`(vault 移動)と同じ「WSL→Windows を叩く」流儀の延長として一貫させた。

## トレードオフ

- WSLg で GUI を出す派(vault を Linux FS に置ける)も世間的には一般的だが、今回は不採用。理由は Windows ネイティブ版が `\\wsl.localhost\...`(WSL の ext4 の奥)の vault をうまく開けないため。結果として **vault は Windows 側(`/mnt/c/...` から見える場所)に置く前提**になる。既存 `obsidian.sh` が obsidian.json を Windows 側から読み `wslpath` で変換している作りとも整合する。
- Windows 側で CLI を動かす際の制約(要検証事項): 旧コンソールホスト(conhost)ではなく Windows Terminal が必要、管理者権限のシェルだと CLI が無反応になる報告あり、`Obsidian.com` は PATHEXT で `.exe` より優先される「ターミナルリダイレクタ」である点。
- 実装・検証の残タスク: OS 差の吸収設計(macOS/Linux はネイティブ CLI、WSL は Windows の `Obsidian.com` へルーティング)の実装、`.com` リダイレクタを WSL interop から実行できるかの検証、`wslpath` によるパス相互変換、既存 `obsidian.sh`(URI方式)との統合方法、Catalyst/Insiderゲートの扱い。実装後はユーザー向け最小セットアップ手順を README へ昇格させる。

## 履歴

- (公式 CLI を採用、WSL は Windows ネイティブを interop 経由で操作、本ADR): 上記の理由により決定
- (2026-08: 実装は着手不可・待機中と確認。作業機(Mac)の Obsidian が v1.11.5 で、CLI 機能が入った v1.12 系より古く CLI バイナリ自体が存在しない。WSL 側も実機なし。macOS の Obsidian を v1.12.4+ に更新する、または WSL 実機を用意するまで着手できない)
- (今後この決定が覆ったら、ここに追記していく。全面書き換えはしない)
