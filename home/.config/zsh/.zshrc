# 履歴設定
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_ALL_DUPS
setopt SHARE_HISTORY

# 対話シェルでも # 以降をコメントとして扱う(bash と同じ挙動)。
# README のコマンド例(末尾に「# 説明」付き)をそのままコピペできるようにするため
setopt INTERACTIVE_COMMENTS

# 共通設定(bash と共有)を読み込む
[ -r "$HOME/.config/shell/init.sh" ] && . "$HOME/.config/shell/init.sh"

# ---- 起動高速化(判断根拠は docs/decisions/zsh-startup-optimization.md 参照)----
#   1. `eval "$(<tool> init zsh)"` の出力はファイルにキャッシュし、ツールが更新されない
#      限り再生成しない(起動のたびのプロセス起動をなくす)
#   2. source する zsh スクリプトは zcompile で事前バイトコンパイルする
#   3. プロンプト表示に不要な初期化(compinit・プラグイン)は zsh-defer で
#      最初のプロンプト表示後に遅延実行する

_dotfiles_zsh_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/zsh"

# init 出力キャッシュ: `eval "$(<tool> init zsh)"` の代わりに使う。
#   使い方: _dotfiles_cached_eval <キャッシュ名> <コマンド> [引数...]
# 出力を $_dotfiles_zsh_cache_dir/<キャッシュ名>.zsh に保存して source する。
# Nix store のファイルは mtime が固定(1970年)で新旧比較に使えないため、シンボリック
# リンク解決後の実体パス(パッケージ更新で store パスごと変わる)をキャッシュ先頭行に
# 記録し、一致する限り再利用する。コマンドが無い・失敗したときは非0を返すだけ。
_dotfiles_cached_eval() {
  local name=$1 cache bin first
  shift
  cache="$_dotfiles_zsh_cache_dir/$name.zsh"
  bin=$(command -v -- "$1") || return 1
  bin=${bin:A}
  [[ -r $cache ]] && IFS= read -r first <"$cache"
  if [[ $first != "# $bin" ]]; then
    mkdir -p "$_dotfiles_zsh_cache_dir"
    { print -r -- "# $bin" && "$@"; } >|"$cache" 2>/dev/null \
      || { rm -f "$cache" "$cache.zwc"; return 1; }
    zcompile "$cache" 2>/dev/null || rm -f "$cache.zwc"
  fi
  source "$cache"
}

# starship プロンプト(Nix の home.packages で導入。無ければ静かにスキップ)。
# プロンプト表示そのものに必要なため遅延せず同期で読み込む。
# `starship init zsh` はブートストラップを介して毎回 starship を起動し直すため、
# キャッシュ対象は本体スクリプトを直接出力する --print-full-init にする
_dotfiles_cached_eval starship starship init zsh --print-full-init

# 何も入力せず Enter しただけの再描画では exit code(✓/✗)を表示しないための橋渡し。
# starship は空 Enter 時に STARSHIP_CMD_STATUS を unset する(preexec が発火しないため)が、
# CLI 側の status モジュールは「未指定」を 0 扱いして ✓ 0 を出してしまう。そこで
# 「コマンド実行があったときだけ値が入る」DOTFILES_LAST_STATUS に写し、
# starship.toml 側の custom モジュール(exit_ok / exit_err)がこれを参照する。
# add-zsh-hook は登録順に実行されるため、starship init(上の行)より後に登録すること
if command -v starship >/dev/null 2>&1; then
  _dotfiles_status_precmd() {
    if [[ -n ${STARSHIP_CMD_STATUS-} ]]; then
      export DOTFILES_LAST_STATUS=$STARSHIP_CMD_STATUS
    else
      unset DOTFILES_LAST_STATUS
    fi
  }
  autoload -Uz add-zsh-hook
  add-zsh-hook precmd _dotfiles_status_precmd
fi

# プロンプト表示に不要な初期化はここにまとめ、zsh-defer で最初のプロンプト表示後に実行する。
# 読み込み順に依存があるため1つの関数にまとめている:
#   compinit → zoxide / fzf(compdef を使う)→ autosuggestions → syntax-highlighting(最後が必須)
_dotfiles_deferred_init() {
  # 補完(自作コマンドの補完定義は ~/.config/zsh/completions/ に置く)
  fpath=("$HOME/.config/zsh/completions" $fpath)
  autoload -Uz compinit
  local dump="${ZDOTDIR:-$HOME}/.zcompdump"
  # キャッシュ(.zcompdump)が24時間以内なら compaudit・dump 再生成を省略(-C)して高速化。
  # glob 修飾子 (#q...) には EXTENDED_GLOB が必要なため、対話シェル全体の
  # glob 挙動を変えないよう無名関数 + localoptions の中でだけ有効化する
  () {
    setopt localoptions extendedglob
    if [[ -n $1(#qN.mh+24) ]]; then
      compinit
      # 補完関数の増減が無いと compinit は dump を書き直さず mtime も更新されないため、
      # 明示的に touch して「フル検査は24時間に1回まで」を保証する
      touch "$1"
    else
      compinit -C
    fi
  } "$dump"
  # 補完キャッシュは大きいので事前バイトコンパイルしておく(次回起動から効く)
  if [[ -s $dump && (! -s $dump.zwc || $dump -nt $dump.zwc) ]]; then
    zcompile "$dump" 2>/dev/null || rm -f "$dump.zwc"
  fi

  # zoxide(賢い cd)。compdef を使うため compinit の後に初期化する
  _dotfiles_cached_eval zoxide zoxide init zsh

  # fzf のキーバインド(Ctrl-R: 履歴検索 / Ctrl-T: ファイル / Alt-C: ディレクトリ移動)
  if ! _dotfiles_cached_eval fzf fzf --zsh; then
    # apt 版など古い fzf(0.48 未満は --zsh 非対応)向けフォールバック
    [[ -r /usr/share/doc/fzf/examples/key-bindings.zsh ]] \
      && source /usr/share/doc/fzf/examples/key-bindings.zsh
  fi

  # zsh-autosuggestions(Nix の home.packages 経由で ~/.nix-profile に入る。
  # home-manager 未適用ならファイルが無いため存在チェックでスキップする)
  local plugin="$HOME/.nix-profile/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
  [[ -r $plugin ]] && source "$plugin"

  # zsh-syntax-highlighting は公式が「.zshrc の一番最後に読み込むこと」を必須要件としている
  # (それより後にウィジェットを追加・変更する設定があるとハイライトの再トリガーが効かない)。
  # そのためこの遅延初期化の中でも zoxide/fzf(ウィジェットを追加しうる)より後、最後に置く
  plugin="$HOME/.nix-profile/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  [[ -r $plugin ]] && source "$plugin"

  # source される zsh スクリプト本体の事前バイトコンパイル(次回起動から効く)。
  # 共通設定(POSIX sh)も zsh から source されるため対象に含める(bash は .zwc を無視する。
  # .zwc は $HOME 側に生成され、リポジトリは汚さない)。local.sh(git 管理外・マシン固有)は
  # 対象外。ソースの方が新しければ zsh は .zwc を無視するため、コンパイルが古くても壊れない
  local src
  for src in "${ZDOTDIR:-$HOME}/.zshrc" "$HOME"/.config/shell/*.sh(N) "$HOME"/.config/shell/os/*.sh(N); do
    [[ $src == */local.sh ]] && continue
    if [[ ! -s $src.zwc || $src -nt $src.zwc ]]; then
      zcompile "$src" 2>/dev/null || rm -f "$src.zwc"
    fi
  done
}

# zsh-defer(Nix の home.packages で導入)があれば遅延実行、無い環境
# (home-manager 未適用等)でも壊れないよう同期実行にフォールバックする
_dotfiles_zsh_defer_plugin="$HOME/.nix-profile/share/zsh-defer/zsh-defer.plugin.zsh"
if [[ -r $_dotfiles_zsh_defer_plugin ]]; then
  source "$_dotfiles_zsh_defer_plugin"
  zsh-defer _dotfiles_deferred_init
else
  _dotfiles_deferred_init
fi
unset _dotfiles_zsh_defer_plugin
