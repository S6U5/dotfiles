# OpenAI Codex CLI 設定

OpenAI Codex CLI の設定ファイル雛形。各マシンへ手動コピーして使う
(`$HOME` への自動リンクはしない。テンプレート配布方式)。
macOS / Windows / Linux 共通。

## ファイル一覧

| ファイル | 説明 |
|----------|------|
| `config.toml.template` | おすすめ設定（バランス型） |
| `config.minimal.toml.template` | 最小限の設定 |
| `config.full.toml.template` | 全オプション記載（リファレンス用） |
| `AGENTS.md.template` | プロジェクト指示テンプレート |

## 配置場所

| 雛形 | ユーザー設定 | プロジェクト設定 |
|----------|-------------|-----------------|
| `config.toml.template` | `~/.codex/config.toml` | `.codex/config.toml` |
| `AGENTS.md.template` | `~/.codex/AGENTS.md` | `AGENTS.md` or `.codex/AGENTS.md` |

## 使い方

```bash
# ユーザー設定をセットアップ
mkdir -p ~/.codex
cp templates/codex/config.toml.template ~/.codex/config.toml

# プロジェクト設定をセットアップ
mkdir -p .codex
cp templates/codex/config.toml.template .codex/config.toml
cp templates/codex/AGENTS.md.template AGENTS.md
```

## 主な設定項目

### モデル設定

```toml
# model = "<モデル名>"            # 使用モデル（雛形では未指定。下記参照）
model_provider = "openai"         # プロバイダー
model_reasoning_effort = "medium" # 推論レベル（minimal/low/medium/high/xhigh）
```

モデル名は時期で変わる時限的な値なので雛形には書かない（`templates/claude/README.md` と同じ方針）。
未指定ならその時々の既定が使われる。固定したい場合はコピー先で指定する。

### セキュリティ設定

```toml
# 承認ポリシー
approval_policy = "on-failure"  # untrusted/on-failure/on-request/never

# サンドボックスモード
sandbox_mode = "workspace-write"  # read-only/workspace-write/danger-full-access
```

### Web 検索

```toml
web_search = "cached"  # disabled/cached/live
```

### MCP サーバー

```toml
[mcp_servers.github]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-github"]
```

## 雛形に入れないもの(コピー先でのみ持つ)

Codex は**実行中に `~/.codex/config.toml` を自動で書き換える**。実機の設定を
この雛形へ還元するときは、以下が混ざっていないか必ず全文を確認して削除する。

| 項目 | 混ざるもの |
|------|-----------|
| `model`（モデル名） | 時期で変わる時限的な値。未指定なら既定が使われる |
| `[projects."..."]` | 信頼済みディレクトリ。実ユーザー名入りの絶対パス・実プロジェクト名 |
| `[marketplaces.*]` / `[plugins."..."]` | プラグインの導入状態。マシンごとのキャッシュパス |
| `[tui.*]` / `[desktop]` | UI の状態値。共有する意味がない |
| `notify` / ChatGPT アプリ同梱の MCP サーバー | 実機のアプリ絶対パス・クライアントのハッシュ値 |
| API キー・トークン | `[mcp_servers.*.env]` に直書きせず `${GITHUB_TOKEN}` のような環境変数参照にする |

## 設定の優先順位（高 → 低）

```
CLI引数 → .codex/config.toml（プロジェクト） → ~/.codex/config.toml（ユーザー）
```

## AGENTS.md の書き方

AGENTS.md はプロジェクトの規約や指示を記述するファイルです。

### 推奨セクション

| セクション | 内容 |
|-----------|------|
| Working agreements | 作業ルール（テスト実行、レビュー要件） |
| Repository expectations | プロジェクト固有の規約 |
| Code style | コーディング規約 |
| Testing | テスト方針とコマンド |

### 配置と優先順位

```
~/.codex/AGENTS.md           # グローバル（全プロジェクト共通）
AGENTS.md                    # プロジェクトルート
subdir/AGENTS.md             # サブディレクトリ（より具体的）
AGENTS.override.md           # 上書き用（最優先）
```

## Claude Code との比較

| 項目 | Codex | Claude Code |
|------|-------|-------------|
| 設定ファイル | `config.toml` | `settings.json` |
| 指示ファイル | `AGENTS.md` | `CLAUDE.md` |
| MCP 設定 | `config.toml` 内 | `.mcp.json` |
| 拡張 | プラグイン（`.codex-plugin/`）+ Skills | プラグイン + Skills |

## 公式ドキュメント

- [Config basics](https://developers.openai.com/codex/config-basic/)
- [Configuration Reference](https://developers.openai.com/codex/config-reference/)
- [Sample Configuration](https://developers.openai.com/codex/config-sample/)
- [AGENTS.md Guide](https://developers.openai.com/codex/guides/agents-md/)
- [MCP Integration](https://developers.openai.com/codex/mcp)
