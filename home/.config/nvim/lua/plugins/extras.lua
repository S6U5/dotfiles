-- LazyVim 公式 extras(:LazyExtras でも有効化できるが、machine間の再現性のため
-- ここで明示的に import して git 管理下に置く)。
return {
  { import = "lazyvim.plugins.extras.lang.typescript" }, -- TypeScript / JavaScript
  { import = "lazyvim.plugins.extras.lang.python" }, -- Python(pyright + ruff。lint相当もruffのLSP診断でカバー)
  { import = "lazyvim.plugins.extras.formatting.prettier" }, -- 保存時フォーマット(CSS/HTML/JS/TS/JSON/Markdown/YAML等)
}
