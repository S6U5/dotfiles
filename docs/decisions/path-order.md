# PATH の並び(Nix と自作コマンドを先にする)

macOS では、入れ子のシェル(tmux・herdr の中など)で PATH の並びが変わり、Nix で入れたコマンドが Homebrew や `/usr/bin` の同名コマンドに隠れる。

- 新しいログインシェル: `/etc/zprofile` の `path_helper` が `/etc/paths` と `/etc/paths.d/`(Homebrew のインストーラが置く `/etc/paths.d/homebrew` を含む)を並べたあと、`/etc/zshrc` の `nix-daemon.sh` が Nix を先頭に足すので、`~/.local/bin` → Nix → システム → Homebrew になる。
- 入れ子のシェル: `path_helper` が受け継いだ PATH を並べ直してシステムと Homebrew を先頭に置き、`nix-daemon.sh` は受け継いだ `__ETC_PROFILE_NIX_SOURCED` を見て何もしない。システム → Homebrew → `~/.local/bin` → Nix になる。`env.sh` は「無ければ足す」だけだったので直らなかった。

| 観点 | **`env.sh` で先頭に置き直す(採用)** | `__ETC_PROFILE_NIX_SOURCED` を消して `nix-daemon.sh` を毎回走らせる | `/etc/paths.d/homebrew` を消す | nix-darwin で PATH を管理する |
| --- | --- | --- | --- | --- |
| zsh と bash の両方に効く | ○ | × `/etc/zshrc` に Nix の行がある zsh だけ | △ | ○ |
| `/usr/bin` の同名にも勝つ | ○ | ○ | × | ○ |
| システムのファイルに触れない | ○ | ○ | × sudo が要り、Homebrew の入れ直しで戻る | × |
| 既存の方針との整合 | ○ | △ Nix のインストーラの書き方に頼る | × | × nix-darwin は対象外(`package-management.md`) |

## 選んだ理由

- `home/.config/shell/env.sh` は zsh と bash の両方から読まれ(`init.sh` が最初に読む)、`path_helper` よりあとに走る。ここで `~/.local/bin` → `~/.nix-profile/bin` → `/nix/var/nix/profiles/default/bin` を、既にあっても取り除いてから先頭へ置き直せば、新しいシェルと入れ子のシェルで同じ並びになる。
- Nix のプロファイルは、Nix 自身のスクリプトが PATH に足しているときだけ動かし、`env.sh` からは足さない(足すのは Nix の役目で、`NIX_PROFILES` など PATH 以外の設定も一緒に要るため)。
- Homebrew とシステムの順番は変えない(今までどおり、`/etc/paths.d/homebrew` があればシステムのあと、無ければ `env.sh` が先頭に足す)。Nix にあるものは Nix が勝ち、Nix に無いものの扱いは今までと変わらない。

## トレードオフ

- `env.sh` を読まないもの(GUI のアプリ、`launchd` から起動するもの)には効かない。`home.activation.dotfilesPathShadow` と `pkgwhere` の「隠れている」案内は残す。
- `~/.local/bin` が Nix より前なので、そこに置いた同名のコマンド(公式インストーラの残りなど)は引き続き Nix に勝つ。これは自作コマンドを最優先にするための意図した並びで、隠れていれば `dotfilesPathShadow` が知らせる。

## 履歴

- (本 ADR): 2026-11、Homebrew の node が Nix の node を隠し、セキュリティリリースを取り込んでも古い node が使われ続けていたことをきっかけに決定
- (今後この決定が覆ったら、ここに追記していく。全面書き換えはしない)
