-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- LazyVimはデフォルトで autowrite(特定操作時の自動保存)を有効にしているが、
-- 保存タイミングが分かりにくくなるため無効化し、保存は常に明示的な :w に統一する。
vim.opt.autowrite = false
