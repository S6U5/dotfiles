local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

config.font = wezterm.font 'JetBrainsMono Nerd Font'
config.font_size = 13.0

config.enable_tab_bar = true
config.window_close_confirmation = 'NeverPrompt'
config.scrollback_lines = 5000

-- アクティブタブに色をつけて現在のタブを判別しやすくする。fancy tab bar(デフォルト)でも
-- colors.tab_bar.active_tab の bg_color / fg_color は有効(タブバー全体の背景色は
-- window_frame 側の管轄で別物)。
config.colors = {
  tab_bar = {
    active_tab = {
      bg_color = '#2b6cb0',
      fg_color = '#ffffff',
    },
  },
}

-- 組み込みの自動更新チェック(デフォルト有効。24時間ごとにGitHubのリリースAPIへ通信する)は
-- 全環境で無効化する。「導入・反映は明示実行のみ」というこのdotfiles全体の方針(Nixの
-- home-manager switchも自動実行しない)に揃える。Windows側で更新したい場合は
-- `winget upgrade wez.wezterm` を手動で実行する。
config.check_for_updates = false

-- クリップボードからの貼り付け。コピー(選択→自動コピーや OSC 52 経由)はデフォルトのままで
-- Windows クリップボードに届くが、貼り付けは Windows Terminal で身についた操作(Ctrl+V・
-- 右クリック・Shift+Insert)がどれもデフォルトではクリップボード貼り付けに割り当たっておらず、
-- 「コピーはできるのに貼り付けだけできない」ように見えるため明示的に設定する。
-- - Ctrl+Shift+V: デフォルトの割り当て(PasteFrom 'Clipboard')だが、自己文書化のため明示する
-- - Shift+Insert: デフォルトは PasteFrom 'PrimarySelection'。プライマリセレクションが実在する
--   のは X11/Wayland だけで、Windows/macOS では WezTerm 内部の選択バッファ(OS クリップボード
--   とは別物)を指すため、他アプリでコピーした内容は何も貼り付けられない。クリップボード
--   貼り付けに統一する(トレードオフ: X11 でのプライマリセレクション貼り付けは中クリックに残る)
-- - Ctrl+V はあえて割り当てない(nvim の矩形選択など、ペイン内アプリに届くべきキーを潰すため。
--   貼り付けは Ctrl+Shift+V か右クリックを使う)
config.keys = {
  { key = 'V', mods = 'CTRL|SHIFT', action = act.PasteFrom 'Clipboard' },
  { key = 'Insert', mods = 'SHIFT', action = act.PasteFrom 'Clipboard' },
}

-- 右クリック: 選択中ならコピーして選択解除、選択なしならクリップボードから貼り付け
-- (Windows Terminal と同じ操作感。公式 Discussion #3541 で案内されている手法)
config.mouse_bindings = {
  {
    event = { Down = { streak = 1, button = 'Right' } },
    mods = 'NONE',
    action = wezterm.action_callback(function(window, pane)
      if window:get_selection_text_for_pane(pane) ~= '' then
        window:perform_action(act.CopyTo 'ClipboardAndPrimarySelection', pane)
        window:perform_action(act.ClearSelection, pane)
      else
        window:perform_action(act.PasteFrom 'Clipboard', pane)
      end
    end),
  },
}

-- Windows ネイティブ側の WezTerm から、インストール済み WSL ディストリビューションを自動検出して
-- デフォルトドメインにする(WSL/macOS/Linux 統一の要。判断根拠は docs/decisions/terminal-emulator.md
-- 参照)。ディストリ名をハードコードせず動的に取得する(環境ごとに異なりうるため)。
-- default_prog を明示的に zsh にする(WSL ディストリ側のログインシェル設定(chsh)に依存させない。
-- 未指定のままだと WSL ディストリのデフォルトシェル(多くの場合 bash)が起動してしまう)。
-- 採用したドメイン名は下の gui-startup でも参照するため local に控える。
local wsl_default_domain
if wezterm.target_triple:find 'windows' then
  local wsl_domains = wezterm.default_wsl_domains()
  if wsl_domains and #wsl_domains > 0 then
    wsl_domains[1].default_prog = { 'zsh' }
    config.wsl_domains = wsl_domains
    config.default_domain = wsl_domains[1].name
    wsl_default_domain = wsl_domains[1].name
  end
end

-- 初期ウィンドウサイズをディスプレイの実サイズから比率で決める(FHD と 4K/ウルトラワイドで
-- 見た目の大きさを揃えるため。initial_cols / initial_rows はセル数指定なのでディスプレイに
-- よって占有率が変わりすぎる)。gui-startup は起動時の最初のウィンドウにだけ発火する。
-- set_inner_size は装飾(タイトルバー等)を除いた内側のサイズ指定なので、中央配置は厳密ではなく
-- 数十px ずれうるが実用上問題ない。
local screen_ratio = 0.5
wezterm.on('gui-startup', function(cmd)
  local screen = wezterm.gui.screens().active
  local width = math.floor(screen.width * screen_ratio)
  local height = math.floor(screen.height * screen_ratio)
  local spawn = cmd or {}
  -- gui-startup で mux.spawn_window を使うと config.default_domain が確実には反映されず、
  -- Windows でローカルドメイン(PowerShell 等)が開いて WSL の zsh 明示起動が効かないことが
  -- あるため、WSL ドメインを明示指定する(CLI 引数などで既にドメイン指定がある場合は触らない)
  if wsl_default_domain and not spawn.domain then
    spawn.domain = { DomainName = wsl_default_domain }
  end
  local _tab, _pane, window = wezterm.mux.spawn_window(spawn)
  local gui_window = window:gui_window()
  gui_window:set_inner_size(width, height)
  gui_window:set_position(
    screen.x + math.floor((screen.width - width) / 2),
    screen.y + math.floor((screen.height - height) / 2)
  )
end)

-- 壁紙はデフォルトでコミット済みの wallpaper.png を使う(プロンプトのパステル配色に合わせた
-- AI 生成のテンプレート壁紙。生成メタデータは除去済み。個人の写真等マシン固有・プライベートに
-- なりうる画像はコミットせず local 側で差し替える方針は従来どおり)。
-- 差し替え・無効化は ~/.config/wezterm/wallpaper.local.lua(*.local は .gitignore 対象)で行う:
--   差し替え: 画像への絶対パスを1行で return する(例: return '/path/to/wallpaper.png')
--   無効化:   return false
-- デフォルト壁紙は設定ディレクトリ相対で解決するため、WSL(Windows 側の WezTerm が UNC パス
-- 経由で設定を読む構成)でもパス変換なしでそのまま表示できる。
-- Cover で画面いっぱいに拡大表示。画像自体の hsb だけで暗くすると、画像内の明るい部分が
-- 局所的に残って文字が読みにくくなることがあるため、上に半透明の黒レイヤーを重ねて均一に暗くする
-- (background のレイヤーは配列の後ろのものほど上に重なる。公式ドキュメント記載の手法)。
local wallpaper_path
local wallpaper_local_ok, wallpaper_local = pcall(dofile, wezterm.config_dir .. '/wallpaper.local.lua')
if wallpaper_local_ok then
  -- local ファイルがある場合はその指定を最優先(文字列なら差し替え、false 等なら壁紙なし)
  if type(wallpaper_local) == 'string' and wallpaper_local ~= '' then
    wallpaper_path = wallpaper_local
  end
else
  local default_wallpaper = wezterm.config_dir .. '/wallpaper.png'
  local f = io.open(default_wallpaper, 'rb')
  if f then
    f:close()
    wallpaper_path = default_wallpaper
  end
end
local wallpaper_enabled = wallpaper_path ~= nil

-- image_opacity を引数にするのは、Ctrl+Shift+O でのウィンドウ透過切り替え(下記)のときに
-- レイヤーごと作り直す必要があるため。config.background のレイヤーが完全に不透明(alpha=1)だと
-- window_background_opacity を下げてもデスクトップへの透過が効かないため、一番下の画像レイヤー
-- 自体の opacity を下げることで透過を実現する。
local function wallpaper_background(image_opacity)
  return {
    {
      source = { File = wallpaper_path },
      width = 'Cover',
      height = 'Cover',
      opacity = image_opacity,
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

-- デフォルトは不透明(壁紙レイヤー・ウィンドウとも opacity 1.0)。Ctrl+Shift+O でデスクトップへの
-- 透過ありの状態にトグルできる。
if wallpaper_enabled then
  config.window_background_opacity = 1.0
  config.background = wallpaper_background(1.0)

  config.keys = config.keys or {}
  table.insert(config.keys, {
    key = 'O',
    mods = 'CTRL|SHIFT',
    action = wezterm.action_callback(function(window, _pane)
      local overrides = window:get_config_overrides() or {}
      if overrides.window_background_opacity == 0.4 then
        overrides.window_background_opacity = 1.0
        overrides.background = wallpaper_background(1.0)
      else
        overrides.window_background_opacity = 0.4
        overrides.background = wallpaper_background(0.45)
      end
      window:set_config_overrides(overrides)
    end),
  })
end

return config
