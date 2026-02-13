-- TODO: Try this out.
return {
  {
    "gbprod/yanky.nvim",
    event = "VeryLazy",
    opts = {
      highlight = {
        on_put = false,
        on_yank = false,
        timer = 250,
      },
      ring = {
        history_length = 50,
        storage = "memory",
        sync_with_numbered_registers = false,
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
      vim.keymap.set({ "n", "x" }, "p", "<Plug>(YankyPutAfter)")
      vim.keymap.set({ "n", "x" }, "P", "<Plug>(YankyPutBefore)")
      vim.keymap.set({ "n", "x" }, "gp", "<Plug>(YankyGPutAfter)")
      vim.keymap.set({ "n", "x" }, "gP", "<Plug>(YankyGPutBefore)")

      vim.keymap.set({ "n", "x" }, "[y", "<Plug>(YankyCycleForward)", { desc = "Yank ring next" })
      vim.keymap.set({ "n", "x" }, "]y", "<Plug>(YankyCycleBackward)", { desc = "Yank ring prev" })
      vim.keymap.set("n", "<C-n", "<Plug>(YankyCycleForward)", { desc = "Yank ring next" })
      vim.keymap.set("n", "<C-p", "<Plug>(YankyCycleBackward)", { desc = "Yank ring prev" })

      vim.keymap.set(
        "n",
        "<leader>sy",
        "<cmd>Telescope yank_history<CR>",
        { desc = "[S]earch [Y]ank history" }
      )
    end,
  },
}

