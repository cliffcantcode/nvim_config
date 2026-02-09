return {
  {
    'stevearc/oil.nvim',
    cmd = "Oil",
    keys = {
      { "-", "<CMD>Oil<CR>", desc = "Open parent directory" },
    },
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {
      columns = { 'icon' },
      keymaps = {
        ['<C-h>'] = false,
        ['<M-h>'] = 'actions.select_split',
      },
      view_options = { show_hidden = true },
      default_file_explorer = true,
    },
  },
}

