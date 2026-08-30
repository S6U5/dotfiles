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

### Claude Code

```sh
# このリポジトリを Marketplace として登録(パスは ./ 始まりの相対パスで指定する)
claude plugin marketplace add ./path/to/dotfiles
```

登録後、`/plugin` から使うプラグインを有効化する。

### Codex

`~/.codex/config.toml` に登録する(Codex 側の UI・コマンドから登録した場合も同じ内容が書かれる)。

```toml
[marketplaces.personal]
source_type = "local"
source = "<このリポジトリのパス>"   # 例: ~/Projects/dotfiles

[plugins."shin5@personal"]
enabled = true
```

プラグインを更新したときは、各ツール側で再インストールすると反映される。

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
