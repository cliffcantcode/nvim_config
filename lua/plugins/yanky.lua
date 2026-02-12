-- TODO: Try this out.
return {
  {
    "gbprod/yanky.nvim",
    event = "VeryLazy",
    opts = {
      highlight = {
        on_put = true,
        on_yank = true,
        timer = 250,
      },
      preserve_cursor_position = {
        enabled = true,
      },
    },
    config = function(_, opts)
      require("yanky").setup(opts)

      -- Telescope integration (safe even if telescope is lazy-loaded later)
      pcall(function()
        require("telescope").load_extension("yank_history")
      end)

      -- Core mappings (keeps your muscle memory; adds yank-ring behavior)
      vim.keymap.set({ "n", "x" }, "y", "<Plug>(YankyYank)")
      vim.keymap.set("n", "p", "<Plug>(YankyPutAfter)")
      vim.keymap.set("n", "P", "<Plug>(YankyPutBefore)")
      vim.keymap.set("n", "gp", "<Plug>(YankyGPutAfter)")
      vim.keymap.set("n", "gP", "<Plug>(YankyGPutBefore)")

      vim.keymap.set("n", "[y", "<Plug>(YankyCycleForward)", { desc = "Yank ring next" })
      vim.keymap.set("n", "]y", "<Plug>(YankyCycleBackward)", { desc = "Yank ring prev" })

      vim.keymap.set(
        "n",
        "<leader>sy",
        "<cmd>Telescope yank_history<CR>",
        { desc = "[S]earch [Y]ank history" }
      )
    end,
  },
}

