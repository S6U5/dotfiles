# agent-interop

複数のコーディングエージェントで同じ資産を使い回すためのプラグイン。指示ファイルと
プラグインを、ツールをまたいで1本化する。

## インストール

```sh
# Claude Code
claude plugin install agent-interop@s6u5-dotfiles

# Codex
codex plugin add agent-interop@s6u5-dotfiles
```

Marketplace をまだ登録していない場合は、先に [../README.md](../README.md) の手順を実行する。

## 収録スキル

- **`agents-init`**(呼び出しは `/agent-interop:agents-init`)— CLAUDE.md を新規作成するとき、中身を
  `@AGENTS.md` の1行にとどめ、指示の実体を AGENTS.md 側へ集約する。ビルド手順や規約のほとんどは
  Claude Code 固有ではなく、他のエージェントにも同じものを読ませたいため。逆に AGENTS.md から作った
  場合もカバーする。Claude Code は CLAUDE.md が無ければ AGENTS.md を直接読むが、`CLAUDE.local.md` や
  親階層の CLAUDE.md があるだけで読まれなくなるなど抜け道が残るため、既定では確認なしで参照役の
  CLAUDE.md を作る。CLAUDE.md を作らず AGENTS.md 1本にする選択肢は、明示的に頼まれたときだけ採る。

- **`agent-plugin-init`**(呼び出しは `/agent-interop:agent-plugin-init`)— Claude Code・Codex・
  Agent Plugins 標準の3形式に届くプラグインを作る。共有できるのは `skills/` だけで、マニフェストは
  3つとも要る、という前提から置き場所を決める判断が本体。新規作成だけでなく、既存プラグインへの
  機能追加や新しい規格への移行にも使う。

どちらも状況に応じて自動で発動する(CLAUDE.md / AGENTS.md を作る場面、プラグインを作る場面)。

## ソース

[S6U5/dotfiles](https://github.com/S6U5/dotfiles) の `plugins/agent-interop/`
