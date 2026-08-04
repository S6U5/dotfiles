#!/usr/bin/env bash
#
# まっさらな環境で install.sh が正しく配置できるかのテスト。
# 実際の $HOME は汚さず、一時ディレクトリを HOME に見立てて検証する。
# devcontainer / CI / ローカル / Docker コンテナのどこでも実行可能。
#
#   ./scripts/test-install.sh
set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

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

TEST_HOME=$(mktemp -d)
trap 'rm -rf "$TEST_HOME"' EXIT

echo "== 1) クリーンな HOME へのインストール"
if HOME="$TEST_HOME" "$DOTFILES_DIR/install.sh" >/dev/null; then
  ok "install.sh 正常終了"
else
  ng "install.sh が失敗"
fi

echo "== 2) 代表ファイルがリンクされているか"
for f in .config/bash/bashrc .tmux.conf .npmrc \
  .config/shell/init.sh .config/pnpm/rc .local/bin/word .local/bin/dotfiles-update \
  .zshenv .config/zsh/.zshrc; do
  if [ -L "$TEST_HOME/$f" ] && [ -e "$TEST_HOME/$f" ]; then
    ok "リンク: $f"
  else
    ng "リンクなし/リンク切れ: $f"
  fi
done

echo "== 2b) .bashrc / .bash_profile はブートストラップの実ファイル(シンボリックリンクではない)"
for f in .bashrc .bash_profile; do
  if [ -f "$TEST_HOME/$f" ] && [ ! -L "$TEST_HOME/$f" ] && grep -qF '.config/bash/bashrc' "$TEST_HOME/$f"; then
    ok "ブートストラップ: $f"
  else
    ng "ブートストラップになっていない: $f"
  fi
done

echo "== 3) 冪等性(再実行しても安全)"
if HOME="$TEST_HOME" "$DOTFILES_DIR/install.sh" >/dev/null; then
  ok "再実行が正常終了"
else
  ng "再実行でエラー"
fi

echo "== 4) 既存ファイルを侵略しない"
rm "$TEST_HOME/.npmrc"
echo "keep-me" >"$TEST_HOME/.npmrc"
HOME="$TEST_HOME" "$DOTFILES_DIR/install.sh" >/dev/null 2>&1 || true
if [ "$(cat "$TEST_HOME/.npmrc")" = "keep-me" ]; then
  ok "既存ファイルが保持される(スキップ)"
else
  ng "既存ファイルが書き換えられた"
fi

echo "== 5) シェルから設定を読み込めるか"
if HOME="$TEST_HOME" sh -c '. "$HOME/.config/shell/init.sh"'; then
  ok "sh: init.sh 読み込み"
else
  ng "sh: init.sh 読み込みでエラー"
fi
if HOME="$TEST_HOME" bash -ic 'type mkcd >/dev/null && type cdov >/dev/null' >/dev/null 2>&1; then
  ok "bash: ブートストラップ(~/.bashrc)経由で関数が定義される"
else
  ng "bash: ブートストラップ経由での関数定義に失敗"
fi
if command -v zsh >/dev/null 2>&1; then
  if HOME="$TEST_HOME" zsh -ic 'type mkcd >/dev/null && type cdov >/dev/null' >/dev/null 2>&1; then
    ok "zsh: ZDOTDIR(~/.zshenv)経由で関数が定義される(home-manager 未適用でも動く)"
  else
    ng "zsh: ZDOTDIR経由での関数定義に失敗"
  fi
fi

echo "== 6) 自作コマンド(アプリの無い環境でも壊れないか)"
if HOME="$TEST_HOME" PATH="$TEST_HOME/.local/bin:$PATH" word >/dev/null 2>&1; then
  ok "word: 正常終了(アプリ不在時も壊れない)"
else
  ng "word: 異常終了"
fi

echo "== 7) --force(既存ファイルを .bak に退避して上書き)"
rm "$TEST_HOME/.npmrc"
echo "keep-me" >"$TEST_HOME/.npmrc"
HOME="$TEST_HOME" "$DOTFILES_DIR/install.sh" --force >/dev/null 2>&1 || true
if [ -L "$TEST_HOME/.npmrc" ] && [ -e "$TEST_HOME/.npmrc" ]; then
  ok "--force: リンクに置き換わる"
else
  ng "--force: リンクに置き換わらない"
fi
bak_file=$(find "$TEST_HOME" -maxdepth 1 -name '.npmrc.bak.*' | head -n 1)
if [ -n "$bak_file" ] && [ "$(cat "$bak_file")" = "keep-me" ]; then
  ok "--force: 元の内容が .bak に保全される"
else
  ng "--force: .bak が無いか内容が失われた"
fi

echo "== 8) --prune(リポジトリ由来のリンク切れだけを掃除)"
# 実リポジトリは変更せず、コピーしたリポジトリでファイル削除を再現する
PRUNE_REPO=$(mktemp -d)
PRUNE_HOME=$(mktemp -d)
trap 'rm -rf "$TEST_HOME" "$PRUNE_REPO" "$PRUNE_HOME"' EXIT
cp -R "$DOTFILES_DIR/." "$PRUNE_REPO/"
HOME="$PRUNE_HOME" "$PRUNE_REPO/install.sh" >/dev/null 2>&1 || true
rm "$PRUNE_REPO/home/.local/bin/word"
ln -s /no/such/other-tool "$PRUNE_HOME/.local/bin/other-tool"
HOME="$PRUNE_HOME" "$PRUNE_REPO/install.sh" --prune >/dev/null 2>&1 || true
if [ ! -e "$PRUNE_HOME/.local/bin/word" ] && [ ! -L "$PRUNE_HOME/.local/bin/word" ]; then
  ok "--prune: 削除されたファイルのリンク切れが消える"
else
  ng "--prune: リンク切れが残っている"
fi
if [ -L "$PRUNE_HOME/.local/bin/other-tool" ]; then
  ok "--prune: 他ツールのリンク切れには触れない"
else
  ng "--prune: 他ツールのリンクを消してしまった"
fi
if [ -L "$PRUNE_HOME/.local/bin/excel" ] && [ -e "$PRUNE_HOME/.local/bin/excel" ]; then
  ok "--prune: 生きているリンクは無傷"
else
  ng "--prune: 生きているリンクが壊れた"
fi

echo "== 8b) リンク切れの扱い(dotfiles 由来だけ張り替え、他ツール由来は保護)"
RELINK_HOME=$(mktemp -d)
trap 'rm -rf "$TEST_HOME" "$PRUNE_REPO" "$PRUNE_HOME" "$RELINK_HOME"' EXIT
# 旧リポジトリ由来を装ったリンク切れ → 張り替えられるべき
ln -s "/no/such/old-repo/home/.npmrc" "$RELINK_HOME/.npmrc"
# 他ツール由来のリンク切れ(dotfiles 構造ではない)→ 触ってはいけない
ln -s "/Volumes/UnmountedSSD/config.txt" "$RELINK_HOME/.tmux.conf"
HOME="$RELINK_HOME" "$DOTFILES_DIR/install.sh" >/dev/null 2>&1 || true
if [ -L "$RELINK_HOME/.npmrc" ] && [ -e "$RELINK_HOME/.npmrc" ]; then
  ok "relink: dotfiles 由来のリンク切れは張り替わる"
else
  ng "relink: dotfiles 由来のリンク切れが張り替わらない"
fi
if [ "$(readlink "$RELINK_HOME/.tmux.conf")" = "/Volumes/UnmountedSSD/config.txt" ]; then
  ok "relink: 他ツール由来のリンク切れは保護される"
else
  ng "relink: 他ツール由来のリンクが書き換えられた"
fi

echo "== 8c) .bashrc の旧方式(home/ 直下へのシンボリックリンク)からブートストラップへの移行"
BOOTSTRAP_MIGRATE_HOME=$(mktemp -d)
trap 'rm -rf "$TEST_HOME" "$PRUNE_REPO" "$PRUNE_HOME" "$RELINK_HOME" "$BOOTSTRAP_MIGRATE_HOME"' EXIT
# 移行前の状態を模倣: home/.bashrc(旧パス、実際には存在しない)へのリンク切れ
ln -s "$DOTFILES_DIR/home/.bashrc" "$BOOTSTRAP_MIGRATE_HOME/.bashrc"
HOME="$BOOTSTRAP_MIGRATE_HOME" "$DOTFILES_DIR/install.sh" >/dev/null 2>&1 || true
if [ -f "$BOOTSTRAP_MIGRATE_HOME/.bashrc" ] && [ ! -L "$BOOTSTRAP_MIGRATE_HOME/.bashrc" ] &&
  grep -qF '.config/bash/bashrc' "$BOOTSTRAP_MIGRATE_HOME/.bashrc"; then
  ok "migrate: 旧方式のリンク切れがブートストラップに置き換わる"
else
  ng "migrate: 旧方式のリンク切れがブートストラップに置き換わらない"
fi

echo "== 8d) ブートストラップの冪等性(再実行で内容が変わらない)"
before=$(cat "$BOOTSTRAP_MIGRATE_HOME/.bashrc")
HOME="$BOOTSTRAP_MIGRATE_HOME" "$DOTFILES_DIR/install.sh" >/dev/null 2>&1 || true
after=$(cat "$BOOTSTRAP_MIGRATE_HOME/.bashrc")
if [ "$before" = "$after" ]; then
  ok "bootstrap: 再実行しても内容が変わらない"
else
  ng "bootstrap: 再実行で内容が変わった"
fi

echo "== 8e) --uninstall(リンク・ブートストラップファイルの削除)"
UNINSTALL_HOME=$(mktemp -d)
trap 'rm -rf "$TEST_HOME" "$PRUNE_REPO" "$PRUNE_HOME" "$RELINK_HOME" "$BOOTSTRAP_MIGRATE_HOME" "$UNINSTALL_HOME"' EXIT
HOME="$UNINSTALL_HOME" "$DOTFILES_DIR/install.sh" >/dev/null 2>&1 || true
# ユーザーが手を加えた .bashrc は誤って消されないことも検証する
printf '%s\n# 手動で追記した内容\n' "$(cat "$UNINSTALL_HOME/.bashrc")" >"$UNINSTALL_HOME/.bashrc"
HOME="$UNINSTALL_HOME" "$DOTFILES_DIR/install.sh" --uninstall >/dev/null 2>&1 || true
if [ ! -L "$UNINSTALL_HOME/.npmrc" ] && [ ! -e "$UNINSTALL_HOME/.npmrc" ]; then
  ok "uninstall: シンボリックリンクが削除される"
else
  ng "uninstall: シンボリックリンクが残っている"
fi
if [ ! -e "$UNINSTALL_HOME/.bash_profile" ]; then
  ok "uninstall: 未編集のブートストラップファイル(.bash_profile)が削除される"
else
  ng "uninstall: 未編集のブートストラップファイルが残っている"
fi
if [ -f "$UNINSTALL_HOME/.bashrc" ]; then
  ok "uninstall: 手を加えた .bashrc は削除されず保護される"
else
  ng "uninstall: 手を加えた .bashrc が誤って削除された"
fi
HOME="$UNINSTALL_HOME" "$DOTFILES_DIR/install.sh" >/dev/null 2>&1 || true
if [ -L "$UNINSTALL_HOME/.npmrc" ] && [ -e "$UNINSTALL_HOME/.npmrc" ]; then
  ok "uninstall後の再install: 正常にリンクし直せる"
else
  ng "uninstall後の再install: リンクできない"
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

echo ""
echo "結果: ok=$pass NG=$fail"
[ "$fail" -eq 0 ] || exit 1
echo "すべてのテストに合格しました。"
