-- Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true

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
require 'echo_brackets'

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et

