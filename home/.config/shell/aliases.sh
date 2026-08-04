# shellcheck shell=sh
# エイリアス。sh 互換で書くこと。
# 新しい名前を付ける前に、既存コマンドとの衝突を確認する(CLAUDE.md「命名規則」参照)。

# ls 系は eza(アイコン・色付きの ls 代替。nix/home.nix で導入)があればそちらを使う。
# 無い環境では色付き ls にフォールバック(GNU ls は --color=auto、BSD/macOS ls は -G)。
if command -v eza >/dev/null 2>&1; then
  # --icons=auto / --classify=auto は出力先が端末のときだけ装飾する(パイプ先には素の名前を
  # 渡せるので、出力を加工するコマンドと組み合わせても安全)。--classify はディレクトリ末尾に
  # / を付ける ls -F 相当。--group-directories-first でディレクトリを先頭にまとめる。
  alias ls='eza --icons=auto --classify=auto --group-directories-first'
  alias ll='eza -l --icons=auto --git --group-directories-first'
  alias la='eza -la --icons=auto --git --group-directories-first'
  alias lt='eza --tree --icons=auto' # ツリー表示(eza があるときだけ定義)
elif command ls --color=auto -d . >/dev/null 2>&1; then
  alias ls='ls --color=auto'
  alias ll='ls --color=auto -l'
  alias la='ls --color=auto -la'
else
  alias ls='ls -G'
  alias ll='ls -G -l'
  alias la='ls -G -la'
fi

# vi / vim / view は Neovim で置換する(nvim が入っている環境のみ。無い環境では通常の vi / vim / view のまま)
if command -v nvim >/dev/null 2>&1; then
  alias vi='nvim'
  alias vim='nvim'
  alias view='nvim -R' # view は読み取り専用モード(vi -R 相当)
fi
