# 検討事項・TODO

今後やること・決めることのメモ。決まったら AGENTS.md に方針として昇格させる(理由の比較・トレードオフは `docs/decisions/` の ADR へ)。解決した項目はここから削除し、蒸し返さないための記録は ADR 側に残す。

## secrets-scan.yml の gitleaks → Betterleaks 移行検討(2026-08時点、保留)

- gitleaks(CLI本体)は開発者が feature-complete を宣言し、今後はセキュリティパッチのみで新機能追加なし。開発リソースは後継の Betterleaks(同じ開発者が MIT ライセンスで新規開発、Aikido Security がスポンサー)へ移行中。
- ただし現状の `.github/workflows/secrets-scan.yml` は Action ではなく CLI 本体をバージョン・チェックサム固定で直接実行する方式のため、gitleaks-action の Node 20 廃止問題(2026年9月)の影響は受けず、動作継続に支障はない。
- Betterleaks は 2026-02 作成、2026-03 に v1.1.1 とまだ非常に新しく、実績が薄い。移行を検討する際は `package-researcher` スキルの基準(upstream のメンテ状況・ライセンス確認)に沿って再調査してから判断する。急ぎではない。

## Windows native マウント上のリポジトリでの starship git_status 対策(2026-08時点、保留)

- 低速マウント(WSL の /mnt/c 等)上のリポジトリでは、git の並列 index 走査がマウント境界で直列化され、大きめのリポジトリの `git status` が分単位になり得ることを、遅延注入 FUSE マウントの実測で確認した(4万ファイル・0.5ms/op 注入で、並列可マウント 16秒 / 直列化マウント 136秒)。
- starship のプロンプト自体は内部タイムアウト(`command_timeout` 既定500ms)で git 走査を打ち切るため数分固まることはないが、+0.5〜0.7秒の遅延と git_status 情報(変更ファイル数等)の欠落が起きる。シェル起動側の最適化(`docs/decisions/zsh-startup-optimization.md`)では救えない領域。
- 対策候補: (1) リポジトリを ext4 側に置く(根本解)、(2) starship の `git_status.windows_starship`(/mnt 配下では Windows 側の starship.exe に計算させる公式機能。パスがマシン依存のため、導入するなら local 系ファイルとの組み合わせが必要)、(3) /mnt 配下のみ git_status を無効化(実測 0.73秒 → 0.12秒)。
- 現状 /mnt 上で日常作業していないため保留。必要になったら検討する。

## 個人的なこと・特定の文脈が分かることは一切含めない(最重要ルール)

プロンプトは特に、書いた人物の状況が特定できる文脈が混ざりやすい。このファイルも含め、コミット前に必ず全文精査し、少しでも疑わしければ入れない。
