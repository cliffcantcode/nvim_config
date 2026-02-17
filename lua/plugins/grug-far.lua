return {
  {
    "MagicDuck/grug-far.nvim",
    cmd = { "GrugFar", "GrugFarWithin" },
    keys = {
      {
        "<leader>frn",
        function()
          require("grug-far").open({
            prefills = { search = vim.fn.expand("<cword>") },
          })
        end,
        desc = "[S]earch [R]eplace (grug-far, word)",
      },
      {
        "<leader>frn",
        function()
          require("grug-far").with_visual_selection()
        end,
        mode = "x",
        desc = "[S]earch [R]eplace (grug-far, selection)",
      },
    },
    config = function()
      require("grug-far").setup({})
    end,
  },
}

