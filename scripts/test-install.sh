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
for f in .zshrc .bashrc .tmux.conf .npmrc \
  .config/shell/init.sh .config/pnpm/rc .local/bin/word .local/bin/dotfiles-update; do
  if [ -L "$TEST_HOME/$f" ] && [ -e "$TEST_HOME/$f" ]; then
    ok "リンク: $f"
  else
    ng "リンクなし/リンク切れ: $f"
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
if HOME="$TEST_HOME" bash -c '. "$HOME/.config/shell/init.sh" && type mkcd >/dev/null && type cdov >/dev/null'; then
  ok "bash: 関数(mkcd / cdov)が定義される"
else
  ng "bash: 関数が定義されない"
fi
if command -v zsh >/dev/null 2>&1; then
  if HOME="$TEST_HOME" zsh -ic 'type mkcd >/dev/null && type cdov >/dev/null' >/dev/null 2>&1; then
    ok "zsh: .zshrc 経由で関数が定義される"
  else
    ng "zsh: .zshrc 読み込みで失敗"
  fi
else
  echo "  skip: zsh が無い環境のため省略"
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
fi

echo ""
echo "結果: ok=$pass NG=$fail"
[ "$fail" -eq 0 ] || exit 1
echo "すべてのテストに合格しました。"
