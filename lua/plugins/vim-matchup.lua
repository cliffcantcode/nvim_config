return {
  'andymass/vim-matchup',
  event = 'VeryLazy',
  dependencies = { 'nvim-treesitter/nvim-treesitter' },
  init = function()
    -- Disable built-in matchparen
    vim.g.loaded_matchparen = 1

    -- Make matchup less aggressive
    vim.g.matchup_matchparen_deferred = 1  -- Defer highlighting
    vim.g.matchup_matchparen_deferred_show_delay = 25  -- Wait 100ms before highlighting
    vim.g.matchup_matchparen_timeout = 100  -- Give up after 100ms
    vim.g.matchup_matchparen_insert_timeout = 30  -- Even faster timeout in insert mode
    vim.g.matchup_matchparen_offscreen = {}  -- Disable offscreen matching (slow feature)
  end,
  config = function()
    -- Enable treesitter integration for faster, smarter matching
    require('nvim-treesitter.configs').setup({
      matchup = {
        enable = true,  -- Use treesitter instead of regex
        disable = {},   -- Optional: list of languages to disable for
      },
    })
  end,
}

