# shellcheck shell=sh
# fzf を使う自作関数の置き場。fzf が無い環境では何も定義しない(エラーも出さない)。
# 履歴検索(Ctrl-R)・ファイル(Ctrl-T)・ディレクトリ移動(Alt-C)は
# fzf 公式のキーバインド統合で対応済み(zsh / bash の設定本体側)。

if command -v fzf >/dev/null 2>&1; then
  # git ブランチを fzf で選んで切り替える(リモートブランチは追跡ブランチを自動作成)
  fbr() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
      echo "fbr: git リポジトリの中ではありません" >&2
      return 1
    fi
    # ローカルブランチ + リモート名を剥がしたリモートブランチを候補にする
    # (origin 以外のリモートにも対応。ローカルの feature/x を壊さないよう剥がすのはリモート側だけ)
    _fbr_sel=$(
      {
        git branch --format='%(refname:short)'
        git branch -r --format='%(refname:short)' | sed 's|^[^/]*/||'
      } | grep -vx 'HEAD' | sort -u | fzf --prompt='branch> '
    ) || {
      unset _fbr_sel
      return 0
    }
    if [ -n "$_fbr_sel" ]; then
      # リモートのブランチ名は相手が決められ、- で始まると git switch のオプションになるため切り替えない
      case "$_fbr_sel" in
        -*)
          echo "fbr: - で始まるブランチ名には切り替えられません" >&2
          unset _fbr_sel
          return 1
          ;;
      esac
      git switch "$_fbr_sel"
    fi
    unset _fbr_sel
  }

  # 自分のプロセスを fzf で選んで kill する(Tab で複数選択)。
  # 使い方: fzkill [-シグナル] [絞り込み語]  例: fzkill / fzkill node / fzkill -9 vite
  # 既定のシグナルは TERM(後片付けの機会を与える)。止まらないときだけ -9 を付ける。
  # 名前は npm の fkill(fkill-cli)との衝突を避けたもの
  fzkill() {
    _fzk_sig=-TERM
    case "${1:-}" in
      -*)
        _fzk_sig=$1
        shift
        ;;
    esac
    # pid / ppid / etime / pcpu / pmem / args は procps(Linux)と BSD(macOS)の ps で共通
    _fzk_sel=$(
      ps -U "$(id -u)" -o pid,ppid,etime,pcpu,pmem,args |
        awk -v me="$$" 'NR == 1 || $1 != me' |
        fzf -m --header-lines=1 --query="$*" --prompt="kill ${_fzk_sig}> "
    ) || {
      unset _fzk_sig _fzk_sel
      return 0
    }
    printf '%s\n' "$_fzk_sel" | sed "s/^/kill ${_fzk_sig}: /"
    # PID の一覧はコマンド置換のまま渡す(変数に入れると zsh は単語分割しないため)
    # shellcheck disable=SC2046
    kill "$_fzk_sig" $(printf '%s\n' "$_fzk_sel" | awk '{print $1}')
    _fzk_rc=$?
    unset _fzk_sig _fzk_sel
    return "$_fzk_rc"
  }
fi
