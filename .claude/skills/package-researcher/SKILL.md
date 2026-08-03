---
name: package-researcher
description: >-
  nix/home.nix(home.packages)で管理しているツールについて、upstream(公式リポジトリ)の
  メンテナンス状況と nixpkgs 側のパッケージの健全性を調査し、追加してよいか判定するスキル。
  新しいツールを nix/home.nix に追加したいとき、「〇〇 入れて」のように依頼側で決まっている
  ように見える場合や、一見1行追記するだけの単純な依頼に見える場合でも必ず使うこと。既存の
  home.packages のエントリが古い判断のままになっていないか棚卸ししたいとき、ツールが
  メンテモード入り・アーカイブされていないか気になったときにも使う。ツール名を明示していなくても
  「このツール最近使われてる?」「まだ更新されてる?」のような開発状況への疑問にも積極的に使う。
---

# package-researcher

## これは何のためのスキルか

このリポジトリはパッケージ管理を Nix + home-manager に一本化している(判断根拠は
`docs/decisions/package-management.md`)。nixpkgs はディストリビューションを問わず単一の
ソースなので、かつての「brewでは推奨だがaptでは非推奨」のようなOS別の分岐判断は無くなった。
一方で、**nixpkgs にパッケージがあるからといって健全とは限らない**(upstreamがアーカイブ済み、
nixpkgs側で `broken` フラグが付いている、更新が長期間止まっている等)。このスキルは、追加前に
その健全性を毎回きちんと確認した上で調査・判定・実装まで行う。

## ワークフロー

対象ツールが1つでも複数(既存 `nix/home.nix` の棚卸しなど)でも、各ツールについて以下を順に行う。

### 1. upstream(公式リポジトリ)のメンテナンス状況を調べる

- GitHub の場合: リポジトリが **Archived** になっていないか、直近のコミット・リリース日時、
  README やピン留めされた Issue に "unmaintained" / "looking for maintainers" / "deprecated"
  のような記載が無いかを確認する。
- `gh api repos/<owner>/<repo> --jq '.archived, .pushed_at'` で確認するか、`gh` が無ければ
  WebFetch でリポジトリのトップページを見る。

### 2. nixpkgs 側のパッケージの健全性を調べる

- `nix search nixpkgs '^<パッケージ名>$'` でパッケージが存在するか確認する(evaluate に時間が
  かかることがあるので、`Bash` の `timeout`/バックグラウンド実行や `nix-search.nixos.org` の
  API(`search.nixos.org`)を使ってもよい)。
- パッケージが `broken = true` 等のフラグ付きでないか、nixpkgs の該当 `.nix` ファイル
  (`gh api` で `nixos/nixpkgs` リポジトリを検索)や [search.nixos.org](https://search.nixos.org)
  のページ上の警告表示を確認する。
- 明示的な非推奨(例: upstream自身が「Nixでの配布は非公式・非推奨」と明言しているケース)が
  無いかも確認する。無ければ通常は OK と判断してよい。

### 3. 調査結果をこの形式の表で報告する

実装に進む前に、必ずこの表を提示してユーザーの確認を取ること(このリポジトリの運用では、
調査→提案→承認を得てから実装、という進め方が好まれている)。

| ツール | upstreamのメンテ状況 | nixpkgsでの状況 | 判定・推奨アクション |
|---|---|---|---|
| 例: ripgrep | 活発(非アーカイブ) | 存在・brokenフラグなし | `nix/home.nix` の `home.packages` に追加 |

「判定・推奨アクション」列は次の3パターンのいずれかに落とし込む:

- **A. そのまま追加**: upstream活発・nixpkgsで健全 → `nix/home.nix` に追記するだけ
- **B. 導入自体を見送る/再検討**: upstreamがメンテ停止・アーカイブ済み、nixpkgsで`broken`、
  または代替ツールがある
- **C. 判断材料不足**: 情報が曖昧 → 正直にそう報告し、ユーザーに判断を仰ぐ

### 4. 承認後の実装

ユーザーの承認を得てから、`nix/home.nix` の `home.packages` リストにパッケージ名を追記する
(既存のエントリと同じ形式に揃える。用途がひと目で分かるようコメントを添える)。

- 追記後は `home-manager switch --flake ./nix#<system> --impure` で実機に反映し、実際に導入
  できることを確認する(可能な環境であれば)。
- `TODO.md` に決定事項として1行〜数行で記録する(既存エントリを参考にしたフォーマットで、
  背景・判断が後から追えるようにする)。
- LSPサーバーやランタイムツールなど、他のツール(mason.nvim 等)が独自にインストールしようと
  する対象と重複する場合は、そちらを無効化して Nix 管理下のものを使わせる設定も忘れずに行う
  (実例: `home/.config/nvim/lua/plugins/` での `mason = false` オーバーライド)。

## 注意点

- `nix/home.nix` の変更は `home-manager switch --flake ./nix#<system>` を **明示的に実行した
  ときだけ**反映される(CLAUDE.md の「明示的に実行したときだけ動く」方針。install.sh /
  update.sh からは呼ばれない)。
- 機密情報・個人情報を一切コメントに含めない(CLAUDE.md 最重要ルール)。
- 迷ったら `references/repo-conventions.md` にこのリポジトリの関連方針をまとめてあるので参照する。
