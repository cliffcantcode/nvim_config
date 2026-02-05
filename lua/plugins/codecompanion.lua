-- TODO: Get autocomplete setup too.
return {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
    require("codecompanion").setup({
      rules = {
        default = {
          description = "Default rules.",
          files = {
            ".codecompanion_rules/default_rules.md",
          },
        },
      },
      display = {
        inline = {
          diff = {
            enabled = true,
          },
        },
        opts = {
          auto_scroll = true,
        },
      },
      strategies = {
        chat = {
          adapter = "ollama",
          model = "qwen2.5-coder:14b",
        },
        inline = {
          adapter = "ollama",
          model = "qwen2.5-coder:14b",
        },
        agent = {
          adapter = "ollama",
          model = "qwen2.5-coder:14b",
        },
      },
      adapters = {
        ollama = function()
          return require("codecompanion.adapters").extend("ollama", {
            env = {
              url = "http://127.0.0.1:11434",
            },
            headers = {
              ["Content-Type"] = "application/json",
            },
            parameters = {
              sync = true,
            },
          })
        end,
      },
    })
  end,
  keys = {
    {
      '<leader>ac',
      '<cmd>CodeCompanionChat #{buffer} #{lsp} #{clipboard} Hello! Be practical and concise. <cr>',
      mode = { "n", "v" },
      desc = 'Open an [a]ssitant [c]hat.',
    },

    -- Send current selection to chat
    {
      '<leader>as',
      function()
        require("codecompanion").chat({ selection = true })
      end,
      mode = "v",  -- Corrected mode from v:visual to v
      desc = 'Open an [a]ssistant with visual [s]election.',
    },

    {
      '<leader>aa',
      '<cmd>CodeCompanionActions<cr>',
      mode = { "n", "v" },
      desc = 'Open [a]ssistant [a]ctions.',
    },

    {
      '<leader>ta',
      '<cmd>CodeCompanionChat Toggle<cr>',
      mode = { "n", "v" },
      desc = '[t]oggle [a]ssistant.',
    },

    {
      '<leader>ah',
      ':CodeCompanion ',
      mode = { "n", "v" },
      desc = 'Inline [a]ssistant [h]ere.',
    },
  }
}


