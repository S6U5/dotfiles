#!/usr/bin/env bash
#
# home-manager 経由の dotfiles 配布(nix/home.nix の home.file / home.activation)が
# 正しく機能するかのテスト。
#
# 既定では `home-manager build`(実際に適用せず result シンボリックリンクを
# 生成するだけ)で検証するため、実際の $HOME には一切触れない。
# 実際に switch(activate)まで検証したい場合は DOTFILES_TEST_SWITCH=1 を設定する
# (実 HOME を書き換えるため、使い捨て環境専用。CI 以外での使用は非推奨)。
#
#   ./scripts/test-home-manager.sh
#   DOTFILES_TEST_SWITCH=1 ./scripts/test-home-manager.sh   # CI 専用
set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export DOTFILES_DIR
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

case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) SYSTEM=aarch64-darwin ;;
  Linux-x86_64) SYSTEM=x86_64-linux ;;
  Linux-aarch64 | Linux-aarch64_be) SYSTEM=aarch64-linux ;;
  *)
    echo "未対応の環境です: $(uname -s)-$(uname -m)" >&2
    exit 1
    ;;
esac

BUILD_DIR=$(mktemp -d)
BOOTSTRAP_BLOCK=$(mktemp)
BOOTSTRAP_HOME=$(mktemp -d)
PROTECT_HOME=$(mktemp -d)
trap 'rm -rf "$BUILD_DIR" "$BOOTSTRAP_BLOCK" "$BOOTSTRAP_HOME" "$PROTECT_HOME"' EXIT

# 初回セットアップ時(CI含む)は home-manager コマンドがまだ存在しないため、
# 本リポジトリの flake が公開する home-manager CLI(flake.lock に固定)へ
# フォールバックする。レジストリ経由の `nix run home-manager --` は毎回 HEAD を
# 未認証の GitHub API で解決するため、共有 CI ランナーのレート制限(HTTP 403)で
# 断続的に失敗する(認証トークンを CI に渡さずに済ませるための固定化でもある)。
if command -v home-manager >/dev/null 2>&1; then
  HOME_MANAGER=(home-manager)
else
  HOME_MANAGER=(nix run "$DOTFILES_DIR/nix#home-manager" --)
fi

# 失敗時の原因調査用に、握りつぶしていた出力をログへ退避して失敗時だけ表示する
# (CI のフレーク(一時的失敗)なのか実バグなのかをログから判別できるようにする)
show_log_tail() {
  echo "  ---- 失敗時の出力(末尾40行) ----" >&2
  tail -40 "$1" >&2
  echo "  ---------------------------------" >&2
}

echo "== 1) nix flake check"
if nix flake check ./nix --impure >"$BUILD_DIR/flake-check.log" 2>&1; then
  ok "flake評価にエラーなし"
else
  ng "flake評価エラー"
  show_log_tail "$BUILD_DIR/flake-check.log"
fi

echo "== 2) home-manager build(実 HOME には触れない)"
if (cd "$BUILD_DIR" && "${HOME_MANAGER[@]}" build --flake "$DOTFILES_DIR/nix#$SYSTEM" --impure >"$BUILD_DIR/build.log" 2>&1); then
  ok "build 成功"
else
  ng "build 失敗"
  show_log_tail "$BUILD_DIR/build.log"
  echo ""
  echo "結果: ok=$pass NG=$fail"
  exit 1
fi

RESULT="$BUILD_DIR/result"

echo "== 3) home/ 配下の全ファイルが配布対象になり、home/ の実体を指しているか"
# git 管理下の home/ 全ファイルを対象にする(代表ファイルだけだと、walkHome の除外ロジックを
# 変えたときの漏れや、新しく置いたファイルが配布されないケースを見逃す)。
# .gitkeep は walkHome が意図的に除外するため対象外
linked=0
while IFS= read -r f; do
  rel=${f#home/}
  case "$rel" in */.gitkeep | .gitkeep) continue ;; esac
  linked_to=$(readlink -f "$RESULT/home-files/$rel" 2>/dev/null || true)
  expected="$DOTFILES_DIR/$f"
  if [ "$linked_to" = "$expected" ]; then
    linked=$((linked + 1))
  else
    ng "リンク先が不一致: $rel (got: ${linked_to:-リンク無し}, want: $expected)"
  fi
done < <(git ls-files -- home)
if [ "$linked" -gt 0 ]; then
  ok "home/ の $linked ファイルすべてが home/ の実体にリンクされている"
else
  ng "home/ に配布対象のファイルが見つからない"
fi

echo "== 3b) diskreport の既知パス一覧が配布されるか"
if [ -f "$RESULT/home-files/.config/dotfiles/diskreport.paths" ]; then
  ok "配布: .config/dotfiles/diskreport.paths"
else
  ng "未配布: .config/dotfiles/diskreport.paths"
fi

echo "== 4) 実行可能属性が維持されているか"
for f in .local/bin/word .local/bin/dotfiles-update .local/bin/dotfiles-switch .local/bin/diskreport .local/bin/nix-gc-setup .local/bin/dotfiles-help; do
  if [ -x "$RESULT/home-files/$f" ]; then
    ok "実行可能: $f"
  else
    ng "実行不可: $f"
  fi
done

echo "== 5) lazy-lock.json が(ツールの実行時書き込みに備えて)書き込み可能か"
if [ -w "$RESULT/home-files/.config/nvim/lazy-lock.json" ]; then
  ok "lazy-lock.json 書き込み可能"
else
  ng "lazy-lock.json 書き込み不可"
fi

echo "== 6) .bashrc / .bash_profile / .config/zsh/.zshrc は home.file 対象外(activation で生成)"
if [ ! -e "$RESULT/home-files/.bashrc" ] && [ ! -e "$RESULT/home-files/.bash_profile" ] &&
  [ ! -e "$RESULT/home-files/.config/zsh/.zshrc" ]; then
  ok ".bashrc/.bash_profile/.config/zsh/.zshrc は home.file に含まれない"
else
  ng ".bashrc/.bash_profile/.config/zsh/.zshrc が誤って home.file に含まれている"
fi

echo "== 7) herdr agent skill が Nix ストア同梱の SKILL.md にリンクされているか"
skill_target=$(readlink -f "$RESULT/home-files/.claude/skills/herdr/SKILL.md" 2>/dev/null || true)
case "$skill_target" in
  /nix/store/*/share/skills/herdr/herdr/SKILL.md)
    if [ -s "$skill_target" ]; then
      ok "herdr スキルがストア同梱の SKILL.md を指し、中身も空でない"
    else
      ng "herdr スキルの SKILL.md が空"
    fi
    ;;
  *)
    ng "herdr スキルのリンク先が想定外 (got: ${skill_target:-リンク無し})"
    ;;
esac

echo "== 8) shell bootstrap(新規生成・冪等性・既存ファイル保護・バックアップ)"
awk '/^_iNote "Activating %s" "dotfilesShellBootstrap"$/{flag=1; next} flag{print} flag && /^done$/{exit}' \
  "$RESULT/activate" >"$BOOTSTRAP_BLOCK"
if [ -s "$BOOTSTRAP_BLOCK" ]; then
  ok "activation script から bootstrap ブロックを抽出"
else
  ng "bootstrap ブロックが見つからない"
fi

if HOME="$BOOTSTRAP_HOME" VERBOSE_ECHO=: DRY_RUN_CMD='' bash -c ". \"$BOOTSTRAP_BLOCK\"" &&
  [ -f "$BOOTSTRAP_HOME/.bashrc" ] && grep -qF '.config/bash/bashrc' "$BOOTSTRAP_HOME/.bashrc" &&
  [ -f "$BOOTSTRAP_HOME/.config/zsh/.zshrc" ] && grep -qF '.config/zsh/zshrc' "$BOOTSTRAP_HOME/.config/zsh/.zshrc"; then
  ok "bootstrap: 新規生成(bash / zsh)"
else
  ng "bootstrap: 新規生成に失敗"
fi

before=$(cat "$BOOTSTRAP_HOME/.bashrc" "$BOOTSTRAP_HOME/.config/zsh/.zshrc" 2>/dev/null || true)
HOME="$BOOTSTRAP_HOME" VERBOSE_ECHO=: DRY_RUN_CMD='' bash -c ". \"$BOOTSTRAP_BLOCK\"" || true
after=$(cat "$BOOTSTRAP_HOME/.bashrc" "$BOOTSTRAP_HOME/.config/zsh/.zshrc" 2>/dev/null || true)
if [ "$before" = "$after" ]; then
  ok "bootstrap: 冪等性"
else
  ng "bootstrap: 再実行で内容が変わった"
fi

echo "# 手動編集済み" >"$PROTECT_HOME/.bashrc"
HOME="$PROTECT_HOME" VERBOSE_ECHO=: DRY_RUN_CMD='' bash -c ". \"$BOOTSTRAP_BLOCK\"" || true
if [ "$(cat "$PROTECT_HOME/.bashrc")" = "# 手動編集済み" ]; then
  ok "bootstrap: 未認識の既存ファイルを保護(スキップ)"
else
  ng "bootstrap: 既存ファイルを上書きしてしまった"
fi

HOME="$PROTECT_HOME" VERBOSE_ECHO=: DRY_RUN_CMD='' HOME_MANAGER_BACKUP_EXT=hmbak bash -c ". \"$BOOTSTRAP_BLOCK\"" || true
if [ -f "$PROTECT_HOME/.bashrc.hmbak" ] && [ "$(cat "$PROTECT_HOME/.bashrc.hmbak")" = "# 手動編集済み" ] &&
  grep -qF '.config/bash/bashrc' "$PROTECT_HOME/.bashrc"; then
  ok "bootstrap: バックアップ付き上書き(HOME_MANAGER_BACKUP_EXT)"
else
  ng "bootstrap: バックアップ付き上書きに失敗"
fi

echo "== 8b) Nix で入れたコマンドが同名の別コマンドに隠れていないかの検知(dotfilesPathShadow)"
# 偽の HOME / 新しい世代 / Homebrew を作り、activation script から取り出したブロックだけを走らせる
SHADOW_ROOT=$(mktemp -d)
trap 'rm -rf "$BUILD_DIR" "$BOOTSTRAP_BLOCK" "$BOOTSTRAP_HOME" "$PROTECT_HOME" "$SHADOW_ROOT"' EXIT
awk '/^_iNote "Activating %s" "dotfilesPathShadow"$/{flag=1; next} flag && /^_iNote /{exit} flag{print}' \
  "$RESULT/activate" >"$SHADOW_ROOT/block"
mkdir -p "$SHADOW_ROOT/gen/home-path/bin" "$SHADOW_ROOT/home/.local/bin" \
  "$SHADOW_ROOT/brew/bin" "$SHADOW_ROOT/brew/Cellar/ripgrep/1.0/bin"
for name in uv uvx rg mytool other; do
  : >"$SHADOW_ROOT/gen/home-path/bin/$name"
done
: >"$SHADOW_ROOT/home/.local/bin/uv"
: >"$SHADOW_ROOT/home/.local/bin/uvx"
# home-manager が配る自作コマンド(ストアを指すリンク)は対象外
ln -s "$RESULT/activate" "$SHADOW_ROOT/home/.local/bin/mytool"
: >"$SHADOW_ROOT/brew/bin/brew"
chmod +x "$SHADOW_ROOT/brew/bin/brew"
: >"$SHADOW_ROOT/brew/Cellar/ripgrep/1.0/bin/rg"
ln -s ../Cellar/ripgrep/1.0/bin/rg "$SHADOW_ROOT/brew/bin/rg"
if [ -s "$SHADOW_ROOT/block" ] &&
  shadow_out=$(HOME="$SHADOW_ROOT/home" newGenPath="$SHADOW_ROOT/gen" _dotfiles_brew_prefixes="$SHADOW_ROOT/brew" \
    bash -euo pipefail -c ". \"$SHADOW_ROOT/block\"" 2>&1); then
  if printf '%s\n' "$shadow_out" | grep -qF 'rm ~/.local/bin/uv ~/.local/bin/uvx' &&
    printf '%s\n' "$shadow_out" | grep -qF 'brew uninstall ripgrep' &&
    ! printf '%s\n' "$shadow_out" | grep -qE 'mytool|other'; then
    ok "隠れているもの(~/.local/bin の uv / uvx、Homebrew の ripgrep)だけを案内する"
  else
    ng "案内の内容が想定外: $shadow_out"
  fi
else
  ng "dotfilesPathShadow ブロックが見つからない、または途中で失敗した: ${shadow_out:-}"
fi
if [ -s "$SHADOW_ROOT/block" ] &&
  shadow_out=$(HOME="$SHADOW_ROOT/empty" newGenPath="$SHADOW_ROOT/gen" _dotfiles_brew_prefixes="$SHADOW_ROOT/none" \
    bash -euo pipefail -c ". \"$SHADOW_ROOT/block\"" 2>&1) && [ -z "$shadow_out" ]; then
  ok "隠れているものが無ければ何も表示しない"
else
  ng "隠れているものが無いのに表示された、または失敗した: ${shadow_out:-}"
fi

echo "== 9) pre-commit フック有効化(dotfilesGitHooks)と WSL のブラウザ設定が activation script に正しく含まれるか"
if grep -qF 'core.hooksPath .githooks' "$RESULT/activate"; then
  ok "pre-commit フック有効化ロジックを含む"
else
  ng "pre-commit フック有効化ロジックが見つからない"
fi
# activation は空の PATH で走るため、外部コマンドはストアのパスで呼ぶ必要がある
# (`command -v git` で判定すると見つからず、黙って飛ばされていた)
if grep -qE '/nix/store/[^ ]+/bin/git -C ' "$RESULT/activate"; then
  ok "git をストアのパスで呼んでいる"
else
  ng "git をストアのパスで呼んでいない(activation の PATH では見つからない)"
fi
if [ "$(uname -s)" = Linux ]; then
  if grep -qE '/nix/store/[^ ]+/bin/xdg-mime default ' "$RESULT/activate"; then
    ok "xdg-mime をストアのパスで呼んでいる"
  else
    ng "xdg-mime をストアのパスで呼んでいない(activation の PATH では見つからない)"
  fi
fi

echo "== 10) 補完定義ファイルの構文"
if bash -n "$DOTFILES_DIR/home/.config/bash/completions/apps.bash" 2>/dev/null; then
  ok "bash 補完: 構文OK"
else
  ng "bash 補完: 構文エラー"
fi
if command -v zsh >/dev/null 2>&1; then
  if zsh -n "$DOTFILES_DIR/home/.config/zsh/completions/_apps" 2>/dev/null; then
    ok "zsh 補完: 構文OK"
  else
    ng "zsh 補完: 構文エラー"
  fi
  if zsh -n "$DOTFILES_DIR/home/.config/zsh/zshrc" 2>/dev/null; then
    ok "zsh 設定本体(zshrc): 構文OK"
  else
    ng "zsh 設定本体(zshrc): 構文エラー"
  fi
fi

echo "== 11) switch.sh / dotfiles-switch が正しい home-manager コマンドを組み立てるか"
# 偽の home-manager を PATH の先頭に置き、実際には switch せず渡された引数だけを記録する
FAKE_BIN=$(mktemp -d)
FAKE_HOME=$(mktemp -d)
trap 'rm -rf "$BUILD_DIR" "$BOOTSTRAP_BLOCK" "$BOOTSTRAP_HOME" "$PROTECT_HOME" "$SHADOW_ROOT" "$FAKE_BIN" "$FAKE_HOME"' EXIT
cat >"$FAKE_BIN/home-manager" <<'FAKE'
#!/bin/sh
printf '%s\n' "$*" >"$FAKE_ARGS"
printf '%s\n' "${DOTFILES_DIR:-unset}" >"$FAKE_ENV"
FAKE
chmod +x "$FAKE_BIN/home-manager"
want_args="switch --flake $DOTFILES_DIR/nix#$SYSTEM --impure -b bak"
if (cd / && env -u DOTFILES_DIR FAKE_ARGS="$FAKE_BIN/args" FAKE_ENV="$FAKE_BIN/env" PATH="$FAKE_BIN:$PATH" \
  "$DOTFILES_DIR/switch.sh" -b bak >/dev/null) &&
  [ "$(cat "$FAKE_BIN/args")" = "$want_args" ] && [ "$(cat "$FAKE_BIN/env")" = "$DOTFILES_DIR" ]; then
  ok "switch.sh: DOTFILES_DIR / <system> / --impure を揃え、追加引数を素通しする"
else
  ng "switch.sh: 組み立てたコマンドが想定外 (got: $(cat "$FAKE_BIN/args" 2>/dev/null), DOTFILES_DIR: $(cat "$FAKE_BIN/env" 2>/dev/null))"
fi
# home-manager 配布後と同じ形(~/.local/bin からリポジトリへのシンボリックリンク)で呼べるか
mkdir -p "$FAKE_HOME/.local/bin"
ln -s "$DOTFILES_DIR/home/.local/bin/dotfiles-switch" "$FAKE_HOME/.local/bin/dotfiles-switch"
rm -f "$FAKE_BIN/args"
if (cd / && env -u DOTFILES_DIR FAKE_ARGS="$FAKE_BIN/args" FAKE_ENV="$FAKE_BIN/env" PATH="$FAKE_BIN:$PATH" \
  "$FAKE_HOME/.local/bin/dotfiles-switch" -b bak >/dev/null) &&
  [ "$(cat "$FAKE_BIN/args")" = "$want_args" ]; then
  ok "dotfiles-switch: シンボリックリンク越しにリポジトリの switch.sh を解決する"
else
  ng "dotfiles-switch: リンク越しの解決に失敗 (got: $(cat "$FAKE_BIN/args" 2>/dev/null))"
fi
# カレントディレクトリが配布済みと違うクローンの中なら、端末で確かめてからそのクローンを対象にする。
# 権限を緩めるテストがあるので、本人だけが入れる親フォルダ(mktemp -d は 0700)の下に作る
OTHER_ROOT=$(mktemp -d)
OTHER_CLONE=$(cd "$OTHER_ROOT" && pwd -P)/clone
trap 'rm -rf "$BUILD_DIR" "$BOOTSTRAP_BLOCK" "$BOOTSTRAP_HOME" "$PROTECT_HOME" "$SHADOW_ROOT" "$FAKE_BIN" "$FAKE_HOME" "$OTHER_ROOT"' EXIT
mkdir -p "$OTHER_CLONE/nix" "$OTHER_CLONE/home/.config"
cp "$DOTFILES_DIR/switch.sh" "$OTHER_CLONE/switch.sh"
cp "$DOTFILES_DIR/nix/home.nix" "$OTHER_CLONE/nix/home.nix"
if command -v python3 >/dev/null 2>&1; then
  # 端末がある状況と無い状況を作る。使い方: tty-run.py <答え|none> <コマンド...>(none は端末なし)
  cat >"$OTHER_ROOT/tty-run.py" <<'PY'
import os, pty, select, signal, sys, time

answer, cmd = sys.argv[1], sys.argv[2:]
if answer == "none":
    pid = os.fork()
    if pid == 0:
        os.setsid()  # 制御端末を手放す
        os.execvp(cmd[0], cmd)
else:
    pid, fd = pty.fork()
    if pid == 0:
        os.execvp(cmd[0], cmd)
    seen, sent, deadline = b"", False, time.time() + 30
    while True:
        if time.time() > deadline:
            os.kill(pid, signal.SIGKILL)
            break
        if select.select([fd], [], [], 0.2)[0]:
            try:
                chunk = os.read(fd, 4096)
            except OSError:
                break
            if not chunk:
                break
            seen += chunk
            sys.stdout.buffer.write(chunk)
            sys.stdout.buffer.flush()
            if not sent and b"[y/N]" in seen:
                os.write(fd, answer.encode() + b"\n")
                sent = True
sys.exit(os.waitstatus_to_exitcode(os.waitpid(pid, 0)[1]))
PY
  other_switch() { # $1: 答え(none は端末なし)。残りは dotfiles-switch の引数。標準入力の y は効かないはず
    local answer=$1
    shift
    rm -f "$FAKE_BIN/args"
    (cd "$OTHER_CLONE/home/.config" && printf 'y\n' | env -u DOTFILES_DIR FAKE_ARGS="$FAKE_BIN/args" FAKE_ENV="$FAKE_BIN/env" \
      PATH="${OTHER_PATH_PREFIX:-}$FAKE_BIN:$PATH" python3 -I "$OTHER_ROOT/tty-run.py" "$answer" "$FAKE_HOME/.local/bin/dotfiles-switch" "$@" 2>&1)
  }
  want_other="switch --flake $OTHER_CLONE/nix#$SYSTEM --impure"
  want_deployed="switch --flake $DOTFILES_DIR/nix#$SYSTEM --impure"

  rc=0
  output=$(other_switch none) || rc=$?
  if [ "$rc" -ne 0 ] && [ ! -e "$FAKE_BIN/args" ]; then
    ok "dotfiles-switch: 端末が無ければ別のクローンを実行しない(標準入力の y も効かない)"
  else
    ng "dotfiles-switch: 端末なしで別のクローンを実行した (rc=$rc, got: $(cat "$FAKE_BIN/args" 2>/dev/null))"
  fi
  rc=0
  output=$(other_switch n) || rc=$?
  if [ "$rc" -ne 0 ] && [ ! -e "$FAKE_BIN/args" ]; then
    ok "dotfiles-switch: n と答えたら別のクローンを実行しない"
  else
    ng "dotfiles-switch: n でも別のクローンを実行した (rc=$rc, got: $(cat "$FAKE_BIN/args" 2>/dev/null))"
  fi
  rc=0
  output=$(other_switch y) || rc=$?
  if [ "$rc" -eq 0 ] && [ "$(cat "$FAKE_BIN/args" 2>/dev/null)" = "$want_other" ]; then
    ok "dotfiles-switch: y と答えたらカレントディレクトリのクローンを対象にする"
  else
    ng "dotfiles-switch: y でそのクローンを対象にできない (rc=$rc, got: $(cat "$FAKE_BIN/args" 2>/dev/null))"
  fi

  chmod o+w "$OTHER_CLONE/nix/home.nix"
  rc=0
  output=$(other_switch y) || rc=$?
  if [ "$rc" -eq 0 ] && [ "$(cat "$FAKE_BIN/args" 2>/dev/null)" = "$want_other" ] && printf '%s' "$output" | grep -q '書き換えられるもの'; then
    ok "dotfiles-switch: 他の人が書けるものがあれば、警告してから y/N を聞く"
  else
    ng "dotfiles-switch: 権限の緩いクローンの扱いが想定外 (rc=$rc, got: $(cat "$FAKE_BIN/args" 2>/dev/null))"
  fi
  chmod o-w "$OTHER_CLONE/nix/home.nix"

  # 別のユーザーのものは、偽の id で自分の uid をずらして再現する
  mkdir -p "$OTHER_ROOT/fake-id"
  cat >"$OTHER_ROOT/fake-id/id" <<'FAKE'
#!/bin/sh
if [ "$1" = "-u" ]; then
  echo $(($(/usr/bin/id -u) + 1))
  exit 0
fi
exec /usr/bin/id "$@"
FAKE
  chmod +x "$OTHER_ROOT/fake-id/id"
  rc=0
  output=$(OTHER_PATH_PREFIX="$OTHER_ROOT/fake-id:" other_switch none) || rc=$?
  if [ "$rc" -eq 0 ] && [ "$(cat "$FAKE_BIN/args" 2>/dev/null)" = "$want_deployed" ]; then
    ok "dotfiles-switch: 別のユーザーのクローンは使わず、配布済みのクローンを対象にする"
  else
    ng "dotfiles-switch: 別のユーザーのクローンの扱いが想定外 (rc=$rc, got: $(cat "$FAKE_BIN/args" 2>/dev/null))"
  fi

  printf '#!/bin/sh\necho CLONE-RAN\n' >"$OTHER_CLONE/switch.sh"
  rc=0
  output=$(other_switch none --help) || rc=$?
  if [ "$rc" -eq 0 ] && ! printf '%s' "$output" | grep -q CLONE-RAN; then
    ok "dotfiles-switch: --help は別のクローンのコードを動かさず、配布済みのクローンで答える"
  else
    ng "dotfiles-switch: --help の扱いが想定外 (rc=$rc)"
  fi
  cp "$DOTFILES_DIR/switch.sh" "$OTHER_CLONE/switch.sh"

  rm -f "$FAKE_BIN/args"
  if (cd "$DOTFILES_DIR/home/.config" && env -u DOTFILES_DIR FAKE_ARGS="$FAKE_BIN/args" FAKE_ENV="$FAKE_BIN/env" PATH="$FAKE_BIN:$PATH" \
    python3 -I "$OTHER_ROOT/tty-run.py" none "$FAKE_HOME/.local/bin/dotfiles-switch" -b bak >/dev/null 2>&1) &&
    [ "$(cat "$FAKE_BIN/args")" = "$want_args" ]; then
    ok "dotfiles-switch: 配布済みのクローンの中では確認なしで実行する"
  else
    ng "dotfiles-switch: 配布済みのクローンの中で実行できない (got: $(cat "$FAKE_BIN/args" 2>/dev/null))"
  fi
else
  echo "  (python3 が無いので、別のクローンの確認のテストを飛ばします)"
fi

echo "== 12) update.sh が pull のあとに switch.sh を呼ぶか(--no-switch では呼ばないか)"
# 合成した origin / clone で検証する(実リポジトリの remote には触れない)。clone 側の update.sh が
# 偽の home-manager(上の FAKE_BIN)を呼ぶので、組み立てたコマンドで確認できる
UPD_ROOT=$(mktemp -d)
trap 'rm -rf "$BUILD_DIR" "$BOOTSTRAP_BLOCK" "$BOOTSTRAP_HOME" "$PROTECT_HOME" "$SHADOW_ROOT" "$FAKE_BIN" "$FAKE_HOME" "$OTHER_ROOT" "$UPD_ROOT"' EXIT
GIT_T=(git -c user.name=test -c user.email=test@example.com -c init.defaultBranch=main -c commit.gpgsign=false)
mkdir -p "$UPD_ROOT/origin/nix"
cp "$DOTFILES_DIR/update.sh" "$DOTFILES_DIR/switch.sh" "$UPD_ROOT/origin/"
cp "$DOTFILES_DIR/nix/home.nix" "$UPD_ROOT/origin/nix/"
("${GIT_T[@]}" -C "$UPD_ROOT/origin" init -q && "${GIT_T[@]}" -C "$UPD_ROOT/origin" add -A &&
  "${GIT_T[@]}" -C "$UPD_ROOT/origin" commit -q -m init) >/dev/null 2>&1
"${GIT_T[@]}" clone -q "$UPD_ROOT/origin" "$UPD_ROOT/clone" >/dev/null 2>&1
rm -f "$FAKE_BIN/args"
if (cd / && env -u DOTFILES_DIR FAKE_ARGS="$FAKE_BIN/args" FAKE_ENV="$FAKE_BIN/env" PATH="$FAKE_BIN:$PATH" \
  "$UPD_ROOT/clone/update.sh" >/dev/null 2>&1) &&
  [ "$(cat "$FAKE_BIN/args")" = "switch --flake $UPD_ROOT/clone/nix#$SYSTEM --impure" ]; then
  ok "update.sh: pull のあと switch.sh を呼ぶ"
else
  ng "update.sh: pull のあとに switch.sh が呼ばれない (got: $(cat "$FAKE_BIN/args" 2>/dev/null))"
fi
rm -f "$FAKE_BIN/args"
if (cd / && env -u DOTFILES_DIR FAKE_ARGS="$FAKE_BIN/args" FAKE_ENV="$FAKE_BIN/env" PATH="$FAKE_BIN:$PATH" \
  "$UPD_ROOT/clone/update.sh" --no-switch >/dev/null 2>&1) && [ ! -e "$FAKE_BIN/args" ]; then
  ok "update.sh --no-switch: switch.sh を呼ばない"
else
  ng "update.sh --no-switch: switch.sh が呼ばれた、または失敗した"
fi

if [ "${DOTFILES_TEST_SWITCH:-0}" = "1" ]; then
  echo "== 13) home-manager switch(実 HOME に適用。使い捨て環境専用)"
  if "${HOME_MANAGER[@]}" switch --flake "$DOTFILES_DIR/nix#$SYSTEM" --impure -b hmbak >/dev/null 2>&1; then
    ok "switch 成功"
  else
    ng "switch 失敗"
  fi
  if "${HOME_MANAGER[@]}" switch --flake "$DOTFILES_DIR/nix#$SYSTEM" --impure -b hmbak >/dev/null 2>&1; then
    ok "2回目の switch も成功(冪等性)"
  else
    ng "2回目の switch が失敗"
  fi
  for f in .config/bash/bashrc .config/zsh/zshrc .tmux.conf .npmrc .zshenv \
    .bashrc .bash_profile .config/zsh/.zshrc; do
    if [ -e "$HOME/$f" ]; then
      ok "switch後に存在: $f"
    else
      ng "switch後に存在しない: $f"
    fi
  done
fi

echo ""
echo "結果: ok=$pass NG=$fail"
[ "$fail" -eq 0 ] || exit 1
echo "すべてのテストに合格しました。"
