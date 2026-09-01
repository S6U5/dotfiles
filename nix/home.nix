{ config, pkgs, lib, ... }:
let
  # dotfiles リポジトリのルート絶対パス。home/ 配下を home.file として配布するために必要
  # (判断根拠は docs/decisions/dotfiles-distribution.md 参照)。`builtins.getEnv` は flake の
  # pure 評価では空文字になるため、呼び出し側は `--impure` を付けたうえで、事前に
  # `export DOTFILES_DIR=$(pwd)`(リポジトリルートで実行)しておく必要がある(README 参照)。
  dotfilesDir =
    let e = builtins.getEnv "DOTFILES_DIR";
    in if e != "" then e
       else throw "DOTFILES_DIR が未設定です。リポジトリルートで `export DOTFILES_DIR=$(pwd)` を実行してから home-manager switch を実行してください(README 参照)。";

  homeSrcDir = dotfilesDir + "/home";

  # home/<relPath> を Nix store にコピーせず、リポジトリ内の実体ファイルへ直接シンボリックリンクする。
  # これにより home/ を直接編集すればすぐ $HOME 側に反映される(store コピー方式だと read-only になり
  # 編集のたびに switch が必要になってしまう。LazyVim の lazy-lock.json のようにツール自身が実行時に
  # 書き込むファイルも、この方式でなければ壊れる)。
  outOfStore = relPath: config.lib.file.mkOutOfStoreSymlink "${homeSrcDir}/${relPath}";

  # home/ を再帰的に走査し、$HOME 相対パス -> home.file 定義を機械的に生成する(install.sh の
  # `find "$HOME_SRC" -type f` ループの Nix 版)。新規ファイルを home/ に追加するだけで自動的に
  # 配布対象になる。.gitignore されている local.sh / *.local は home/ に実体が無いため readDir にも
  # 現れず、何も特別扱いしなくても自動的にスキップされる。
  walkHome = dir: prefix:
    lib.concatMapAttrs
      (name: type:
        let rel = if prefix == "" then name else "${prefix}/${name}";
        in
        if type == "directory" then
          walkHome "${dir}/${name}" rel
        else if name == ".gitkeep" then
          { }
        else
          { ${rel} = { source = outOfStore rel; }; }
      )
      (builtins.readDir dir);
in
{
  # 実際のユーザー名・ホームディレクトリはハードコードしない(プライベートなパスをコミットしないという方針のため)。
  # 実行時に環境から解決する。`builtins.getEnv` は flake の pure 評価では空文字になるため、
  # 呼び出し側は `--impure` を付ける必要がある(README 参照)。
  home.username = builtins.getEnv "USER";
  home.homeDirectory = if pkgs.stdenv.isDarwin then "/Users/${config.home.username}" else "/home/${config.home.username}";

  # home-manager 自体の互換性バージョン。初回導入時に固定し、以後は変更しない(home-manager の作法)。
  home.stateVersion = "24.11";

  # home/ 配下(dotfiles本体)の配布。判断根拠・設計は docs/decisions/dotfiles-distribution.md 参照。
  # programs.zsh / programs.bash は使わない(home-managerの設定生成に依存すると、switch 未実行時に
  # 何も効かなくなるという過去の失敗があるため。docs/decisions/zshrc-pollution.md の履歴参照)。
  # ~/.bashrc / ~/.bash_profile / ~/.config/zsh/.zshrc だけは home.file にせず下記の home.activation で
  # 生成する(nvm/pyenv 等のインストーラによる追記をリポジトリ管理下ファイルに届かせないため)。
  home.file = walkHome homeSrcDir "" // {
    # herdr の agent skill を配布する(判断根拠は docs/decisions/agent-skills.md 参照)。
    # nixpkgs の herdr パッケージが postInstall で `herdr --skill` の出力を同梱しているため、
    # ストアパス参照にすればスキル本文とバイナリのバージョンが構造的に一致する
    # (npx skills 等での手動導入と違い、flake.lock の更新で herdr 本体と一緒に追従する)。
    # ~/.claude/ 配下は原則エージェント側の領域で管理対象外だが、このディレクトリのみ例外。
    ".claude/skills/herdr".source = "${pkgs.herdr}/share/herdr/skills/herdr";
  };

  # ~/.bashrc / ~/.bash_profile / ~/.config/zsh/.zshrc を「dotfiles 管理外の実ファイル」として生成する。
  # 旧 install.sh の bootstrap_file() の移植+zsh への対称展開(判断根拠は
  # docs/decisions/zshrc-pollution.md 参照)。home.file にしない理由は上記コメントの通り
  # (mkOutOfStoreSymlink のリンク越しの追記は最終実体=リポジトリ内ファイルに書き込まれてしまう。
  # nvm は ZDOTDIR を尊重して $ZDOTDIR/.zshrc に追記するため、zsh 側も実ファイル化が必要)。
  # $VERBOSE_ECHO / $DRY_RUN_CMD / $HOME_MANAGER_BACKUP_EXT は home-manager の
  # アクティベーションスクリプトが提供する規約(-v / -n / -b <拡張子> にそれぞれ対応)。
  # linkGeneration の後に実行する(旧世代で home.file 管理だった ~/.config/zsh/.zshrc の
  # シンボリックリンクが掃除された後に実ファイルを生成するため)。
  home.activation.dotfilesShellBootstrap = lib.hm.dag.entryAfter [ "writeBoundary" "linkGeneration" ] ''
    _dotfiles_bash_bootstrap_content='# このファイルは dotfiles の管理外です(意図的にシンボリックリンクにしていません)。
    # nvm/pyenv/Homebrew 等のインストーラがここへ自動追記しても、
    # 実体の設定(~/.config/bash/bashrc、dotfiles 管理下)には影響しません。
    # 判断根拠は docs/decisions/zshrc-pollution.md 参照。
    [ -r "$HOME/.config/bash/bashrc" ] && . "$HOME/.config/bash/bashrc"
    '

    _dotfiles_zsh_bootstrap_content='# このファイルは dotfiles の管理外です(意図的にシンボリックリンクにしていません)。
    # nvm 等 ZDOTDIR を尊重するインストーラがここへ自動追記しても、
    # 実体の設定(~/.config/zsh/zshrc、dotfiles 管理下)には影響しません。
    # 判断根拠は docs/decisions/zshrc-pollution.md 参照。
    [ -r "$HOME/.config/zsh/zshrc" ] && . "$HOME/.config/zsh/zshrc"
    '

    for _dotfiles_bootstrap_dest in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.config/zsh/.zshrc"; do
      case "$_dotfiles_bootstrap_dest" in
        */.config/zsh/.zshrc)
          _dotfiles_bootstrap_content=$_dotfiles_zsh_bootstrap_content
          _dotfiles_bootstrap_marker='.config/zsh/zshrc'
          ;;
        *)
          _dotfiles_bootstrap_content=$_dotfiles_bash_bootstrap_content
          _dotfiles_bootstrap_marker='.config/bash/bashrc'
          ;;
      esac

      if [ -f "$_dotfiles_bootstrap_dest" ] && [ ! -L "$_dotfiles_bootstrap_dest" ] \
        && grep -qF "$_dotfiles_bootstrap_marker" "$_dotfiles_bootstrap_dest" 2>/dev/null; then
        $VERBOSE_ECHO "dotfiles: $_dotfiles_bootstrap_dest は既にブートストラップ済みです"
        continue
      fi

      if [ -e "$_dotfiles_bootstrap_dest" ] || [ -L "$_dotfiles_bootstrap_dest" ]; then
        if [ -n "''${HOME_MANAGER_BACKUP_EXT:-}" ]; then
          $DRY_RUN_CMD mv "$_dotfiles_bootstrap_dest" "$_dotfiles_bootstrap_dest.$HOME_MANAGER_BACKUP_EXT"
          $VERBOSE_ECHO "dotfiles: $_dotfiles_bootstrap_dest を $_dotfiles_bootstrap_dest.$HOME_MANAGER_BACKUP_EXT に退避しました"
        else
          $VERBOSE_ECHO "dotfiles: スキップ: $_dotfiles_bootstrap_dest は既に存在します(home-manager switch -b <拡張子> で退避して上書きできます)"
          continue
        fi
      fi

      $DRY_RUN_CMD mkdir -p "$(dirname "$_dotfiles_bootstrap_dest")"
      $DRY_RUN_CMD sh -c "printf '%s' \"\$1\" > \"\$2\"" _ "$_dotfiles_bootstrap_content" "$_dotfiles_bootstrap_dest"
      $VERBOSE_ECHO "dotfiles: $_dotfiles_bootstrap_dest を生成しました(ブートストラップ、dotfiles管理外の実ファイル)"
    done
  '';

  # このリポジトリ自身の pre-commit フック(機密情報の事前ブロック)を有効化する。
  # 旧 install.sh 末尾のロジックの移植。dotfilesDir は Nix 側の値をそのまま文字列補間する
  # (bash 変数ではない)。
  home.activation.dotfilesGitHooks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if command -v git >/dev/null 2>&1 \
      && [ -d "${dotfilesDir}/.git" ] \
      && [ -d "${dotfilesDir}/.githooks" ]; then
      $DRY_RUN_CMD git -C "${dotfilesDir}" config core.hooksPath .githooks
      $VERBOSE_ECHO "dotfiles: ${dotfilesDir} の pre-commit フックを有効化しました(core.hooksPath = .githooks)"
    fi
  '';

  # パッケージ管理は Nix に一本化(2026-08-01。判断根拠は docs/decisions/package-management.md 参照)。
  # zsh バイナリ(ログインシェル本体)は引き続き対象外(docs/decisions/login-shell.md 参照。
  # 設定ファイルの生成元をどこにするかとログインシェル本体は独立した話)。
  # zsh-autosuggestions / zsh-syntax-highlighting は zsh の起動設定(home/.config/zsh/zshrc)から
  # ~/.nix-profile 配下のファイルを直接 source する形で使う。starship は zsh のプロンプト
  # (home/.config/zsh/zshrc で `starship init zsh` を呼ぶ)。
  # ripgrep / fd / ruff は LazyVim(home/.config/nvim)の検索機能・Python LSP が要求する依存
  # (docs/decisions/editor.md 参照)。ruff は mason(LazyVim側のツールインストーラ)経由だと
  # このMacのHomebrew Python由来のpip/venv不具合で導入に失敗するため、Nix管理に切り替えて
  # mason管理からは除外している(home/.config/nvim/lua/plugins/ 参照)。
  # nerd-fonts.jetbrains-mono は LazyVim・Starship のアイコン表示用。導入だけでは効かず、
  # ターミナルエミュレータ側でこのフォントを選択する設定も別途必要(README の
  # 「Nerd Font をターミナルで有効にする」参照)。WSL の場合、この home-manager が
  # 入れるのは WSL 内(Linux 側)のみで、Windows ネイティブの Windows Terminal 等からは
  # 見えないため、Windows 側にも別途インストールが必要(WSL 内で wsl-font-setup を
  # 実行すると自動化できる)。
  # lazygit は LazyVim のgit連携キーマップ(<leader>gg 等)が使うgit TUI。
  # delta は git diff/log/blame のシンタックスハイライトページャ。設定は
  # templates/git/.gitconfig.template 側(delta が無くても less にフォールバックする)。
  # wezterm はターミナルエミュレータ本体(判断根拠は docs/decisions/terminal-emulator.md 参照)。
  # macOS・Linux ではこれがそのままターミナルエミュレータとして動く。WSL の場合、実際に画面を
  # 描画する WezTerm は Windows ネイティブ側(winget 等で別途手動インストール、README 参照)で
  # 動くため、ここで入る WSL 内(Linux 側)の wezterm バイナリは(nerd-fonts と同様に)使わない。
  # 設定ファイルは home/.config/wezterm/wezterm.lua。
  # eza は ls の代替(アイコン・色付き表示)。ls/ll/la/lt エイリアスとして使う
  # (home/.config/shell/aliases.sh 側。無い環境では色付き ls にフォールバック)。
  home.packages = with pkgs; [
    tmux
    fzf
    shellcheck
    shfmt
    zoxide
    neovim
    ripgrep
    fd
    eza
    ruff
    herdr
    nerd-fonts.jetbrains-mono
    lazygit
    delta
    starship
    zsh-autosuggestions
    zsh-syntax-highlighting
    wezterm
  ];

  programs.home-manager.enable = true;
}
