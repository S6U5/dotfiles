# Claude Code ユーザー設定の雛形

`settings.json.template` を各マシンの `~/.claude/settings.json` にコピーして使う
(自動リンクはしない。テンプレート配布方式)。

```sh
cp templates/claude/settings.json.template ~/.claude/settings.json
```

## ルール

- **API キーをこの雛形に書かない**。settings.json は `env` に `ANTHROPIC_API_KEY` 等を
  直書きできてしまうが、キーが必要な場合はコピー先でのみ、
  `~/.config/shell/local.sh`(git 管理外)の環境変数か `apiKeyHelper` 方式を使う。
- マシン固有の設定はコピー先でのみ変更する。全マシンに効かせたい変更は
  この雛形に反映してコミットする(その際キー・個人情報が混ざっていないか全文確認)。
- 通知フックはクロスプラットフォームの `notify` コマンド(`home/.local/bin/notify`)
  経由なので、macOS / WSL / Linux のどこでも動く。

## 注意

- settings.json は厳密な JSON(コメント不可)のため、雛形にもコメントは書かない。
  補足はこの README に書く。
