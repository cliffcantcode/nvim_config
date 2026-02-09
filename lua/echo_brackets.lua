local ns = vim.api.nvim_create_namespace("BracketEcho")
local aug = vim.api.nvim_create_augroup("BracketEcho", { clear = true })

local last = {
  bufnr = -1,
  row = -1,
  col = -1,
  tick = -1,
}

local function clear(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

-- Clear stale text quickly when you move (so it never “lags behind”)
vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "InsertEnter", "BufLeave" }, {
  group = aug,
  callback = function(args)
    clear(args.buf)
  end,
})

vim.api.nvim_create_autocmd("CursorHold", {
  desc = "Show matching line using Treesitter (cached)",
  group = aug,
  callback = function(args)
    local bufnr = args.buf

    -- Hard skips for huge buffers (prevents TS parse spikes)
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    if line_count > 5000 then return end
    if vim.b[bufnr].ts_disable then return end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1
    local col = cursor[2]
    local tick = vim.b[bufnr].changedtick

    -- Cache: don’t redo work if nothing changed
    if last.bufnr == bufnr and last.row == row and last.col == col and last.tick == tick then
      return
    end
    last = { bufnr = bufnr, row = row, col = col, tick = tick }

    clear(bufnr)

    local has_ts, ts = pcall(require, "vim.treesitter")
    if not has_ts then return end

    local ok_parser, parser = pcall(ts.get_parser, bufnr)
    if not ok_parser or not parser then return end

    local line_text = vim.api.nvim_get_current_line()
    if line_text == "" then return end

    -- Find last closing bracket on the line (your existing heuristic)
    local start_idx
    do
      local i = 1
      while true do
        local s = line_text:find("[%]%)%}]", i)
        if not s then break end
        start_idx = s
        i = s + 1
      end
    end

    if not start_idx then
      local i = 1
      while true do
        local s = line_text:find("%f[%w]end%f[%W]", i)
        if not s then break end
        start_idx = s
        i = s + 1
      end
    end

    if not start_idx then return end

    local node_ok, node = pcall(vim.treesitter.get_node, { bufnr = bufnr, pos = { row, start_idx - 1 } })
    if not node_ok or not node then return end

    local target = node
    local start_row = target:range()
    while target and start_row == row do
      target = target:parent()
      if target then start_row = target:range() end
    end

    if not target or start_row == row then return end
    if (math.abs(start_row - row) <= 15) or (start_row == 0) then return end

    local match_line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1]
    if not match_line then return end

    local display = match_line:match("^%s*$") and "<blank line>" or match_line
    display = display:gsub("^%s+", "")
    if #display > 160 then display = display:sub(1, 160) .. "..." end

    vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
      virt_text = { { string.format("#%d: %s", start_row + 1, display), "Comment" } },
      virt_text_pos = "eol",
      hl_mode = "combine",
    })
  end,
})

