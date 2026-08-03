# tmux

標準の操作は `man tmux` や `prefix + ?`(バインド一覧表示)を参照。ここには**標準から
変更・追加した設定**だけをまとめる。

設定ファイル: `home/.tmux.conf`

- プレフィックスキー・ペイン分割キーは **デフォルトのまま**(`Ctrl+b`、`prefix + %` で左右分割、`prefix + "` で上下分割。過去にカスタムを検討したが最終的にデフォルトに統一。herdrと合わせている)
- 256色モードを有効化(`tmux-256color`)
- マウス操作を有効化
- クリップボード連携: OS ごとに自動でコピーコマンドを選択(macOS: `pbcopy`、WSL: `clip.exe`、Linux: `xclip`/`wl-copy`)。マウスドラッグ選択で自動コピー
- WSL: `prefix + ]` で Windows のクリップボードから貼り付け
- マシン固有の設定は `~/.tmux.conf.local`(git管理外)で上書き可能
- 設定変更を反映するには: `prefix + :` → `source-file ~/.tmux.conf`(または新規セッション)

## よく使うシェルコマンド

| コマンド | 内容 |
|---|---|
| `tmux new -s <name>` | 名前付きセッションを新規作成 |
| `tmux attach -t <name>` | 既存セッションにアタッチ |
| `tmux ls` | セッション一覧 |
| `tmux kill-session -t <name>` | セッションを終了 |

## よく使うキーバインド(prefix = `Ctrl+b`)

| キー | 内容 |
|---|---|
| `prefix c` | 新規ウィンドウ |
| `prefix n` / `prefix p` | 次/前のウィンドウ |
| `prefix 0`〜`9` | ウィンドウ番号で直接切り替え |
| `prefix %` | ペインを左右分割 |
| `prefix "` | ペインを上下分割 |
| `prefix 矢印キー` | ペイン間フォーカス移動 |
| `prefix x` | ペインを閉じる(確認あり) |
| `prefix z` | ペインをズーム(全画面化) |
| `prefix ,` | ウィンドウ名を変更 |
| `prefix $` | セッション名を変更 |
| `prefix d` | デタッチ |
| `prefix [` | コピーモードに入る(`q`で抜ける) |
| `prefix ?` | 全キーバインド一覧 |
