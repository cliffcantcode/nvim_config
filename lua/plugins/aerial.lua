return {
  "stevearc/aerial.nvim",
  event = "BufReadPost",
  dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
  cmd = { "AerialToggle", "AerialOpen", "AerialClose" },

  opts = {
    open_automatic = function(bufnr)
      -- only real files
      return (vim.bo[bufnr].buftype == ""
        and vim.api.nvim_buf_get_name(bufnr) ~= ""
        and vim.bo[bufnr].filetype ~= "oil"
        and vim.bo[bufnr].filetype ~= "lazy")
    end,

    on_attach = function(bufnr)
      vim.keymap.set("n", "{", "<cmd>AerialPrev<CR>", { buffer = bufnr })
      vim.keymap.set("n", "}", "<cmd>AerialNext<CR>", { buffer = bufnr })
    end,

    layout = {
      placement = "edge", -- keep it on the edge
      default_direction = "right",
      resize_to_content = false,

      -- Make it narrow and consistent:
      max_width = { 12, 0.18 },
      min_width = { 6, 0.10 },

      win_opts = {
        number = false,
        relativenumber = false,
        signcolumn = "no",
        foldcolumn = "0",
        cursorline = false,
        winblend = 40,
        winhl = "Normal:NormalFloat,SignColumn:NormalFloat",
      },
    },

    backends = {
      ["_"] = { "treesitter", "lsp", "markdown", "asciidoc", "man" },
      sql = { "lsp" },
      pgsql = { "lsp" },
      plpgsql = { "lsp" },
    },
  },

  config = function(_, opts)
    require("aerial").setup(opts)

    -- Close Aerial automatically if it's the last window left in the tab.
    -- (Prevents "oops I'm stuck with only the sidebar" after closing other windows.)
    local group = vim.api.nvim_create_augroup("AerialCloseIfLast", { clear = true })

    vim.api.nvim_create_autocmd("BufEnter", {
      group = group,
      callback = function()
        if vim.bo.filetype ~= "aerial" then
          return
        end

        -- If every window in this tabpage is an aerial window, quit.
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.bo[buf].filetype ~= "aerial" then
            return
          end
        end

        -- Use quit (not close) so it works even if this is the last window.
        vim.schedule(function()
          pcall(vim.cmd, "quit")
        end)
      end,
    })
  end,

  keys = {
    { "<leader>tfm", "<cmd>AerialToggle!<CR>", desc = "[t]oggle [f]unctions [m]ap." },
  },
}

