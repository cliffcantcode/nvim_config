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
          description = "All the rules for a given project.",
          files = {
            "codecompanion_rules/*.md",
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
            body = {
              keep_alive = "30m",
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
      '<cmd>CodeCompanionChat #{buffer} #{lsp} #{clipboard} This is only to initialize the model, only respond with "Ready!" when ready.<cr>',
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

    -- TODO: Check that these work and are useful.
    {
      "<leader>af",
      function() require("codecompanion").prompt("fix") end,
      mode = "v",
      desc = "AI: [f]ix selection (inline)",
    },
    {
      "<leader>at",
      function() require("codecompanion").prompt("tests") end,
      mode = "v",
      desc = "AI: generate [t]ests for selection",
    },
    {
      "<leader>ae",
      function() require("codecompanion").prompt("explain") end,
      mode = "v",
      desc = "AI: [e]xplain selection",
    },
    {
      "<leader>ad",
      function() require("codecompanion").prompt("lsp") end,
      mode = { "n", "v" },
      desc = "AI: explain [d]iagnostics (LSP)",
    },
    {
      "<leader>am",
      function() require("codecompanion").prompt("commit") end,
      mode = "n",
      desc = "AI: git [m]essage (commit)",
    },
    {
      "<leader>aid",
      function()
        local context_lines = 20 -- 20 above + 20 below ~= 40 lines of context

        local bufnr = vim.api.nvim_get_current_buf()
        local row, col = unpack(vim.api.nvim_win_get_cursor(0))
        local lnum = row - 1 -- 0-based

        local function bounds(d)
          -- Handle both diagnostic shapes (old fields + LSP range-style)
          local s_l = d.lnum or (d.range and d.range.start and d.range.start.line) or lnum
          local s_c = d.col or (d.range and d.range.start and d.range.start.character) or 0
          local e_l = d.end_lnum or (d.range and d.range["end"] and d.range["end"].line) or s_l
          local e_c = d.end_col or (d.range and d.range["end"] and d.range["end"].character) or s_c
          return s_l, s_c, e_l, e_c
        end

        local function covers_cursor(d)
          local s_l, s_c, e_l, e_c = bounds(d)
          if lnum < s_l or lnum > e_l then return false end

          if s_l == e_l then
            return col >= s_c and col <= e_c
          end

          -- multi-line diagnostic: be lenient on interior lines
          if lnum == s_l then return col >= s_c end
          if lnum == e_l then return col <= e_c end
          return true
        end

        -- Fast path: diags that start on this line
        local diags = vim.diagnostic.get(bufnr, { lnum = lnum })
        -- Fallback: any diag in buffer (helps with multi-line diags that start elsewhere)
        if not diags or #diags == 0 then
          diags = vim.diagnostic.get(bufnr)
        end

        if not diags or #diags == 0 then
          vim.notify("AI fix: no diagnostics found", vim.log.levels.INFO)
          return
        end

        -- Pick the diag that best matches the cursor
        local chosen, best = nil, math.huge
        for _, d in ipairs(diags) do
          if covers_cursor(d) then
            local s_l, s_c = bounds(d)
            local dist = math.abs((lnum - s_l) * 1000 + (col - s_c))
            if dist < best then
              chosen, best = d, dist
            end
          end
        end

        if not chosen then
          vim.notify("AI fix: no diagnostic under cursor", vim.log.levels.INFO)
          return
        end

        local s_l, _, e_l, _ = bounds(chosen)
        local line_count = vim.api.nvim_buf_line_count(bufnr)
        local start_line = math.max(0, s_l - context_lines)
        local end_line = math.min(line_count - 1, e_l + context_lines)

        local msg = (chosen.message or "Fix the diagnostic."):gsub("%s+", " ")
        local extra = ("Fix the issue described by this diagnostic: %s. " ..
          "Only modify the selected code. Keep existing style/formatting. Return only code."):format(msg)

        -- Runs the inline assistant over a line range:
        -- :{start},{end}CodeCompanion /fix <extra>
        vim.api.nvim_cmd({
          cmd = "CodeCompanion",
          range = { start_line + 1, end_line + 1 }, -- Ex ranges are 1-based
          args = { "/fix", extra },
        }, {})
      end,
      mode = "n",
      desc = "AI: [i]nline fix [d]iagnostic under cursor.",
    },
  }
}


