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
          alt = { 'REFACTOR' },
        },
        STUDY = {
          color = '#fab387', -- STUDY: Peach
        },
        IMPORTANT = {
          color = '#f9e2af', -- IMPORTANT: Yellow
        },
      },
    },
    keys = {
      vim.keymap.set("n", "<leader>st", "<cmd>TodoTelescope<cr>", { desc = "[S]earch [T]odos" }),
      vim.keymap.set("n", "<leader>sT", "<cmd>TodoQuickFix<cr>",  { desc = "[S]end [T]odos to quickfix" }),
    },
  },
}
-- vim: ts=2 sts=2 sw=2 et

