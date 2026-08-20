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

echo "== 3) 代表ファイルが home/ の実体を指しているか"
for f in .config/bash/bashrc .tmux.conf .npmrc \
  .config/shell/init.sh .config/pnpm/rc .local/bin/word .local/bin/dotfiles-update \
  .zshenv .config/zsh/.zshrc .config/nvim/lazy-lock.json; do
  linked_to=$(readlink -f "$RESULT/home-files/$f" 2>/dev/null || true)
  expected="$DOTFILES_DIR/home/$f"
  if [ "$linked_to" = "$expected" ]; then
    ok "リンク先が一致: $f"
  else
    ng "リンク先が不一致: $f (got: $linked_to, want: $expected)"
  fi
done

echo "== 4) 実行可能属性が維持されているか"
for f in .local/bin/word .local/bin/dotfiles-update; do
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

echo "== 6) .bashrc / .bash_profile は home.file 対象外(activation で生成)"
if [ ! -e "$RESULT/home-files/.bashrc" ] && [ ! -e "$RESULT/home-files/.bash_profile" ]; then
  ok ".bashrc/.bash_profile は home.file に含まれない"
else
  ng ".bashrc/.bash_profile が誤って home.file に含まれている"
fi

echo "== 7) bash bootstrap(新規生成・冪等性・既存ファイル保護・バックアップ)"
awk '/^_iNote "Activating %s" "dotfilesBashBootstrap"$/{flag=1; next} flag{print} flag && /^done$/{exit}' \
  "$RESULT/activate" >"$BOOTSTRAP_BLOCK"
if [ -s "$BOOTSTRAP_BLOCK" ]; then
  ok "activation script から bootstrap ブロックを抽出"
else
  ng "bootstrap ブロックが見つからない"
fi

if HOME="$BOOTSTRAP_HOME" VERBOSE_ECHO=: DRY_RUN_CMD='' bash -c ". \"$BOOTSTRAP_BLOCK\"" &&
  [ -f "$BOOTSTRAP_HOME/.bashrc" ] && grep -qF '.config/bash/bashrc' "$BOOTSTRAP_HOME/.bashrc"; then
  ok "bootstrap: 新規生成"
else
  ng "bootstrap: 新規生成に失敗"
fi

before=$(cat "$BOOTSTRAP_HOME/.bashrc" 2>/dev/null || true)
HOME="$BOOTSTRAP_HOME" VERBOSE_ECHO=: DRY_RUN_CMD='' bash -c ". \"$BOOTSTRAP_BLOCK\"" || true
after=$(cat "$BOOTSTRAP_HOME/.bashrc" 2>/dev/null || true)
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

echo "== 8) pre-commit フック有効化(dotfilesGitHooks)が activation script に含まれるか"
if grep -qF 'core.hooksPath .githooks' "$RESULT/activate"; then
  ok "pre-commit フック有効化ロジックを含む"
else
  ng "pre-commit フック有効化ロジックが見つからない"
fi

echo "== 9) 補完定義ファイルの構文"
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
  if zsh -n "$DOTFILES_DIR/home/.config/zsh/.zshrc" 2>/dev/null; then
    ok "zsh .zshrc: 構文OK"
  else
    ng "zsh .zshrc: 構文エラー"
  fi
fi

if [ "${DOTFILES_TEST_SWITCH:-0}" = "1" ]; then
  echo "== 10) home-manager switch(実 HOME に適用。使い捨て環境専用)"
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
  for f in .config/bash/bashrc .tmux.conf .npmrc .zshenv .bashrc .bash_profile; do
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
