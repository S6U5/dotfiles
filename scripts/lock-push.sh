#!/usr/bin/env bash
#
# このリポジトリの clone に対して、誤 push 事故防止のセーフティネットを掛ける/外す。
# origin の push 先だけを無効な URL に差し替えることで、fetch/pull はそのまま使えるが
# push だけがエラーで即座に失敗するようになる。ローカルの .git/config だけが対象で、
# リポジトリの中身やリモート側には一切影響しない(本気で push URL を書き戻せば push
# できてしまうので、悪意ある第三者からの防御ではなく誤操作防止のためのもの)。
#
#   ./scripts/lock-push.sh           # push を無効化(ロック)
#   ./scripts/lock-push.sh --unlock  # push を元に戻す(fetch URL と同じ値に戻す)
set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$DOTFILES_DIR"

remote=origin
disabled_url=DISABLED

if [ "${1:-}" = "--unlock" ]; then
  fetch_url=$(git remote get-url "$remote")
  git remote set-url --push "$remote" "$fetch_url"
  echo "lock-push: push を有効化しました($remote -> $fetch_url)"
else
  git remote set-url --push "$remote" "$disabled_url"
  echo "lock-push: push を無効化しました($remote への push は失敗するようになります)"
  echo "lock-push: 元に戻すには ./scripts/lock-push.sh --unlock を実行してください"
fi
