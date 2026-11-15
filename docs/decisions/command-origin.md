# コマンドの出どころを PATH 上のパスの形から判定して表示する

同じ名前のコマンドが Nix・Homebrew・npm -g などに重なって入り、どれが使われているか、どれが dotfiles の管理下かが分かりにくい。人が打って確かめられる `pkgwhere`(`home/.local/bin/`)を足した。

| 観点 | 各パッケージ管理に一覧を聞く | PATH 上のパスとリンク先の形で判定(採用) | `nix-duplicate-check` スキルを広げる | switch のときの案内だけ |
|---|---|---|---|---|
| 「実際に使われるもの」が分かる | ×(入っているかしか分からない) | ○(PATH の順に見る) | ○ | △(switch のときだけ) |
| 速さ | ×(brew・dnf などは1回数秒) | ○(1秒未満) | ○ | ○ |
| 道具が無い環境で壊れない | △ | ○(無いものは飛ばす) | ○ | ○ |
| 人がいつでも打てる | ○ | ○ | ×(エージェントから呼ぶもの) | × |

- 分け方は dotfiles · Nix / dotfiles · 自作 / OS(Homebrew・apt・rpm・pacman・snap・macOS 標準とインストーラ)/ 個別(nix profile・npm -g・pnpm・uv tool・pipx・cargo・go・アプリ同梱・手で置いたもの)/ Windows 側。dotfiles が入れるのは Nix の `home.packages` と自作コマンドだけなので(OS のパッケージ管理は直接使わない。[`package-management.md`](package-management.md))、「dotfiles の管理か」はこの2つかどうかで決まる。
- 判定はリンクを1段ずつたどった先の形で行う(`/nix/store/<ハッシュ>-<名前>`、`Cellar/<formula>`、`uv/tools/<名前>` など)。home-manager の分かどうかは、今の世代の `home-path/bin` の同名のファイルと同じものかで見る(nix profile で別に入れたものと分けるため)。パッケージ名は、リンクをたどる途中で最初に出会うパッケージのものを使う(最後までたどると nodejs が nodejs-slim になるなど、`home.packages` に書いた名前と変わるため)。
- 帳簿を引くのは軽いものだけにする: dpkg(`dpkg -S`)・macOS の `pkgutil --file-info` は PATH 上の1つのファイルの持ち主を聞くときだけ。Homebrew の「自分で入れたもの」は `INSTALL_RECEIPT.json` を grep し、`brew` 自体は起動しない。
- 消すことはしない。Nix で入れたコマンドが別のものに隠れているときだけ、消し方(`brew uninstall` など)と「残すなら PATH で Nix の bin を先にする」を案内する(`home.activation.dotfilesPathShadow` と同じ「検出して報告するだけ」の方針)。

## トレードオフ

- apt は OS の初期パッケージも manual 指定に入り、自分で入れたものと区別できないので、数だけ出す。dnf・pacman の「自分で入れたもの」の一覧も、問い合わせが遅いので出さない(1つのコマンドの持ち主は出す)。
- 引数なしのときは、WSL が PATH の後ろに足す Windows 側(`/mnt/c` など)を見ない。9P 越しの確認はツールの数だけ遅くなるため。`pkgwhere <名前>` では見る。
- パスの形で判定するので、変わった置き方をしたものは「手で置いたもの」や「持ち主不明」になる。
