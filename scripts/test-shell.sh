#!/usr/bin/env bash
#
# シェル設定(home/.config/shell/ 以下の共通設定と、bash / zsh の設定本体)を実際に
# 読み込んで動作を検証するテスト。shellcheck は静的検査(`shell=sh` の構文)しか見ないため、
# 「dash / bash / zsh のそれぞれで本当に読み込めるか」「関数が定義されるか」「cd 系が移動しない
# ときに非0を返すか(AGENTS.md「終了コードの決まり」)」は実行しないと分からない。
#
# 使い捨ての $HOME を作り、home/ の該当ファイルをコピーして(home-manager は使わない)、
# nix/home.nix の home.activation と同じ1行のブートストラップファイルを置いてから、
# 各シェルを対話モードで起動して確かめる。実際の $HOME には一切触れない。
#
#   ./scripts/test-shell.sh
#
# 無いシェルは飛ばす(dash / zsh が無い環境でもテスト自体は落ちない。CI 側では必ず入れる)。
set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$DOTFILES_DIR"

pass=0
fail=0
ok() {
  echo "  ok: $*"
  pass=$((pass + 1))
}
ng() {
  echo "  NG: $*" >&2
  fail=$((fail + 1))
}

FAKE_HOME=$(mktemp -d)
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$FAKE_HOME" "$WORK_DIR"' EXIT

# home/ から、シェル起動時に読まれるものだけをコピーする(実行時に外部ツールの有無で挙動が
# 変わらないよう、PATH も最小限にする。fzf / eza / zoxide / starship 等は無い前提で通ること
# =「依存ツールが無い環境でも壊れない」の検証を兼ねる)
mkdir -p "$FAKE_HOME/.config"
cp -R home/.config/shell "$FAKE_HOME/.config/shell"
cp -R home/.config/bash "$FAKE_HOME/.config/bash"
cp -R home/.config/zsh "$FAKE_HOME/.config/zsh"
cp -R home/.local "$FAKE_HOME/.local"
cp home/.zshenv "$FAKE_HOME/.zshenv"

# nix/home.nix の home.activation.dotfilesShellBootstrap が生成する管理外ファイルと同じ内容
# shellcheck disable=SC2016  # $HOME は起動したシェル側で展開させる(意図的なシングルクォート)
printf '%s\n' '[ -r "$HOME/.config/bash/bashrc" ] && . "$HOME/.config/bash/bashrc"' >"$FAKE_HOME/.bashrc"
# shellcheck disable=SC2016  # 同上
printf '%s\n' '[ -r "$HOME/.config/zsh/zshrc" ] && . "$HOME/.config/zsh/zshrc"' >"$FAKE_HOME/.config/zsh/.zshrc"

# 検証用の git リポジトリ(cdgr の確認に使う)
git -C "$WORK_DIR" init -q
mkdir -p "$WORK_DIR/sub/dir"

# 共通設定を読み込んだあとに実行する検証本体(POSIX sh 互換で書く。3シェルで共有)
# 標準出力に "RESULT <名前> <値>" を並べ、呼び出し側で判定する
CHECKS=$(
  cat <<'EOF'
for f in mkcd cdgr tmpd cdov ov cdod cdode cdic cdgd cdwin herdrs _dotfiles_is_wsl _dotfiles_pick_line; do
  if command -v "$f" >/dev/null 2>&1; then
    echo "RESULT defined:$f yes"
  else
    echo "RESULT defined:$f no"
  fi
done
case ":$PATH:" in
  *":$HOME/.local/bin:"*) echo "RESULT path_local_bin yes" ;;
  *) echo "RESULT path_local_bin no" ;;
esac
[ -n "${EDITOR:-}" ] && echo "RESULT editor_set yes" || echo "RESULT editor_set no"
[ -n "${XDG_CONFIG_HOME:-}" ] && echo "RESULT xdg_config_home yes" || echo "RESULT xdg_config_home no"
cd "$DOTFILES_TEST_WORK/sub/dir" || exit 97
cdgr 2>/dev/null
echo "RESULT cdgr_rc $?"
echo "RESULT cdgr_pwd $PWD"
cd /
cdgr 2>/dev/null
echo "RESULT cdgr_outside_rc $?"
mkcd "$DOTFILES_TEST_WORK/made/here" 2>/dev/null
echo "RESULT mkcd_rc $?"
echo "RESULT mkcd_pwd $PWD"
tmpd 2>/dev/null
echo "RESULT tmpd_rc $?"
case "$PWD" in
  "${TMPDIR:-/tmp}"/tmpd.*) echo "RESULT tmpd_pwd yes" ;;
  *) echo "RESULT tmpd_pwd no" ;;
esac
rmdir "$PWD" 2>/dev/null
cd /
# 以下は候補が無い(または非 WSL の)環境なので「移動せず非0」が正解
cdod 2>/dev/null
echo "RESULT cdod_rc $?"
cdode 2>/dev/null
echo "RESULT cdode_rc $?"
cdic 2>/dev/null
echo "RESULT cdic_rc $?"
cdgd 2>/dev/null
echo "RESULT cdgd_rc $?"
cdov 2>/dev/null
echo "RESULT cdov_rc $?"
echo "RESULT after_cd_pwd $PWD"
# 内部変数が残っていないこと(init.sh が unset する)
[ -z "${_dotfiles_shell_dir:-}${_dotfiles_file:-}${_dotfiles_os:-}" ] && echo "RESULT internals_unset yes" || echo "RESULT internals_unset no"
EOF
)

# WSL 以外の環境でだけ成り立つ検証(WSL では cdwin が実際に移動する)
if [ -z "${WSL_DISTRO_NAME:-}" ] && ! grep -qi microsoft /proc/version 2>/dev/null; then
  CHECKS="$CHECKS
cdwin 2>/dev/null
echo \"RESULT cdwin_rc \$?\"
_dotfiles_is_wsl
echo \"RESULT is_wsl_rc \$?\""
  EXPECT_WSL=0
else
  EXPECT_WSL=1
fi

# 検証本体はファイルにして各シェルから source する(対話モードの標準入力はスクリプトにできないため)
printf '%s\n' "$CHECKS" >"$WORK_DIR/checks.sh"

# $1: シェル名(表示用) $2: シェルの起動コマンド文字列(checks.sh を source する形で書く)
# 標準エラー出力は空であること(起動時に依存ツール不在でエラーが出ない、の検証)
run_shell() {
  local label=$1 cmd=$2
  local out err
  out=$(mktemp)
  err=$(mktemp)
  # 標準出力・標準エラー出力はシェル自身からファイルへ向ける(pty 経由では分離できないため)。
  # 環境は最小限にし、fzf / eza / zoxide / starship 等が無い前提で通ることも確かめる
  # shellcheck disable=SC2016  # $DOTFILES_TEST_OUT / ERR は起動したシェル側で展開させる
  cmd=$cmd' >"$DOTFILES_TEST_OUT" 2>"$DOTFILES_TEST_ERR"'
  local -a envargs=(
    env -i HOME="$FAKE_HOME" PATH="/usr/bin:/bin" TERM=dumb
    DOTFILES_TEST_WORK="$WORK_DIR" DOTFILES_TEST_OUT="$out" DOTFILES_TEST_ERR="$err" TMPDIR="${TMPDIR:-/tmp}"
  )
  # 擬似端末(pty)の下で起動する。CI のように制御端末が無い環境では、zsh を -i で起動しても
  # 端末を開けず「not interactive and can't open terminal」で compinit が中断し、bash も
  # ジョブ制御の警告を出すため。util-linux(Linux)と BSD(macOS)で script の引数の形が違う。
  # script が無ければそのまま実行する(手元に端末があれば問題なく通る)
  local rc=0
  if script --version 2>/dev/null | grep -q util-linux; then
    "${envargs[@]}" script -qec "$cmd" /dev/null >/dev/null 2>&1 </dev/null || rc=$?
  elif command -v script >/dev/null 2>&1; then
    "${envargs[@]}" script -q /dev/null sh -c "$cmd" >/dev/null 2>&1 </dev/null || rc=$?
  else
    "${envargs[@]}" sh -c "$cmd" </dev/null || rc=$?
  fi
  if [ "$rc" -ne 0 ]; then
    ng "$label: シェルが非0で終了した(rc=$rc)"
    sed 's/^/      /' "$err" >&2
  fi
  # bash は端末(tty)無しで -i 起動すると、設定を読む前にジョブ制御の警告を2行出す。
  # これは起動方法によるもので設定の問題ではないため、この2行だけは無視する
  sed -i -e '/^bash: cannot set terminal process group/d' -e '/^bash: no job control in this shell$/d' "$err"
  if [ -s "$err" ]; then
    ng "$label: 読み込み中に標準エラー出力があった:"
    sed 's/^/      /' "$err" >&2
    # compinit の中断は、fpath 上に他ユーザー所有・グループ書き込み可のディレクトリがあると
    # 安全性監査が端末に問い合わせて止まるのが典型(CI のランナーで起きる)。該当があれば示す
    if grep -q compinit "$err" && command -v zsh >/dev/null 2>&1; then
      echo "      ヒント: compaudit が安全でないと判定したディレクトリ:" >&2
      "${envargs[@]}" zsh -fc 'autoload -Uz compaudit; compaudit' 2>&1 | sed 's/^/        /' >&2 || true
    fi
  else
    ok "$label: 標準エラー出力なし"
  fi

  expect() { # $1: 項目名 $2: 期待値
    local got
    got=$(sed -n "s/^RESULT $1 //p" "$out" | tail -n 1)
    if [ "$got" = "$2" ]; then
      ok "$label: $1 = $2"
    else
      ng "$label: $1 = '${got:-(なし)}'(期待: $2)"
    fi
  }
  for f in mkcd cdgr tmpd cdov ov cdod cdode cdic cdgd cdwin herdrs _dotfiles_is_wsl _dotfiles_pick_line; do
    expect "defined:$f" yes
  done
  expect path_local_bin yes
  expect editor_set yes
  expect xdg_config_home yes
  expect cdgr_rc 0
  expect cdgr_pwd "$(cd "$WORK_DIR" && pwd -P)"
  expect cdgr_outside_rc 1
  expect mkcd_rc 0
  expect mkcd_pwd "$WORK_DIR/made/here"
  expect tmpd_rc 0
  expect tmpd_pwd yes
  expect cdod_rc 1
  expect cdode_rc 1
  expect cdic_rc 1
  expect cdgd_rc 1
  expect cdov_rc 1
  expect after_cd_pwd /
  expect internals_unset yes
  if [ "$EXPECT_WSL" -eq 0 ]; then
    expect cdwin_rc 1
    expect is_wsl_rc 1
  fi
  rm -f "$out" "$err"
}

echo "== 1) POSIX sh(dash)で共通設定 init.sh を読み込む"
if command -v dash >/dev/null 2>&1; then
  # shellcheck disable=SC2016  # 変数は起動したシェル側で展開させる(意図的なシングルクォート)
  run_shell dash 'dash -c ". \"\$HOME/.config/shell/init.sh\"; . \"\$DOTFILES_TEST_WORK/checks.sh\""'
else
  echo "  skip: dash が見つかりません"
fi

echo "== 2) bash $(bash -c 'echo "${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"') を対話モードで起動し、ブートストラップ ~/.bashrc 経由で設定本体を読み込む"
# 対話モード(-i)でないと bashrc が先頭で return する
# shellcheck disable=SC2016  # 変数は起動したシェル側で展開させる(意図的なシングルクォート)
run_shell bash 'bash -ic ". \"\$DOTFILES_TEST_WORK/checks.sh\""'

echo "== 3) zsh $(zsh -c 'echo $ZSH_VERSION' 2>/dev/null || echo '(なし)') を対話モードで起動し、~/.zshenv(ZDOTDIR)→ ブートストラップ .zshrc 経由で設定本体を読み込む"
if command -v zsh >/dev/null 2>&1; then
  # shellcheck disable=SC2016  # 変数は起動したシェル側で展開させる(意図的なシングルクォート)
  run_shell zsh 'zsh -ic ". \"\$DOTFILES_TEST_WORK/checks.sh\""'
  if [ -e "$FAKE_HOME/.zcompdump" ] || [ -e "$FAKE_HOME/.config/zsh/.zcompdump" ]; then
    ok "zsh: compinit が実行された(.zcompdump が生成された)"
  else
    ng "zsh: .zcompdump が生成されていない(compinit が動いていない?)"
  fi
else
  echo "  skip: zsh が見つかりません"
fi

echo "== 4) diskreport の集計を、偽の docker と使い捨ての \$HOME で確かめる"
# 実際の $HOME と履歴には触れない(既知パスの一覧は repo のものを読む)
DISK_TEST=$WORK_DIR/diskreport
DISK_STATE=$DISK_TEST/home/.local/state/dotfiles
mkdir -p "$DISK_TEST/bin" "$DISK_STATE" "$DISK_TEST/home/Library/Containers/com.docker.docker" "$DISK_TEST/home/Library/Containers/other.app"
head -c 3145728 /dev/urandom >"$DISK_TEST/home/Library/Containers/com.docker.docker/disk"
head -c 1048576 /dev/urandom >"$DISK_TEST/home/Library/Containers/other.app/data"
# docker system df の実際の形式(最後の行だけ割合が付かない)
cat >"$DISK_TEST/bin/docker" <<'EOF'
#!/bin/sh
case "$1" in
  info) printf '%s\n' "$FAKE_DOCKER_OS" ;;
  system) printf '1.5GB\t1GB (66%%)\n100MB\t0B (0%%)\n2GB\t1GB (50%%)\n500MB\t500MB\n' ;;
esac
EOF
chmod +x "$DISK_TEST/bin/docker"
run_diskreport() { # $1: docker info が返す OS 名、残りは diskreport の引数
  local docker_os=$1
  shift
  env -i HOME="$DISK_TEST/home" PATH="$DISK_TEST/bin:/usr/bin:/bin" FAKE_DOCKER_OS="$docker_os" \
    "$DOTFILES_DIR/home/.local/bin/diskreport" "$@" </dev/null 2>&1
}
expect_in() { # $1: 出力, $2: 探す文字列, $3: 説明
  if grep -qF -- "$2" <<<"$1"; then ok "$3"; else ng "$3(「$2」が出力に無い)"; fi
}
expect_not_in() { # $1: 出力, $2: 探す文字列, $3: 説明
  if grep -qF -- "$2" <<<"$1"; then ng "$3(「$2」が出力にある)"; else ok "$3"; fi
}

out=$(run_diskreport "Ubuntu 24.04") || ng "diskreport が非0で終了(Docker Engine)"
expect_in "$out" "4.1G  vm:docker" "Docker Engine: 全行のサイズが足される"
expect_in "$out" "Docker の未使用分 2.5G" "Docker Engine: 未使用分も全行が足される"
expect_not_in "$out" "8589934592" "Docker Engine: 桁あふれしない"

# 桁あふれしていた頃の履歴が残っていても、前回比に出さない
printf '%s\tcat:vm\t9223372036854775807\n' "$(($(date +%s) - 100))" >"$DISK_STATE/diskreport.tsv"
out=$(run_diskreport "Docker Desktop") || ng "diskreport が非0で終了(Docker Desktop)"
expect_not_in "$out" "vm:docker" "Docker Desktop: docker system df を会計に足さない"
expect_in "$out" "Docker の未使用分 2.5G" "Docker Desktop: 未使用分は表示する"
expect_in "$out" "仮想ディスク・コンテナ: 3.0M" "入れ子: カテゴリが違えば内側のカテゴリで数える"
expect_in "$out" "アプリデータ・キャッシュ: 1.0M" "入れ子: 外側のカテゴリからは引く"
expect_not_in "$out" "8589934592" "履歴の異常値を前回比に使わない"

# 見かけだけ大きい疎ファイルは、大きいファイルの索引に載せない
dd if=/dev/null of="$DISK_TEST/home/sparse.img" bs=1 seek=1073741824 count=0 2>/dev/null
run_diskreport "Ubuntu 24.04" scan >/dev/null || ng "diskreport scan が非0で終了"
if [ -f "$DISK_STATE/diskindex-bigfiles.tsv" ] && ! grep -qF "sparse.img" "$DISK_STATE/diskindex-bigfiles.tsv"; then
  ok "大きいファイル: 疎ファイルを実使用量で除外する"
else
  ng "大きいファイル: 疎ファイルが索引に載っている(または索引が無い)"
fi

# ディレクトリ名の改行とタブで偽造できる索引の行を、算術式として評価しない。
# /bin/sh が dash の環境でも確かめられるよう bash で動かす(式の中身は使い捨ての $HOME に空ファイルを作るだけ)
# shellcheck disable=SC2016  # $(...) と $HOME は偽の行の文字列そのもの(ここでは展開しない)
forged='1+HOME[$(: >"$HOME/injected")]'
printf '#time\t%s\n%s\ty\n4096\t%s\n' "$(date +%s)" "$forged" "$DISK_TEST/home/real" >"$DISK_STATE/diskindex-home.tsv"
printf '#time\t%s\n%s\ty\n1024\t%s\n' "$(date +%s)" "$forged" "$DISK_TEST/home/real" >"$DISK_STATE/diskindex-home.tsv.prev"
out=$(env -i HOME="$DISK_TEST/home" PATH="$DISK_TEST/bin:/usr/bin:/bin" FAKE_DOCKER_OS="Ubuntu 24.04" \
  bash "$DOTFILES_DIR/home/.local/bin/diskreport" </dev/null 2>&1) || ng "diskreport が非0で終了(偽造した索引)"
if [ -e "$DISK_TEST/home/injected" ]; then
  ng "索引: 偽造した行の第1列がコマンドとして実行された"
else
  ok "索引: 偽造した行の第1列を評価しない"
fi
expect_in "$out" "+3.0M      4.0M  $DISK_TEST/home/real" "索引: 偽造した行があっても、普通の行の前回比は出る"

echo "== 5) cachesweep が入っているツールだけを表示し、WSL では Windows 側も数えるか"
# Windows 側は偽の powershell.exe が返す行の表示だけを確かめる(PowerShell の中身は動かない)
SWEEP_TEST=$WORK_DIR/cachesweep
mkdir -p "$SWEEP_TEST/bin" "$SWEEP_TEST/home/.cargo/registry/index"
head -c 4096 /dev/urandom >"$SWEEP_TEST/home/.cargo/registry/index/crate"
cat >"$SWEEP_TEST/bin/powershell.exe" <<'EOF'
#!/bin/sh
printf 'npm\t2097152\tC:\\Users\\me\\AppData\\Local\\npm-cache\tFalse\r\n'
printf 'scoop\t1024\tC:\\Users\\me\\scoop\\cache\tTrue\r\n'
EOF
chmod +x "$SWEEP_TEST/bin/powershell.exe"
run_cachesweep() { # 引数は env に渡す追加の環境変数
  env -i HOME="$SWEEP_TEST/home" PATH="$SWEEP_TEST/bin:/usr/bin:/bin" "$@" \
    "$DOTFILES_DIR/home/.local/bin/cachesweep" </dev/null 2>&1
}
out=$(run_cachesweep WSL_DISTRO_NAME=test) || ng "cachesweep が非0で終了"
expect_in "$out" "cargo" "cachesweep: 入っているツールを検出する"
expect_not_in "$out" "yarn" "cachesweep: 入っていないツールは出さない"
expect_in "$out" "2.0G  C:\\Users\\me\\AppData\\Local\\npm-cache" "cachesweep: WSL では Windows 側のサイズを出す"
expect_in "$out" "上限時間で打ち切り" "cachesweep: 打ち切ったことを出す"
expect_in "$out" "合計" "cachesweep: Windows 側の合計を出す"
if ! grep -qi microsoft /proc/version 2>/dev/null; then
  out=$(run_cachesweep) || ng "cachesweep が非0で終了(WSL 以外)"
  expect_not_in "$out" "Windows 側" "cachesweep: WSL 以外では Windows 側を数えない"
fi

echo ""
echo "結果: ok=$pass NG=$fail"
[ "$fail" -eq 0 ] || exit 1
echo "すべてのテストに合格しました。"
