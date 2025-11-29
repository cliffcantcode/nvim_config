-- [[ Basic Autocommands ]]

-- Highlight when yanking (copying) text
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- TODO: Make this not trigger if it's pairing with the top of the file.
-- Show paired bracket line.
local ns = vim.api.nvim_create_namespace("BracketEcho")
vim.api.nvim_create_autocmd("CursorHold", {
  desc = "Show matching line using Treesitter (non-blocking)",
  group = vim.api.nvim_create_augroup("BracketEcho", { clear = true }),
  callback = function()
    vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)

    -- 0. Ensure Treesitter is available + buffer has a parser
    local has_ts, ts = pcall(require, "vim.treesitter")
    if not has_ts then
      return -- TS not installed
    end

    local ok_parser, parser = pcall(ts.get_parser, 0)
    if not ok_parser or not parser then
      return -- no parser for this buffer/filetype
    end

    -- 1. Get current state
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1
    local line_text = vim.api.nvim_get_current_line()

    -- 2. Find bracket or 'end'
    local start_idx = line_text:find("[%]%)%}]")
    if not start_idx then
      start_idx = line_text:find("%f[%w]end%f[%W]")
    end
    if not start_idx then return end

    local col = start_idx - 1

    -- 3. Treesitter node
    local ok, node = pcall(vim.treesitter.get_node, { pos = { row, col } })
    if not ok or not node then return end

    -- 4. Walk up
    local target = node
    local start_row = target:range()
    while target and start_row == row do
      target = target:parent()
      if target then start_row = target:range() end
    end

    if not target or start_row == row then return end

    if (math.abs(start_row - row) <= 15) or (start_row == 0) then return end

    -- 5. Get line
    local match_line = vim.api.nvim_buf_get_lines(0, start_row, start_row + 1, false)[1]
    if not match_line then return end

    local display = match_line:match("^%s*$") and "<blank line>" or match_line
    display = display:gsub("^%s+", "")
    if #display > 160 then display = display:sub(1, 160) .. "..." end

    -- 6. Virtual text under the cursor line (NO hit-enter prompt possible)
    vim.api.nvim_buf_set_extmark(0, ns, row, 0, {
      virt_text = { { string.format("#%d: %s", start_row + 1, display), "Comment" } },
      virt_text_pos = "eol",
      hl_mode = "combine",
    })
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
    
    if line_count == 0 then return end

    local last_line = vim.api.nvim_buf_get_lines(bufnr, line_count - 1, line_count, false)[1]

    if last_line ~= "" then
      local view = vim.fn.winsaveview()
      vim.api.nvim_buf_set_lines(bufnr, line_count, line_count, false, { "" })
      vim.fn.winrestview(view)
    end
  end,
})

-- vim: ts=2 sts=2 sw=2 et

