# docs/assets/

README に埋め込む画像置き場。`<img src="docs/assets/*.svg">` で直接埋め込んでいる(PNG化は不要。同一リポジトリ内の相対パスなら GitHub は `<img>` で正しく描画する)。

## stack.svg — 実行時構造図

ターミナルエミュレータを開く → ログインシェル(zsh)が起動 → そこから herdr を起動 → そのペインの中で Neovim・fzf・zoxide などのCLIが動く、という実際の起動順序を1本の縦フローで示した図。herdr はキーバインド・操作感を tmux に寄せているだけで、tmux 自体を別途起動する構成ではないため、tmux は図に出していない(判断の詳細は `docs/decisions/terminal-multiplexer.md` 参照。tmux 自体は herdr 非対応環境向けに Nix でも導入はしている)。

- 青枠(herdr・CLIアプリの2ボックス)は Nix + Home Manager が導入・設定を管理する範囲を外側から点線で囲んで示している。点線の外(ターミナルエミュレータ・zsh)はOS標準の環境をそのまま利用しており、Nixでは管理しない。
- Claude Code・Git・Docker・ripgrep・Python はこの図には含めていない。作業環境そのものの構成要素ではなく、周囲(OS標準・システムのパッケージマネージャ等)に合わせて使えば動く部類のため、Nix管理・図示のどちらの対象にもしていない(Claude Code は加えて `CLAUDE.md`「商用ツールは呼び出すのはOK、組み込むのはNG」の対象外規定もある)。lazygit のNix管理化は保留中。

## config-placement.svg — 設定ファイル配置図

`install.sh` が `home/` 以下のファイルを `$HOME` へどうシンボリックリンクするかを、代表的なファイルの対応関係で示した図。「リポジトリ構成」節のツリーの視覚版。

## 注意点

- インライン `<svg>...</svg>` をREADME本文に直接貼り付ける方式は不可(GitHubのHTMLサニタイザがSVG要素自体を許可リストから除外しており、まるごと消される)。`<img src="相対パス">` でファイルとして参照する形のみ有効。
- `<picture>` + `prefers-color-scheme` でのライト/ダーク出し分けは避けている。`<source srcset>` はエディタのプレビュー(例: Markdown Preview Enhanced の `crossnote`)では `img[src]` / `a[href]` しか解決されずパス解決に失敗するため、単一画像・固定背景にして GitHub・ローカルプレビュー両方で確実に表示されるようにしている(`stack.svg` は黒、`config-placement.svg` は白と、図ごとに固定背景色は異なる)。
