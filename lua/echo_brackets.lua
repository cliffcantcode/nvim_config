local api = vim.api
local fn = vim.fn
local ts = vim.treesitter
if not ts then return end

local ns  = api.nvim_create_namespace("BracketEcho")
local aug = api.nvim_create_augroup("BracketEcho", { clear = true })

-- Tunables (override via vim.g.*)
local MAX_LINES    = vim.g.bracketecho_max_lines or 5000
local MIN_DISTANCE = vim.g.bracketecho_min_distance or 15
local MAX_DISPLAY  = vim.g.bracketecho_max_display or 160

local uv = vim.uv or vim.loop
local last_hold_ms = 0
local HOLD_THROTTLE_MS = vim.g.bracketecho_throttle_ms or 800

-- If you really want this to work even when there isn't an existing TS tree,
-- set this to 1 (may reintroduce occasional parse pauses).
local FORCE_PARSE  = vim.g.bracketecho_force_parse == 1

-- Hot-path state (no table allocations)
local last_buf, last_win, last_row, last_tick, last_tok = -1, -1, -1, -1, -1
local mark_buf, mark_id = -1, nil

-- Per-buffer TS cache
local cache = {} -- bufnr -> { parser=..., tree=..., tick=... }

local function del_mark(bufnr)
  if mark_id and mark_buf == bufnr and api.nvim_buf_is_valid(bufnr) then
    pcall(api.nvim_buf_del_extmark, bufnr, ns, mark_id)
  end
  if mark_buf == bufnr then
    mark_buf, mark_id = -1, nil
  end
end

-- Clear stale hint immediately on movement
api.nvim_create_autocmd({ "CursorMoved", "InsertEnter", "BufLeave", "WinLeave" }, {
  group = aug,
  callback = function(args)
    del_mark(args.buf)
  end,
})

api.nvim_create_autocmd({ "BufUnload", "BufWipeout" }, {
  group = aug,
  callback = function(args)
    cache[args.buf] = nil
    del_mark(args.buf)
  end,
})

-- Find the *last* closing token on the line (cursor can be anywhere)
-- Returns 0-indexed column, or nil if none.
local function find_last_closer_col(line)
  -- scan from end for ) ] }
  for i = #line, 1, -1 do
    local b = line:byte(i)
    if b == 41 or b == 93 or b == 125 then
      return i - 1
    end
  end
  -- fallback: last word-boundary `end`
  local s = line:match(".*()%f[%w]end%f[%W]")
  if s then return s - 1 end
  return nil
end

local function get_tree(bufnr, tick)
  local c = cache[bufnr]
  local parser = c and c.parser
  if not parser then
    local ok
    ok, parser = pcall(ts.get_parser, bufnr)
    if not ok or not parser then return nil end
    c = c or {}
    c.parser = parser
    cache[bufnr] = c
  end

  if c.tick == tick and c.tree then
    return c.tree
  end

  -- FAST PATH: do NOT force a parse. Reuse existing TS tree if present.
  local trees = parser:trees()
  local tree = trees and trees[1] or nil
  if not tree then
    if not FORCE_PARSE then return nil end
    local ok, parsed = pcall(function() return parser:parse() end)
    if not ok or not parsed or not parsed[1] then return nil end
    tree = parsed[1]
  end

  c.tree = tree
  c.tick = tick
  return tree
end

api.nvim_create_autocmd("CursorHold", {
  group = aug,
  desc = "Echo opener line for closers (fast cached TS, cursor can be anywhere on line)",
  callback = function(args)
    local bufnr = args.buf

    local now = uv and uv.now and uv.now() or 0
    if now ~= 0 and (now - last_hold_ms) < HOLD_THROTTLE_MS then return end
    last_hold_ms = now

    if vim.bo[bufnr].buftype ~= "" then return end
    if vim.b[bufnr].ts_disable then return end
    if api.nvim_buf_line_count(bufnr) > MAX_LINES then return end

    local win = api.nvim_get_current_win()
    local row = api.nvim_win_get_cursor(win)[1] - 1
    local tick = vim.b[bufnr].changedtick

    local line = api.nvim_get_current_line()
    if line == "" then return end

    local tok = find_last_closer_col(line)
    if not tok or tok < 0 or tok >= #line then return end

    -- Cache: ignore cursor column entirely (works anywhere on the line)
    if bufnr == last_buf and win == last_win and row == last_row and tick == last_tick and tok == last_tok then
      return
    end
    last_buf, last_win, last_row, last_tick, last_tok = bufnr, win, row, tick, tok

    del_mark(bufnr)

    local tree = get_tree(bufnr, tick)
    if not tree then return end

    local root = tree:root()
    if not root then return end

    local node = root:descendant_for_range(row, tok, row, tok + 1)
    if not node then return end

    -- Walk up until we find a node that starts above this line.
    local target = node
    local start_row = row
    while target do
      start_row = target:range() -- first return is start row
      if start_row < row then break end
      target = target:parent()
    end
    if not target or start_row >= row then return end

    local dist = row - start_row
    if dist <= MIN_DISTANCE or start_row == 0 then return end

    -- Only show if opener is offscreen above
    local top = fn.line("w0") - 1
    if start_row >= top then return end

    local match_line = api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1]
    if not match_line then return end

    local display = match_line:match("^%s*$") and "<blank line>" or match_line
    display = display:gsub("^%s+", "")
    if #display > MAX_DISPLAY then
      display = display:sub(1, MAX_DISPLAY) .. "..."
    end

    mark_id = api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
      virt_text = { { "#" .. (start_row + 1) .. ": " .. display, "Comment" } },
      virt_text_pos = "eol",
      hl_mode = "combine",
    })
    mark_buf = bufnr
  end,
})

