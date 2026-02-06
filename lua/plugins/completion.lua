return {
  "hrsh7th/nvim-cmp",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "neovim/nvim-lspconfig",
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-path",
    "L3MON4D3/LuaSnip",
    "saadparwaiz1/cmp_luasnip",
  },
  config = function()
    local present, cmp = pcall(require, "cmp")
    if not present then
      vim.notify("nvim-cmp not available", vim.log.levels.WARN)
      return
    end

    local has_plenary, Job = pcall(require, "plenary.job")
    if not has_plenary then
      vim.notify("plenary not available; AI source disabled", vim.log.levels.WARN)
    end

    -- === Simple async Ollama AI cmp source using plenary.job (curl) ===
    -- Configure your endpoint/model here:
    local OLLAMA_ENDPOINT = "http://localhost:11434"
    local MODEL_NAME = "qwen2.5-coder:1.5b"

    local ai_source = nil
    if has_plenary then
      ai_source = {
        -- source metadata
        new = function()
          return setmetatable({}, { __index = ai_source })
        end,
        -- unique id
        priority = 50,
        register = function() end,
        get_debug_name = function() return "ollama_async" end,

        -- is available: only enable for non-binary buffers
        is_available = function()
          return vim.bo.filetype ~= "gitcommit" -- example; tweak as needed
        end,

        complete = function(self, params, callback)
          -- Collect a small context around the cursor to send as prompt
          local buf = vim.api.nvim_get_current_buf()
          local row, col = unpack(vim.api.nvim_win_get_cursor(0))
          local start_row = math.max(0, row - 6)
          local end_row = math.min(vim.api.nvim_buf_line_count(buf) - 1, row + 2)
          local lines = vim.api.nvim_buf_get_lines(buf, start_row, end_row + 1, false)
          local context_text = table.concat(lines, "\n")

          -- Build a minimal prompt for the model
          local prompt = string.format([[
You are an expert coding assistant. Given the code context, suggest up to 3 short completion candidates for the current cursor location. Return plain completion text (no code fence). Keep suggestions concise.

Context:
%s

Cursor line (1-based): %d
]], context_text, row)

          -- Build request body for Ollama
          local payload = vim.fn.json_encode({
            model = MODEL_NAME,
            prompt = prompt,
            options = {
              -- adjust these for desired behavior
              max_tokens = 128,
              temperature = 0.2,
              n = 1,
            },
          })

          -- Use curl via plenary.job to POST JSON (non-blocking)
          local stdout = {}
          local stderr = {}
          local job = Job:new({
            command = "curl",
            args = {
              "-sS",
              "-X", "POST",
              "-H", "Content-Type: application/json",
              "--data-binary", "@-",
              OLLAMA_ENDPOINT .. "/api/generate"
            },
            writer = { payload },
            on_stdout = function(_, line)
              table.insert(stdout, line)
            end,
            on_stderr = function(_, line)
              table.insert(stderr, line)
            end,
            on_exit = vim.schedule_wrap(function(j, return_val)
              if return_val ~= 0 then
                -- Error; optionally log stderr
                -- Do not block completion; just return nothing
                vim.schedule(function()
                  vim.notify("AI completion request failed: " .. table.concat(stderr, "\n"), vim.log.levels.DEBUG)
                end)
                callback({ items = {}, isIncomplete = false })
                return
              end

              local resp = table.concat(stdout, "\n")
              local ok, decoded = pcall(vim.fn.json_decode, resp)
              if not ok or not decoded then
                callback({ items = {}, isIncomplete = false })
                return
              end

              -- Ollama's response shape may vary by version; try a few fallbacks
              local text_candidates = {}
              if decoded and decoded.text then
                table.insert(text_candidates, decoded.text)
              elseif decoded and decoded.generations and type(decoded.generations) == "table" then
                for _, g in ipairs(decoded.generations) do
                  if g and g.text then table.insert(text_candidates, g.text) end
                end
              elseif decoded and decoded.results and type(decoded.results) == "table" then
                for _, r in ipairs(decoded.results) do
                  if r.output and r.output[1] and r.output[1].content then
                    table.insert(text_candidates, r.output[1].content)
                  end
                end
              end

              -- Fallback: empty
              if #text_candidates == 0 then
                callback({ items = {}, isIncomplete = false })
                return
              end

              -- Build cmp completion items
              local items = {}
              for i, text in ipairs(text_candidates) do
                text = text:gsub("^%s+", ""):gsub("%s+$", "")
                if #text > 0 then
                  table.insert(items, {
                    label = (text:gsub("\n", " ")):sub(1, 80),
                    kind = cmp.lsp.CompletionItemKind.Snippet,
                    documentation = {
                      kind = "markdown",
                      value = "AI suggestion\n\n```\n" .. text .. "\n```",
                    },
                    insertText = text,
                    -- ensure we insert as-is
                    insertTextFormat = 2,
                    -- give ai suggestions a custom sort priority via score (lower => later)
                    sortText = string.format("~%03d", i),
                    data = { source = "ollama" },
                  })
                end
              end

              callback({ items = items, isIncomplete = false })
            end),
          })

          job:start()
        end,
      }
    end

    -- === cmp setup ===
    cmp.setup({
      snippet = {
        expand = function(args)
          require("luasnip").lsp_expand(args.body)
        end,
      },
      mapping = cmp.mapping.preset.insert({
        ["<CR>"] = cmp.mapping.confirm({ select = true }),
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<C-e>"] = cmp.mapping.abort(),
      }),
      sources = cmp.config.sources(
        -- Put AI source near top so it shows up early (adjust priority in source)
        (ai_source and { { name = "ollama_ai", priority = 80 } } or {}),
        {
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "buffer" },
          { name = "path" },
        }
      ),
      experimental = {
        ghost_text = false, -- change if you like experimental ghost text
      },
      formatting = {
        format = function(entry, vim_item)
          -- Show source in completion menu (AI will say "ollama")
          local src = entry.source.name or ""
          vim_item.menu = "[" .. src .. "]"
          return vim_item
        end,
      },
    })

    -- Register the custom source if available
    if ai_source then
      cmp.register_source("ollama_ai", ai_source)
    end

    -- Buffer-local LSP attach mapping: optionally show where the completion came from
    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        -- nothing extra here; LSP still supplies completions normally
      end,
    })
  end,
}

-- return {
--   "hrsh7th/nvim-cmp",
--   dependencies = {
--     "nvim-lua/plenary.nvim",
--     "neovim/nvim-lspconfig",
--     "hrsh7th/cmp-nvim-lsp",
--     "hrsh7th/cmp-buffer",
--     "hrsh7th/cmp-path",
--     "L3MON4D3/LuaSnip",
--   },
--   config = function()
--     local cmp = require("cmp")
--     cmp.setup({
--       snippet = {
--         expand = function(args)
--           require("luasnip").lsp_expand(args.body)
--         end,
--       },
--       mapping = cmp.mapping.preset.insert({
--         ["<CR>"] = cmp.mapping.confirm({ select = true }),
--       }),
--       sources = cmp.config.sources({
--         { name = "nvim_lsp" },
--         { name = "buffer" },
--         { name = "path" },
--       }),
--     })
--   end
-- }
--

