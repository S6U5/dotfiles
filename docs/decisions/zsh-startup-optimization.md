# zsh の起動高速化はキャッシュ + zcompile + zsh-defer で行う

対話 zsh の起動が遅い(特に低速マウント・低速ディスク環境で顕著)問題への対策として、
`home/.config/zsh/.zshrc` に以下の3点を実装した。

0. **Debian/Ubuntu のグローバル compinit の無効化**: `/etc/zsh/zshrc` は
   `skip_global_compinit` が未設定だと毎起動フルの compinit(compaudit + dump 検査)を
   実行する。補完初期化は .zshrc 側で自前管理(キャッシュ + 遅延実行)しているため
   完全に二重であり、`home/.zshenv` で `skip_global_compinit=1` を設定して無効化する
   (~/.zshenv はグローバル zshrc より先に読まれるためここに置く)。他の OS では未使用の
   変数になるだけで無害。**計測上はこれが最大の支配的要因だった**(下記)。
1. **init 出力のファイルキャッシュ**: `eval "$(starship init zsh)"` / `zoxide init zsh` /
   `fzf --zsh` は起動のたびにツールを起動して初期化スクリプトを生成していた。出力を
   `$XDG_CACHE_HOME/dotfiles/zsh/` にキャッシュし、ツールの実体が変わらない限り source
   するだけにする。Nix store のファイルは mtime が固定(1970年)で新旧比較が使えないため、
   キャッシュの鍵はシンボリックリンク解決後の実体パス(パッケージ更新で store パスごと
   変わる)にする。
2. **zcompile による事前バイトコンパイル**: `.zshrc`・共通シェル設定・`.zcompdump`・
   上記キャッシュを zcompile し、次回以降はワードコード(.zwc)を読ませる。
3. **zsh-defer による遅延実行**: プロンプト表示に不要な初期化(compinit、zoxide/fzf、
   autosuggestions、syntax-highlighting)を最初のプロンプト表示後に回す。starship だけは
   プロンプトそのものなので同期のまま。

## 計測(Ubuntu コンテナ、実ツール一式・プラグイン込み、hyperfine)

プロンプト表示までの時間。「低速FS」は LD_PRELOAD で open/stat 1回に 0.5ms・プロセス起動に
+5ms を注入した擬似低速マウント(WSL の 9p マウント風)。

| 構成 | 通常FS | 低速FS | ファイル系syscall数 |
|---|---|---|---|
| 最適化前 | 87ms | 1.38s | 2200回 |
| キャッシュ + zcompile + zsh-defer | 49ms | 1.03s | 1682回 |
| + skip_global_compinit | 29ms | **0.19s** | 298回 |
| (参考)設定ゼロの `zsh -f` | 2ms | ー | ー |

グローバル compinit だけで約1400回のファイル操作(fpath 配下全補完関数の compaudit)を
毎起動行っていた。総仕事量(遅延分も同期実行した場合)も 2200回 → 約1000回に半減。

## 検討した代替

- **何もしない(毎回 eval)**: 起動のたびに外部プロセスを数個起動する。低速環境で体感遅延の主因。
- **Turbo モード付きプラグインマネージャ(zinit / sheldon 等)の導入**: 遅延実行とキャッシュを
  マネージャに任せる案。プラグイン導入経路を Nix + home-manager に一本化している方針
  (`docs/decisions/package-management.md`、oh-my-zsh 廃止の経緯は
  `docs/decisions/zshrc-pollution.md`)と衝突し、管理レイヤーが1つ増えるため不採用。
- **遅延実行の自前実装(zle -F を直接使う)**: zsh-defer(約150行)の再実装になり、
  ワークキュー・エッジケース処理を自前で抱えるだけなので不採用。
- **zsh-defer のコード取り込み(vendoring)**: zsh-defer は GPL-3.0 のため、MIT の本リポジトリに
  コードをコミットするのはライセンス方針(「MIT と非互換のコードはコミットしない」)に反する。
  nixpkgs 経由の導入(呼び出すだけ)なら問題ない。
- **`setopt no_global_rcs`(グローバル rc を全部読まない)**: skip_global_compinit より
  さらに数 ms 速いが、macOS では `/etc/zprofile` の path_helper(`/etc/paths.d` の PATH 登録)まで
  無効になり環境を壊しうるため不採用。skip_global_compinit は compinit だけを狙い撃ちでき副作用が無い。
- **同期初期化の単一ブロブ化(共通シェル設定 + starship init を1個の zcompile 済みファイルに
  連結し、鮮度チェック自体もプロンプト表示後に回す)**: プロトタイプ計測では通常FS 29ms→12ms、
  低速FS 189ms→137ms とさらに速くなるが、(1) 「編集が次々回の起動まで反映されない」挙動になる、
  (2) git 管理外の local.sh の内容までキャッシュファイルに複製される、(3) 生成・再検証ロジックの
  複雑さが一段増える、に対して skip_global_compinit 適用後の残り改善幅が小さいため見送り。
  将来さらに詰めたくなったときの選択肢として記録しておく。

## 選んだ理由

- 3点ともプラグインマネージャ無しで実現でき、既存の方針(Nix 一本化・依存が無い環境でも
  壊れない)と両立する。zsh-defer が無い環境では同期実行にフォールバックする。
- zsh-defer は upstream(romkatv/zsh-defer)が非アーカイブ・意図的に小さく完成された
  ツール(最終コミット 2026-08 時点で 2024-02、実装は約150行)で、nixpkgs にパッケージが存在し
  `broken` フラグなし(2026-08 に package-researcher スキルで確認)。

## トレードオフ

- キャッシュ・.zwc という「生成物」が `$XDG_CACHE_HOME/dotfiles/zsh/` と設定ファイルの隣
  (`~/.config/zsh/`・`~/.config/shell/` の `.zwc`)に増える。挙動が怪しいときは
  `zsh-cache-reset --clean`(`home/.local/bin/`)で全て削除でき、次回起動時に再生成される。
- 補完・プラグインはプロンプト表示直後まで効かない(体感できない程度の一瞬)。
- `starship init zsh --print-full-init` の出力キャッシュはバイナリの絶対パスを含むため
  マシン間で共有できないが、キャッシュはマシンローカル(`$XDG_CACHE_HOME`)なので問題ない。

## 履歴

- (キャッシュキーに実行コマンドラインを追加): 当初の実装はバイナリ実体パスのみをキーに
  していたため、.zshrc 側で init の引数を変えてもキャッシュが再生成されない欠陥があった。
  キーに「実体パス + コマンドライン」を使う形に修正(キー形式が変わるため、旧形式の
  キャッシュは初回起動時に自動で再生成される)。
- (計測手法の補足): 上記の擬似低速FSは LD_PRELOAD による遅延注入で、シェル起動
  (libc の open 経由が主体)の計測には有効。一方 starship(gitoxide)は libc を介さない
  raw syscall でファイル走査するため LD_PRELOAD では捕捉できず、プロンプト側の git 走査の
  計測は遅延注入 FUSE マウントで別途行った。プロンプトの git 走査コストはリポジトリ規模に
  比例する別問題で、本 ADR の最適化の対象外(TODO.md「Windows native マウント上の
  リポジトリでの starship git_status 対策」参照)。
