return {
  "kevinhwang91/nvim-ufo",
  dependencies = { "kevinhwang91/promise-async" },
  event = "VeryLazy",
  init = function()
    vim.o.foldcolumn = "0" -- remove fold gutter
    vim.o.foldlevel = 99
    vim.o.foldlevelstart = 99
    vim.o.foldenable = true
  end,
  opts = {
    provider_selector = function(bufnr, filetype, buftype)
      local clients = vim.lsp.get_clients({ bufnr = bufnr })
      for _, client in ipairs(clients) do
        if client.server_capabilities and client.server_capabilities.foldingRangeProvider then
          return { "lsp", "indent" }
        end
      end

      return { "treesitter", "indent" }
    end,
  },
  config = function(_, opts)
    local ufo = require("ufo")
    ufo.setup(opts)

    vim.keymap.set("n", "zR", ufo.openAllFolds, { desc = "Open all folds" })
    vim.keymap.set("n", "zM", ufo.closeAllFolds, { desc = "Close all folds" })
  end,
}

