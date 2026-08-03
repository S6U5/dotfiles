# Docker は Engine のみを前提にし、Desktop は組み込まない

## 検討した代替

- Docker Desktop(macOS / Linux / WSL 共通で最も手軽な選択肢)

## 選んだ理由

- 普段の作業は CLI で完結しており、Docker Desktop の GUI 機能を必要としていない。Engine さえあれば実用上困らないため、わざわざ Desktop を入れる理由がない。
- 本リポジトリは MIT で OSS 公開予定であり、「商用ツールは呼び出すのは OK、組み込むのは NG」という方針を採っている(`nix/` で導入前提にするツールは無償かつ OSS ライセンスに限る)。Docker Desktop は商用ライセンスのため、dotfiles が前提として依存する対象からは外し、Engine のみを対象にした。

## トレードオフ

- Linux / WSL は `docker-ce` を公式 apt リポジトリからそのまま導入でき、問題は小さい。
- macOS は Docker Engine をネイティブ実行できないため、colima 等の軽量 VM 経由が必要になる。現状の作業機は Docker Desktop のままで、Engine 構成への移行は未実施(要検討)。

## 履歴

- (Docker Desktop → Engine のみを前提にする方針、本ADR): 上記の理由により決定
- (今後この決定が覆ったら、ここに追記していく。全面書き換えはしない)
