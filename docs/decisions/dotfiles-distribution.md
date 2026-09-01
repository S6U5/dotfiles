# dotfiles 本体(home/)の配布方式

**結論**: `home/` を唯一のソースツリーとして維持しつつ、配布経路は `install.sh` の手動シンボリックリンクから `home-manager`(`home.file` + `mkOutOfStoreSymlink`)に一本化した(2026-08)。

## 背景

従来は「`home/` 配下を `install.sh` がシンボリックリンクする」系統と「`nix/home.nix` の `home.packages` でツールを導入する」系統という2つの独立した管理システムが併存していた。これ自体が保守コストになっているとして、二重管理の解消を目的に一本化した。

## 検討した代替

| 観点 | 現状維持(install.sh) | `programs.zsh`/`programs.bash` 等の専用モジュール | `home.file` の通常コピー方式 | `home.file` + `mkOutOfStoreSymlink`(採用) |
|---|---|---|---|---|
| 管理系統の一本化 | ×(home/ と nix/ が別系統) | ○ | ○ | ○ |
| Nix未実行時に最低限動くか | ○ | ×(過去に実際に壊れた) | ○ | ○ |
| home/ を直接編集して即反映されるか | ○ | -(そもそも生ファイルを持たない) | ×(Nix storeコピーは read-only) | ○ |
| ツール自身の実行時書き込み(例: LazyVimのlazy-lock.json)に耐えるか | ○ | - | ×(read-onlyで壊れる) | ○ |

## 選んだ理由

- **`mkOutOfStoreSymlink`** は home-manager が公式提供する、Nix storeにコピーせず指定した絶対パス(=リポジトリ内の実体ファイル)へ直接シンボリックリンクを張る仕組み。これにより、通常の `home.file.source`(Nix storeコピー方式)が抱える2つの問題を回避できる: (1) 編集のたびに `home-manager switch` が必要になるDX劣化、(2) LazyVimの `lazy-lock.json` のようにツール自身が実行時に書き込むファイルが read-only 化で壊れる問題。
- **`programs.zsh` / `programs.bash` は使わない**。過去(oh-my-zsh導入時)に zsh 設定の生成そのものを home-manager モジュールに委ねたところ、「`home-manager switch` を一度も実行していない初期状態だとシェル設定が一切効かない」という不具合が発生した(`docs/decisions/zshrc-pollution.md` の履歴参照)。今回は `home/` の中身をテキストファイルのまま `home.file` で配置するだけにとどめ、home-manager独自の設定生成ロジックには依存しない。
- **`~/.bashrc` / `~/.bash_profile` / `~/.config/zsh/.zshrc` だけは `home.file` にせず `home.activation` で生成する**。これらは「nvm/pyenv/Homebrew等のインストーラが自由に追記しても実害が出ない、dotfiles 管理外の実ファイル」であることが設計の本質(`docs/decisions/zshrc-pollution.md`)。`home.file`(`mkOutOfStoreSymlink`)にすると、シンボリックリンク越しの追記がエラーにならず最終実体=リポジトリ管理下ファイルへ書き込まれてしまう(中間リンクが read-only の Nix store 内にあっても防げないことを検証済み。詳細は `zshrc-pollution.md` の履歴参照)。
- `home/` を再帰的に読んで `home.file` エントリを機械生成する(`nix/home.nix` の `walkHome`)ことで、`install.sh` の `find "$HOME_SRC" -type f` ループと同じ「新規ファイルを `home/` に足すだけで自動的に配布対象になる」エルゴノミクスを維持している。

## トレードオフ

- **Nixが唯一のセットアップ経路になった(fail-open → fail-closed)**。従来は `install.sh` だけで最低限のシェル環境が手に入ったが、統合後は初回 `home-manager switch` が失敗すると新規マシンでは `$PATH` 追加・エイリアス・関数を含め何も使えない。Nixが使えない環境向けのフォールバックは意図的に作らない(まさに解消したい「二系統管理」を別の形で再現してしまうため)。
- `DOTFILES_DIR` という新しい環境変数が必要になった(`nix/home.nix` が `home/` の実体パスを解決するため。`home.username` の `builtins.getEnv "USER"` と同じ `--impure` 前提の流儀)。
- `mkOutOfStoreSymlink` は実体上「Nix store内の中間シンボリックリンク → リポジトリ実体」という2段構成になる(`readlink -f` で最終的に正しい実体を指すことは確認済み)。
- macOSのAPFSボリューム作成は、従来はパッケージ管理だけの理由で必要だったが、統合後は dotfiles を使う限り必ず通る前提になった。
- CI(`test.yml`)は実際にNixをインストールして `home-manager switch` まで検証するようになり、従来のbashのみのテストより明らかに重い。
- 機密混入しうる単一ファイル(`.gitconfig`、各種 `settings.json` 等)は今回の変更でも `templates/` 配布のまま変更していない(`docs/decisions/gitconfig-management.md` 参照)。「機密を書き込みうるファイルは自動配布しない」という設計思想は、配布経路が `install.sh` から `home-manager` に変わっても維持している。

## 履歴

- (`install.sh` の手動シンボリックリンク → `home-manager`(`home.file` + `mkOutOfStoreSymlink`)、本ADR): 上記の理由により決定。`install.sh` / `backup.sh` / `scripts/test-install.sh` を削除し、`scripts/test-home-manager.sh` に置き換えた。`update.sh` は縮小し、`git pull` 後に `home-manager switch` の実行を促すメッセージ表示のみに変更した。
- (2026-09: `~/.config/zsh/.zshrc` も `home.activation` 生成の対象に追加): nvm のインストーラが ZDOTDIR を尊重して `$ZDOTDIR/.zshrc` へ追記すること、および `mkOutOfStoreSymlink` のリンク越しの追記はエラーにならずリポジトリ内の実体へ書き込まれることが判明したため。zsh の設定本体は `home/.config/zsh/zshrc` へ移動した(経緯の詳細は `docs/decisions/zshrc-pollution.md` の履歴参照)。
- (今後この決定が覆ったら、ここに追記していく。全面書き換えはしない)
