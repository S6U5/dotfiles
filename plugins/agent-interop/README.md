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
  場合もカバーする(Claude Code は AGENTS.md をネイティブに読まないので、参照役の CLAUDE.md が無いと
  指示が一度も読み込まれない)。

- **`agent-plugin-init`**(呼び出しは `/agent-interop:agent-plugin-init`)— Claude Code・Codex・
  Agent Plugins 標準の3形式に届くプラグインを作る。共有できるのは `skills/` だけで、マニフェストは
  3つとも要る、という前提から置き場所を決める判断が本体。新規作成だけでなく、既存プラグインへの
  機能追加や新しい規格への移行にも使う。

どちらも状況に応じて自動で発動する(CLAUDE.md / AGENTS.md を作る場面、プラグインを作る場面)。

## ソース

[S6U5/dotfiles](https://github.com/S6U5/dotfiles) の `plugins/agent-interop/`
