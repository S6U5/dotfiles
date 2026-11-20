# mdgrid は nixpkgs に無いため、flake の入力にしたソースから Nix でビルドして導入

## 検討した代替

| 観点 | flake の入力からビルド(採用) | `fetchFromGitHub` でタグからビルド | GitHub Releases のビルド済みバイナリ | 各マシンで `cargo install mdgrid --locked` |
| --- | --- | --- | --- | --- |
| 宣言的に入る(`home-manager switch` で揃う) | ○ | ○ | ○ | × |
| 取得元をコミットとハッシュで固定 | ○(flake.lock) | △(ハッシュを手で持つ) | △(OS・CPU ごとにハッシュ3つ) | × |
| Dependabot で更新できる | ○(既存の nix の設定で拾う) | × | × | × |
| ビルド時間 | △(初回だけ数分) | △ | ○ | △ |

nixpkgs への登録も考えたが、登録まで時間がかかるため今は見送った。

## 選んだ理由

- ほかのツールと同じく `home-manager switch` だけで全マシンに同じ版が入るようにしたかった。
- flake の入力にすると、取得するコミットと中身のハッシュが flake.lock に固定され、Dependabot(`.github/dependabot.yml` の `nix`)が nixpkgs などと同じく更新の PR を作る。依存のクレートは mdgrid の Cargo.lock のハッシュで固定される(`cargoLock.lockFile`)ので、`cargoHash` を手で持たなくて済む。
- MIT / Apache-2.0 のデュアルライセンスなので、組み込みの条件(AGENTS.md「商用ツールは呼び出すのは OK、組み込むのは NG」)を満たす。

## トレードオフ

- 入力は既定のブランチを追うので、リリースのタグではなく、Dependabot が PR を作った時点の既定のブランチの版が入る。
- 試験(`doCheck`)は省いている。疑似端末を使う試験がビルドの隔離環境で動かず、試験自体は mdgrid 側の CI で回っているため。
- 同じ名前のコマンドを別の方法でも入れているマシンでは、PATH で先にある方が動く。

## 履歴

- (2026-10-16: 導入。本ADR)
- 2026-11-20: 入力を既定のブランチからリリースのタグ(`github:S6U5/mdgrid/v0.4.0`)に変え、`nix/home.nix` に書いていたビルドの手順をやめて、mdgrid 自身の flake のパッケージ(`packages.<system>.default`)を入れるようにした。
  - 理由: 既定のブランチを追うと、リリースの前に開発中の版が入る。mdgrid は Cargo.toml の版をリリースより先に上げるので、`mdgrid --version` は新しい版を名乗るのに、中身はタグより古いことがある(実際に、v0.4.0 のタグより18コミット前のものが `0.4.0` として入っていた)。
  - 固定: 取得するコミットと中身のハッシュは、今までどおり flake.lock が固定する。タグが後から動かされても、flake.lock を更新するまで入る中身は変わらない。mdgrid の公開リポは `v*` のタグの作成・更新・削除をルールセットで管理者だけに限っている。
  - 更新: Dependabot の nix は、版の形のタグを指す入力では新しいタグを探し、`flake.nix` のタグと `flake.lock` をまとめて PR にする。cooldown の 7 日はタグにもかかるので、PR はリリースから1週間後に来る。
  - ほかに変わること: man とシェルの補完も入る(mdgrid 側の flake が入れる)。nixpkgs は `inputs.nixpkgs.follows` でこのリポのものに揃え、ビルドに使う Rust のツールチェーンは今までと同じ。
- (今後この決定が覆ったら、ここに追記していく。全面書き換えはしない)
