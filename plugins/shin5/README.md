# shin5

図を主体に、とても簡単な日本語で解説するプラグイン。

## インストール

```sh
# Claude Code
claude plugin install shin5@personal

# Codex
codex plugin add shin5@personal
```

Marketplace をまだ登録していない場合は、先に [../README.md](../README.md) の手順を実行する。

## 収録スキル

- **`shin5`**(呼び出しは `/shin5:shin5`、Codex では `$shin5`)— 与えられた話題を、図を主体にした
  とても簡単な日本語で説明する。図が絵として描画される環境(Chrome 拡張のサイドパネルなど)では
  `svg` / `mermaid` のコードブロックで出力し、描画されない環境(ターミナルなど)では HTML の
  アーティファクトに切り替える。

Chrome 拡張のサイドパネルから使っている場合は、解説を求めたとき(「わからない」「解説して」など)
にも自動で発動する。それ以外の環境では明示的に呼んだときだけ動く。

## ソース

[S6U5/dotfiles](https://github.com/S6U5/dotfiles) の `plugins/shin5/`
