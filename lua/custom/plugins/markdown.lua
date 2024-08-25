return {
  -- centers text for writing with :ZenMode
  {
    'folke/zen-mode.nvim',
    opts = {},

    vim.keymap.set('n', '<leader>z', '<CMD>ZenMode<CR>', { desc = '[Z]en Mode' }),
  },

  -- TODO: describe this once you use it more
  {
    'jakewvincent/mkdnflow.nvim',
    config = function()
      require('mkdnflow').setup {
        -- Config goes here; leave blank for defaults
      }
    end,
  },
}
