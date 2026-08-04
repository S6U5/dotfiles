# パッケージ・dotfiles 管理は Nix + home-manager に一元化する方針

**方針は決定、Nix + home-manager に一本化済み**(実機での動作確認は 2026-07-31 に完了。当初は軽量な代替として `packages/`(Brewfile / apt.txt)を併存させていたが、2026-08-01 に廃止して完全に一本化した。TODO.md「install.sh / 運用」参照)。

## 検討した代替

| 観点 | mise/asdf | chezmoi | Nix + home-manager(採用) |
|---|---|---|---|
| OS非依存マニフェスト | ○ | △(dotfiles配置が主目的) | ○ |
| 実行忘れ対策(自動トリガー) | ×(`mise install` を自分で叩く必要あり) | ○(`run_onchange_` で自動導入) | ○(`home-manager switch` 前提だが構成自体が宣言的) |
| 拡張性の天井 | △(devtoolsの範囲に限定) | △(dotfiles配布の範囲に限定) | ○(パッケージからdotfiles配布まで一元管理できる) |
| 学習コスト | ○ | △ | ×(単体では高いが、下記の理由により不採用の決め手にはしない) |
| 現時点の判断 | 不採用(Nixの範囲に包含される) | 不採用(Nixの範囲に包含される) | 採用(home-manager の範囲まで。nix-darwin は対象外、下記参照) |

## 選んだ理由

- Nix は宣言的な再現性という点で拡張性の天井が最も高く、mise(devtool限定)・chezmoi(dotfiles配布限定)がそれぞれ個別に解決していた課題を一元的に解決できる。
- 従来「学習コストが高い」「エラーメッセージが分かりにくい」という理由でNixを保留していたが、Claude Code 等のAIアシスタントの支援を前提にすれば、この種の摩擦(構文の学習、エラー原因の特定)は大きく軽減されるため、単独では不採用の理由にしない。
- macOS での Nix 導入に伴う専用 APFS ボリューム作成・`fstab` 書き換えは、Nix を使う以上避けられない一回限りのセットアップとして許容する。
- **nix-darwin(OS全体をNixで宣言的管理する層)はスコープが大きすぎるため対象外**とし、home-manager の範囲(ユーザー環境・パッケージ・dotfiles配布)に留める。
- 既存の `install.sh` / `packages/` 構成からの移行コストは判断材料に含めない(移行そのものを厭わない方針)。
- 宣言的に管理しているということは、現在の状態がすべて明文化されているということでもあり、将来 Nix 以外へ乗り換える場合の移行もしやすい(何が入っているかを推測する必要がない)。一方通行の選択ではない。

## トレードオフ

- macOS は専用 APFS ボリューム作成などシステムレベルの初期セットアップが必要(nix-darwin を使わなくても回避不可)。これは macOS 固有の事情(読み取り専用のシステムボリューム)によるもので、WSL/Linux 側には無い。
- WSL/Linux は通常の書き込み可能なファイルシステムなので、`/nix` を普通のディレクトリとして作るだけで済み、macOS より単純(ボリューム作成・`fstab` 書き換えは不要)。
- Windows ネイティブは非対応で、WSL 経由が前提(このリポジトリの既存方針と一致するため実害は小さい)。
- git のように厳密に固定したくないツールは、あえて Nix の管理下に置かず素通しにしてよい(全部を管理対象にする必要はない)。

## Nix本体のインストーラの選定

- **検討した代替**: NixOS公式のクラシックインストーラ(`nixos.org/nix/install`)、Determinate Systems製インストーラ(`install.determinate.systems/nix`)
- **選んだ理由**: [NixOS/nix-installer](https://github.com/NixOS/nix-installer)(`artifacts.nixos.org/nix-installer`)を使う。これは NixOS Foundation の「Nix Installer Working Group」が管理する、Determinate Nix Installer からのフォーク。**Determinate Systems 製インストーラは2026年1月1日以降、upstream(無償・本家)のNixではなく自社の商用製品「Determinate Nix」だけをインストールする方針に転換している**(下記ソース参照)ため、Determinate版をそのまま使うと「`packages/`で導入するツールは無償・OSSライセンスのものに限る」という本リポジトリの方針に抵触しうる。`NixOS/nix-installer` はこの転換前の状態からコミュニティがフォークして作った、upstream Nixだけをインストールし続けるための代替であり、この事情から選んだ。flakesを扱える(`--enable-flakes` を明示)、アンインストールが `nix-installer uninstall` で綺麗に戻せる、という実利面もクラシックインストーラより優れる。
  - ソース: [NixOS/nix-installer](https://github.com/NixOS/nix-installer)、[Dropping upstream Nix from Determinate Nix Installer](https://determinate.systems/blog/installer-dropping-upstream/)
- **トレードオフ**: クラシックインストーラより新しく、実績(導入数)ではDeterminate版に及ばない可能性がある。

## 履歴

- (mise/chezmoi の個別導入を検討 → Nix + home-manager へ一元化、本ADR): 上記の理由により決定
- (2026-07-31: 実機で `nix flake check` / `home-manager switch` の動作確認が完了したため、「任意の選択肢」から「基本(推奨)の導入経路」に格上げ。`packages/` は軽量な代替として併存)
- (2026-08-01: `packages/`(Brewfile / apt.txt / neovim-install.sh / zoxide-install.sh / fd-install.sh)を完全廃止し、Nix + home-manager に一本化。二経路併存は「どちらの経路を選んだかでツールの有無が変わる」「新しいツールを追加するたびに両方へ反映する手間と反映漏れのリスクがある」という運用コストがあり、実行系コード(install.sh / update.sh / CI)はどこも `packages/` に依存していなかった(ドキュメントと `package-researcher` スキルからの参照のみ)ため、一本化しても実害が無いと判断した。`package-researcher` スキルは「brew/aptどちらが推奨か」の比較ではなく「nixpkgsのパッケージが健全か(archived/brokenでないか)」の確認に主旨を変更)
- (zsh の設定配布を home-manager の `programs.zsh` に統合): oh-my-zsh 等のフレームワークが `.zshenv` に `home.file` で書き込む設計のため、`home/` の手動シンボリックリンクと構造的に衝突することが判明した(判断の詳細は `docs/decisions/zshrc-pollution.md` の履歴参照)。対策として zsh の `.zshrc`/`.zshenv` の生成だけを `nix/home.nix` の `programs.zsh` に委ねることにした。これは「dotfiles 配布は `home/` に任せ、Nix はパッケージのみ」という本 ADR の原則の**例外**だが、nix-darwin 対象外・home-manager 単体構成という方針自体、およびログインシェル本体(zshバイナリ)を Nix 管理しないという方針(`docs/decisions/login-shell.md`)は変更していない。
- (oh-my-zsh 廃止に伴い、zsh の設定配布を `home/` の手動シンボリックリンクに戻した): oh-my-zsh のプラグイン読み込みが低速マウント上で起動遅延を起こす問題があり、oh-my-zsh を廃止して Starship に置き換えた。これにより上記エントリの例外理由(oh-my-zsh の `home.file` 書き込みとの衝突)が無くなったため、`nix/home.nix` の `programs.zsh` を削除し、zsh の `.zshrc`/`.zshenv` も他の dotfiles と同じく `home/` からのシンボリックリンクに統一した(「dotfiles 配布は `home/` に任せ、Nix はパッケージのみ」という本 ADR の原則の例外が解消され、原則どおりに戻った)。starship / zsh-autosuggestions / zsh-syntax-highlighting は引き続き `home.packages` で導入する。詳細は `docs/decisions/zshrc-pollution.md` の履歴参照。
- (今後この決定が覆ったら、ここに追記していく。全面書き換えはしない)
