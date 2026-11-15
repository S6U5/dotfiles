# AI ツールが溜めるデータを、ツールとプロファイルごとに数えて表示する

Claude Code・Codex・Claude アプリなどの会話の記録、本体の版、キャッシュは数 GB から十数 GB になる。Claude Code は `CLAUDE_CONFIG_DIR` でプロファイルを分けて使うこともあり、どこに何がどれだけあるかが分かりにくい。人が打って確かめられる `aidata`(`home/.local/bin/`)を足した。

## どこに置くか

| 観点 | `diskreport` の既知パスに足す | `diskreport ai` のような語を足す | 別のコマンド(採用) |
|---|---|---|---|
| ツール・プロファイルごとの内訳が出る | ×(カテゴリ別の会計なので1行ずつ) | ○ | ○ |
| `diskreport` の覚える語を増やさない | ○ | ×(`diskreport` / `scan` / `windows` の3つに決めている) | ○ |
| 普段の `diskreport` の速さを保つ | △(プロファイルを探す分だけ遅くなる) | ○ | ○ |

`diskreport` の既知パス(`~/.claude/projects`・`~/.codex`)はそのまま残し、会計の中の「アプリデータ・キャッシュ」として数える。`diskreport` の「次の一手」から `aidata` を案内する。

## プロファイルの見つけ方

| 観点 | 設定ファイルに一覧を書く | エイリアスを読み取る | フォルダの形で探す(採用) |
|---|---|---|---|
| 設定なしで動く | × | ○ | ○ |
| 置き方を選ばない | ○ | ×(書き方がばらばら) | △(隠しフォルダの下3段まで) |
| 読んではいけないものを読まない | ○ | ×(`local.sh` は資格情報を含みうる) | ○ |

- Claude Code は `projects/` と、`history.jsonl`・`.claude.json`・`file-history/` などを持つフォルダをプロファイルとみなす。Codex は `sessions/<年>/`・`archived_sessions/`・`state_*.sqlite` などを持つフォルダにする。`sessions/` だけなら他の道具(herdr など)にもあるので見分けに使わない。
- 探すのはホームの隠しフォルダと `~/.config` の下3段まで(`~/.claude-work`、`~/.ccs/instances/<名前>` のような置き方に届く深さ)。`node_modules`・`.cache`・ごみ箱などは見ない。いまのシェルの `CLAUDE_CONFIG_DIR`・`CODEX_HOME`・`COPILOT_HOME`・`GEMINI_CLI_HOME` も見る。
- それ以外の場所は `DOTFILES_AI_DIRS`(: 区切り。`local.sh` に書く)か引数で足す。同じ実体と、別のプロファイルの中にあるフォルダは1回だけ数える。

## 数え方と書き方

- 中身はトップの1段だけを `du` で数え、大きい順に出す。ファイルの中身は読まない(会話の記録や設定には秘密が混ざりうるため)。件数と古さは、ファイルの数と更新日で出す。
- 「会話の記録」の列には、会話そのものと入力の履歴だけを足す。Antigravity の `antigravity/` や agy の `antigravity-cli/` のように本体やログと同じフォルダに入っているものは足さず、件数だけを添える(本体の大きさで会話が多く見えないように)。
- 説明は公式の文書(Claude Code の `.claude` ディレクトリのページ、Codex・Gemini CLI・Copilot CLI の文書とソース)にあるものだけ付ける。分からないものは名前と大きさだけ出す。
- 自動で消えるかのメモも、文書にあるものだけ書く(Claude Code の `cleanupPeriodDays` と `desktopSessionCleanupPeriodDays`、Codex の `codex delete`、Gemini CLI の `general.sessionRetention`)。「30 日より前」の数は、Claude Code と Gemini CLI の既定に合わせた固定の日数で数える(実際の設定値を読むには `settings.json` を開く必要があるため)。
- 何も消さない。消し方は各ツールの設定とコマンドを案内するだけにする(`diskreport` と同じ方針)。

## トレードオフ

- フォルダの形はツールの版で変わりうる。形が変わると、プロファイルを見落とすか、内訳の説明が付かなくなる。
- Cursor と Antigravity は会話の置き場が文書に無いので、アプリのフォルダの大きさだけを出す。
- WSL では Windows 側(ユーザーフォルダの `.claude` や Claude アプリ)を数えない。`/mnt` 越しの `du` は遅いため。Windows 側は `diskreport windows` で数える。
- 隠しフォルダの外に置いたプロファイルは、`DOTFILES_AI_DIRS` か引数で足さないと出ない。
