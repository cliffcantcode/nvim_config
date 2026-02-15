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

      -- Exclude noisy files/dirs from TodoTelescope/TodoQuickFix/etc.
      search = {
        command = "rg",
        args = {
          "--color=never",
          "--no-heading",
          "--with-filename",
          "--line-number",
          "--column",

          -- TODO: Get this to exclude any local dependencies/ or ../tracy/
          -- Exclude THIS config file anywhere it appears:
          "--glob=!**/lua/plugins/todo-comments.lua",
          -- Exclude, it has false todos in tests.
          "--glob=!**/lua/autocorrect.lua",
          -- Exclude vendored/third-party dirs (common sources of noise):
          "--glob=!dependencies/**",
          "--glob=!**/dependencies/**",
          -- Exclude tracy checkout if it's inside (or nested within) the search root:
          "--glob=!tracy/**",
          "--glob=!**/tracy/**",
          -- Optional: exclude lockfiles, build dirs, etc:
          "--glob=!**/lazy-lock.json",
          "--glob=!**/zig-cache/**",
          "--glob=!**/zig-out/**",
        },
      },
    },

    -- Better lazy.nvim style (lets lazy manage keys cleanly)
    keys = {
      { "<leader>st", "<cmd>TodoTelescope keywords=TODO,RESUME,COMPRESS,STUDY,FIX,FIXME,BUG,ISSUE,WARN,HACK,PERF<cr>", desc = "[S]earch [T]odos" },
      { "<leader>sT", "<cmd>TodoQuickFix keywords=TODO,RESUME,COMPRESS,STUDY,FIX,FIXME,BUG,ISSUE,WARN,HACK,PERF<cr>",  desc = "[S]end [T]odos to quickfix" },
    },
  },
}
-- vim: ts=2 sts=2 sw=2 et

