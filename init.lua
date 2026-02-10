-- Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true

-- Replace matchparen with a plugin (vim-matchup). It's causing severe lag on Windows.
vim.g.loaded_matchparen = 1

if vim.loader then vim.loader.enable() end

-- Disable tree-sitter completely for Swift files
-- Needs to be loaded before plugins.
vim.api.nvim_create_autocmd({ "BufReadPre", "FileType" }, {
  pattern = "swift",
  callback = function(args)
    -- Prevent Neovim from trying TS at all
    vim.b[args.buf].ts_disable = true

    -- Stop any TS parser if it started
    pcall(vim.treesitter.stop, args.buf)
  end,
})

-- [[ Setting options ]]
require 'options'

-- [[ Basic Keymaps ]]
require 'keymaps'

-- [[ Basic Autocommands ]]
require 'autocommands'

-- [[ Install `lazy.nvim` plugin manager ]]
require 'lazy-bootstrap'

-- [[ Configure and install plugins ]]
require 'lazy-plugins'

-- [[ Switch based on common pairs ]]
require 'mini_switch'

-- [[ Fix miss-spellings I've missed before ]]
require 'autocorrect'

-- [[ Insert templates for common patterns ]]
require 'insert_snippets'

-- [[ Lint on questionable patterns I've been known to make ]]
require 'linter'

-- [[ Auto format code before saving. ]]
require 'formatter'

-- [[ Help for working with dimensions (ex: X, Y, Z) ]]
require 'dimensions'

-- [[ Show distant paired brackets inline. ]]
-- TODO: Get this to be not so slow.
-- require 'echo_brackets'

-- [[ Helper for runtime profiling (:StartProfile/:StopProfile)]]
require 'profile'

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et

