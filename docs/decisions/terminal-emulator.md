# ターミナルエミュレータは WezTerm を採用する

## 検討した代替

| 観点 | WezTerm | Kitty | Ghostty | Alacritty |
|---|---|---|---|---|
| WSL/macOS/Linux 統一 | ○(`config.default_domain = 'WSL:Ubuntu'` でWSL統合が作り込み済み) | ×(Windows非公式非対応。WSL2+Xserver経由の裏技のみ) | ×(2026年3月時点でWindows非公式非対応。非公式移植版Winghosttyは単独メンテナの若いプロジェクトで信頼性未知数) | ○(3環境ともネイティブ対応) |
| メモリ使用量 | ×(約320MB) | ○(60〜100MB) | ○(60〜100MB) | ○(軽量) |
| 起動速度 | △(GPU/ドライバ環境依存でばらつき大) | ー | ー | ー |
| 機能・成熟度 | ○ | ー | ー | △(機能はミニマルで自称「betaレベル」) |
| upstream/nixpkgsの健全性 | ○(package-researcherで確認済み) | ー | ー | ー |

## 選んだ理由

- 3環境統一を諦めない前提だと、現実的な選択肢は WezTerm か Alacritty の二択に絞られる(Kitty・Ghostty は Windows 非公式非対応のため除外)。
- WezTerm は WSL 統合の作り込み(`config.default_domain` による WSL ドメイン自動検出)で優位。メモリ使用量(約320MB)は Kitty/Ghostty(60〜100MB)より重いが、3環境統一・機能面のメリットを優先し許容することにした。
- upstream(wezterm/wezterm)は継続的にコミットがあり非アーカイブ、nixpkgs 側も `broken` フラグなし・MIT ライセンスで健全(2026-08 に package-researcher スキルで再確認)。

## トレードオフ

- メモリ使用量は Kitty/Ghostty より重い(採用理由の欄を参照。3環境統一を優先したうえでの許容)。
- WSL 環境では実際に画面を描画する WezTerm 本体は Windows ネイティブ側で動く(WSL 統合はあくまで Windows 側の WezTerm が WSL 内のシェルを呼び出す機能)。この dotfiles(Nix + home-manager)は WSL 内(Linux 側)にしか配布できないため、Windows 側の WezTerm 本体・設定反映は手動対応が必要(詳細は README 参照)。

## 履歴

- (管理対象にしない): 2026-08、WezTerm導入を検討したがメモリ使用量を理由に見送り
- (WezTerm採用に転換、本ADR): 2026-08-05、3環境統一のメリットを優先してメモリ使用量のトレードオフを許容し、採用に転換。設定ファイル(`home/.config/wezterm/wezterm.lua`)は home-manager 配布、バイナリ本体は macOS/Linux(WSL含む)は `nix/home.nix` の `home.packages`、Windows ネイティブ側のみ対象外(winget 等での手動導入に任せる。判断根拠は `docs/decisions/login-shell.md` のログインシェル本体と同じロジック)
- (`check_for_updates` を全環境で無効化): WezTerm 組み込みの自動更新チェック(デフォルト有効。24時間ごとに GitHub のリリース API へ通信)を、当初は「Windows ネイティブ側は Nix 管理外だから有効なままの方が便利」という理由で Windows のみ有効のままにしていたが、ターミナルという常駐アプリが定期的に外部通信すること自体への懸念から、全環境で無効化する方針に変更した。「導入・反映は明示実行のみ」というこのリポジトリ全体の方針(Nix の `home-manager switch` も自動実行しない)とも整合する。Windows 側で更新したい場合は `winget upgrade wez.wezterm` を手動実行する(README「更新」参照)。WezTerm 自体にテレメトリ・クラッシュレポートは無く、この更新チェックが唯一の外部通信だった(公式 [PRIVACY.md](https://github.com/wezterm/wezterm/blob/main/PRIVACY.md) で確認済み)。
- (今後この決定が覆ったら、ここに追記していく。全面書き換えはしない)
