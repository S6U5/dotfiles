# shellcheck shell=sh
# 環境変数。共通設定の中で最初に読み込まれる。
# 機密になりうる値(トークン、プライベートなパス等)はここに書かず local.sh へ(CLAUDE.md 参照)。

# 既定エディタ(nvim があれば nvim、無ければ vim。既に設定済みなら尊重)
if command -v nvim >/dev/null 2>&1; then
  export EDITOR="${EDITOR:-nvim}"
else
  export EDITOR="${EDITOR:-vim}"
fi

# 設定ディレクトリを ~/.config に統一(macOS でも pnpm 等の XDG 対応ツールが ~/.config を読むように)
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# Homebrew(macOS)。zsh は ZDOTDIR 方式(docs/decisions/zshrc-pollution.md 参照)のため、
# brew インストール直後の案内が指示する `~/.zprofile` への追記は読み込まれず PATH が通らない。
# ディレクトリの有無だけで判定し、shellenv 相当の PATH 追加をここで行う。
for _brew_prefix in /opt/homebrew /usr/local; do
  if [ -x "$_brew_prefix/bin/brew" ]; then
    case ":$PATH:" in
      *":$_brew_prefix/bin:"*) ;;
      *) PATH="$_brew_prefix/bin:$_brew_prefix/sbin:$PATH" ;;
    esac
    break
  fi
done
unset _brew_prefix

# PATH の先頭は ~/.local/bin(自作コマンド)→ Nix のプロファイルの順にそろえる。macOS の
# /etc/zprofile・/etc/profile が呼ぶ path_helper は、入れ子のシェル(tmux・herdr の中など)で
# /etc/paths と /etc/paths.d/(Homebrew の /etc/paths.d/homebrew を含む)を先頭に並べ直し、
# Nix の nix-daemon.sh は2回目は何もしない。そのままだと Homebrew や /usr/bin の同名コマンドが
# Nix で入れたものより先に見つかるため、既にあっても取り除いてから先頭へ置き直す
# (判断根拠は docs/decisions/path-order.md)。
_dotfiles_path_front() {
  _dotfiles_rest=":$PATH:"
  while :; do
    case "$_dotfiles_rest" in
      *":$1:"*) _dotfiles_rest="${_dotfiles_rest%%":$1:"*}:${_dotfiles_rest#*":$1:"}" ;;
      *) break ;;
    esac
  done
  _dotfiles_rest=${_dotfiles_rest#:}
  _dotfiles_rest=${_dotfiles_rest%:}
  PATH="$1${_dotfiles_rest:+:$_dotfiles_rest}"
  unset _dotfiles_rest
}
# Nix のプロファイルは、Nix 自身のスクリプトが PATH に足しているときだけ動かす(ここでは足さない)
for _dotfiles_nix_bin in /nix/var/nix/profiles/default/bin "$HOME/.nix-profile/bin"; do
  case ":$PATH:" in
    *":$_dotfiles_nix_bin:"*) _dotfiles_path_front "$_dotfiles_nix_bin" ;;
  esac
done
unset _dotfiles_nix_bin
# 自作コマンド置き場(home/.local/bin/)は、無ければ足して一番前に置く
_dotfiles_path_front "$HOME/.local/bin"
unset -f _dotfiles_path_front
export PATH
