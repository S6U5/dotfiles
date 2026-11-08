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
for f in mkcd cdgr tmpd cdov ov cdod cdode cdic cdgd cdwin _dotfiles_is_wsl _dotfiles_pick_line; do
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
  for f in mkcd cdgr tmpd cdov ov cdod cdode cdic cdgd cdwin _dotfiles_is_wsl _dotfiles_pick_line; do
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

echo ""
echo "結果: ok=$pass NG=$fail"
[ "$fail" -eq 0 ] || exit 1
echo "すべてのテストに合格しました。"
