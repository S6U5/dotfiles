# WSL ではブラウザを Windows 側の既定ブラウザで開く

WSL からツールが URL を開くと、WSL 内(Linux 側)にブラウザが入っているとそちらが WSLg のウィンドウで起動する。Windows 側のブラウザ(ログイン状態・拡張機能が揃っている方)で開くようにした。

| 観点 | 何もしない | wslu の `wslview` | 自作 `wsl-browser`(採用) |
|---|---|---|---|
| Windows 側で開く | × | ○ | ○ |
| 追加の依存 | なし | wslu パッケージ | なし(Windows 標準の `rundll32.exe url.dll`) |

- `BROWSER`(`os/wsl.sh`)だけでは足りない。xdg-open は `BROWSER` より x-scheme-handler の既定アプリを優先するため、WSL 内の Chrome が既定ブラウザ登録されていると結局そちらが開く。そこで `home.activation` で `.desktop` を生成し、`xdg-mime default` で http / https / text/html の既定にする。
- 起動には `rundll32.exe url.dll,FileProtocolHandler` を使う。`cmd.exe /c start` は `&` 等を解釈して URL が壊れ、`powershell.exe` は起動が遅い。
- 開くのは Windows の「既定のブラウザ」。特定のブラウザを指定する設定は作らない(Windows 側の既定アプリ設定で選ぶ)。

## トレードオフ

- WSL 内のブラウザをあえて使いたいときは、そのブラウザのコマンドを直接実行する。
- `~/.config/mimeapps.list` は WSL 内のブラウザ自身も書き換える(「既定にする」等)。奪い返された場合は次の `home-manager switch` で戻る。
