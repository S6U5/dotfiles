# herdr のエージェント通知は、アプリ内トースト+WSL 向け自作プラグインの併用にする

herdr 0.8.0 の `[ui.toast] delivery` と、herdr プラグインによる通知を比較した(WSL + WezTerm / macOS + WezTerm で使う前提)。

| 観点 | `herdr`(アプリ内トースト) | `terminal`(OSC 9 を外側のターミナルへ) | `system`(OS の通知) | 自作プラグインで powershell.exe から Windows トースト |
|---|---|---|---|---|
| herdr を見ていないときに気づける | × | ○ | ○ | ○ |
| WSL で届く | ○ | ×(Windows 版 WezTerm 安定版が同梱する ConPTY が OSC 9 を通さない) | ×(Linux 扱いで `notify-send` になり Windows に届かない) | ○(ターミナルを経由しない) |
| macOS で届く | ○ | ○ | ○ | ―(WSL 専用) |
| 追加の実装・依存 | なし | なし | なし | 小さなスクリプト(sh + PowerShell) |
| 現時点の判断 | 採用 | 不採用 | 不採用 | 採用(WSL のみ、アプリ内トーストと併用) |

- アプリ内トーストは全環境で確実に動くためベースとして残す。WSL でターミナルを見ていないときだけ、自作プラグイン(`herdr-plugins/wsl-notify`)が Windows のトースト通知を出す(フォアグラウンドのウィンドウが WezTerm / Windows Terminal なら出さない)。
- `terminal` は herdr が `TERM_PROGRAM` で WezTerm を検出でき(WezTerm は WSLENV で WSL 側へ渡す)、herdr 側は OSC 9 を出力するが、WezTerm 安定版(20240203、同梱 ConPTY は 2022 年の v1.14 系)の ConPTY で捨てられる。WezTerm 作者も ConPTY が制御シーケンスを落とすことを認め、ssh / mux ドメインでの回避を案内している(wezterm/wezterm Discussion #6588)。WezTerm の安定版は 2024-02 以降出ておらず、更新での解決は見込みにくい。
- 同じ仕組みのサードパーティ製 herdr プラグインも存在するが、エージェントの状態を受け取って任意コードを実行する性質上、第三者のコードは入れず自作にした(`agent-skills.md` と同じ供給元の考え方)。
- 登録は `home-manager switch` の `home.activation` で自動実行する(`herdr plugin link` はプラグイン id をキーにした上書きで冪等。プラグイン自体が WSL 以外では何もしない)。

## トレードオフ

- Windows 側の送信元表示は「Windows PowerShell」になる(独自の AppUserModelID の登録はしない)。
- 通知1回ごとに PowerShell を起動するため 1 秒弱の遅延がある(done / blocked 以外は sh 側で起動前に弾く)。
- `herdr plugin disable` で止めても、次の `home-manager switch` の再登録で有効に戻る。
