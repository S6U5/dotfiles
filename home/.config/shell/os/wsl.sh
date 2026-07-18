# shellcheck shell=sh
# WSL 固有の「起動時設定」(環境変数・エイリアス・PATH 調整など)。WSL 以外では読み込まれない。
# 注意: コマンド・関数はここではなく共通層に置く(常に定義+実行時チェック方式。CLAUDE.md 参照)。
#       Windows 連携コマンドの実体は windows.sh / home/.local/bin/ にある。
