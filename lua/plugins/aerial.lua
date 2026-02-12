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
      placement = "edge",          -- keep it on the edge
      default_direction = "right",  -- or "prefer_left"
      resize_to_content = false,   -- don't widen based on symbol names

      -- Make it narrow and consistent:
      max_width = { 12, 0.18 },
      min_width = {  6, 0.10 },

      win_opts = {
        number = false,
        relativenumber = false,
        signcolumn = "no",
        foldcolumn = "0",
        cursorline = false,
        winblend = 40, -- subtle transparency
        -- Optional: make it visually "float-like"
        winhl = "Normal:NormalFloat,SignColumn:NormalFloat",
      },
    },
  },
  keys = {
    { "<leader>tfm", "<cmd>AerialToggle!<CR>", desc = "[t]oggle [f]unctions [m]ap." },
  },
}

