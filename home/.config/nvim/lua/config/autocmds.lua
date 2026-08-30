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

-- 外部編集(Claude Code / Codex 等)と手元の未保存変更を3-wayマージして取り込む。
-- 標準のW12警告は「リロード(手元の編集が消える)か維持(外部の編集を無視)」の
-- 二択しかないため、BufReadPost/BufWritePost 時点の内容を base として控えておき、
-- 外部変更検知時に base / バッファ / ディスクを git merge-file でマージする。
-- 衝突箇所は conflict マーカー(<<<<<<<)で残るので手で解消し、:w で確定する。
local merge_group = vim.api.nvim_create_augroup("external_edit_merge", { clear = true })
local base_lines = {} -- bufnr -> 最後にディスクと同期した時点の行

vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
  group = merge_group,
  callback = function(ev)
    base_lines[ev.buf] = vim.api.nvim_buf_get_lines(ev.buf, 0, -1, false)
  end,
})

vim.api.nvim_create_autocmd("BufDelete", {
  group = merge_group,
  callback = function(ev)
    base_lines[ev.buf] = nil
  end,
})

vim.api.nvim_create_autocmd("FileChangedShell", {
  group = merge_group,
  callback = function(ev)
    local buf = ev.buf
    -- 未保存変更が無い・ファイル削除・baseが無い場合は従来動作に任せる
    if not vim.bo[buf].modified or vim.v.fcs_reason == "deleted" then
      vim.v.fcs_choice = "reload"
      return
    end
    if not base_lines[buf] or vim.fn.executable("git") == 0 then
      vim.v.fcs_choice = "ask"
      return
    end
    vim.v.fcs_choice = "" -- バッファは維持し、この後自前でマージする
    local fname = vim.api.nvim_buf_get_name(buf)
    -- FileChangedShell ハンドラ内ではバッファ変更が制限されるため schedule で逃す
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end
      local tmp_ours = vim.fn.tempname()
      local tmp_base = vim.fn.tempname()
      vim.fn.writefile(vim.api.nvim_buf_get_lines(buf, 0, -1, false), tmp_ours)
      vim.fn.writefile(base_lines[buf], tmp_base)
      -- git merge-file はリポジトリ外のファイルでも使える純粋な3-wayマージ。
      -- exit code は衝突数(負値はエラー)。
      local merged = vim.fn.systemlist({
        "git",
        "merge-file",
        "-p",
        "-L",
        "ours (buffer)",
        "-L",
        "base",
        "-L",
        "theirs (disk)",
        tmp_ours,
        tmp_base,
        fname,
      })
      local nconflicts = vim.v.shell_error
      vim.fn.delete(tmp_ours)
      vim.fn.delete(tmp_base)
      if nconflicts < 0 then
        vim.notify("外部編集とのマージに失敗しました: " .. fname, vim.log.levels.ERROR)
        return
      end
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, merged)
      base_lines[buf] = vim.fn.readfile(fname) -- 新しいbaseはディスク側の内容
      if nconflicts > 0 then
        vim.notify(
          ("外部編集と衝突 %d 箇所(<<<<<<< マーカーを解消してください)"):format(nconflicts),
          vim.log.levels.WARN
        )
      else
        vim.notify("外部編集を手元の変更とマージしました: " .. vim.fn.fnamemodify(fname, ":t"))
      end
    end)
  end,
})
