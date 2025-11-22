local flavor_i = 1

return {
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    opts = {},
    priority = 1000, -- Make sure to load this before all the other start plugins.
    config = function()
      require('catppuccin').setup {
        dim_inactive = {
          enabled = true,
          shade = "dark",
          percentage = 0.30,
        },
        transparent_background = false,
        styles = {
          sidebars = 'transparent',
          floats = 'transparent',
        },
      }
      vim.cmd.colorscheme 'catppuccin-mocha'
    end,

    vim.keymap.set('n', '<leader>cc', function()
      local flavors = { 'catppuccin-latte', 'catppuccin-mocha' }
      flavor_i = (flavor_i % #flavors) + 1
      vim.cmd.colorscheme(flavors[flavor_i])
    end, { desc = "[c]hange [c]olorscheme" })
  },
}
-- vim: ts=2 sts=2 sw=2 et
