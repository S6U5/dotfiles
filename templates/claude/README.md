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
- **許可リスト(`permissions.allow`)** — 「確認なしで実行されるコマンドの一覧」は攻撃者(特にプロンプトインジェクション)に有益な情報であり、リポジトリを公開する場合は晒さない。またマシン・用途で変わる個人設定でもある。**コピー先でのみ**下の参考例から必要な分を足す。一方 **deny はテンプレートに残す**(防御の表明は公開しても失うものがなく、全マシンに配る価値がある)
- **モデル指定(`model`)** — モデル名は時期で変わる時限的な値。未指定ならその時々の既定が使われる
- **実験的フラグ(`env` の `CLAUDE_CODE_EXPERIMENTAL_*` 等)** — 将来のバージョンで廃止・改名されうる
- **プラグイン構成(`enabledPlugins`)** — プラグインはマシンごとの導入状態と対で管理するもの。雛形には書かず、各マシンで導入・有効化する

## 参考: 許可リスト(allow)の例

コピー先の `~/.claude/settings.json` の `permissions` に、必要な分だけ足して使う。
`curl`(任意 URL への送信)や `pkill`(プロセス強制終了)のような広すぎる許可は入れず、都度確認にする。

```json
"allow": [
  "Bash(mkdir:*)", "Bash(touch:*)", "Bash(ls:*)", "Bash(tree:*)",
  "Bash(mv:*)", "Bash(cp:*)", "Bash(cat:*)", "Bash(grep:*)",
  "Bash(find:*)", "Bash(echo:*)", "Bash(true)",
  "Bash(npm install:*)", "Bash(npm run dev:*)", "Bash(npm run build:*)",
  "Bash(npm run test:*)", "Bash(npm run lint)", "Bash(npm run lint:*)",
  "Bash(npm run format:*)", "Bash(npm ls:*)", "Bash(npx:*)", "Bash(npm exec:*)"
]
```

## 注意

- settings.json は厳密な JSON(コメント不可)のため、雛形にもコメントは書かない。
  補足はこの README に書く。
