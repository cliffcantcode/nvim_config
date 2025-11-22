-- [[ Basic Autocommands ]]

-- Highlight when yanking (copying) text
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Show paired bracket line.
vim.api.nvim_create_autocmd("CursorHold", {
  desc = "Show what's on the line of the matching bracket.",
  group = vim.api.nvim_create_augroup("BracketEcho", { clear = true }),
  pattern = "*",
  callback = function()
    local orig_pos = vim.api.nvim_win_get_cursor(0)
    local row = orig_pos[1]
    local line = vim.api.nvim_get_current_line()

    local byte_idx = line:find("[%]%)%}]")
    if not byte_idx then
      vim.api.nvim_echo({}, false, {})
      return
    end
    -- Convert the byte index to a column index for the cursor.
    local col = vim.str_utfindex(line:sub(1, byte_idx)) - 1

    -- Save the cursor position and jump to the bracket.
    vim.api.nvim_win_set_cursor(0, { row, col })

    local ok = pcall(vim.cmd, "silent! normal! %")
    if not ok then
      vim.api.nvim_win_set_cursor(0, orig_pos)
      vim.api.nvim_echo({}, false, {})
      return
    end

    local match_row = vim.fn.line(".")
    if match_row == row then
      vim.api.nvim_win_set_cursor(0, orig_pos)
      vim.api.nvim_echo({}, false, {})
      return
    end

    local match_line = vim.fn.getline(match_row)
    local display = match_line:match("^%s*$") and "<blank line>" or match_line
    vim.api.nvim_echo({{string.format("# %d: %s", match_row, display), "Comment"}}, false, {})

    vim.api.nvim_win_set_cursor(0, orig_pos)
  end
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

vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("EnsureFinalNewline", { clear = true }),
  pattern = "*",
  callback = function()
    local bufnr = vim.api.nvim_get_current_buf()
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    local last_line = vim.api.nvim_buf_get_lines(bufnr, line_count - 1, line_count, false)[1]

    if last_line ~= "" then
      local view = vim.fn.winsaveview()
      vim.api.nvim_buf_set_lines(bufnr, line_count, line_count, false, { "" })
      vim.fn.winrestview(view)
    end
  end,
})

-- vim: ts=2 sts=2 sw=2 et

