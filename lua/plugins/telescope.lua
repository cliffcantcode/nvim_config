local function tbuiltin(fn, opts)
  return function()
    require("telescope.builtin")[fn](opts or {})
  end
end

return {
  {
    "nvim-telescope/telescope.nvim",
    event = "VeryLazy",
    cmd = "Telescope",
    -- Lazy.nvim will create these mappings in a way that loads Telescope on demand.
    keys = {
      { "<leader>sf", function()
        local builting = require("telescope.builtin")
        local ok = pcall(builtin.git_files, { show_untracked = true })
        if not ok then builtin.find_files() end
      end, desc = "[S]earch [F]iles" },
      { "<leader>sh", tbuiltin("help_tags"), desc = "[S]earch [H]elp" },
      { "<leader>sk", tbuiltin("keymaps"), desc = "[S]earch [K]eymaps" },
      { "<leader>ss", tbuiltin("builtin"), desc = "[S]earch [S]elect Telescope" },
      { "<leader>sw", tbuiltin("grep_string"), desc = "[S]earch current [w]ord" },
      { "<leader>sg", tbuiltin("live_grep"), desc = "[S]earch by [G]rep" },
      { "<leader>sd", tbuiltin("diagnostics"), desc = "[S]earch [D]iagnostics" },
      { "<leader>sr", tbuiltin("resume"), desc = "[S]earch [R]esume" },
      { "<leader>s.", tbuiltin("oldfiles"), desc = [[ [S]earch Recent Files ("." for repeat) ]] },
      { "<leader><leader>", tbuiltin("buffers"), desc = "[ ] Find existing buffers" },

      {
        "<leader>sp",
        function()
          require("telescope.builtin").grep_string({ search = vim.fn.input("rg > ") })
        end,
        desc = "[S]earch with [p]rompt for grep.",
      },

      {
        "<leader>/",
        function()
          local themes = require("telescope.themes")
          require("telescope.builtin").current_buffer_fuzzy_find(themes.get_dropdown({
            winblend = 10,
            previewer = false,
          }))
        end,
        desc = "[/] Fuzzily search in current buffer",
      },

      {
        "<leader>s/",
        function()
          require("telescope.builtin").live_grep({
            grep_open_files = true,
            prompt_title = "Live Grep in Open Files",
          })
        end,
        desc = "[S]earch [/] in Open Files",
      },

      {
        "<leader>sn",
        function()
          require("telescope.builtin").find_files({ cwd = vim.fn.stdpath("config") })
        end,
        desc = "[S]earch [N]eovim files",
      },
    },

    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        cond = function()
          return vim.fn.executable("make") == 1
        end,
      },
      "nvim-telescope/telescope-ui-select.nvim",
      { "nvim-tree/nvim-web-devicons", enabled = vim.g.have_nerd_font },
    },

    config = function()
      local telescope = require("telescope")
      local actions = require("telescope.actions")
      local themes = require("telescope.themes")

      telescope.setup({
        defaults = {
          path_display = { "smart" },

          file_ignore_patterns = {
            "node_modules/",
            "%.git/",
            "zig%-cache/",
            "zig%-out/",
            "target/",
            "dist/",
            "build/",
            "%.dll$",
            "%.exe$",
            "%.so$",
            "%.a$",
            "%.dylib$",
          },

          mappings = {
            i = {
              ["<c-enter>"] = "to_fuzzy_refine",
              ["<c-j>"] = actions.move_selection_next,
              ["<c-k>"] = actions.move_selection_previous,
              ["<c-l>"] = actions.send_to_qflist + actions.open_qflist,
              ["<Esc>"] = actions.close,
            },
          },
        },

        extensions = {
          fzf = {
            fuzzy = true,
            override_generic_sorter = true,
            override_file_sorter = true,
            case_mode = "smart_case",
          },
          ["ui-select"] = {
            themes.get_dropdown(),
          },
        },
      })

      pcall(telescope.load_extension, "fzf")
      pcall(telescope.load_extension, "ui-select")
    end,
  },
}

-- vim: ts=2 sts=2 sw=2 et

