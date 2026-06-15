-- Highlight todo, notes, etc in comments
local TODO_KEYWORDS = "TODO,RESUME,COMPRESS,STUDY,FIX,FIXME,BUG,ISSUE,WARN,HACK,PERF"

local function current_file_dir()
  local filename = vim.api.nvim_buf_get_name(0)
  if filename == "" then return vim.fn.getcwd() end
  return vim.fn.fnamemodify(filename, ":p:h")
end

local function todo_search_root()
  local bufnr = 0

  local project_root = vim.fs.root(bufnr, {
    "build.zig",
    "build.zig.zon",
    "Package.swift",
    "Cargo.toml",
    "pyproject.toml",
    "package.json",
    "go.mod",
  })
  if project_root then return project_root end

  return vim.fs.root(bufnr, { ".git" }) or current_file_dir()
end

local function todo_telescope()
  local telescope = require("telescope")
  pcall(telescope.load_extension, "todo-comments")
  telescope.extensions["todo-comments"].todo({
    cwd = todo_search_root(),
    keywords = TODO_KEYWORDS,
  })
end

local function todo_quickfix()
  require("todo-comments.search").setqflist({
    cwd = todo_search_root(),
    keywords = TODO_KEYWORDS,
  })
end

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
      { "<leader>st", todo_telescope, desc = "[S]earch [T]odos" },
      { "<leader>sT", todo_quickfix, desc = "[S]end [T]odos to quickfix" },
    },
  },
}
-- vim: ts=2 sts=2 sw=2 et

