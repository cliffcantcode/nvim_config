-- [[ Basic Autocommands ]]

-- Highlight when yanking (copying) text
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Avoid chasing down unsaved files.
vim.api.nvim_create_autocmd("BufLeave", {
  desc = "Auto-save when leaving buffer",
  group = vim.api.nvim_create_augroup("SaveOnExit", { clear = true }),
  pattern = "*",
  callback = function()
    if vim.bo.modified and vim.bo.buftype == "" then
      vim.cmd("silent write")
    end
  end,
})

-- I usually don't want the line after a comment to also be a comment.
vim.api.nvim_create_autocmd("FileType", {
  desc = "Disable auto-commenting on newlines",
  group = vim.api.nvim_create_augroup("AutoCommentOff", { clear = true }),
  pattern = "*",
  callback = function()
    vim.opt_local.formatoptions:remove({ "c", "r", "o" })
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  desc = "Open help in vertical split",
  group = vim.api.nvim_create_augroup("HelpSplitsVertical", { clear = true }),
  pattern = { "help", "man" },
  callback = function()
    vim.cmd("wincmd L")
    vim.cmd("setlocal winwidth=80")
  end,
})

-- Two commands that pair to reopen files where I left off.
vim.api.nvim_create_autocmd("BufLeave", {
  desc = "Remember cursor position when leaving a buffer",
  group = vim.api.nvim_create_augroup("RememberCursorOnLeave", { clear = true }),
  pattern = "*",
  callback = function()
    if
      vim.bo.buftype == ""
      and vim.bo.filetype ~= "help"
      and vim.bo.modifiable
    then
      vim.cmd("normal! m\"") -- Set the '"' mark (used for last cursor position)
    end
  end,
})
vim.api.nvim_create_autocmd("BufWinEnter", {
  desc = "Restore cursor position only if safe",
  group = vim.api.nvim_create_augroup("RestoreCursorOnEnter", { clear = true }),
  pattern = "*",
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Multiple file cleaning steps done in a single save pass.
vim.api.nvim_create_autocmd("BufWritePre", {
  desc = "Clean on save: - Ensure newline at end of file. - Remove white space from end of lines.",
  group = vim.api.nvim_create_augroup("CleanOnSave", { clear = true }),
  pattern = "*",
  callback = function(args)
    local bufnr = args.buf

    if vim.bo[bufnr].buftype ~= "" then return end
    if not vim.bo[bufnr].modifiable then return end
    if vim.bo[bufnr].readonly then return end

    local view = vim.fn.winsaveview()

    -- Try to join with previous undo block (ok if it fails)
    pcall(vim.cmd, "silent undojoin")

    -- 1) Trim trailing whitespace.
    What is the e doing here?
    vim.cmd([[silent keepjumps keeppatterns %s/\s\+$//e]])

    -- 2) Put a newline at the end of the file.
    local name = vim.api.nvim_buf_get_name(bufnr)
    local ext = vim.fn.fnamemodify(name, ":e")
    local files_that_want_newline = {zig = true, c = true, cpp = true, lua = true, md = true, txt = true, json = true, toml = true, vim = true, py = true}

    if files_that_want_newline[ext] then
      local line_count = vim.api.nvim_buf_line_count(bufnr)
      if line_count > 0 then
        local last_line = vim.api.nvim_buf_get_lines(bufnr, line_count - 1, line_count, false)[1]
        if last_line ~= "" then
          vim.api.nvim_buf_set_lines(bufnr, line_count, line_count, false, { "" })
        end
      end
    end

    vim.fn.winrestview(view)
  end,
})

