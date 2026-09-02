# プラグイン(Claude Code / Codex 共通)

このリポジトリ自身を Claude Code と [OpenAI Codex CLI](https://developers.openai.com/codex/) の
**ローカル Marketplace** として公開するためのプラグイン置き場。
**dotfiles 側を正本**にし、両方のツールへ同じスキルを配る。

## 構成

| パス | 用途 |
|------|------|
| `.claude-plugin/marketplace.json` | Claude Code 用の目録 |
| `.agents/plugins/marketplace.json` | Codex 用の目録(Codex で意味のあるものだけ載せる) |
| `plugins/<名前>/plugin.json` | Agent Plugins 1.0 標準のマニフェスト(Cursor / Copilot / VS Code / Kiro / Gemini ほか) |
| `plugins/<名前>/.claude-plugin/plugin.json` | Claude Code 用(ルートの標準版を読まないため別に要る) |
| `plugins/<名前>/.codex-plugin/plugin.json` | Codex 用(同上。加えて `"skills": "./skills/"` のパス明示が要る) |
| `plugins/<名前>/skills/<名前>/SKILL.md` | **スキル本体(全ツールで共有する唯一の実体)** |
| `plugins/<名前>/skills/<名前>/agents/openai.yaml` | Codex / ChatGPT 用の UI メタデータ(任意) |

`home/` 配下と違い `$HOME` には配置されない(シンボリックリンクを張らない)。
各ツール側にこのリポジトリを Marketplace として登録して使う。

## 収録プラグイン

| 名前 | 収録スキル | 説明 | Claude Code | Codex |
|------|------------|------|-------------|-------|
| [`shin5`](shin5/README.md) | `shin5` | 図を主体に、とても簡単な日本語で解説する | ○ | ○ |
| [`agent-interop`](agent-interop/README.md) | `agents-init` | CLAUDE.md を `@AGENTS.md` の1行にとどめ、指示の実体を AGENTS.md に集約する | ○ | ○ |
| | `agent-plugin-init` | Claude Code / Codex / 標準の3形式に届くプラグインを作る(共通化の範囲を判断して実装) | ○ | ○ |

## セットアップ

### 1. Marketplace を登録する(マシンごとに初回のみ)

通常は **GitHub 経由**で登録する。マシンごとに違う絶対パスへ依存せず、どの環境でも同じコマンドで
済むため。`--sparse` を付けるとプラグイン関連のディレクトリだけを取得するので、dotfiles 本体を
まるごとクローンせずに済む。

```sh
# Claude Code
claude plugin marketplace add S6U5/dotfiles --sparse .claude-plugin plugins

# Codex
codex plugin marketplace add S6U5/dotfiles --sparse .agents --sparse plugins
```

**プラグイン自体を編集しているときはローカルパスで登録する**(GitHub 経由だと push するまで
反映されないため)。

```sh
/plugin marketplace add ./path/to/dotfiles      # Claude Code、セッション内から
claude plugin marketplace add ./path/to/dotfiles # Claude Code、シェルから
codex plugin marketplace add ./path/to/dotfiles  # Codex
```

ローカルパスの場合、Claude Code には `.claude-plugin/marketplace.json` を含むディレクトリか、
その JSON への直接パスを渡す。Codex 側は `~/.codex/config.toml` に次の形で書かれる
(UI・コマンドから登録しても同じ内容)。

```toml
[marketplaces.s6u5-dotfiles]
source_type = "local"
source = "<このリポジトリのパス>"   # 例: ~/Projects/dotfiles
```

**Cursor は目録を経由しない。** `~/.cursor/plugins/local/` に置いたものを直接読むので、
プラグインごとにシンボリックリンクを張る(ルート直下の `plugin.json` が読まれる)。

```sh
ln -s "$PWD/plugins/agent-interop" ~/.cursor/plugins/local/agent-interop
```

張ったあと Cursor を再起動するか **Developer: Reload Window** を実行する。

### まとめてやる

`agent-plugins-setup`(`home/.local/bin/`)が、以下をまとめて行う。何度実行しても安全。

- Marketplace の登録(未登録なら)と更新
- 未導入のプラグインの導入
- 取り残しの点検(`~/.claude/skills/` の手動配置、`plugins/` から消えたのに導入済みのもの)

```sh
agent-plugins-setup             # plugins/ 配下すべて
agent-plugins-setup shin5       # 指定したものだけ
```

**有効/無効の切り替えには触れない。** 意図して無効にしたものを勝手に戻さないため。
取り残しも報告するだけで削除はしない。以下は手動で行う場合の手順。

### 2. プラグインを入れる

**プラグインごとに**以下を行う。Marketplace を登録しただけでは何も入らない。

#### shin5

**Claude Code**

```sh
/plugin install shin5@s6u5-dotfiles          # セッション内から(スコープを対話で選ぶ)
claude plugin install shin5@s6u5-dotfiles    # シェルから(既定は user スコープ。--scope で変更)
```

インストール後の要約に `Run /reload-plugins to activate.` と出たら `/reload-plugins` を実行する
(`Plugin is now active.` ならその必要はない)。

呼び出しは **`/shin5:shin5`**。プラグインのスキルは `プラグイン名:スキル名` で名前空間が付く。

**Codex**

`~/.codex/config.toml` に書く。

```toml
[plugins."shin5@s6u5-dotfiles"]
enabled = true
```

呼び出しは `$shin5` または「shin5」。Chrome 拡張のサイドパネルから使っている場合は、
解説を求めたとき(「わからない」「解説して」など)にも自動で発動する。

#### agent-interop

**Claude Code**

```sh
/plugin install agent-interop@s6u5-dotfiles
claude plugin install agent-interop@s6u5-dotfiles
```

呼び出しは **`/agent-interop:agents-init`** と **`/agent-interop:agent-plugin-init`**。どちらも
状況に応じて自動でも発動する(CLAUDE.md / AGENTS.md を作る場面、プラグインを作る場面)。

**Codex**

```sh
codex plugin add agent-interop@s6u5-dotfiles
```

`~/.codex/config.toml` に直接書いてもよい。

```toml
[plugins."agent-interop@s6u5-dotfiles"]
enabled = true
```

### 更新・無効化・削除(Claude Code)

**ローカル Marketplace は自動更新が既定で無効**なので、このリポジトリ側を更新したら
明示的に取り込む。

```sh
/plugin marketplace update s6u5-dotfiles     # このリポジトリの変更を取り込む
/plugin list                            # 入っているプラグインを見る
/plugin disable shin5@s6u5-dotfiles          # 消さずに無効化
/plugin enable shin5@s6u5-dotfiles           # 再度有効化
/plugin uninstall shin5@s6u5-dotfiles        # 削除
```

Codex 側はプラグインを再インストールすると反映される。

### 開発中の動作確認(Claude Code)

このリポジトリで作業している間は、`.claude/skills/` にプラグインへの symlink を張っておくと、
Marketplace に登録しなくても読み込まれる。`.claude-plugin/plugin.json` を持つディレクトリは
`<名前>@skills-dir` として扱われるため、**呼び出し名も配布時と同じ `<名前>:<スキル名>` になる**。

```sh
ln -sfn ../../plugins/agent-interop .claude/skills/agent-interop
ln -sfn ../../plugins/shin5 .claude/skills/shin5
```

リンクはコミットしない(`.gitignore` に列挙してある。プラグインを増やしたらそこにも1行足す)。

単発で試すだけなら、ディレクトリを直接読み込む方法もある。

```sh
claude --plugin-dir ./plugins/shin5
```

なお `~/.claude/skills/` に同名のスキルがあると、そちらが優先される(personal スコープが
project スコープを上書きするため)。古い実体が残っていると、直したはずの内容が反映されない。

## 方針

### スキルの中身に個人的な文脈・機密を書かない(最重要)

**SKILL.md はプロンプトであり、カスタマイズされたプロジェクト情報が最も混ざりやすい。**
実際のプロジェクト名・vault のパス・所属・業務の事情などは、「役に立つ具体例」のつもりで
書いた一文に紛れ込む。コミット前に必ず全文を読み直すこと
(pre-commit フックと gitleaks が見るのは機密パターンだけで、文脈の混入は人間しか検出できない)。

### 目的単位で分割する

1つのプラグインに全部を詰めない。目的が同じスキル群をまとめる粒度で分ける。

理由は、Claude Code にしかない機能(commands / hooks / workflows / outputStyles など)を
使うプラグインが出てきたときに、分かれていれば **Codex の目録に載せないだけで済む**から。
1つに詰めていると、Codex 側に意味を持たないファイルが混ざる。更新時の再インストール範囲も
プラグイン単位で閉じる。

### MCP サーバーはプラグインに入れない

- Claude Code はプラグイン内の `.mcp.json`、Codex は `config.toml` の `[mcp_servers.*]` と
  形式が非互換で、共通化の余地がない
- MCP サーバーは API キーを要求するものが多く、公開リポジトリに置く方針と相性が悪い
- マシンごとの導入状態と対で管理するもの(`templates/claude/README.md` が `enabledPlugins` を
  雛形に入れないのと同じ理由)

必要になったら `templates/` 側で雛形として配る。

### ツール間の差分

共有できるのは `skills/<名前>/SKILL.md` だけ。マニフェストは各ツールの分をそれぞれ置く。

**Claude Code も Codex もルート直下の `plugin.json` を読まない。** Claude Code は
`.claude-plugin/plugin.json` を、Codex は `.codex-plugin/plugin.json` を見る。しかも Codex は
Claude Code と違って `skills/` を規約で自動検出しないため、マニフェストにパスを書く必要がある。

紛らわしいのは、標準形式だけのプラグインでも Claude Code では `skills/` があれば動いてしまう
こと。ただしそのときマニフェストは読まれておらず、プラグイン名はディレクトリ名から取られ、
`version` も `displayName` も伝わらない(実測で確認)。**動くことと意図どおり読まれていることは
別なので、1つに寄せて整理した気にならないこと。** 3つのマニフェストは重複ではなく、それぞれ
別のツールが読む。`name` / `version` / `description` は3つとも揃えておく。

| 項目 | Claude Code | Codex |
|------|-------------|-------|
| 目録の場所 | `.claude-plugin/marketplace.json` | `.agents/plugins/marketplace.json` |
| スキルの UI メタデータ | 指定できない | `skills/<名前>/agents/openai.yaml` の `interface` |
| 暗黙呼び出しの制御 | `SKILL.md` の frontmatter `disable-model-invocation` | 同ファイルの `policy.allow_implicit_invocation` |

`agents/openai.yaml` は Claude Code のコンポーネント探索の対象外なので、置いたままで問題ない。
`allow_implicit_invocation` の既定は `true` なので、暗黙発火を許すなら `policy` ごと省略する。

### 商用ツールとの関係

Claude Code / Codex はどちらも無償の OSS ではないが、ここに置くのは**設定とプロンプトだけ**で、
この dotfiles の動作がそれらに依存するわけではない(`templates/claude/` と同じ扱い。
「呼び出すのは OK、組み込むのは NG」の方針に反しない)。
