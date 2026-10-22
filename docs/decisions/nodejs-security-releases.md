# Node.js のセキュリティリリースへの追従

nixpkgs の `nodejs` は多くのパッケージの依存元のため、更新が `staging` を経由し、unstable に届くまで 2〜3 週間かかることがある(例: 2026-10-21 の 24.22.1 は、公開当日に staging へ入ったが unstable は 24.21.0 のままだった)。その間の穴をどう塞ぐかの決定。

## 検討した代替

| 観点 | 遅れを受け入れる | mise / fnm 等で各自導入 | 公式バイナリで補う + PR 自動作成 | **公式バイナリで補う + 検知のみ自動(採用)** |
| --- | --- | --- | --- | --- |
| 修正版が入るまで | × 2〜3 週間 | ○ 即日(ただし手で上げる) | ○ 即日 | ○ 即日(通知後に手でコマンド1つ) |
| 既存方針との整合 | ○ | × Nix 一本化・バージョン管理ツール不採用(`package-management.md` / `dependency-tooling-scope.md`)に反する | ○ | ○ |
| Actions に必要な権限 | — | — | × `contents` / `pull-requests` の書き込み + GitHub App の秘密鍵 | ○ 読み取りのみ |
| nixpkgs が追いついた後 | — | — | ○ 自動で nixpkgs 版に戻る | ○ 自動で nixpkgs 版に戻る |

## 選んだ理由

- `nix/home.nix` は `nix/nodejs-bin.json` のバージョンと nixpkgs の `nodejs` を比べ、nixpkgs が古いときだけ nodejs.org の公式バイナリ(`nix/nodejs-bin.nix`)を使う。nixpkgs が追いつけば Dependabot の flake.lock 更新だけで元に戻るので、外し忘れで更新が止まることがない。`nodejs-bin.json` は次のセキュリティリリースまで古いまま残してよい。
- ソースからのビルド(`overrideAttrs` で src を差し替える)はバイナリキャッシュが効かず、マシンごとに数十分かかるため採らない。
- 検知(`.github/workflows/nodejs-security.yml`)は毎日、nodejs.org の `index.json` の `security` フラグで判定し、遅れていればジョブを失敗させて通知に使う。年に数回しか動かない仕組みのために書き込み権限を常設するのは、サプライチェーン対策の方針と釣り合わない。PR のマージはどちらの案でも手動なので、手間の差はコマンド1回だけ。
- `scripts/nodejs-security.sh update` は `SHASUMS256.txt.asc` を Node.js のリリース鍵(nodejs.org とは別経路の `nodejs/release-keys`)で検証してからハッシュを書き込む。検証できなければ書き込まない。

## トレードオフ

- 差し替え中に出た通常リリース(セキュリティ以外)は追わない。nixpkgs が追いつくまで、セキュリティリリース時点のバージョンに留まる。
- 公式バイナリに同梱の npm を使うため、差し替え中は nixpkgs 版と npm のバージョンが異なることがある(`home/.npmrc` の `min-release-age` は npm 11.5.1+ が必要。24.22.1 同梱は 11.19.1)。
- 公開リポジトリのスケジュール実行は、60 日間リポジトリに動きが無いと GitHub に止められる。Dependabot の PR をマージしていれば通常は止まらない。
- スケジュール実行の失敗通知は、ワークフローを作った人(cron を変更した人、無効化→再有効化した人がいればその人)にしか届かず、受け取る側で Actions の通知設定を有効にしておく必要がある。届かない場合の保険として、`update.sh`(`dotfiles-update`)の実行時にも同じ判定をして警告を出す(判定できないときは何も出さない)。Issue での通知は、見る習慣が無ければ気づけないため採らなかった。
- 対象は `nix/nodejs-bin.nix` の対応表にある 3 システム(x86_64-linux / aarch64-linux / aarch64-darwin)のみ。flake の対象システムを増やしたら対応表も増やす。

## 履歴

- (本 ADR): 2026-10、Node.js 2026-10-21 セキュリティリリース(CVE-2026-111497 ほか)への対応をきっかけに決定
- (今後この決定が覆ったら、ここに追記していく。全面書き換えはしない)
