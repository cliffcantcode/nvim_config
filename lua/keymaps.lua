-- [[ Basic Keymaps ]]

-- Clear highlights on search when pressing <Esc> in normal mode
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Keybinds to make split navigation easier.
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- Simple writing and quitting are a bit awkward
vim.keymap.set('n', ',w', ':w<CR>', { desc = '[w]rite to file' })
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

-- Run the project's build script. Change this to match the desired project's build script
vim.keymap.set('n', ',b', ':w<CR> :!P:\\handmade\\code\\build.bat<CR>', { desc = 'Run [b]uild script.' })
vim.keymap.set('n', ',z', ':w<CR> :!zig build run<CR>', { desc = 'Run the [z]ig build script.' })

-- Source the current buffer
vim.keymap.set('n', ',s', ':w<CR> :source "C:\\Users\\cliff\\AppData\\Local\\nvim\\init.lua"<CR>',
  { desc = '[s]ource the init.lua changes.' })

-- Replace word with what's in the clipboard.
vim.keymap.set('n', 'cp', 'ciw<ESC>"0pyiw', { desc = 'Swap with clipboard text.' })
vim.keymap.set('n', 'cP', 'ciW<ESC>"0pyiW', { desc = 'Swap with clipboard text.' })

-- Splitting horizontal should match the vertical command (:vs).
vim.keymap.set('n', ':hs<CR>', ':split<CR>', { desc = 'Horizontal window split.' })

-- Making the undolist easier to use.
vim.keymap.set('n', '<leader>u', ':undolist<CR>', { desc = '[u]ndo list' })
vim.keymap.set('n', 'U', ':undo ')

vim.keymap.set('n', '<leader>%', '%:print<CR>%', { desc = 'Print paired bracket line.' })

-- Easier spell checking.
vim.keymap.set('n', '<leader>sc', ':set spell! spelllang=en_us<CR>', { desc = '[s]pell [c]heck toggle.' })

-- Exchange coordinates more quickly. (X->Y->Z->X)
local function cycle_dimensions_xyz(text)
  -- Temporary replacements to avoid collision
  text = text:gsub("X", "|X|")
  text = text:gsub("Y", "|Y|")
  text = text:gsub("Z", "|Z|")

  -- Final replacements (rotating)
  text = text:gsub("|X|", "Y")
  text = text:gsub("|Y|", "Z")
  text = text:gsub("|Z|", "X")

  return text
end

vim.keymap.set("n", "<leader>cd", function()
  local line = vim.api.nvim_get_current_line()
  vim.api.nvim_set_current_line(cycle_dimensions_xyz(line))
end, { desc = "[c]ycle [d]imensions across a line." })

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

-- vim: ts=2 sts=2 sw=2 et

