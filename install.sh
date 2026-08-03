#!/usr/bin/env bash
#
# dotfiles installer
#
# home/ 以下のファイルを、同じディレクトリ構造で $HOME にシンボリックリンクする。
#
#   home/.tmux.conf         -> ~/.tmux.conf
#   home/.config/foo/bar    -> ~/.config/foo/bar
#
# zsh の .zshenv / .config/zsh/.zshrc は対象外(nix/home.nix の programs.zsh が生成。
# 判断根拠は docs/decisions/zshrc-pollution.md の履歴参照)。
#
# 例外: ~/.bashrc と ~/.bash_profile はシンボリックリンクにせず、実体を
# ~/.config/bash/bashrc から読み込むだけの薄いブートストラップの実ファイルとして生成する。
# nvm/pyenv/Homebrew 等のインストーラがここへ自動追記しても、dotfiles 管理下の
# ~/.config/bash/bashrc は汚れない(判断根拠は docs/decisions/zshrc-pollution.md 参照)。
#
# 方針:
#   - 既存ファイルは絶対に上書きしない。存在する場合はスキップして警告を出す。
#   - --force 指定時のみ、既存ファイルを *.bak.<timestamp> に退避してからリンクする。
#   - 何度実行しても安全(冪等)。リンク済みのものは何もしない。
#
# 使い方:
#   ./install.sh              # インストール(既存ファイルはスキップ)
#   ./install.sh --dry-run    # 何が行われるかの表示のみ
#   ./install.sh --force      # 既存ファイルを .bak に退避して上書き
#   ./install.sh --prune      # リンク後に、リポジトリ由来のリンク切れリンクを削除
#   ./install.sh --uninstall  # このリポジトリが作成したリンク・ブートストラップファイルを削除
set -euo pipefail

# pwd -P で物理パスに正規化する(シンボリックリンク経由で実行されても
# リンク済み判定(_dotfiles_realpath 参照)が安定するように)
DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
HOME_SRC="$DOTFILES_DIR/home"

FORCE=0
DRY_RUN=0
PRUNE=0
UNINSTALL=0

usage() {
  # 先頭のコメントブロック(シェバンの次の行から最初の非コメント行まで)を表示する
  awk 'NR > 1 && !/^#/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "${BASH_SOURCE[0]}"
}

log() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry-run] $*"
  else
    "$@"
  fi
}

# シングルクォートで定義し、$HOME はここでは展開せず出力ファイルに
# 文字列のまま残す(各シェル起動時にそのシェルの $HOME で評価させるため)。
# shellcheck disable=SC2016
BASH_BOOTSTRAP_CONTENT='# このファイルは dotfiles の管理外です(意図的にシンボリックリンクにしていません)。
# nvm/pyenv/Homebrew 等のインストーラがここへ自動追記しても、
# 実体の設定(~/.config/bash/bashrc、dotfiles 管理下)には影響しません。
# 判断根拠は docs/decisions/zshrc-pollution.md 参照。
[ -r "$HOME/.config/bash/bashrc" ] && . "$HOME/.config/bash/bashrc"
'

# リンク済み判定を「文字列が一致するか」ではなく「実体が同じファイルか」で行うための
# ヘルパー。同じリポジトリに別パス経由(シンボリックリンクを含む中間ディレクトリ等)で
# アクセスした場合の誤警告を防ぐ。readlink -f が使えない環境では、1段階だけ解決する
# 従来の readlink、それも無ければ引数をそのまま返す(= 旧来の文字列比較)にフォールバック
# する(GNU/BSD どちらの readlink でも -f はシンボリックリンクでない通常のパスにも使え、
# 中間ディレクトリのシンボリックリンクを解決してくれる)。
_dotfiles_realpath() {
  readlink -f "$1" 2>/dev/null || readlink "$1" 2>/dev/null || printf '%s\n' "$1"
}

detect_os() {
  case "$(uname -s)" in
    Darwin) echo macos ;;
    Linux)
      if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null; then
        echo wsl
      else
        echo linux
      fi
      ;;
    *) echo unknown ;;
  esac
}

link_file() {
  src=$1
  dest=$2

  # すでに正しいリンクなら何もしない
  if [ -L "$dest" ] && [ "$(_dotfiles_realpath "$dest")" = "$(_dotfiles_realpath "$src")" ]; then
    log "  ok:   $dest (リンク済み)"
    return 0
  fi

  # 既存ファイル・リンクがある場合
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    # 「dotfiles 構造(.../home/<相対パス>)を指すリンク切れ」だけは退避せず張り替える
    # (リポジトリを移動・改名した後でも --force なしで再インストールできるように)。
    # それ以外のリンク切れ(他ツール由来・未マウントの外部ボリューム等)には触れない。
    relink=0
    if [ -L "$dest" ] && [ ! -e "$dest" ]; then
      rel_dest=${dest#"$HOME"/}
      case "$(readlink "$dest")" in
        */home/"$rel_dest") relink=1 ;;
      esac
    fi
    if [ "$relink" -eq 1 ]; then
      run rm "$dest"
      log "  relink: $dest(旧リポジトリへのリンク切れを張り替え)"
    elif [ "$FORCE" -eq 1 ]; then
      backup="$dest.bak.$(date +%Y%m%d%H%M%S)"
      run mv "$dest" "$backup"
      log "  bak:  $dest -> $backup"
    else
      warn "スキップ: $dest は既に存在します(--force で .bak に退避して上書き)"
      return 0
    fi
  fi

  # 親パスの途中に通常ファイルがあると mkdir -p は失敗する。
  # set -e で全体が止まらないよう、方針どおり「スキップ+警告」にする
  if ! run mkdir -p "$(dirname "$dest")" 2>/dev/null; then
    warn "スキップ: $dest(親ディレクトリを作成できません。$(dirname "$dest") の途中に通常ファイルがある可能性)"
    return 0
  fi
  run ln -s "$src" "$dest"
  log "  link: $dest -> $src"
}

# ~/.bashrc / ~/.bash_profile を「dotfiles 管理外の実ファイル」として生成する
# (シンボリックリンクにしない理由は install.sh 冒頭コメント参照)。
#   dest:    生成先($HOME/.bashrc 等)
#   old_rel: 旧方式(home/ 直下へのシンボリックリンク)での相対パス。移行検出用
bootstrap_file() {
  dest=$1
  old_rel=$2

  # 既にブートストラップ済みなら何もしない(冪等。内容の細かい差分までは見ない)
  if [ -f "$dest" ] && [ ! -L "$dest" ] && grep -qF '.config/bash/bashrc' "$dest" 2>/dev/null; then
    log "  ok:   $dest (ブートストラップ済み)"
    return 0
  fi

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    # 旧方式(home/ 直下へのシンボリックリンク)のリンク切れだけはブートストラップに置き換える
    relink=0
    if [ -L "$dest" ] && [ ! -e "$dest" ]; then
      case "$(readlink "$dest")" in
        */home/"$old_rel") relink=1 ;;
      esac
    fi
    if [ "$relink" -eq 1 ]; then
      run rm "$dest"
      log "  relink: $dest(旧方式のシンボリックリンクをブートストラップに置き換え)"
    elif [ "$FORCE" -eq 1 ]; then
      backup="$dest.bak.$(date +%Y%m%d%H%M%S)"
      run mv "$dest" "$backup"
      log "  bak:  $dest -> $backup"
    else
      warn "スキップ: $dest は既に存在します(--force で .bak に退避して上書き)"
      return 0
    fi
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry-run] $dest にブートストラップ内容を書き込みます"
  else
    printf '%s' "$BASH_BOOTSTRAP_CONTENT" >"$dest"
  fi
  log "  create: $dest(ブートストラップ、dotfiles 管理外の実ファイル)"
}

# --uninstall: home/ が作成したシンボリックリンクと、~/.bashrc / ~/.bash_profile の
# ブートストラップファイルを削除する。install.sh とは逆方向の操作。
#   - シンボリックリンクは「リンク先がこのリポジトリの該当ファイルと完全一致するもの」
#     だけを対象にする(有効・リンク切れを問わず削除。他ツールのリンクには触れない)。
#   - ブートストラップファイルは、内容が生成時のものと完全一致する場合だけ削除する
#     (ユーザーが手を加えていたら、誤って消さないようスキップして警告する)。
#   - nix/home.nix が管理する zsh 設定(.zshenv 等)やパッケージ、このリポジトリ自身の
#     .githooks 設定はこのコマンドの対象外(install.sh が作ったものではないため)。
uninstall() {
  if [ ! -d "$HOME_SRC" ]; then
    warn "home/ ディレクトリがありません。削除対象なし。"
    return 0
  fi

  log "アンインストール: home/ が作成したリンクを削除します。"
  log ""
  removed=0
  while IFS= read -r -d '' src; do
    rel=${src#"$HOME_SRC"/}
    case "$rel" in
      .gitkeep | */.gitkeep) continue ;;
    esac
    dest="$HOME/$rel"
    if [ -L "$dest" ] && [ "$(_dotfiles_realpath "$dest")" = "$(_dotfiles_realpath "$src")" ]; then
      run rm "$dest"
      log "  del:  $dest -> $src"
      removed=$((removed + 1))
    fi
  done < <(find "$HOME_SRC" -type f -print0 | sort -z)

  log ""
  for dest in "$HOME/.bashrc" "$HOME/.bash_profile"; do
    if [ -f "$dest" ] && [ ! -L "$dest" ] &&
      [ "$(cat "$dest" 2>/dev/null)" = "$(printf '%s' "$BASH_BOOTSTRAP_CONTENT")" ]; then
      run rm "$dest"
      log "  del:  $dest(ブートストラップ内容のみだったため削除)"
      removed=$((removed + 1))
    elif [ -e "$dest" ]; then
      warn "スキップ: $dest はブートストラップ生成時の内容と異なるため削除しません(手動で確認してください)"
    fi
  done

  log ""
  if [ "$DRY_RUN" -eq 1 ]; then
    log "uninstall: [dry-run] ${removed} 件を削除します。"
  else
    log "uninstall: ${removed} 件を削除しました。"
  fi
  log ""
  log "注意: nix/home.nix が管理する zsh 設定・パッケージや、このリポジトリ自身の"
  log "      .githooks 設定(git config core.hooksPath)はこのコマンドの対象外です。"
}

main() {
  for arg in "$@"; do
    case "$arg" in
      --force) FORCE=1 ;;
      --dry-run) DRY_RUN=1 ;;
      --prune) PRUNE=1 ;;
      --uninstall) UNINSTALL=1 ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        warn "不明なオプション: $arg"
        usage
        exit 1
        ;;
    esac
  done

  log "dotfiles: $DOTFILES_DIR"
  log "OS:       $(detect_os)"
  log ""

  if [ "$UNINSTALL" -eq 1 ]; then
    uninstall
    exit 0
  fi

  if [ ! -d "$HOME_SRC" ]; then
    warn "home/ ディレクトリがありません。リンク対象なし。"
    exit 0
  fi

  count=0
  while IFS= read -r -d '' src; do
    rel=${src#"$HOME_SRC"/}
    case "$rel" in
      .gitkeep | */.gitkeep) continue ;;
    esac
    link_file "$src" "$HOME/$rel"
    count=$((count + 1))
  done < <(find "$HOME_SRC" -type f -print0 | sort -z)

  log ""
  bootstrap_file "$HOME/.bashrc" .bashrc
  bootstrap_file "$HOME/.bash_profile" .bash_profile

  log ""
  log "完了: ${count} ファイルを処理しました。"

  # --prune: home/ から削除されたファイルのリンク(このリポジトリを指すリンク切れ)を掃除する。
  # 対象は $HOME 直下と、このリポジトリがリンクを張る領域(~/.config, ~/.local)のみ。
  # 他ツールのリンクには触れない(リンク先が $HOME_SRC 配下のものだけ削除)。
  if [ "$PRUNE" -eq 1 ]; then
    log ""
    pruned=0
    while IFS= read -r -d '' link; do
      target=$(readlink "$link") || continue
      case "$target" in
        "$HOME_SRC"/*) ;;
        *) continue ;;
      esac
      if [ ! -e "$link" ]; then
        run rm "$link"
        log "  del:  $link -> $target(リンク切れ)"
        pruned=$((pruned + 1))
      fi
    done < <(
      find "$HOME" -maxdepth 1 -type l -print0 2>/dev/null
      find "$HOME/.config" "$HOME/.local" -type l -print0 2>/dev/null
    )
    if [ "$DRY_RUN" -eq 1 ]; then
      log "prune: [dry-run] リンク切れ ${pruned} 件を削除します。"
    else
      log "prune: リンク切れを ${pruned} 件削除しました。"
    fi
  fi

  # このリポジトリ自身の pre-commit フック(機密情報の事前ブロック)を有効化
  if command -v git >/dev/null 2>&1 && [ -d "$DOTFILES_DIR/.git" ] && [ -d "$DOTFILES_DIR/.githooks" ]; then
    run git -C "$DOTFILES_DIR" config core.hooksPath .githooks
    if [ "$DRY_RUN" -eq 1 ]; then
      log "githooks: [dry-run] core.hooksPath を .githooks に設定します。"
    else
      log "githooks: core.hooksPath を .githooks に設定しました。"
    fi
  fi
}

main "$@"
