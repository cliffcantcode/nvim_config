return {
  "mizlan/iswap.nvim",
  event = "VeryLazy",

  vim.keymap.set('n', '<leader>ps', ':ISwapWith<CR>', { desc = '[p]arameter [s]wap' }),
}

