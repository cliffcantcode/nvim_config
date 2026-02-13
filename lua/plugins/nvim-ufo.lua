return {
  "kevinhwang91/nvim-ufo",
  dependencies = { "kevinhwang91/promise-async" },
  event = "VeryLazy",
  init = function()
    vim.o.foldcolumn = "0" -- no fold gutter
    vim.o.foldlevel = 99
    vim.o.foldlevelstart = 99
    vim.o.foldenable = true
  end,
  opts = {
    provider_selector = function(_, _, _)
      return { "lsp", "treesitter", "indent" }
    end,
  },
  config = function(_, opts)
    local ufo = require("ufo")
    ufo.setup(opts)
    vim.keymap.set("n", "zR", ufo.openAllFolds, { desc = "Open all folds" })
    vim.keymap.set("n", "zM", ufo.closeAllFolds, { desc = "Close all folds" })
  end,
}

