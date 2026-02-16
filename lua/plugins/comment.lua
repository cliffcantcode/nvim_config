return {
  "numToStr/Comment.nvim",
  opts = {},

  config = function(_, opts)
    require("Comment").setup(opts)

    -- Append a timestamp as an end-of-line comment (works in Zig, respects commentstring).
    -- Uses Comment.nvim's default extra mapping: `gcA` = "comment at end of line and enter INSERT". :contentReference[oaicite:1]{index=1}
    vim.keymap.set(
      "n",
      "<leader>ts",
      "gcA<C-r>=strftime('%Y-%m-%d %H:%M:%S')<CR><Esc>",
      { desc = "Append [t]ime[s]tamp", remap = true }
    )
  end,
}

-- vim: ts=2 sts=2 sw=2 et

