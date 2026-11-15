# pnpm の入れ方(corepack でプロジェクトの版を使う)

npm は Node.js に同梱のものを使う。pnpm は、使うプロジェクトがそれぞれ `package.json` の `packageManager` で版を決めている(同じマシンの中でも 9 系や 10 系が混ざる)。npm だけのプロジェクトも多い。yarn は使わない。それまでは Homebrew の node に `npm -g` で pnpm と yarn を入れていたが、Nix の node へ寄せるにあたって入れ方を決め直した。

| 観点 | nixpkgs の `pnpm`(12 系)を入れる | nixpkgs の `pnpm_10` を入れる | **nixpkgs の `corepack` の pnpm の入口だけを出す(採用)** | `npm -g` で入れる |
| --- | --- | --- | --- | --- |
| プロジェクトが決めた版で動く | △ pnpm 自身の版の切り替え(`manage-package-manager-versions`)に頼る | △ 同左 | ○ `packageManager` の版を取ってきて使う | △ |
| 版を上げる手間 | flake.lock 任せ(nixpkgs は upstream より数週遅れる) | 同左。いずれ 12 系への移行が要る | プロジェクトの `packageManager` を上げるだけ | 手で上げる。lockfile も無い |
| Node.js の版から独立 | ○ | ○ | ○ 単体のパッケージ(Node.js 25 以降は corepack を同梱しない) | × node ごとに入れ直し |
| 取ってくるものの検証 | Nix のハッシュ | Nix のハッシュ | npm の署名を既定で確かめる(`COREPACK_INTEGRITY_KEYS`) | npm 任せ |

## 選んだ理由

- 版を決めるのはプロジェクトなので、グローバルに1つの版を固定して入れる意味が薄い。corepack は `packageManager` を読んでその版を使い、違う道具を打つと止まる(strict が既定)。`package.json` に勝手に `packageManager` を書き足す機能(auto pin)は既定で切れている。
- nixpkgs の `corepack` は `pnpm`・`pnpx`・`yarn` の入口をまとめて置くが、yarn は使わないので、`corepack` 本体と pnpm の入口だけを `runCommand` で出す(`nix/home.nix` の `corepackPnpm`)。yarn が要るプロジェクトに出会ったら `corepack yarn …` で使える。
- npm は corepack の入口に含めず、Node.js 同梱のものをそのまま使う(npm だけのプロジェクトの使い方は変わらない)。
- nixpkgs の node にも `bin/corepack` があるため、単体の corepack を `lib.hiPrio` で優先する。

## トレードオフ

- 初めて使う版は、そのときにネットから取ってくる(`~/.cache/node/corepack`)。プロジェクトの外では npm の最新版を使う(`COREPACK_DEFAULT_TO_LATEST`)。
- pnpm の設定は版で読むファイルが違う: 10 までは `~/.config/pnpm/rc`(`minimum-release-age`)、11 以降は `~/.config/pnpm/config.yaml`(`minimumReleaseAge`)。どちらの版も動くので、同じ値を両方に置く。
- 公開からの待ち時間(`minimumReleaseAge`)は pnpm 10.16 以降にしか無い。それより古い版を `packageManager` で決めているプロジェクトでは効かないので、効かせたいならプロジェクト側で版を上げる(corepack にする前から、pnpm 10 がプロジェクトの版へ切り替えていたので同じ状況だった)。

## 履歴

- (本 ADR): 2026-11、Homebrew の node をやめて Nix の node に寄せるときに決定
- (今後この決定が覆ったら、ここに追記していく。全面書き換えはしない)
