# プロジェクト共有用 Claude Code 設定の雛形

`settings.json.template` をプロジェクトルートの `.claude/settings.json` にコピーして使う
(チームで共有する場合はコピー後の内容をそのプロジェクトのリポジトリにコミットする)。

```sh
mkdir -p .claude
cp templates/project/.claude/settings.json.template .claude/settings.json
```

## 雛形に入れないもの

- **許可リスト(`permissions.allow`)** — 「確認なしで実行されるコマンドの一覧」は
  攻撃者(特にプロンプトインジェクション)に有益な情報のため、雛形には入れない。
  下の参考例からプロジェクトに合わせて必要な分だけコピー先で足す
  (`templates/claude/README.md` のユーザー設定版と同じ方針)。
- **deny はテンプレートに残す** — 防御の表明は公開しても失うものがなく、
  全プロジェクトに配る価値がある。

## 参考: 許可リスト(allow)の例

コピー先の `.claude/settings.json` の `permissions` に、プロジェクトに応じて
必要な分だけ足して使う。

```json
"allow": [
  "Read",
  "Read(./.env.example)",
  "Edit",
  "Write",
  "Bash(npm run *)",
  "Bash(npm install)",
  "Bash(npm test)",
  "Bash(npx *)",
  "Bash(yarn *)",
  "Bash(pnpm *)",
  "Bash(git status)",
  "Bash(git diff *)",
  "Bash(git log *)",
  "Bash(git branch *)",
  "Bash(git checkout *)",
  "Bash(git add *)",
  "Bash(git commit *)",
  "Bash(git pull)",
  "Bash(git fetch *)",
  "Bash(ls *)",
  "Bash(mkdir *)",
  "Bash(cp *)",
  "Bash(mv *)",
  "Bash(which *)",
  "Bash(pwd)",
  "Bash(node *)",
  "Bash(python *)",
  "Bash(python3 *)"
]
```

## 注意

- settings.json は厳密な JSON(コメント不可)のため、雛形にもコメントは書かない。
  補足はこの README に書く。
- API キー・機密はこの雛形にもコピー先にも書かない。
