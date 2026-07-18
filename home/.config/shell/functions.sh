# shellcheck shell=sh
# 自作関数。sh 互換で書くこと。
# 外部ツールに依存する関数は、実行時に存在チェックして無ければ親切なメッセージを出して終了する
# (CLAUDE.md「外部ツール依存の扱い」参照)。

# WSL 上で動いているかを判定する共通ヘルパー(判定条件はここに一本化する)
_dotfiles_is_wsl() {
  [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null
}

# WSL: 現在の Windows ユーザーのプロファイル(/mnt/c/Users/名前)を出力する。
# 共有 PC で他ユーザーのフォルダを誤って拾わないため、探索はまずこの配下から行う
_dotfiles_win_profile() {
  command -v cmd.exe >/dev/null 2>&1 || return 1
  _dwp_win=$(
    cd /mnt/c 2>/dev/null || cd /
    cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r'
  )
  if [ -z "$_dwp_win" ]; then
    unset _dwp_win
    return 1
  fi
  wslpath -u "$_dwp_win" 2>/dev/null || {
    unset _dwp_win
    return 1
  }
  unset _dwp_win
}

# ディレクトリを作って移動する
mkcd() {
  mkdir -p "$1" && cd "$1" || return 1
}

# git リポジトリのルートへ移動する(深い階層から一発で戻る)
cdgr() {
  _cdgr_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "cdgr: git リポジトリの中ではありません" >&2
    unset _cdgr_root
    return 1
  }
  cd "$_cdgr_root" || {
    unset _cdgr_root
    return 1
  }
  unset _cdgr_root
}

# 使い捨ての一時ディレクトリを作って移動する。
# 場所は OS の一時領域(Linux: /tmp、macOS: TMPDIR)なので、掃除は OS 任せでよい
tmpd() {
  _tmpd_dir=$(mktemp -d "${TMPDIR:-/tmp}/tmpd.XXXXXX") || {
    echo "tmpd: 一時ディレクトリを作成できませんでした" >&2
    unset _tmpd_dir
    return 1
  }
  cd "$_tmpd_dir" || {
    unset _tmpd_dir
    return 1
  }
  unset _tmpd_dir
}

# 候補(1行1件のパス)から1つ選んで標準出力に出す共通ヘルパー。
# $1: 候補リスト、$2: 絞り込み(部分一致・大文字小文字無視)、$3: プロンプト表示名
# 絞り込みは最後のパス要素(フォルダ名)だけに効かせる(親ディレクトリ名への誤マッチを防ぐ)。
# $(...) のサブシェルから呼ぶ想定。候補はパイプではなく引数で渡す
# (パイプにすると番号選択の read が標準入力を読めなくなるため)。
# 1件なら即決、複数なら fzf(あれば)か番号選択。候補0件: return 1、キャンセル: 空出力で return 0
_dotfiles_pick_line() {
  _dp_list=$1
  if [ -n "${2:-}" ]; then
    _dp_pat=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')
    _dp_list=$(printf '%s\n' "$_dp_list" | awk -F/ -v pat="$_dp_pat" 'index(tolower($NF), pat) > 0')
    unset _dp_pat
  fi
  if [ -z "$_dp_list" ]; then
    unset _dp_list
    return 1
  fi
  if [ "$(printf '%s\n' "$_dp_list" | wc -l)" -eq 1 ]; then
    printf '%s\n' "$_dp_list"
  elif command -v fzf >/dev/null 2>&1; then
    printf '%s\n' "$_dp_list" | fzf --prompt="${3:-select}> " || true
  else
    printf '%s\n' "$_dp_list" | awk '{printf "  %d) %s\n", NR, $0}' >&2
    printf '番号を選択: ' >&2
    read -r _dp_no
    case "${_dp_no:-}" in
      *[!0-9]* | '') : ;;
      *) printf '%s\n' "$_dp_list" | sed -n "${_dp_no}p" ;;
    esac
  fi
  unset _dp_list _dp_no
  return 0
}

# 候補リストから1つ選んで cd する共通処理(cdod / cdic / cdgd などの実体)。
# $1: 候補リスト(1行1件)、$2: 絞り込み、$3: コマンド名(メッセージ・プロンプトに使用)
# 終了コード: 実際に移動したときだけ 0(候補なし・不一致・キャンセルは 1。
# `cdod && コマンド` のような合成で、移動していないのに後続が走るのを防ぐ)
_dotfiles_cd_from_list() {
  if [ -z "$1" ]; then
    echo "$3: 対象フォルダが見つかりません(未設定?)" >&2
    return 1
  fi
  _dcf_t=$(_dotfiles_pick_line "$1" "${2:-}" "$3") || {
    echo "$3: 該当するフォルダがありません${2:+(絞り込み: $2)}" >&2
    unset _dcf_t
    return 1
  }
  if [ -z "$_dcf_t" ]; then
    unset _dcf_t
    return 1
  fi
  cd "$_dcf_t" || {
    unset _dcf_t
    return 1
  }
  unset _dcf_t
}
