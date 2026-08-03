-- LazyVim 公式 extras に存在しない言語の LSP サーバーを追加する。
-- (HTML/CSS/PowerShell には lazyvim.plugins.extras.lang.* が無いため手動設定)
return {
  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = {
      ---@type lspconfig.options
      servers = {
        html = {},
        cssls = {},
        powershell_es = {},
        -- ruff は mason 経由(pip/venv)だとこのMacのHomebrew Python由来の不具合で
        -- インストールに失敗するため、Nix(nix/home.nix)で導入済みのものを使わせる。
        ruff = { mason = false },
      },
    },
  },
}
