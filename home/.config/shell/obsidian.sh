# shellcheck shell=sh
# Obsidian 連携コマンド。
#   cdov [名前の一部] — vault のディレクトリへ移動する
#   ov   [名前の一部] — vault を指定して Obsidian を起動する(obsidian:// URI 経由)
# vault のパスはハードコードせず、Obsidian アプリ自身の vault 一覧(obsidian.json)を実行時に読む。
# 候補が複数のときは fzf(あれば)か番号選択(共通ヘルパー _dotfiles_pick_line)。

# vault 一覧ファイル(obsidian.json)の場所を OS ごとに解決して出力する
_obsidian_config() {
  case "$(uname -s)" in
    Darwin)
      printf '%s\n' "$HOME/Library/Application Support/obsidian/obsidian.json"
      ;;
    Linux)
      if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null; then
        # WSL: Windows 側の Obsidian の設定を探す
        find /mnt/c/Users -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while read -r _obs_u; do
          if [ -r "$_obs_u/AppData/Roaming/obsidian/obsidian.json" ]; then
            printf '%s\n' "$_obs_u/AppData/Roaming/obsidian/obsidian.json"
          fi
        done | head -n 1
      else
        printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/obsidian/obsidian.json"
      fi
      ;;
  esac
}

# vault を1つ選んでパスを出力する($(...) のサブシェルから呼ぶ想定。メッセージは stderr)
_obsidian_pick() {
  _obs_conf=$(_obsidian_config)
  if [ -z "$_obs_conf" ] || [ ! -r "$_obs_conf" ]; then
    echo "Obsidian の vault 一覧が見つかりません(Obsidian 未インストール?)" >&2
    return 0
  fi

  if command -v jq >/dev/null 2>&1; then
    _obs_paths=$(jq -r '.vaults[].path' "$_obs_conf")
  else
    # jq が無い環境向けの簡易パース(","で分割して "path":"..." を抜き出す)
    _obs_paths=$(tr ',' '\n' <"$_obs_conf" | sed -n 's/.*"path":"\([^"]*\)".*/\1/p' | sed 's/\\\\/\\/g')
  fi

  _obs_sel=$(_dotfiles_pick_line "$_obs_paths" "${1:-}" vault) || {
    echo "該当する vault がありません${1:+(絞り込み: $1)}" >&2
    return 1
  }

  # WSL: obsidian.json のパスは Windows 形式(C:\...)なので WSL のパスに変換する
  case "$_obs_sel" in
    [A-Za-z]:\\*) _obs_sel=$(wslpath -u "$_obs_sel") ;;
  esac

  printf '%s\n' "$_obs_sel"
}

# Obsidian の vault へ移動する
cdov() {
  _cdov_t=$(_obsidian_pick "${1:-}") || {
    unset _cdov_t
    return 1
  }
  if [ -z "$_cdov_t" ]; then
    unset _cdov_t
    return 0
  fi
  if [ ! -d "$_cdov_t" ]; then
    echo "cdov: vault のディレクトリが存在しません: $_cdov_t" >&2
    unset _cdov_t
    return 1
  fi
  cd "$_cdov_t" || {
    unset _cdov_t
    return 1
  }
  unset _cdov_t
}

# vault を指定して Obsidian を起動する
ov() {
  _ov_t=$(_obsidian_pick "${1:-}") || {
    unset _ov_t
    return 1
  }
  if [ -z "$_ov_t" ]; then
    unset _ov_t
    return 0
  fi

  # vault 名(フォルダ名)を URL エンコードして obsidian:// URI を作る
  _ov_name=$(basename "$_ov_t")
  if command -v jq >/dev/null 2>&1; then
    _ov_enc=$(jq -rn --arg s "$_ov_name" '$s|@uri')
  elif command -v python3 >/dev/null 2>&1; then
    _ov_enc=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "$_ov_name")
  else
    echo "ov: URL エンコードに jq か python3 が必要です(どちらも見つかりません)" >&2
    unset _ov_t _ov_name
    return 0
  fi
  _ov_uri="obsidian://open?vault=$_ov_enc"

  case "$(uname -s)" in
    Darwin)
      open "$_ov_uri"
      ;;
    Linux)
      if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null; then
        (
          cd /mnt/c 2>/dev/null || cd /
          cmd.exe /c start "" "$_ov_uri"
        )
      elif command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$_ov_uri"
      else
        echo "ov: URI を開く手段が見つかりません(xdg-open なし)" >&2
      fi
      ;;
    *)
      echo "ov: 未対応の OS です($(uname -s))" >&2
      ;;
  esac
  unset _ov_t _ov_name _ov_enc _ov_uri
}