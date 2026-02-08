return {
  'karb94/neoscroll.nvim',
  config = function()
    require('neoscroll').setup {
      easing = 'quadratic',
      mappings = {},
      hide_cursor = false,
      stop_eof = true,
      respect_scrolloff = false,
      cursor_scrolls_alone = true,
      performance_mode = true,
    }
  end,
}

