# home-manager switch の実行方法(環境変数の手打ちか、ラッパーコマンドか)

`nix/home.nix` は `home/` の実体パスを `builtins.getEnv "DOTFILES_DIR"` で解決する([`dotfiles-distribution.md`](dotfiles-distribution.md))。そのため `home-manager switch` のたびに `export DOTFILES_DIR=$(pwd)`・`<system>` の選択・`--impure` の3点を手で揃える必要があり、どれかを忘れると「DOTFILES_DIR が未設定です」のエラーで止まる(別タブや新しいシェルで export が消えているのが典型)。この手間をどこで吸収するかの決定。

## 検討した代替

| 観点 | 毎回手で揃える(従来) | `home.nix` で `PWD` にフォールバック | `env.sh` で `DOTFILES_DIR` を自動 export | ラッパー `switch.sh` + `dotfiles-switch`(採用) |
|---|---|---|---|---|
| export 忘れ・別タブで消える問題 | × | ○ | ○(初回セットアップ中は無理) | ○ |
| `--impure` 忘れ・`<system>` の手入力 | × | × | × | ○ |
| 対象クローンが明示されるか | ○(`$(pwd)`) | △(別ディレクトリから実行すると黙って違う場所を指す) | △(配布済みクローンに固定) | ○(スクリプトの場所で決まり、実行前に表示) |
| 初回(`home-manager` 未導入)でも使えるか | ○(手順が別) | ○ | × | ○(`nix run` フォールバック内蔵) |
| 反映は明示実行のみ、という方針 | ○ | ○ | ○ | ○(打つコマンドが変わるだけ) |

## 選んだ理由

- エラーの原因は3点とも「毎回手で打つ運用」そのものなので、スクリプトに閉じ込めるのが筋。`home.nix` 側の fail-closed な throw はそのまま残す(手動実行で間違えたときに黙って違うパスへリンクが張られるより、止まる方が安全)。
- `PWD` フォールバックは別ディレクトリから実行したときに意図しないパスへ配布してしまう。`env.sh` での自動 export は「export 忘れ」しか救えず、初回セットアップ中は効かない。
- 既存の `update.sh` + `home/.local/bin/dotfiles-update`(自身のシンボリックリンクをたどってリポジトリを見つける薄いラッパー)と同じ二段構成にし、`home-manager` 不在時のフォールバックと `<system>` 判定は `scripts/test-home-manager.sh` と同じ実装にして、新しい流儀を増やさない。
- 「反映は明示実行のみ」([`package-management.md`](package-management.md))は、シェル起動時や `update.sh` から勝手に `switch` が走ることを禁じる方針であり、ユーザーが自分で打つコマンドが増えるのは方針の枠内([`windows-supply-chain.md`](windows-supply-chain.md) の履歴で同じ整理をしている)。

## トレードオフ

- ラッパーの中で何が起きているか見えにくくなる。対策として、対象クローンと実行する `home-manager` コマンドの全文を実行前に必ず表示する。
- PATH 上の `dotfiles-switch` は「配布済みのクローン」を指す。別クローン(ブランチ検証用など)を反映したいときは、そのクローンの `./switch.sh` を実行する必要がある(表示で気づけるようにしてある)。
- リポジトリを移動した直後は `~/.local/bin/dotfiles-switch` が移動前のパスを指して壊れているので、その1回だけは移動先で `./switch.sh` を直接呼ぶ(README「リポジトリを別の場所へ移動したとき」)。

## 履歴

- 2026-10: README の `home-manager switch` の例すべてに `export DOTFILES_DIR=$(pwd)` を足す対応をした際、「参照するのは `nix/home.nix` だけ」「反映は明示実行のみ」「実行のたびに対象リポジトリを明示する」を理由にラッパーは設けない判断をした。ただしこの判断は PR 本文にしか残っておらず ADR 化していなかった。
- 2026-11: 上記を覆してラッパーを採用(本 ADR)。「明示実行のみ」はラッパーを断る理由にならないこと、「対象を明示する」は実行前の表示で満たせること、手打ちの箇所が README 4 か所と `update.sh` の案内文に散らばって実際に export 忘れのエラーが起きていることから。当時の判断が思い出せなかった反省として、今回は ADR に残す。
