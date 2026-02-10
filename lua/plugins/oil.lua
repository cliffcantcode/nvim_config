-- TODO: Set it to default open the explorer, right now it goes to a blank page after something like a plugin install.
return {
  {
    'stevearc/oil.nvim',
    cmd = "Oil",
    lazy = false,
    cmd = "Oil",
    keys = {
      { "-", "<CMD>Oil<CR>", desc = "Open file explorer." },
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

