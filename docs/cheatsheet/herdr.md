# herdr

標準の操作は `<leader>` 相当のprefixキー(`Ctrl+b`)を押して少し待つか、`herdr --default-config`
で全設定項目を確認できる。ここには**標準から変更・追加した設定**だけをまとめる。

設定ファイル: `home/.config/herdr/config.toml`

- プレフィックスキーは **デフォルトの `Ctrl+b` のまま**(過去にカスタムを検討したが最終的にデフォルトに統一)
- ペイン分割も **デフォルトのまま**: `prefix + %` で左右分割、`prefix + "` で上下分割。デフォルト値と同じだが `[keys]` の `split_vertical` / `split_horizontal` で明示指定している(tmuxのデフォルトに揃える意図を明文化するため)
- ワークスペース選択(navigate mode)は、ペイン移動(`h`/`j`/`k`/`l`)はデフォルトで既に有効だが、ワークスペース上下だけデフォルトが矢印キーのみだったため `navigate_workspace_up = "k"` / `navigate_workspace_down = "j"` を追加
- エージェントの完了・入力待ち通知は **`[ui.toast]` の `delivery = "herdr"`(アプリ内トースト)を有効化**(デフォルトは `off` で効果音のみ)。アプリ内描画方式なので WSL/macOS/Linux どこでも動く。アクティブなタブへの通知は自動で抑制される
- pane画面履歴のディスク永続化は **`[experimental]` の `pane_history = false` で明示的に無効化**。pane出力にはAPIキー・プロンプト・token等が含まれ得るため。現行デフォルトと同じだが、experimental な機能はデフォルトが変わり得るため先回りして固定している
- 設定変更を反映するには: `herdr server reload-config`(既存セッションを終了せずに反映できる)

## 概念(Workspace / Tab / Pane)

公式ドキュメント([herdr.dev/docs/concepts](https://herdr.dev/docs/concepts/))より、階層関係:

```
Workspace(プロジェクト単位。リポジトリ・タスクごとに1つ)
  └─ Tab(同じワークスペース内でのビュー分離。agents用/ログ用/サーバー用等)
       └─ Pane(実際のターミナルプロセス)
```

- 別プロジェクト・別リポジトリを触る → 新しい **Workspace**
- 同じプロジェクト内で作業の種類を切り替えたい → **Tab**
- 同じ作業の中で画面を分割したい → **Pane分割**
- 完全に独立した複数の作業をしたい場合、公式はワークスペースを増やすより**名前付きセッション**(`herdr --session <name>`)の使用を推奨している

## よく使うCLIコマンド

| コマンド | 内容 |
|---|---|
| `herdr` | セッションを起動 or アタッチ |
| `herdr --session <name>` | 名前付きセッションを使う・作る |
| `herdr session attach <name>` | 既存の名前付きセッションにアタッチ |
| `herdr status` | クライアント/サーバーの稼働状況を表示 |
| `herdr server reload-config` | `config.toml` を再読み込み(セッションは維持) |
| `herdr server stop` | サーバーを停止 |
| `herdr config check` | `config.toml` の構文チェック |
| `herdr config reset-keys` | カスタムキーバインドをバックアップして削除 |
| `herdr update` | 最新版をダウンロード・インストール |
| `herdr channel set stable\|preview` | 更新チャンネルを切り替え |

## よく使うキーバインド(prefix = `Ctrl+b`)

| キー | 内容 |
|---|---|
| `prefix c` | 新規タブ |
| `prefix n` / `prefix p` | 次/前のタブ |
| `prefix 1`〜`9` | タブ番号で直接切り替え |
| `prefix %` | ペインを左右分割 |
| `prefix "` | ペインを上下分割 |
| `prefix h/j/k/l` | ペイン間フォーカス移動 |
| `prefix Tab` / `prefix Shift+Tab` | 次/前のペインへ順番に切り替え(方向を気にせず切り替えたいとき) |
| `prefix x` | ペインを閉じる |
| `prefix z` | ペインをズーム(全画面化) |
| `prefix w` | ワークスペース一覧(その中で `j`/`k` または矢印キーで移動) |
| `prefix Shift+n` | 新規ワークスペース |
| `prefix Shift+w` | ワークスペース名を変更 |
| `prefix Shift+d` | ワークスペースを閉じる |
| `prefix g` | goto(移動) |
| `prefix q` | デタッチ |
| `prefix ?` | ヘルプ(全キーバインド一覧) |

**agentの切り替え(`next_agent`/`previous_agent`/`focus_agent`)はデフォルト未設定**。公式にも
定番の割り当ては無い。必要なら `home/.config/herdr/config.toml` の `[keys]` に自分で追加する
(例: `focus_agent = "prefix+alt+1..9"` で番号ジャンプ)。
