return {
  'karb94/neoscroll.nvim',
  event = "VeryLazy",
  config = function()
    require('neoscroll').setup {
      easing = 'quadratic',
      mappings = { "<C-u>", "<C-d>", "<C-b>", "<C-f>", "zt", "zz", "zb" },
      hide_cursor = false,
      stop_eof = true,
      respect_scrolloff = false,
      cursor_scrolls_alone = true,
      performance_mode = true,
    }
  end,
}

