# herdr

標準の操作は `<leader>` 相当のprefixキー(`Ctrl+b`)を押して少し待つか、`herdr --default-config`
で全設定項目を確認できる。ここには**標準から変更・追加した設定**だけをまとめる。

設定ファイル: `home/.config/herdr/config.toml`

- プレフィックスキーは **デフォルトの `Ctrl+b` のまま**(過去にカスタムを検討したが最終的にデフォルトに統一)
- ペイン分割も **デフォルトのまま**: `prefix + %` で左右分割、`prefix + "` で上下分割。デフォルト値と同じだが `[keys]` の `split_vertical` / `split_horizontal` で明示指定している(tmuxのデフォルトに揃える意図を明文化するため)
- ワークスペース選択(navigate mode)は、ペイン移動(`h`/`j`/`k`/`l`)はデフォルトで既に有効だが、ワークスペース上下だけデフォルトが矢印キーのみだったため `navigate_workspace_up = "k"` / `navigate_workspace_down = "j"` を追加
- エージェントの完了・入力待ち通知は **`[ui.toast]` の `delivery = "herdr"`(アプリ内トースト)を有効化**(デフォルトは `off` で効果音のみ)。アプリ内描画方式なので WSL/macOS/Linux どこでも動く。アクティブなタブへの通知は自動で抑制される
- **WSL では自作プラグイン `dotfiles.wsl-notify`(`herdr-plugins/wsl-notify`)が Windows のトースト通知も出す**(エージェントが完了・入力待ちになり、かつ WezTerm / Windows Terminal が最前面でないときだけ)。`home-manager switch` で自動登録される。OS 通知の `delivery`(`system` / `terminal`)は WSL で届かないため不採用(判断根拠は `docs/decisions/herdr-notification.md`)
  - テスト通知: `herdr plugin action invoke dotfiles.wsl-notify.test`
  - 実行ログ: `herdr plugin log list --plugin dotfiles.wsl-notify`
  - 一時停止: `herdr plugin disable dotfiles.wsl-notify`(次の `home-manager switch` で有効に戻る)
- エージェントへ直接移動するキーを追加(デフォルトは未設定): `prefix + Alt + 1`〜`9` でサイドバーの Agents パネルの上から N 番目へ、`prefix + Alt + n` / `prefix + Alt + p` で次/前のエージェントへ。macOS では**左の** Option キーを Alt として使う(WezTerm のデフォルトでは右の Option は特殊文字入力用)
- Agents パネルの並び順は **`agent_panel_sort = "priority"`**(デフォルトは Space ごとにまとめる `"spaces"`)。入力待ち(blocked) → 完了(done) → 作業中(working) → 待機(idle) → 不明 の順で、同じ状態なら最近変化したものが上。状態が変わるたびに並びも動く
- テーマは **`rose-pine`** をベースに `[theme.custom]` で上書き: アクセント色を Starship のピンク(`#F2A9C4`)に、選択中の Space / Agent の行(`active_row_bg`)と Navigate モードのカーソル行(`selection_bg`)をピンク寄りの色にして見やすくしている
- エージェントの状態表示は **`status_indicators = "symbols"`**(色の点ではなく形の違う記号)
- 分割したペインの枠にエージェント名を出す(`show_agent_labels_on_pane_borders = true`。`rename_pane` で手動の名前を付けたペインはそちらが優先)
- Space を作るときに名前を聞く(`prompt_new_workspace_name = true`。タブは元々デフォルトで聞かれる)
- サイドバーの行のレイアウトを変更(`[ui.sidebar.agents]` / `[ui.sidebar.spaces]` の `rows`):
  - Agents: 1行目 `Space 名 · エージェント名(太字)`、2行目 エージェントが出すターミナルタイトル(Claude Code なら作業内容の要約。薄く表示)
  - Spaces: 1行目 `Space 名(太字)`、2行目 `ブランチ名 進み/遅れ数 · 状態`(状態は薄く表示し、入力待ち `blocked` のときだけ赤)。Git 管理外の Space でも状態が出るので全 Space が2行に揃う
  - 区切り文字 ` · ` は herdr 側で固定されていて変えられない。文字サイズも変えられないので、強調は太字・薄く表示・色で付ける
- **herdr の画面から設定を変えない**: Settings 画面でのテーマ選択などは `config.toml` に書き込まれ、シンボリックリンク越しにリポジトリ内のファイルが書き換わる(実際に `[theme]` が重複して書き足され、設定全体が読み込めなくなったことがある)。設定はこのファイルを編集して `herdr server reload-config` で反映する。Agents パネル見出しの並び順の切り替え(クリック)も同様に書き込む可能性があるため避ける。操作したあとは `git diff home/.config/herdr/config.toml` で確認する
- pane画面履歴のディスク永続化は **`[experimental]` の `pane_history = false` で明示的に無効化**。pane出力にはAPIキー・プロンプト・token等が含まれ得るため。現行デフォルトと同じだが、experimental な機能はデフォルトが変わり得るため先回りして固定している
- 設定変更を反映するには: `herdr server reload-config` または `prefix + Shift + r`(既存セッションを終了せずに反映できる)

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
定番の割り当ては無いが、この dotfiles では `prefix + Alt + 1`〜`9` / `n` / `p` に割り当てている(上記参照)。
