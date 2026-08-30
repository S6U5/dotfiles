# VS Code 設定の雛形

各マシンへ手動コピーして使う(`$HOME` への自動リンクはしない。テンプレート配布方式)。
**ファイルごとにコピー先が違う**ので注意。

| 雛形 | コピー先 | 種類 |
|------|---------|------|
| `settings.json.template` | macOS: `~/Library/Application Support/Code/User/settings.json`<br>Linux: `~/.config/Code/User/settings.json`<br>Windows: `%APPDATA%\Code\User\settings.json` | **ユーザー設定**(全プロジェクトに効く個人設定) |
| `extensions.json.template` | プロジェクトの `.vscode/extensions.json` | **プロジェクト設定**(そのプロジェクトの推奨拡張リスト) |

```sh
# ユーザー設定(macOS の例)
cp templates/vscode/settings.json.template "$HOME/Library/Application Support/Code/User/settings.json"

# プロジェクトの推奨拡張
mkdir -p .vscode
cp templates/vscode/extensions.json.template .vscode/extensions.json
```

`settings.json` はコピー先のパスが OS で違うため、`home/` の直マッピング(home-manager 配布)の
対象にしていない(判断基準は `AGENTS.md`「ツール設定を dotfiles に入れるかの判断基準」)。

## ルール

- **API キー・サブスクリプションキーを雛形に書かない**。コピー先でのみ記入し、
  可能なら拡張機能の SecretStorage / キーチェーン保存を使う
- ユーザー名入りの絶対パスなどマシン固有の値も雛形には書かない
  (`settings.json.template` 末尾の「マシン固有」欄をコピー先で埋める)
- 実機の設定を雛形へ還元するときが唯一の混入ポイントなので、その際は必ず全文を精査する

## 雛形に入れないもの

- `launch.json`(デバッグ構成) / `tasks.json`(タスク定義) — 中身がプロジェクト固有で、
  雛形にすると `configurations: []` のような空ファイルにしかならない。VS Code が UI から
  同じものを自動生成するため、写す情報が無い
