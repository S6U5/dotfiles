# エディタは Neovim、Linux/WSL は公式 tarball で導入

## 検討した代替(エディタ本体)

| 観点 | Neovim(採用) | VSCode + Vim拡張 | Claude/Codex 内蔵編集 | Zed | Cursor |
|---|---|---|---|---|---|
| ターミナル中心ワークフロー(Wezterm/tmux)との相性 | ○ | △ | ×(画面分割の都合と噛み合わない) | △ | △ |
| 起動速度(ターミナルから開いてファイルが見えるまで) | ○(即時) | ×(`code` 起動から表示までタイムラグがある) | ー | ○ | × |
| プレビュー・拡張機能の手軽さ | △ | ○ | ー | ×(拡張機能が少ない) | ○ |
| 現状の慣れ・使用頻度 | △(まだ移行中) | ○(実は一番愛用している) | ×(使い慣れていない) | ×(乗り換えるほどエディタを開かない) | ー |
| 複数画面分割(ペイン分割)での作業のしやすさ | ○ | ○ | × | ○ | ○ |
| コスト | 無料 | 無料 | ー | 無料 | ×(有料契約が前提。契約しておらず予定もない) |
| 現時点の判断 | 採用(段階的移行) | 併用継続。まずは VSCode に Vim 拡張を入れることを検討中 | 不採用(通常のエディタの代替にはしない) | 不採用 | 不採用 |

Linux/WSL への Neovim 導入方法(`apt` / unstable PPA / 公式 GitHub Releases tarball / bob / AppImage)も比較したが、こちらは代替候補が一本(公式 tarball)に絞れたため表にはせず後述の理由のみ記載。

## 選んだ理由

- VSCode は実際には一番愛用しているエディタで、プレビューや拡張機能の手軽さから使い続けている。ただしターミナルから `code` で起動してファイルが表示されるまでのタイムラグがあり、ターミナル中心ワークフローでは無視できないため、メインは Neovim(kickstart.nvim)へ段階的に移行する方針にした。
- 移行の第一歩として、VSCode 側にも Vim 拡張を入れることを検討中(Neovim に完全移行する前のつなぎとして)。
- Zed は拡張機能がまだ少なく、そもそも乗り換えを検討するほど頻繁にエディタを開く使い方をしていないため見送り。
- Cursor は単純に契約しておらず、契約する予定も今のところないため見送り(機能面の評価以前の話)。
- `apt` 版の Neovim は Ubuntu LTS だと数世代古く、kickstart.nvim / LazyVim が要求する新しめのバージョンでは動かない可能性が高いため除外。
- macOS は Homebrew(常に最新)、Linux/WSL は公式 GitHub Releases の tarball を `~/.local` に展開する方式に統一(`packages/neovim-install.sh`)。sudo 不要・常に最新・更新は再実行するだけ。

## トレードオフ

- バージョン切り替え(複数バージョン共存)が必要になったら bob を検討する。
- Raspberry Pi(ARM)は公式 arm64 ビルドの対応状況を要確認。
- kickstart.nvim ベースの設定自体はまだ未着手(段階的導入中)。

## 履歴

- (Atom → VSCode): GitHub が Microsoft に買収された後 Atom 自体が廃止されたため VSCode に移行
- (VSCode → Neovim、本ADR): 上記の理由により決定
- (2026-07-31: Nix + home-manager が基本(推奨)の導入経路になったため、`nixpkgs-unstable` 経由で Linux/WSL でも常に新しいバージョンが入るようになり、apt が古い問題は Nix 経由では発生しなくなった。`packages/neovim-install.sh`(公式 tarball)は `packages/` を選んだ場合のフォールバックとして引き続き必要。判断根拠は `package-management.md` 参照)
- (2026-08-01: `home/.config/nvim/init.lua` の実装段階で、当初想定していた kickstart.nvim ではなく **LazyVim** を採用。kickstart.nvim は「読んで理解しながら育てる最小の出発点」、LazyVim は「プリセットで最初から高機能な既製ディストリビューション」という違いがあり、素早く使える状態にしたい・学習コストを抑えたいという理由で LazyVim を選んだ(トレードオフとして、中身のブラックボックス化はkickstart.nvimより進む)。導入は公式スターター `LazyVim/starter` を `home/.config/nvim/` にほぼそのまま配置する形(ライセンスは Apache-2.0)。プラグイン管理は `lazy.nvim`(初回起動時に自己ブートストラップ)。付随して `ripgrep`・`fd` を依存ツールとして追加。詳細は `TODO.md` 参照)
- (2026-08-01: 同日中に `packages/`(Brewfile / apt.txt / neovim-install.sh / fd-install.sh)を完全廃止し Nix に一本化。Neovim本体・`ripgrep`・`fd` は全OS共通で `nix/home.nix` 経由の導入のみになった。判断根拠は `package-management.md` 参照)
- (2026-08: lazy.nvim(LazyVimのプラグイン管理)をNix化するかどうかを検討し、見送り。zsh(oh-my-zsh)のNix化と違い、lazy.nvimは `home/` 側のファイルと衝突しておらず、無理に移行する技術的必然性が無いため。調査した代替: `nixvim`(nix-community、star 2,897、活発)は独自のプラグイン宣言方式(`plugins.<name>.enable`)でLazyVimの `lua/plugins/*.lua` とは別パラダイムのためそのままでは動かず書き直しが必要、かつ遅延読み込みがまだ「実験的」段階。ハイブリッド構成(nixvim内でlazy.nvimを使い続ける)の実例(`azuwis/lazyvim-nixvim`)は最終更新1年半以上前でメンテ状況に不安、別の実例(`matadaniel/LazyVim-module`)は比較的最近まで動いている。LazyVimとの親和性を重視するなら公式にLazyVim向けテンプレートがある `nixCats-nvim` の方が現実的な候補。結論: 投資対効果が今のところ見合わないため見送り、着手するなら `nixCats-nvim` から検討する)
- (2026-08: mason 経由の `ruff` インストールが Mac 実機で失敗する問題を解決。原因は Homebrew `python@3.14` がビルド時に想定した `libexpat`(2.7以降で追加されたシンボル必要)と、macOS 26.2 のシステム標準 `libexpat` のバージョン不一致(`brew upgrade python@3.14` では解消せず)。`nix/home.nix` に `ruff` を追加してNix管理下のバイナリを使わせ、`home/.config/nvim/lua/plugins/lsp-extra-servers.lua` で `servers.ruff = { mason = false }` を設定してmason管理から除外することで解決。実機で `ruff` LSPクライアントの正常attach・mason再試行が発生しないことを確認済み)
- (今後この決定が覆ったら、ここに追記していく。全面書き換えはしない)
