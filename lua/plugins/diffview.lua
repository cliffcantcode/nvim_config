-- TODO: Try this out.
-- TODO: Keymap :tabclose
return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewFileHistory" },
  keys = {
    { "<leader>gdv", "<cmd>DiffviewOpen<CR>", desc = "Git Diffview" },
    { "<leader>gdfh", "<cmd>DiffviewFileHistory<CR>", desc = "Git File History" },
  },
}

