# Node.js のセキュリティリリースへの追従

nixpkgs の `nodejs` は多くのパッケージの依存元のため、更新が `staging` を経由し、unstable に届くまで数週間かかることがある(例: 2026-10-21 公開の 24.22.1 は、公開当日に staging へ入ったが、2026-11 上旬になっても unstable は 24.21.0 のままだった)。その間の穴をどう塞ぐかの決定。

## 検討した代替

| 観点 | 遅れを受け入れる | mise / fnm 等で各自導入 | 公式バイナリ + 固定値を git に置いて PR で配る | **公式バイナリ + 固定値を各マシンが git 管理外に書く(採用)** | switch のたびに最新を自動で取る |
| --- | --- | --- | --- | --- | --- |
| 修正版が入るまで | × 数週間 | ○ 即日(手で上げる) | ○ 即日 | ○ 次の `dotfiles-update` | ○ 次の switch |
| リリースごとの作業 | なし | 各マシンで手動 | コマンド + PR + マージ | **なし**(いつもの `dotfiles-update`) | なし |
| 既存方針との整合 | ○ | × Nix 一本化・バージョン管理ツール不採用(`package-management.md` / `dependency-tooling-scope.md`)に反する | ○ | ○ | △ |
| オフラインで switch | ○ | ○ | ○ | ○ | × 評価中にネットへ出るため失敗する |
| 再現性・記録 | ○ | × | ○ コミットに残る | △ マシンごとのファイルだけ | × 同じコミットでも日によって変わる |
| 遅れの通知 | — | — | Actions の失敗メール(届く相手と設定に条件がある) | 不要(取り込みまで自動) | 不要 |

## 選んだ理由

- `dotfiles-update`(`update.sh`)は pull と switch を1回で行うので、そのあいだで遅れを調べて取り込めば、いつもの1コマンドがそのまま対策になる。リリースのたびのコミットも PR も、遅れを知らせる仕組みも要らない。
- 固定値(バージョンと 3 環境分のハッシュ)は git 管理外の `nix/nodejs-bin.local.json` に書く。`nix/home.nix` は nixpkgs の `nodejs` がこれより古いときだけ公式バイナリ(`nix/nodejs-bin.nix`)を使う。nixpkgs が追いつけば Dependabot の flake.lock 更新だけで元に戻るので、ファイルは古いまま残っていてよい。
- `scripts/nodejs-security.sh update` は `SHASUMS256.txt.asc` を Node.js のリリース鍵(nodejs.org とは別経路の `nodejs/release-keys`)で検証してからハッシュを書く。検証できなければ書かず、nixpkgs 版のまま進む。入れる前には Nix がそのハッシュで tarball を照合する。
- ネットに出るのは `dotfiles-update`(もともと `git pull` でネットを使う)だけで、switch は手元のファイルを読むだけなので、オフラインでも switch は失敗しない。
- 公式バイナリが合わないマシンは、`DOTFILES_NODEJS=nixpkgs`(`local.sh` に書けばそのマシンだけ)で nixpkgs 版に固定できる。逆向きの「公式バイナリに固定」は作らない。固定値はセキュリティリリースのときにしか更新されないため、nixpkgs が先に進んだあとも古い版に留まってしまう。
- ソースからのビルド(`overrideAttrs` で src を差し替える)はバイナリキャッシュが効かず、マシンごとに数十分かかるため採らない。
- 固定値を git に置いて PR で配る案は、1 回のマージで全マシンに届く利点はあるが、毎回の PR の手間と、遅れを知らせる仕組み(Actions の失敗メール。スケジュール実行の通知はワークフローを作った人・cron を変えた人・再有効化した人にしか届かず、受け取る側の通知設定も要る)が必要になる。Actions に書き込み権限を置いて PR まで自動化する案は、年に数回のためにサプライチェーン対策の方針と釣り合わない権限を常設することになる。

## トレードオフ

- 各マシンがそれぞれ取り込む(結果は同じバージョンになる)。どのマシンがいつ取り込んだかはコミットに残らない。今どちらの Node かは `scripts/nodejs-security.sh status` で見る。
- 差し替え中に出た通常リリース(セキュリティ以外)は追わない。nixpkgs が追いつくまで、セキュリティリリース時点のバージョンに留まる。
- 公式バイナリに同梱の npm を使うため、差し替え中は nixpkgs 版と npm のバージョンが異なることがある(`home/.npmrc` の `min-release-age` は npm 11.5.1+ が必要。24.22.1 同梱は 11.19.1)。
- Linux 版は patchelf で Nix の libc / libstdc++ に向け直す。patchelf 0.19.2 では、interpreter を書き換えたあとに RUNPATH を書き換えると node が起動時に segfault する(`autoPatchelfHook` の順番)ため、順番を固定して自前で呼ぶ。固定値が無い CI では切り替えが使われないので、`scripts/test-home-manager.sh` が `scripts/fixtures/nodejs-bin.json` でビルドと起動を毎回確かめる。
- 対象は `nix/nodejs-bin.nix` の対応表にある 3 システム(x86_64-linux / aarch64-linux / aarch64-darwin)のみ。flake の対象システムを増やしたら対応表も増やす。

## 履歴

- (本 ADR): 2026-11、Node.js 2026-10-21 セキュリティリリース(CVE-2026-111497 ほか)への対応をきっかけに決定
- (今後この決定が覆ったら、ここに追記していく。全面書き換えはしない)
