return {
  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    event = { "BufReadPost", "BufNewFile" },
    build = ':TSUpdate',
    dependencies = { "nvim-treesitter/nvim-treesitter-textobjects" },
    main = 'nvim-treesitter.configs', -- Sets main module to use for opts
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
    opts = {
      ensure_installed = { 'zig', 'bash', 'c', 'cpp', 'python', 'diff', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc' },
      -- Autoinstall languages that are not installed
      auto_install = false,
      matchup = { enabled = true },
      highlight = {
        enable = true,
        disable = { 'swift' },
        disable = function(lang, buf)
          if lang == "swift" then return true end

          local max_filesize = 5000
          local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
          if ok and stats and stats.size > max_filesize * 1024 then
            return true
          end

          if vim.api.nvim_buf_line_count(buf) > max_filesize then
            return true
          end
        end,
      },
      indent = { enable = true, disable = { 'sql', 'swift' } },
      textobjects = {
        select = {
          enable = true,
          lookahead = true, -- allows 'vaf' even if cursor is before the function
          keymaps = {
            ["af"] = "@function.outer",
            ["if"] = "@function.inner",
          },
        },

        move = { enable = false },
        swap = { enable = false },
        lsp_interop = { enable = false },

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

