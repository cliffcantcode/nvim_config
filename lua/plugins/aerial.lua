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
    },
  },

  config = function(_, opts)
    require("aerial").setup(opts)

    -- Close Aerial automatically if it's the last window left in the tab.
    -- (Prevents "oops I'm stuck with only the sidebar" after closing other windows.)
    local group = vim.api.nvim_create_augroup("AerialCloseIfLast", { clear = true })

    local function close_if_last()
      vim.schedule(function()
        local wins = vim.api.nvim_tabpage_list_wins(0)
        -- Ignore floating windows
        local normal_wins = vim.tbl_filter(function(win)
          local cfg = vim.api.nvim_win_get_config(win)
          return cfg.relative == ""
        end, wins)

        if #normal_wins ~= 1 then
          return
        end

        local only_win = normal_wins[1]
        local only_buf = vim.api.nvim_win_get_buf(only_win)
        if vim.bo[only_buf].filetype == "aerial" then
          pcall(vim.cmd, "quit")
        end
      end)
    end

    vim.api.nvim_create_autocmd({ "WinEnter", "WinClosed", "BufEnter" }, {
      group = group,
      desc = "Close Neovim tab if Aerial is the last remaining window",
      callback = close_if_last,
    })
  end,

  keys = {
    { "<leader>tfm", "<cmd>AerialToggle!<CR>", desc = "[t]oggle [f]unctions [m]ap." },
  },
}

