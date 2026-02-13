-- TODO: Fix this error:
-- Error executing Lua callback: ...ams/nvim/share/nvim/runtime/lua/vim/treesitter/qu
-- ery.lua:373: Query error at 37:2. Invalid node type "create_policy":
-- (create_policy
--  ^
--
-- stack traceback:
--         [C]: in function '_ts_parse_query'
--         ...ams/nvim/share/nvim/runtime/lua/vim/treesitter/query.lua:373: in functi
-- on 'fn'
--         ...ograms/nvim/share/nvim/runtime/lua/vim/func/_memoize.lua:78: in functio
-- n 'fn'
--         ...ograms/nvim/share/nvim/runtime/lua/vim/func/_memoize.lua:78: in functio
-- n 'get'
--         ...y/aerial.nvim/lua/aerial/backends/treesitter/helpers.lua:43: in functio
-- n 'get_query'
--         ...lazy/aerial.nvim/lua/aerial/backends/treesitter/init.lua:22: in functio
-- n 'is_supported'                                                                          .../nvim-data/lazy/aerial.nvim/lua/aerial/backends/init.lua:40: in function 'is_supported'                                                                          .../nvim-data/lazy/aerial.nvim/lua/aerial/backends/init.lua:73: in function 'get_best_backend'                                                                      .../nvim-data/lazy/aerial.nvim/lua/aerial/backends/init.lua:147: in function 'get'                                                                                  ...a/Local/nvim-data/lazy/aerial.nvim/lua/aerial/window.lua:335: in function 'open'                                                                                 ...a/Local/nvim-data/lazy/aerial.nvim/lua/aerial/window.lua:373: in function 'toggle'                                                                               ...ata/Local/nvim-data/lazy/aerial.nvim/lua/aerial/init.lua:304: in functi
-- on 'toggle'
--         .../Local/nvim-data/lazy/aerial.nvim/lua/aerial/command.lua:8: in function
--  <.../Local/nvim-data/lazy/aerial.nvim/lua/aerial/command.lua:3>

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

