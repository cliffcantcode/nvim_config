-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
return {
  {
    'folke/flash.nvim',
    event = 'VeryLazy',
    ---@type Flash.Config
    opts = {},
  -- stylua: ignore
  keys = {
    { ",s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
    -- { ",S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
    -- { ",r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
    -- { ",R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
    -- { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
  },
  },

  -- "gc" to comment visual regions/lines
  {
    'numToStr/Comment.nvim',
    opts = {},

    -- slap a timestamp at the end of the line --[[ 2024-08-15 21:31:58 ]]
    -- stylua: ignore
    vim.keymap.set(
      'n',
      '<leader>ts',
      "A<space><C-r>=strftime('%Y-%m-%d %H:%M:%S')<CR><Esc>2B<Plug>(comment_toggle_linewise)$",
      { desc = 'Append [t]ime[s]tamp' }
    ),
  },

  { -- Open files where you left off
    'farmergreg/vim-lastplace',
  },

  -- custom quick swapping of common terms (ex: true -> false, 0 -> 1, {} -> {};)
  {
    'AndrewRadev/switch.vim',
    config = function()
      vim.g.switch_custom_definitions = {
        { '0', '1' },
        { 'var', 'const' },
        -- { '{}', '{};' }, -- TODO: figure out if this can be done properly in lua
        { 'init', 'deinit' },
      }
    end,
  },

  -- scroll smoothly instead of jumping to a place
  {
    'karb94/neoscroll.nvim', -- smooths regular scroll mostions (ex: CTRL-E, CTRL-Y)
    config = function()
      require('neoscroll').setup { easing = 'quadratic' }
    end,

    'joeytwiddle/sexy_scroller.vim', -- helps with spatial recognition
  },
}
