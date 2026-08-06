# zsh の起動高速化はキャッシュ + zcompile + zsh-defer で行う

対話 zsh の起動が遅い(特に低速マウント・低速ディスク環境で顕著)問題への対策として、
`home/.config/zsh/.zshrc` に以下の3点を実装した。

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

## 選んだ理由

- 3点ともプラグインマネージャ無しで実現でき、既存の方針(Nix 一本化・依存が無い環境でも
  壊れない)と両立する。zsh-defer が無い環境では同期実行にフォールバックする。
- zsh-defer は upstream(romkatv/zsh-defer)が非アーカイブ・意図的に小さく完成された
  ツール(最終コミット 2026-08 時点で 2024-02、実装は約150行)で、nixpkgs にパッケージが存在し
  `broken` フラグなし(2026-08 に package-researcher スキルで確認)。

## トレードオフ

- キャッシュ・.zwc という「生成物」が `$XDG_CACHE_HOME/dotfiles/zsh/` と設定ファイルの隣
  (`~/.config/zsh/`・`~/.config/shell/` の `.zwc`)に増える。壊れた場合はキャッシュディレクトリと
  `.zwc` を消せば次回起動時に再生成される。
- 補完・プラグインはプロンプト表示直後まで効かない(体感できない程度の一瞬)。
- `starship init zsh --print-full-init` の出力キャッシュはバイナリの絶対パスを含むため
  マシン間で共有できないが、キャッシュはマシンローカル(`$XDG_CACHE_HOME`)なので問題ない。
