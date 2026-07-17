# 検討事項・TODO

今後やること・決めることのメモ。決まったら CLAUDE.md に方針として昇格させる。

## シェル設定

- [ ] どのシェルを主軸にするか(zsh / bash 両対応?)
- [ ] エイリアス・関数の置き場所の構成(1ファイル? 機能別に分割?)
- [ ] OS 分岐の実装パターンを決める(`case "$(uname -s)"` を共通関数化するか)

## fzf 系コマンド

- [ ] 何を作るか洗い出し(履歴検索、ディレクトリ移動、git ブランチ切替など)
- [ ] fzf が無い場合のフォールバックをどこまで作り込むか(スキップで済ますか)

## アプリ操作コマンド

- [ ] Obsidian: URI スキーム(`obsidian://`)で何を操作するか(ノート作成、検索など)
- [ ] Vault パスなどの環境変数名の命名規則(`DOTFILES_` プレフィックスなど)
- [ ] WSL の Windows 連携(explorer / Office / PowerShell)で作るコマンドの洗い出し

## .claude / .codex / .tmux 系

- [ ] どのファイルを管理対象にするか(機密・個人情報が混ざりやすいので要精査)
- [ ] `~/.claude/settings.json` など JSON 系は symlink でよいか、マージが必要か
- [ ] tmux は既存設定と共存させるか(source 方式)、丸ごとリンクか

## install.sh / 運用

- [ ] アンインストール(リンク解除)機能を作るか
- [ ] 既存シェル設定への source 行追記を install.sh でやるか、手動にするか
- [ ] 管理ツール(chezmoi / stow / yadm)の導入検討 — 有力候補は chezmoi(OS別テンプレート分岐・機密分離・diff 確認が要件に合う)
  - [ ] 導入するなら install.sh との関係をどうするか(置き換え? 併用?)
  - [ ] 導入タイミング(ファイル数・OS分岐が増えてきたら or 早めに試す)

## リポジトリ保護・PR 運用

- [ ] main のブランチ保護を設定する(直 push 禁止、PR 経由必須)
  - [ ] CI 必須(status check)にするか
  - [ ] 個人リポジトリなのでレビュー必須はどうするか(自分しかいないので不要?)
- [ ] PR テンプレート(`.github/pull_request_template.md`)を用意するか
- [ ] CODEOWNERS は個人リポジトリでは不要か
- [ ] 公開後の外部からの PR / Issue の受け入れ方針(CONTRIBUTING.md を書くか)

## 他のエンジニアがよくやっている取り組み(導入検討)

セットアップ自動化:

- [ ] ワンライナーインストール(`curl -fsSL .../install.sh | sh` で新マシンを一発セットアップ)
- [ ] パッケージリストの管理(macOS: `Brewfile` + `brew bundle`、Linux: apt 等のリスト)でツール一式も再現可能にする
- [ ] `mise` / `asdf` で言語・ツールのバージョン管理(`.tool-versions`)

品質・テスト:

- [ ] CI で shellcheck / shfmt(lint・フォーマット強制)
- [ ] CI でインストールテスト — まっさらな Ubuntu コンテナ + macOS ランナーで `install.sh` を実走させてクロスプラットフォーム動作を自動確認

GitHub 連携:

- [ ] Codespaces / devcontainer 連携 — GitHub 設定で dotfiles リポジトリを指定すると起動時に自動適用される(`install.sh` が自動実行される)。**GitHub 側の設定が必要なので忘れないこと**

機密管理:

- [ ] age / SOPS で暗号化してコミットする方式の検討
- [ ] 1Password / Bitwarden CLI 連携(chezmoi 導入時の定番。テンプレートから実行時に注入)

見せ方・その他:

- [ ] README にスクリーンショット・機能一覧(OSS 公開時の「見せる dotfiles」化)
- [ ] `Makefile` / `justfile` で `make install` / `make test` などタスク整理
- [ ] Neovim 設定など肥大化するものは別リポジトリに分けるか検討
- [ ] GitHub のリポジトリトピックに `dotfiles` を付けて公開時に見つけやすくする(dotfiles.github.io にコミュニティの慣習まとめあり)

設定の中身でよくあるもの:

- [ ] プロンプトのカスタマイズ(starship が定番。TOML 1ファイルで全シェル・全OS共通にできる)
- [ ] `.gitconfig` の工夫 — `[include]` でローカル設定(名前・メール)を分離、diff を見やすくする delta / difftastic 導入
- [ ] ターミナルエミュレータ設定(alacritty / wezterm / ghostty)も管理対象にする
- [ ] `.editorconfig` をリポジトリに置く
- [ ] Dependabot / Renovate で GitHub Actions などのバージョン更新を自動化

## 品質・公開準備

- [ ] shellcheck を CI(GitHub Actions)で回すか
- [ ] 機密情報の混入チェック(gitleaks など)を CI に入れるか
- [ ] OSS 公開前の最終レビュー(個人情報・プライベートパスの全ファイル確認)
- [ ] README の英語化をするか
