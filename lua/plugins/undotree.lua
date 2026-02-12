-- TODO: Try this out.
return {
  {
    "mbbill/undotree",
    cmd = { "UndotreeToggle", "UndotreeShow", "UndotreeHide" },
    keys = {
      -- You currently map <leader>u to :undolist. This replaces it with the visual tree:
      { "<leader>u", "<cmd>UndotreeToggle<cr>", desc = "[U]ndo tree" },
    },
    init = function()
      -- optional: focus the undotree window when you open it
      vim.g.undotree_SetFocusWhenToggle = 1
    end,
  },
}

