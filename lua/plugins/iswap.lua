return {
  "mizlan/iswap.nvim",
  event = "VeryLazy",

  vim.keymap.set('n', '<leader>is', ':ISwapWith<CR>', { desc = '[is]wap where you are with a target' }),
}
