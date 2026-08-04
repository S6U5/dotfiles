local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.font = wezterm.font 'JetBrainsMono Nerd Font'
config.font_size = 13.0

config.enable_tab_bar = true
config.window_close_confirmation = 'NeverPrompt'
config.scrollback_lines = 5000

-- 組み込みの自動更新チェック(デフォルト有効。24時間ごとにGitHubのリリースAPIへ通信する)は
-- 全環境で無効化する。「導入・反映は明示実行のみ」というこのdotfiles全体の方針(Nixの
-- home-manager switchも自動実行しない)に揃える。Windows側で更新したい場合は
-- `winget upgrade wez.wezterm` を手動で実行する。
config.check_for_updates = false

-- Windows ネイティブ側の WezTerm から、インストール済み WSL ディストリビューションを自動検出して
-- デフォルトドメインにする(WSL/macOS/Linux 統一の要。判断根拠は docs/decisions/terminal-emulator.md
-- 参照)。ディストリ名をハードコードせず動的に取得する(環境ごとに異なりうるため)。
if wezterm.target_triple:find 'windows' then
  local wsl_domains = wezterm.default_wsl_domains()
  if wsl_domains and #wsl_domains > 0 then
    config.default_domain = wsl_domains[1].name
  end
end

-- 壁紙はデフォルト OFF。画像パスはマシン固有・プライベートになりうるためコミットしない
-- (CLAUDE.md の「機密になりうる値は環境変数や *.local ファイルから読む」方針)。有効にするには
-- ~/.config/wezterm/wallpaper.local.lua(*.local は .gitignore 対象)を作成し、画像への絶対パスを
-- 1行で return する(例: return '/path/to/wallpaper.png')。
-- Cover で画面いっぱいに拡大表示。画像自体の hsb だけで暗くすると、画像内の明るい部分が
-- 局所的に残って文字が読みにくくなることがあるため、上に半透明の黒レイヤーを重ねて均一に暗くする
-- (background のレイヤーは配列の後ろのものほど上に重なる。公式ドキュメント記載の手法)。
local wallpaper_ok, wallpaper_path = pcall(dofile, wezterm.config_dir .. '/wallpaper.local.lua')
if wallpaper_ok and type(wallpaper_path) == 'string' and wallpaper_path ~= '' then
  config.background = {
    {
      source = { File = wallpaper_path },
      width = 'Cover',
      height = 'Cover',
      hsb = { brightness = 0.3, hue = 1.0, saturation = 1.0 },
    },
    {
      source = { Color = '#000000' },
      width = '100%',
      height = '100%',
      opacity = 0.78,
    },
  }
end

return config
