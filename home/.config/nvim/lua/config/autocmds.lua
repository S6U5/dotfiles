-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- ファイルが外部(Claude Code等)で書き換えられたとき自動で読み込み直す。
-- LazyVim標準は FocusGained 等でのみ checktime するが、tmux/herdr越しだとフォーカス
-- イベントが届かないことがあるため、無操作時(CursorHold)にも追加でチェックする。
vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
  command = "checktime",
})
