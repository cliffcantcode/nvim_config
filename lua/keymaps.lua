-- [[ Basic Keymaps ]]

-- Clear highlights on search when pressing <Esc> in normal mode
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Keybinds to make split navigation easier.
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- Simple writing and quitting are a bit awkward
vim.keymap.set('n', '<leader>w', ':w<CR>', { desc = '[w]rite to file' })
vim.keymap.set('n', '<leader>q', ':q<CR>', { desc = '[q]uit file' })

-- Diagnostics
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Show diagnostic [e]rror messages' })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next     [d]iagnostic message' })
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous [d]iagnostic message' })

-- Return to normal mode more easily
vim.keymap.set('i', 'jk', '<Esc>', { desc = 'Exit insert mode' })

-- Make the arrow keys useful again
vim.keymap.set('n', '<down>', ':m .+1<CR>==', { desc = 'Move line down once' })
vim.keymap.set('n', '<up>',   ':m .-2<CR>==', { desc = 'Move line up once' })
vim.keymap.set('n', '<left>',  ':bprev<CR>', { desc = 'Move to the previous buffer' })
vim.keymap.set('n', '<right>', ':bnext<CR>', { desc = 'Move to the next buffer' })

-- TODO: Try these out.
-- Tabs
vim.keymap.set('n', ']t', '<cmd>tabnext<cr>', { desc = 'Next tab' })
vim.keymap.set('n', '[t', '<cmd>tabprevious<cr>', { desc = 'Previous tab' })

vim.keymap.set('n', '<leader><tab>n', '<cmd>tabnext<cr>', { desc = 'Next tab' })
vim.keymap.set('n', '<leader><tab>p', '<cmd>tabprevious<cr>', { desc = 'Previous tab' })
vim.keymap.set('n', '<leader><tab>t', '<cmd>tabnew<cr>', { desc = 'New tab' })
vim.keymap.set('n', '<leader><tab>c', '<cmd>tabclose<cr>', { desc = 'Close tab' })
vim.keymap.set('n', '<leader><tab>o', '<cmd>tabonly<cr>', { desc = 'Close other tabs' })

-- Move current tab left/right
vim.keymap.set('n', '<leader><tab>h', '<cmd>tabmove -1<cr>', { desc = 'Move tab left' })
vim.keymap.set('n', '<leader><tab>l', '<cmd>tabmove +1<cr>', { desc = 'Move tab right' })

-- Jump directly to tab #
for i = 1, 9 do
  vim.keymap.set('n', '<leader><tab>' .. i, i .. 'gt', { desc = 'Go to tab ' .. i })
end
vim.keymap.set('n', '<leader><tab>0', '<cmd>tablast<cr>', { desc = 'Go to last tab' })

-- Run the project's build script. Change this to match the desired project's build script
-- vim.keymap.set('n', ',b', ':w<CR> :!P:\\handmade\\code\\build.bat<CR>', { desc = 'Run [b]uild script.' })
-- vim.keymap.set('n', ',z', ':w<CR> :!zig build run -Ddev<CR>', { desc = 'Run the [z]ig build script.' })

-- Source the current buffer
vim.keymap.set('n', '<leader>ns', ':w<CR> :source ' .. vim.fn.stdpath('config') .. '/init.lua<CR>',
  { desc = '[n]eovim [s]ource the init.lua changes.' })

-- Replace word with what's in the clipboard.
vim.keymap.set('n', 'cp', 'ciw<ESC>"0pyiw', { desc = 'Swap with clipboard text.' })
vim.keymap.set('n', 'cP', 'ciW<ESC>"0pyiW', { desc = 'Swap with clipboard text.' })

vim.keymap.set('n', '<leader>hs', '<cmd>split<CR>', { desc = '[h]orizontal [s]plit window.' })
vim.keymap.set('n', '<leader>vs', '<cmd>vsplit<CR>', { desc = '[v]ertical [s]plit window.' })

-- Making the undolist easier to use.
vim.keymap.set('n', '<leader>u', ':undolist<CR>', { desc = '[u]ndo list' })
vim.keymap.set('n', '<leader>U', ':undo ')

vim.keymap.set('n', '<leader>%', '%:print<CR>%', { desc = 'Print paired bracket line.' })

-- Easier spell checking.
vim.keymap.set('n', '<leader>sc', ':set spell! spelllang=en_us<CR>', { desc = '[s]pell [c]heck toggle.' })

-- Function to multiply the number under the cursor
local function multiply_number_under_cursor(multiplier)
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_get_current_line()

    -- Pattern to match integers or floats (optional negative sign)
    -- It captures the start and end indices of the match
    local s, e, num = line:find("([-]?%d+%.?%d*)", col + 1)

    if s and e and num then
        local new_val = tonumber(num) * multiplier
        -- Replace the old number with the new value
        line = line:sub(1, s-1) .. new_val .. line:sub(e+1)
        vim.api.nvim_set_current_line(line)
    end
end

vim.keymap.set("n", "<leader>dn", function() multiply_number_under_cursor(2.0) end, { desc = "[d]ouble number under cursor" })
vim.keymap.set("n", "<leader>hn", function() multiply_number_under_cursor(0.5) end, { desc = "[h]alve  number under cursor" })

vim.keymap.set("n", "]q", "<cmd>cnext<cr>", { desc = "Quickfix next" })
vim.keymap.set("n", "[q", "<cmd>cprev<cr>", { desc = "Quickfix prev" })

local function find_paren_pair_on_line(line, cursor_col0)
  local stack = {}
  local pairs = {}
  local in_string = nil
  local escape = false

  for i = 1, #line do
    local ch = line:sub(i, i)

    if in_string then
      if escape then
        escape = false
      elseif ch == "\\" then
        escape = true
      elseif ch == in_string then
        in_string = nil
      end
    else
      if ch == "\"" or ch == "'" then
        in_string = ch
      elseif ch == "(" then
        stack[#stack + 1] = i
      elseif ch == ")" and #stack > 0 then
        local open = table.remove(stack)
        pairs[#pairs + 1] = { open = open, close = i }
      end
    end
  end

  local cursor = cursor_col0 + 1
  local best
  for _, pair in ipairs(pairs) do
    if pair.open < cursor and cursor <= pair.close then
      if not best or pair.open > best.open then
        best = pair
      end
    end
  end
  if best then return best end

  for _, pair in ipairs(pairs) do
    if not best or math.abs(pair.open - cursor) < math.abs(best.open - cursor) then
      best = pair
    end
  end
  return best
end

local function split_top_level_args(text)
  local args = {}
  local start = 1
  local depth = 0
  local in_string = nil
  local escape = false

  for i = 1, #text do
    local ch = text:sub(i, i)

    if in_string then
      if escape then
        escape = false
      elseif ch == "\\" then
        escape = true
      elseif ch == in_string then
        in_string = nil
      end
    else
      if ch == "\"" or ch == "'" then
        in_string = ch
      elseif ch == "(" or ch == "{" or ch == "[" then
        depth = depth + 1
      elseif ch == ")" or ch == "}" or ch == "]" then
        if depth > 0 then depth = depth - 1 end
      elseif ch == "," and depth == 0 then
        args[#args + 1] = text:sub(start, i - 1)
        start = i + 1
      end
    end
  end

  args[#args + 1] = text:sub(start)
  return args
end

local function strip_type_from_arg(arg)
  local leading, body, trailing = arg:match("^(%s*)(.-)(%s*)$")
  if not body or body == "" then return arg end
  if body:find("=", 1, true) then return arg end

  local name_part = body:match("^(.-)%s*:%s*.+$")
  if not name_part then return arg end

  local name = name_part:match("([A-Za-z_][A-Za-z0-9_]*)%s*$")
  if not name then return arg end

  local before_name = name_part:sub(1, #name_part - #name)
  if before_name:find("[^%sA-Za-z0-9_]") then return arg end

  return leading .. name .. trailing
end

local function remove_types_inside_parens()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local pair = find_paren_pair_on_line(line, col)
  if not pair then return end

  local inside = line:sub(pair.open + 1, pair.close - 1)
  local args = split_top_level_args(inside)
  local changed = false

  for i, arg in ipairs(args) do
    local stripped = strip_type_from_arg(arg)
    if stripped ~= arg then
      changed = true
      args[i] = stripped
    end
  end

  if not changed then return end

  local new_inside = table.concat(args, ",")
  local new_line = line:sub(1, pair.open) .. new_inside .. line:sub(pair.close)
  vim.api.nvim_set_current_line(new_line)
  pcall(vim.api.nvim_win_set_cursor, 0, { row, math.min(col, #new_line) })
end

vim.keymap.set("n", "<leader>dtip", remove_types_inside_parens, { desc = "[d]elete [t]ypes [i]n [p]arens" })

-- vim: ts=2 sts=2 sw=2 et


