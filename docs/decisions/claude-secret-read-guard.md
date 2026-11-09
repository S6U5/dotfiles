# Claude Code に資格情報ファイルを読ませないガード

Claude Code が API キー・トークン類を読んでしまわないようにする方法の決定。`templates/claude/settings.json.template` の `permissions.deny` に資格情報ファイルの `Read(...)` を並べる(パッケージマネージャ・クラウド CLI・エージェントの認証ファイルを含む)。リポジトリの `.claude/settings.json` にも `.env` と `local.sh` の分だけ置く。

## 検討した代替

| 観点 | Read deny のみ(採用) | Read deny + `sandbox.filesystem.denyRead` に重複記載 | PreToolUse フック | CLAUDE.md で禁止を指示 |
| --- | --- | --- | --- | --- |
| Read / Grep / Glob を止める | ○ | ○ | ○ | ×(モデル任せ) |
| Bash(`cat` 等)を止める | △(sandbox 有効時のみ。Read deny が自動で denyRead に合流) | △(同左。重複分の効果は無い) | △(コマンド文字列の照合なので迂回できる) | × |
| 保守の手間 | ○(1か所) | ×(2か所を同期) | ×(スクリプトの保守) | ○ |

## 選んだ理由

- 公式ドキュメント上、`Read(...)` の deny は sandbox の読み取り禁止リストに自動で加わる。`sandbox.filesystem.denyRead` に同じパスを書いても、効果は増えず同期の手間だけが残る。
- フックによる文字列照合は、変数展開・別コマンド経由で簡単に迂回できる。Bash を止めるなら OS レベルで効く sandbox のほうが確実。

## トレードオフ

- sandbox は無効のまま(Bash の書き込み先やネットワークも制限され、普段の作業への影響が大きいため)。この状態では Bash 経由の読み取りは止まらない。必要になったらコピー先で `sandbox.enabled` を有効にする。
- `~/.npmrc`・`~/.config/nix/nix.conf` のように、トークンと通常設定が同居するファイルは、通常設定の確認にも読めなくなる(dotfiles 管理分は `home/` 側の実体を読めばよい)。
- `.env.*` を塞ぐので `.env.example` も読めない(deny は allow より優先されるため、例外は作れない)。

## 履歴

- Read deny への資格情報ファイル追加を採用(本 ADR)
- (今後この決定が覆ったら、ここに追記していく。全面書き換えはしない)
