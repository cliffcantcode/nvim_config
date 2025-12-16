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
      { "<leader>tm", function()
        require("render-markdown").toggle()
        -- Lightweight "zen-mode"
        if vim.bo.filetype == "markdown" then
          vim.wo.number = false
          vim.wo.relativenumber = false
          vim.wo.signcolumn = "no"
          vim.wo.cursorline = false
          vim.bo.textwidth = 80          -- used by gq / formatting
          vim.wo.conceallevel = 2        -- hide markup noise a bit
          vim.wo.concealcursor = "nc"    -- keep it readable while moving
          vim.wo.wrap = true
          vim.wo.linebreak = true        -- wrap on words
          vim.wo.breakindent = true
        end
      end, ft = "markdown", desc = "[t]oggle [m]arkdown rendering." },
    },
  },
}

