-- TODO: Try this out.
return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewFileHistory" },
  keys = {
    { "<leader>dv", "<cmd>DiffviewOpen<CR>", desc = "Git Diffview" },
    { "<leader>dh", "<cmd>DiffviewFileHistory<CR>", desc = "Git File History" },
  },
}

