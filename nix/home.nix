{ config, pkgs, ... }:
{
  # 実際のユーザー名・ホームディレクトリはハードコードしない(プライベートなパスをコミットしないという方針のため)。
  # 実行時に環境から解決する。`builtins.getEnv` は flake の pure 評価では空文字になるため、
  # 呼び出し側は `--impure` を付ける必要がある(README 参照)。
  home.username = builtins.getEnv "USER";
  home.homeDirectory = if pkgs.stdenv.isDarwin then "/Users/${config.home.username}" else "/home/${config.home.username}";

  # home-manager 自体の互換性バージョン。初回導入時に固定し、以後は変更しない(home-manager の作法)。
  home.stateVersion = "24.11";

  # パッケージ管理は Nix に一本化(2026-08-01。判断根拠は docs/decisions/package-management.md 参照)。
  # dotfiles 自体は基本的にここでは配布しない(home/ のシンボリックリンクに任せ、
  # install.sh との責務重複を避ける)。zsh の設定内容(.zshrc/.zshenv)も含め home/ 側で
  # 管理する(oh-my-zsh 廃止に伴い、home.file 書き込みによる手動シンボリックリンクとの
  # 衝突が解消されたため。判断根拠は docs/decisions/zshrc-pollution.md の履歴、
  # docs/decisions/package-management.md の履歴参照)。
  # zsh バイナリ(ログインシェル本体)は引き続き対象外(docs/decisions/login-shell.md 参照。
  # 設定ファイルの生成元をどこにするかとログインシェル本体は独立した話)。
  # zsh-autosuggestions / zsh-syntax-highlighting は zsh の起動設定(home/.config/zsh/.zshrc)から
  # ~/.nix-profile 配下のファイルを直接 source する形で使う。starship は zsh のプロンプト
  # (home/.config/zsh/.zshrc で `starship init zsh` を呼ぶ)。
  # ripgrep / fd / ruff は LazyVim(home/.config/nvim)の検索機能・Python LSP が要求する依存
  # (docs/decisions/editor.md 参照)。ruff は mason(LazyVim側のツールインストーラ)経由だと
  # このMacのHomebrew Python由来のpip/venv不具合で導入に失敗するため、Nix管理に切り替えて
  # mason管理からは除外している(home/.config/nvim/lua/plugins/ 参照)。
  # nerd-fonts.jetbrains-mono は LazyVim のアイコン表示用。導入だけでは効かず、
  # ターミナルエミュレータ側でこのフォントを選択する設定も別途必要。
  # lazygit は LazyVim のgit連携キーマップ(<leader>gg 等)が使うgit TUI。
  # delta は git diff/log/blame のシンタックスハイライトページャ。設定は
  # templates/git/.gitconfig.template 側(delta が無くても less にフォールバックする)。
  home.packages = with pkgs; [
    tmux
    fzf
    shellcheck
    shfmt
    zoxide
    neovim
    ripgrep
    fd
    ruff
    herdr
    nerd-fonts.jetbrains-mono
    lazygit
    delta
    starship
    zsh-autosuggestions
    zsh-syntax-highlighting
  ];

  programs.home-manager.enable = true;
}
