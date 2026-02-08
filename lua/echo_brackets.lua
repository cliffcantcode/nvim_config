-- Show paired bracket line.
local ns = vim.api.nvim_create_namespace("BracketEcho")
vim.api.nvim_create_autocmd("CursorHold", {
  desc = "Show matching line using Treesitter (non-blocking)",
  group = vim.api.nvim_create_augroup("BracketEcho", { clear = true }),
  callback = function()
    vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)

    -- Make sure Treesitter is available + buffer has a parser
    local has_ts, ts = pcall(require, "vim.treesitter")
    if not has_ts then
      return -- TS not installed
    end

    local ok_parser, parser = pcall(ts.get_parser, 0)
    if not ok_parser or not parser then
      return
    end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1         -- 0-based
    local line_text = vim.api.nvim_get_current_line()
    if line_text == "" then return end

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

    local col = start_idx - 1
    local ch = line_text:sub(start_idx, start_idx)

    -- If this bracket's opener is also on this line then skip it.
    -- This is a simple heuristic: if the line contains both '(' and ')', or '{' and '}', etc. then we assume that particular type is "closed on the same line".
    if ch == ")" and line_text:find("%(") then
      return
    elseif ch == "}" and line_text:find("{") then
      return
    elseif ch == "]" and line_text:find("%[") then
      return
    end

    local ok, node = pcall(vim.treesitter.get_node, { pos = { row, col } })
    if not ok or not node then return end

    local target = node
    local start_row = target:range()
    while target and start_row == row do
      target = target:parent()
      if target then start_row = target:range() end
    end

    if not target or start_row == row then return end
    if (math.abs(start_row - row) <= 15) or (start_row == 0) then return end

    local match_line = vim.api.nvim_buf_get_lines(0, start_row, start_row + 1, false)[1]
    if not match_line then return end

    local display = match_line:match("^%s*$") and "<blank line>" or match_line
    display = display:gsub("^%s+", "")
    if #display > 160 then display = display:sub(1, 160) .. "..." end

    vim.api.nvim_buf_set_extmark(0, ns, row, 0, {
      virt_text = { { string.format("#%d: %s", start_row + 1, display), "Comment" } },
      virt_text_pos = "eol",
      hl_mode = "combine",
    })
  end,
})

