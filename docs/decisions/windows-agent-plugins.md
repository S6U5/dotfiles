# ネイティブ Windows のエージェントへのプラグインの届け方

WSL とネイティブ Windows の両方に Claude Code / Codex CLI を入れている場合、設定ディレクトリ(`~/.claude`・`~/.codex` と `%USERPROFILE%\.claude`・`%USERPROFILE%\.codex`)は完全に別物になり、WSL 内で行った Marketplace の登録は Windows 側に届かない。この穴をどう塞ぐかの決定。

## 検討した代替

- **何もしない**(エージェントは WSL 内でしか使わないことにする)
- **UNC パスでローカル登録**(Windows 側から `\\wsl.localhost\<ディストリ名>\home\<ユーザー名>\...` を Marketplace のパスとして登録する)
- **WSL から Windows 側へプラグインの実体をコピーする明示実行コマンドを作る**([`windows-supply-chain.md`](windows-supply-chain.md) の `wsl-supplychain-setup` と同型)
- **Windows 側でも GitHub 経由で Marketplace を登録する**(採用。手順は README「同梱プラグイン」参照)

## 選んだ理由

- プラグインで効くのはファイルの実体ではなく **Marketplace の参照先**であり、設定ファイルのようにコピーする必然性がない。両側が同じ GitHub リポジトリを独立に参照すれば、それだけで同じスキルが届く。
- 本リポジトリは公開済みなので、GitHub 経由ならマシン固有の絶対パス・ディストリ名・ユーザー名がどこにも出てこない。WSL / macOS / Linux で使っているコマンドと1文字も変わらない。
- UNC 参照は、WSL が停止していると参照先ごと消え、9p 経由で読みが遅く、パスにディストリ名とユーザー名が入る。3点とも常用する登録先としては致命的。
- コピー方式のコマンドは、`wsl-font-setup` / `wsl-supplychain-setup` と違って**代行する処理がほとんど無い**(Windows 側で登録と導入を数行叩くだけ)。README に手順を書けば足り、コマンドを増やす価値が薄い。

## トレードオフ

- WSL 側(`agent-plugins-setup` によるローカル参照)は編集が即反映されるのに対し、Windows 側は GitHub 参照のため **push するまで反映されない**。追従のタイミングが非対称になる。
- Windows 側の登録・更新は手動。`agent-plugins-setup` は POSIX sh のため、ネイティブ Windows では動かない(WSL 内から Windows 側の `claude.exe` を叩く形にもしない。上記のとおり代行する処理が無いため)。
