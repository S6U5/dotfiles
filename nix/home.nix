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
  # install.sh との責務重複を避ける)。ただし zsh の設定内容(.zshrc/.zshenv)だけは例外で、
  # 下記 programs.zsh が生成する(理由: oh-my-zsh 等のフレームワークが .zshenv に home.file で
  # 書き込む設計のため、手動シンボリックリンクと構造的に衝突する。判断根拠は
  # docs/decisions/zshrc-pollution.md の履歴、docs/decisions/package-management.md の履歴参照)。
  # zsh バイナリ(ログインシェル本体)は引き続き対象外(docs/decisions/login-shell.md 参照。
  # 設定ファイルの生成元をどこにするかとログインシェル本体は独立した話)。
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
  ];

  programs.home-manager.enable = true;

  # zsh 設定(2026-08 追加。判断根拠は docs/decisions/zshrc-pollution.md 履歴参照)。
  # dotDir は旧 home/.zshenv が設定していた ZDOTDIR と同じ値。~/.zshenv は
  # home-manager がスタブ(ZDOTDIR設定 + このdotDirをsource)を自動生成するので、
  # 旧アーキテクチャと同じ「$HOME直下はこの1ファイルのみ」という汚染対策が保たれる。
  programs.zsh = {
    enable = true;
    dotDir = ".config/zsh";

    history = {
      path = "$HOME/.zsh_history";
      size = 10000;
      save = 10000;
      share = true;
      ignoreAllDups = true;
    };

    # 独自の24時間キャッシュ判定ロジック(下記initContent)をそのまま使うため、
    # home-managerのデフォルトcompinit呼び出しは無効化する
    enableCompletion = false;

    # oh-my-zsh は Nix store(read-only)上で動くため自己アップデート
    # (`omz update`)は使えない。更新は flake.lock 更新 + home-manager switch で行う。
    # .zshenv はZDOTDIRが定まる前・.zshrcより先に読まれるため、oh-my-zsh起動前に
    # 確実に反映させるためenvExtra側に置く
    envExtra = ''
      DISABLE_AUTO_UPDATE="true"
      DISABLE_UPDATE_PROMPT="true"
    '';

    initContent = ''
      # 共通設定(bash と共有)を読み込む
      [ -r "$HOME/.config/shell/init.sh" ] && . "$HOME/.config/shell/init.sh"

      # 補完(自作コマンドの補完定義は ~/.config/zsh/completions/ に置く)
      fpath=("$HOME/.config/zsh/completions" $fpath)
      autoload -Uz compinit
      # キャッシュ(.zcompdump)が24時間以内なら検査を省略(-C)して高速起動。
      # glob 修飾子 (#q...) には EXTENDED_GLOB が必要なため、対話シェル全体の
      # glob 挙動を変えないよう無名関数 + localoptions の中でだけ有効化する
      () {
        setopt localoptions extendedglob
        if [[ -n ''${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
          compinit
        else
          compinit -C
        fi
      }

      # zoxide(賢い cd)。compinit の後に初期化する必要がある
      command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"

      # fzf のキーバインド(Ctrl-R: 履歴検索 / Ctrl-T: ファイル / Alt-C: ディレクトリ移動)
      if command -v fzf >/dev/null 2>&1; then
        if _fzf_init=$(fzf --zsh 2>/dev/null); then
          eval "$_fzf_init"
        elif [ -r /usr/share/doc/fzf/examples/key-bindings.zsh ]; then
          # apt 版など古い fzf(0.48 未満は --zsh 非対応)向けフォールバック
          source /usr/share/doc/fzf/examples/key-bindings.zsh
        fi
        unset _fzf_init
      fi

      # zsh-syntax-highlighting は公式が「.zshrc の一番最後に読み込むこと」を必須要件としている
      # (それより後にウィジェットを追加・変更する設定があるとハイライトの再トリガーが効かない)。
      # home-manager は programs.zsh.plugins を initContent より先に配置する仕様のため、
      # ここより上の zoxide/fzf(ウィジェットを追加しうる)より後に来るよう、plugins リストではなく
      # ここで直接 source する
      source "${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    '';

    # agnoster は Powerline記号を使うため、ターミナル側で Nerd Font(nerd-fonts.jetbrains-mono を
    # nix/home.nix に導入済み)を選択していないと矢印・記号が文字化けする
    oh-my-zsh = {
      enable = true;
      theme = "agnoster";
      plugins = [
        "git"
        "colored-man-pages"
        "extract"
        "copyfile"
        "web-search"
      ];
    };

    # zsh-syntax-highlighting はここに入れない(initContent の最後で直接 source する。理由は上記コメント参照)
    plugins = [
      {
        name = "zsh-autosuggestions";
        src = pkgs.zsh-autosuggestions;
        file = "share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh";
      }
    ];
  };
}
