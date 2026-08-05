# WezTerm

標準の操作は `wezterm show-keys`(現在有効なキーバインド一覧)や[公式ドキュメント](https://wezterm.org/)を参照。ここには**このリポジトリで標準から変更・追加した設定**だけをまとめる。

設定ファイル: `home/.config/wezterm/wezterm.lua`

- 組み込みの自動更新チェック(`check_for_updates`)は全環境で無効化(プライバシー上の理由。判断根拠は `docs/decisions/terminal-emulator.md` 参照)
- 初期ウィンドウサイズはディスプレイの実サイズの 50% で画面中央に配置(`gui-startup` イベント。FHD と 4K/ウルトラワイドで見た目の占有率を揃えるため。比率は `wezterm.lua` 冒頭の `screen_ratio` で変更可)
- アクティブタブは青背景+白文字で色付け(`colors.tab_bar.active_tab`)
- Windows ネイティブ側では、インストール済み WSL ディストリビューションを自動検出して `default_domain` に設定(WSL/macOS/Linux 統一)。起動するシェルは WSL 側の `chsh` 設定に関わらず `zsh` を明示指定
- 壁紙はデフォルト有効(同梱のテンプレート壁紙 `wallpaper.png`)。`~/.config/wezterm/wallpaper.local.lua`(git 管理外)で差し替え(画像パスを `return`)・無効化(`return false`)できる(詳細は README「WezTerm を使う」参照)
- 設定変更を反映するには: `Cmd+Shift+R`(反映されない場合は完全終了して再起動)
- WSL: Windows 側の `WEZTERM_CONFIG_FILE` は `wsl-wezterm-setup`(WSL 内で実行)で自動設定できる

## よく使うキーバインド(このリポジトリでの追加分)

壁紙が有効なとき(デフォルト有効)だけ使えます。

| キー | 内容 |
|---|---|
| `Ctrl+Shift+O` | ウィンドウ透過のON/OFF切り替え(デフォルトは不透明。ONにすると壁紙越しにデスクトップが薄く透ける) |
