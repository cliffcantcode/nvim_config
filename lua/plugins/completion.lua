return {
  {
    "milanglacier/minuet-ai.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      provider = "openai_fim_compatible",
      provider_options = {
        openai_fim_compatible = {
          model = "qwen2.5-coder:14b",
          end_point = "http://localhost:11434/v1/completions",
          name = "Ollama",
          api_key = "TERM",
          stream = true,
          optional = {
            num_predict = 256,
            temperature = 0.2,
            stop = { "\n\n" },
          },
        },
      },
    }
  },
  {
    "saghen/blink.cmp",
    dependencies = {
      "neovim/nvim-lspconfig",
    },
    opts = {
      keymap = {
        preset = "default",
        ["<CR>"] = { "accept", "fallback" },
        ["<C-g>"] = { function(cmp) cmp.show({ providers = { "minuet" } }) end },
      },

      appearance = {
        use_nvim_cmp_as_default = true,
        nerd_font_variant = 'mono',
      },

      completion = {
        ghost_text = {
          enabled = true,
        },
      },

      sources = {
        default = {
          "lsp",
          "buffer",
          "path",
          "minuet",
        },
        providers = {
          minuet = {
            name = "minuet",
            module = "minuet.blink",
            score_offset = 100,
            async = true,
          },
        },
      },
    },
  },
}

