# Neovim(LazyVim)

標準のキーバインドは `which-key.nvim` が `<leader>` 等を押して少し待つとその場で一覧表示して
くれる。ここには**標準から変更・追加した設定**だけをまとめる。

設定ファイル: `home/.config/nvim/`

kickstart.nvim ではなく **LazyVim** を採用(学習コストの観点。判断の詳細は
`docs/decisions/editor.md`)。

## よく使うコマンド・キーバインド

### 保存・終了(Vim基本)

| コマンド | 内容 |
|---|---|
| `:w` | 保存 |
| `:q` | 終了(未保存の変更があると失敗) |
| `:q!` | 保存せずに強制終了 |
| `:wq` / `:x` | 保存して終了 |
| `ZZ`(ノーマルモード) | 保存して終了(`:wq`と同じ) |
| `ZQ`(ノーマルモード) | 保存せず終了(`:q!`と同じ) |

### コピー・クリップボード

LazyVimは `clipboard = "unnamedplus"` を標準設定しているため(SSH接続時を除く)、ヤンクは
自動でOSのクリップボードと同期される(`"+y` 等を明示する必要は無い)。

| コマンド | 内容 |
|---|---|
| `ggyG` | ファイル全文をヤンク(コピー) |
| `:%y` | 同上(Exコマンド版) |

### LazyVim管理系(Exコマンド)

| コマンド | 内容 |
|---|---|
| `:Lazy` | プラグイン管理UI(インストール状況・更新) |
| `:Mason` | LSP/フォーマッタ/リンタのインストールUI |
| `:LazyExtras` | 公式extraの一覧・有効化(このリポジトリでは基本 `lua/plugins/extras.lua` に明示するので通常は不要) |
| `:checkhealth lazyvim` | 依存ツール(git/rg/fd/lazygit/fzf等)の健全性チェック |

### ファイル移動・検索(leader = `<space>`)

| キー | 内容 |
|---|---|
| `<space>e` / `<space>E` | Explorer(root dir / cwd)の開閉 |
| `<space>ff` / `<space><space>` | ファイル検索(root dir) |
| `<space>fF` | ファイル検索(cwd) |
| `<space>fb` | 開いているバッファ一覧 |
| `<space>fr` | 最近使ったファイル |
| `<space>sg` / `<space>/` | 全文検索 grep(root dir) |
| `<space>sG` | 全文検索 grep(cwd) |
| `Alt+h`(検索・Explorer内) | 隠しファイル表示のトグル(このリポジトリはデフォルトで表示済み) |

### コード編集・LSP

| キー | 内容 |
|---|---|
| `gd` | 定義へジャンプ |
| `gr` | 参照を検索 |
| `K` | ホバー(ドキュメント表示) |
| `<space>ca` | コードアクション |
| `<space>cr` | リネーム |
| `<space>cm` | Mason UIを開く |

### Git

| キー | 内容 |
|---|---|
| `<space>gs` | Git Status |
| `<space>gd` | Git Diff(hunks) |

`<space>gg` 等のgit TUI起動キーは今は未設定。`lazygit`はシェルから直接起動する運用(下記「依存ツール」参照)。

## 言語サポート(LSP)

| 言語 | 方式 | 補足 |
|---|---|---|
| TypeScript / JavaScript | 公式extra(`lazyvim.plugins.extras.lang.typescript`) | `lua/plugins/extras.lua` |
| Python | 公式extra(`lazyvim.plugins.extras.lang.python`) | pyright + ruff |
| HTML / CSS | 手動追加 | `lua/plugins/lsp-extra-servers.lua`(`html` / `cssls`)。LazyVim公式extrasには存在しない |
| PowerShell(ps1) | 手動追加 | 同上(`powershell_es`) |
| Lua(この設定ファイル自体) | 追加設定不要 | 同梱の `lazydev.nvim` が nvim 設定ディレクトリ内を自動検知して `lua_ls` を構成する |

## フォーマット(保存時自動整形)

- CSS / HTML / JS / TS / JSON / Markdown / YAML: `prettier`(公式extra `lazyvim.plugins.extras.formatting.prettier`)
- Lua: `stylua`(LazyVim標準)
- Shell: `shfmt`(LazyVim標準)
- Python: `ruff` が整形も兼務(追加設定不要)

## lint(診断)の対応状況

- Python(`ruff`)・PowerShell(`powershell_es` 内蔵の PSScriptAnalyzer)は LSP診断経由で既にカバー
- **TypeScript/JS の ESLintルール**(型エラーとは別)と **CSS の stylelint** は未設定。前者は公式extra `lazyvim.plugins.extras.linting.eslint` があるが今回は未追加。後者はLazyVimに公式extra自体が無いため手動設定が必要

## ファイルエクスプローラー

- `<leader>e`(root dir)/ `<leader>E`(cwd)で開閉できる(`snacks.nvim` 内蔵の Explorer。LazyVim標準のデフォルトピッカー/エクスプローラーとして最初から有効)。ファイルを開くには `Enter`
- `<leader>ff` / `<leader><space>` でファイル検索、`<leader>sg` / `<leader>/` で全文検索(grep)

## 依存ツール

- `ripgrep` / `fd` / `ruff`: `nix/home.nix` で全OS共通管理(2026-08-01 に Nix へ一本化。`packages/` は完全廃止)
- Nerd Font: `nix/home.nix` に `nerd-fonts.jetbrains-mono` を追加済み。**ただし導入だけでは表示されず、ターミナルエミュレータ側でこのフォント(`JetBrainsMono Nerd Font Mono` 等)を選択する設定が別途必要**(macOS標準Terminal.appの場合: 設定 → プロファイル → テキスト → フォントの変更)
- `lazygit`: `nix/home.nix` で導入済みだが、**LazyVim側にキーバインドはまだ無い**(現行LazyVimの `<leader>gg` は `lazygit` ではなく別のgit TUI `gitui` を使う `lazyvim.plugins.extras.util.gitui` extra 用で、今回は未導入)。今のところシェルから `lazygit` を直接起動する運用。nvim統合が欲しい場合は `util.gitui` extraを導入するか(その場合 `gitui` も別途必要)、自前で `lazygit` 用のキーマップを追加する

## 解決済みの問題(参考)

- このMacでは、Homebrew の `python@3.14` が macOS 側の `libexpat` とバージョン不整合を起こしており、mason経由の `ruff` インストールが `ensurepip` の段階で失敗していた。`ruff` を Nix(`nix/home.nix`)管理に切り替え、`lua/plugins/lsp-extra-servers.lua` で `servers.ruff = { mason = false }` を設定して mason 管理から除外することで解決した
