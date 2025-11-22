-- Highlight todo, notes, etc in comments
return {
  {
    'folke/todo-comments.nvim',
    event = 'VimEnter',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = {
      signs = false,
      -- Colors are based on catppuccin-mocha.
      keywords = {
        TODO = {
          color = '#eba0ac', -- TODO: Maroon
        },
        RESUME = {
          color = '#a6e3a1', -- RESUME: Green
          alt = { 'START', 'CONTINUE' },
        },
        COMPRESS = {
          color = '#cba6f7', -- COMPRESS: Mauve
        },
        STUDY = {
          color = '#fab387', -- STUDY: Peach
        },
        IMPORTANT = {
          color = '#f9e2af', -- IMPORTANT: Yellow
        },
      },
    },
  },
}
-- vim: ts=2 sts=2 sw=2 et
