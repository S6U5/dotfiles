# shellcheck shell=sh
# herdr(ターミナルマルチプレクサ)を補助する関数。sh 互換で書くこと。
# 「常に定義+実行時チェック」: herdr が無い環境でも定義し、実行時に親切なメッセージを出す。

# herdr のセッションを選んで入る(一覧に無い名前を打てば新しく作る)。
# 使い方: herdrs(一覧から選ぶ) / herdrs 名前(その名前のセッションに入る。無ければ作る)
# fzf があれば一覧で絞り込み、一覧に無い名前を打って Enter で新規作成。無ければ番号で選ぶ。
# herdr の中(HERDR_ENV=1)からは入れ子になるので実行しない
herdrs() {
  if ! command -v herdr >/dev/null 2>&1; then
    echo "herdrs: herdr が見つかりません" >&2
    return 0
  fi
  if [ "${HERDR_ENV:-}" = 1 ]; then
    echo "herdrs: herdr の中からは別のセッションに入れません(入れ子になるため)。デタッチしてから実行してください" >&2
    return 1
  fi
  if [ -n "${1:-}" ]; then
    herdr --session "$1"
    return
  fi

  # 一覧の表(名前 状態 ディレクトリ ソケット)から名前と状態だけを取り出す。
  # 字下げされた行は直前のセッションの補足(接続エラー等)なので除く
  _hs_list=$(herdr session list 2>/dev/null | awk 'NR > 1 && $0 !~ /^[[:space:]]/ && NF { printf "%-20s %s\n", $1, $2 }')
  if [ -z "$_hs_list" ]; then
    # セッションが1つも無ければ既定のセッションを起動する
    unset _hs_list
    herdr
    return
  fi

  if command -v fzf >/dev/null 2>&1; then
    # --print-query: 1行目に打った文字、2行目に選んだ行が出る(一致なしなら1行目だけ)
    _hs_out=$(printf '%s\n' "$_hs_list" | fzf --print-query --prompt='herdr session> ' \
      --header='Enter: 入る / 一覧に無い名前を打って Enter: 新しく作る')
    _hs_rc=$?
    if [ "$_hs_rc" -ne 0 ] && [ "$_hs_rc" -ne 1 ]; then
      # Esc / Ctrl-C で中断
      unset _hs_list _hs_out _hs_rc
      return 0
    fi
    _hs_name=$(printf '%s\n' "$_hs_out" | sed -n 2p | awk '{print $1}')
    [ -n "$_hs_name" ] || _hs_name=$(printf '%s\n' "$_hs_out" | sed -n 1p)
  else
    _hs_name=$(_dotfiles_pick_line "$(printf '%s\n' "$_hs_list" | awk '{print $1}')" "" "herdrs") || _hs_name=
  fi
  unset _hs_list _hs_out _hs_rc
  if [ -z "$_hs_name" ]; then
    unset _hs_name
    return 0
  fi
  set -- "$_hs_name"
  unset _hs_name
  herdr --session "$1"
}
