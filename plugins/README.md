# プラグイン(Claude Code / Codex 共通)

このリポジトリ自身を Claude Code と [OpenAI Codex CLI](https://developers.openai.com/codex/) の
**ローカル Marketplace** として公開するためのプラグイン置き場。
**dotfiles 側を正本**にし、両方のツールへ同じスキルを配る。

## 構成

| パス | 用途 |
|------|------|
| `.claude-plugin/marketplace.json` | Claude Code 用の目録 |
| `.agents/plugins/marketplace.json` | Codex 用の目録(Codex で意味のあるものだけ載せる) |
| `plugins/<名前>/.claude-plugin/plugin.json` | Claude Code 用のマニフェスト |
| `plugins/<名前>/.codex-plugin/plugin.json` | Codex 用のマニフェスト |
| `plugins/<名前>/skills/<名前>/SKILL.md` | **スキル本体(両ツールで共有する唯一の実体)** |

`home/` 配下と違い `$HOME` には配置されない(シンボリックリンクを張らない)。
各ツール側にこのリポジトリを Marketplace として登録して使う。

## 収録プラグイン

| 名前 | 説明 | Claude Code | Codex |
|------|------|-------------|-------|
| `shin5` | 図を主体に、とても簡単な日本語で解説するスキル | ○ | ○ |

## セットアップ

### 1. Marketplace を登録する(マシンごとに初回のみ)

**Claude Code**

```sh
/plugin marketplace add ./path/to/dotfiles      # セッション内から
claude plugin marketplace add ./path/to/dotfiles # シェルから
```

ローカルパスの場合、`.claude-plugin/marketplace.json` を含むディレクトリか、
その JSON への直接パスを渡す。

**Codex**

`~/.codex/config.toml` に書く(Codex 側の UI・コマンドから登録しても同じ内容が書かれる)。

```toml
[marketplaces.personal]
source_type = "local"
source = "<このリポジトリのパス>"   # 例: ~/Projects/dotfiles
```

### 2. プラグインを入れる

**プラグインごとに**以下を行う。Marketplace を登録しただけでは何も入らない。

#### shin5

**Claude Code**

```sh
/plugin install shin5@personal          # セッション内から(スコープを対話で選ぶ)
claude plugin install shin5@personal    # シェルから(既定は user スコープ。--scope で変更)
```

インストール後の要約に `Run /reload-plugins to activate.` と出たら `/reload-plugins` を実行する
(`Plugin is now active.` ならその必要はない)。

呼び出しは **`/shin5:shin5`**。プラグインのスキルは `プラグイン名:スキル名` で名前空間が付く。

**Codex**

`~/.codex/config.toml` に書く。

```toml
[plugins."shin5@personal"]
enabled = true
```

呼び出しは `$shin5` または「shin5」。Chrome 拡張のサイドパネルから使っている場合は、
解説を求めたとき(「わからない」「解説して」など)にも自動で発動する。

### 更新・無効化・削除(Claude Code)

**ローカル Marketplace は自動更新が既定で無効**なので、このリポジトリ側を更新したら
明示的に取り込む。

```sh
/plugin marketplace update personal     # このリポジトリの変更を取り込む
/plugin list                            # 入っているプラグインを見る
/plugin disable shin5@personal          # 消さずに無効化
/plugin enable shin5@personal           # 再度有効化
/plugin uninstall shin5@personal        # 削除
```

Codex 側はプラグインを再インストールすると反映される。

### 開発中の動作確認(Claude Code)

Marketplace に登録せず、ディレクトリを直接読み込んで試せる。

```sh
claude --plugin-dir ./plugins/shin5
```

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

共有できるのは `skills/<名前>/SKILL.md` だけで、目録とマニフェストは各ツールの形式で別々に持つ。

| 項目 | Claude Code | Codex |
|------|-------------|-------|
| 目録の場所 | `.claude-plugin/marketplace.json` | `.agents/plugins/marketplace.json` |
| マニフェストの場所 | `plugins/<名前>/.claude-plugin/plugin.json` | `plugins/<名前>/.codex-plugin/plugin.json` |
| 暗黙呼び出しの制御 | `SKILL.md` の `description` の書き方のみ | `skills/<名前>/agents/openai.yaml` の `policy.allow_implicit_invocation` |

Codex 固有の `skills/<名前>/agents/openai.yaml` は、Claude Code のコンポーネント探索
(`skills/*/SKILL.md` と、プラグイン直下の `agents/`)の対象外なので置いたままで問題ない。

### 商用ツールとの関係

Claude Code / Codex はどちらも無償の OSS ではないが、ここに置くのは**設定とプロンプトだけ**で、
この dotfiles の動作がそれらに依存するわけではない(`templates/claude/` と同じ扱い。
「呼び出すのは OK、組み込むのは NG」の方針に反しない)。
