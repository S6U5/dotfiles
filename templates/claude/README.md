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

## 雛形に入れないもの(コピー先でのみ設定する)

- **API キー・機密**(前述)
- **モデル指定(`model`)** — モデル名は時期で変わる時限的な値。未指定ならその時々の既定が使われる
- **実験的フラグ(`env` の `CLAUDE_CODE_EXPERIMENTAL_*` 等)** — 将来のバージョンで廃止・改名されうる
- **広すぎる許可** — `curl`(任意 URL への送信)や `pkill`(プロセス強制終了)などは自動許可にせず都度確認する

## 注意

- settings.json は厳密な JSON(コメント不可)のため、雛形にもコメントは書かない。
  補足はこの README に書く。
