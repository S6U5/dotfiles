# zoxide は Linux/WSL のみ公式インストールスクリプトで導入

## 検討した代替(ツール採用そのもの)

- 標準の `cd` のみ(ディレクトリジャンプツールを使わない)

## 検討した代替(Linux/WSL の導入方法)

- `apt`(Debian/Ubuntu 系の標準リポジトリ)

## 選んだ理由

- zoxide はディレクトリ移動をシンプルかつ便利にでき、fzf(`fzf.md` 参照)とも組み合わせられるため採用した。
- zoxide 公式が「Debian/Ubuntu 系の apt は更新が遅いのでインストールスクリプトを使うこと」と明言しているため、`packages/apt.txt` には含めず `packages/zoxide-install.sh`(内部で公式インストールスクリプトを実行)を用意した。
- macOS は Homebrew が常に最新を追従するため、そのまま `packages/Brewfile` で導入する。

## トレードオフ

- 特になし。公式ドキュメントが明言している内容にそのまま従っただけの判断で、迷う余地は小さい。

## 履歴

- (apt → 公式インストールスクリプト、本ADR): 上記の理由により決定
- (2026-07-31: Nix + home-manager が基本(推奨)の導入経路になったため、`nixpkgs-unstable` 経由で Linux/WSL でも常に新しいバージョンが入るようになり、apt が古い問題は Nix 経由では発生しなくなった。`packages/zoxide-install.sh`(公式インストールスクリプト)は `packages/` を選んだ場合のフォールバックとして引き続き必要。判断根拠は `package-management.md` 参照)
- (2026-08-01: `packages/`(Brewfile / apt.txt / zoxide-install.sh)を完全廃止し Nix に一本化。zoxide は全OS共通で `nix/home.nix` 経由の導入のみになった。判断根拠は `package-management.md` 参照)
- (今後この決定が覆ったら、ここに追記していく。全面書き換えはしない)
