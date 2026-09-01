# Starship

標準の挙動は[公式ドキュメント](https://starship.rs/config/)を参照。ここには**このリポジトリで標準から変更・追加した設定**だけをまとめる。

設定ファイル: `home/.config/starship.toml`(公式の pastel-powerline プリセットをベースにカスタマイズ)

## レイアウト

2行スタイル。1行目に情報、2行目の記号(`❯`)でコマンド入力する。

- **左(1行目)**: OS アイコン → ディレクトリ(フォルダアイコン付き)→ git(ブランチ・状態・rebase/merge 進行中表示)→ 言語(golang / nodejs / bun / rust / python)・nix_shell — パステル配色の powerline セグメント
- **右(入力行の右端)**: 直前のコマンドの exit code → 実行時間 → 完了時刻 — 塗りつぶし無しの細矢印()区切り。入力がそこまで伸びると自動で消える

## 標準から変更した主な点

- **exit code をコマンド実行時のみ表示**(`custom.exit_ok` / `custom.exit_err`): 成功は緑の `✓ 0`、失敗は赤の `✗ <code>`(例: `✗ 127`)。**何も入力せず Enter しただけの再描画では表示しない**。組み込みの `status` モジュールは「exit code 未指定(空 Enter)」を 0 と区別できないため、zsh の precmd フック(`home/.config/zsh/zshrc`)が「コマンド実行があったときだけ」`DOTFILES_LAST_STATUS` をセットし、custom モジュールがそれを参照する構成にしている
- **実行時間を常時・ms 単位まで表示**(`cmd_duration`): `min_time = 0` + `show_milliseconds = true`。`750ms` → `1s500ms` → `1m35s0ms` のように桁が上がると単位も繰り上がる。ms 非表示だと 1 秒未満がすべて `0s` になるため両方セットで設定している(空 Enter 時は starship 側の仕組みで元々非表示)
- **入力記号は形を変えず色だけ変化**(`character`): 成功=緑 / 失敗=赤の `❯`。記号を `✗` 等に変えると「これから打つコマンドが間違っている」ように見えるため、失敗の詳細表示は右側の exit code 表示に任せる
- **ユーザー名は root か SSH 接続時のみ表示**(`username`): ローカルの通常操作では非表示(主流のデフォルト挙動)
- **OS アイコンを表示**(`os`): macOS ``、WSL はディストリのアイコン(Ubuntu `` 等)
- 言語モジュールは使うものだけに整理(golang / nodejs / bun / rust / python)。`docker_context` は削除(default 以外の context を使い分ける運用をしていないため)

## 前提

Nerd Font が必要(README「Nerd Font をターミナルで有効にする」参照)。グリフが豆腐(□)になる場合はターミナルのフォント設定を確認する。
