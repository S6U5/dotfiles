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

echo ""
echo "結果: ok=$pass NG=$fail"
[ "$fail" -eq 0 ] || exit 1
echo "すべてのテストに合格しました。"
