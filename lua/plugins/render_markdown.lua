return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {},
    keys = {
      { "<leader>tmd", function() require("render-markdown").toggle() end, ft = "markdown", desc = "[t]oggle [m]ark[d]own rendering." },
    },
  },
}

