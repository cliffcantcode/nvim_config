return {
  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    dependencies = { "nvim-treesitter/nvim-treesitter-textobjects" },
    main = 'nvim-treesitter.configs', -- Sets main module to use for opts
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
    opts = {
      ensure_installed = { 'zig', 'bash', 'c', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc' },
      -- Autoinstall languages that are not installed
      auto_install = false,
      highlight = {
        enable = true,
        disable = { 'swift' },
      },
      indent = { enable = true, disable = { 'sql', 'swift' } },
      textobjects = {
        select = {enable = true, lookahead = true, -- allows 'vaf' even if cursor is before the function keymaps = { ["af"] = "@function.outer", ["if"] = "@function.inner", },},
      },

      -- There are additional nvim-treesitter modules that you can use to interact
      -- with nvim-treesitter. You should go explore a few and see what interests you:
      --
      --    - Incremental selection: Included, see `:help nvim-treesitter-incremental-selection-mod`
      --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
      },
    },
  },
}
-- vim: ts=2 sts=2 sw=2 et

