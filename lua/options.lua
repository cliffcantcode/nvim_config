-- [[ Setting options ]]
--
-- Make line numbers default
vim.opt.number = false

-- Enable mouse mode, can be useful for resizing splits for example!
vim.opt.mouse = 'a'

-- Don't show the mode, since it's already in the status line
vim.opt.showmode = false

-- Sync clipboard between OS and Neovim.
vim.opt.clipboard = 'unnamedplus'

-- Enable break indent
vim.opt.breakindent = true

-- Changes 8 spaced <TAB> to 4 space characters
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

-- Save undo history
vim.opt.undofile = true
vim.opt.swapfile = false

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Keep signcolumn on by default
vim.opt.signcolumn = 'no'

-- Decrease update time
vim.opt.updatetime = 250

-- Decrease mapped sequence wait time
vim.opt.timeoutlen = 300

-- Configure how new splits should be opened
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
vim.opt.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions live, as you type!
vim.opt.inccommand = 'split'

-- Show which line your cursor is on
vim.opt.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.opt.scrolloff = 17
vim.opt.sidescrolloff = 5

-- Make command line completion more usable
vim.opt.wildmode = "longest:full,full"
vim.opt.wildmenu = true


-- If performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
-- instead raise a dialog asking if you wish to save the current file(s)
vim.opt.confirm = true

-- Wrap text
vim.opt.wrap = true
vim.opt.linebreak = false

-- Ensure that files are formatted correctly
vim.opt.encoding = "utf-8"
vim.opt.fileencoding = "utf-8"

-- Make jump list behave like a stack to prevent a build up of weird jumps.
vim.opt.jumpoptions = "stack"

-- vim: ts=2 sts=2 sw=2 et

