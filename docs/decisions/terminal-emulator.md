# ターミナルエミュレータ設定は当面管理対象にしない

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
- WezTerm は WSL 統合の作り込みで優位だが、メモリ使用量(約320MB)が Kitty/Ghostty(60〜100MB)と比べ明確に重く、起動時間も環境依存でばらつきが大きい。
- 今回はメモリの重さを優先し、WezTerm・Alacritty のどちらも導入せず見送った。

## トレードオフ

- 再検討する場合は、軽量寄りの Alacritty から試すのが妥当(ただし WSL 統合の作り込みは WezTerm に劣る)。

## 履歴

- (管理対象にしない、本ADR): 2026-08、WezTerm導入を検討したがメモリ使用量を理由に見送り
- (今後この決定が覆ったら、ここに追記していく。全面書き換えはしない)
