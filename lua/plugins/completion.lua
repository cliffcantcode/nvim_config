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
    local cmp_ok, cmp = pcall(require, "cmp")
    if not cmp_ok then
      vim.notify("nvim-cmp not available", vim.log.levels.WARN)
      return
    end

    local luasnip_ok, luasnip = pcall(require, "luasnip")
    if not luasnip_ok then luasnip = nil end

    -- Ollama configuration (override via globals before require)
    local endpoint    = vim.g.ollama_endpoint or "http://localhost:11434"
    local model       = vim.g.ollama_model or "qwen2.5-coder:1.5b"
    local max_tokens  = vim.g.ollama_max_tokens or 256
    local temperature = vim.g.ollama_temperature or 0.1
    local ctx_lines   = vim.g.ollama_context_lines or 40

    local function decode_json_safe(s)
      if not s or s == "" then return nil end
      local ok, decoded = pcall(vim.fn.json_decode, s)
      if ok and decoded then return decoded end
      return nil
    end

    local function extract_text_from_ollama_resp(body)
      local dec = decode_json_safe(body)
      if not dec then return vim.trim(body) end

      if type(dec) == "table" then
        if dec.content and type(dec.content) == "string" then return vim.trim(dec.content) end
        if dec.result and type(dec.result) == "table" and #dec.result > 0 then
          local first = dec.result[1]
          if first and type(first.content) == "string" then return vim.trim(first.content) end
        end
        if dec.text and type(dec.text) == "string" then return vim.trim(dec.text) end
        if dec.message and dec.message.content then return vim.trim(dec.message.content) end
      end

      return vim.trim(vim.fn.json_encode(dec))
    end

    local function build_prompt(context_text, ft)
      local preamble = string.format(
        "You are a code-completion assistant. Filetype: %s\n\nContext:\n%s\n\nRespond with the most likely continuation/completion. Return only code (no explanation).",
        ft or "unknown",
        context_text
      )
      return preamble
    end

    local function ask_ollama(prompt)
      local payload = {
        model = model,
        prompt = prompt,
        max_tokens = max_tokens,
        temperature = temperature,
        stream = false,
      }

      local payload_json = vim.fn.json_encode(payload)

      local cmd = {
        "curl", "-sS", "-X", "POST",
        endpoint .. "/api/generate",
        "-H", "Content-Type: application/json",
        "-d", payload_json,
      }

      local ok, res = pcall(vim.fn.system, cmd)
      if not ok then
        return nil, "curl failed"
      end
      if vim.v.shell_error ~= 0 then
        return nil, res
      end

      local text = extract_text_from_ollama_resp(res)
      return text, nil
    end

    -- --- Ollama cmp source -------------------------------------------------
    local source = {}
    source.new = function() return setmetatable({}, { __index = source }) end
    source.is_available = function() return true end
    source.get_debug_name = function() return "ollama" end
    source.get_keyword_pattern = function() return [[\k\+]] end

    source.complete = function(self, params, callback)
      -- Assemble context: lines around cursor
      local bufnr = vim.api.nvim_get_current_buf()
      local row = params.context.cursor.row - 1
      local total = vim.api.nvim_buf_line_count(bufnr)
      local start_line = math.max(0, row - ctx_lines)
      local end_line = math.min(total - 1, row + ctx_lines)

      local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line + 1, false)
      local context_text = table.concat(lines, "\n")
      local prompt = build_prompt(context_text, vim.bo.filetype)

      -- Synchronous call (simple, blocks briefly)
      local text, err = ask_ollama(prompt)
      if not text then
        vim.schedule(function()
          vim.notify("[ollama] request failed: " .. tostring(err), vim.log.levels.DEBUG)
        end)
        callback({})
        return
      end

      local item = {
        label = (text:gsub("\n", " ")):sub(1, 80),
        kind = cmp.lsp.CompletionItemKind.Snippet or 15,
        documentation = {
          kind = "markdown",
          value = "```text\n" .. text .. "\n```",
        },
        insertText = text,
      }

      callback({ item })
    end

    source.resolve = function(self, item, callback) callback(item) end
    source.execute = function(self, item, callback) callback(item) end

    pcall(function() cmp.register_source("ollama", source.new()) end)

    -- --- cmp setup ---------------------------------------------------------
    local mapping = cmp.mapping.preset.insert({
      ["<CR>"] = cmp.mapping.confirm({ select = true }),
      ["<Tab>"] = cmp.mapping(function(fallback)
        if cmp.visible() then cmp.select_next_item() elseif luasnip and luasnip.expand_or_jumpable() then luasnip.expand_or_jump() else fallback() end
      end, { "i", "s" }),
      ["<S-Tab>"] = cmp.mapping(function(fallback)
        if cmp.visible() then cmp.select_prev_item() elseif luasnip and luasnip.jumpable(-1) then luasnip.jump(-1) else fallback() end
      end, { "i", "s" }),
    })

    cmp.setup({
      snippet = {
        expand = function(args)
          if luasnip then luasnip.lsp_expand(args.body) end
        end,
      },
      mapping = mapping,
      sources = cmp.config.sources({
        { name = "nvim_lsp" },
        { name = "luasnip" },
        { name = "buffer" },
        { name = "path" },
        -- Ollama source is included so AI suggestions appear alongside other sources.
        { name = "ollama" },
      }),
    })

    -- Buffer/local setups for cmdline (optional)
    cmp.setup.cmdline("/", {
      mapping = cmp.mapping.preset.cmdline(),
      sources = { { name = "buffer" } },
    })
    cmp.setup.cmdline(":", {
      mapping = cmp.mapping.preset.cmdline(),
      sources = cmp.config.sources({ { name = "path" } }, { { name = "cmdline" } }),
    })

    -- Convenience keymap: explicit Ollama-only completion (insert mode)
    vim.keymap.set("i", "<C-Space>", function()
      cmp.complete({ config = { sources = { { name = "ollama" } } } })
    end, { noremap = true, silent = true, desc = "Ollama completion" })

    -- Optional: a normal-mode insertion helper
    vim.keymap.set("n", "<leader>ai", function()
      local bufnr = vim.api.nvim_get_current_buf()
      local row = vim.api.nvim_win_get_cursor(0)[1]
      local start_line = math.max(0, row - ctx_lines)
      local end_line = math.min(vim.api.nvim_buf_line_count(bufnr) - 1, row + ctx_lines)
      local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line + 1, false)
      local prompt = build_prompt(table.concat(lines, "\n"), vim.bo.filetype)
      local text, err = ask_ollama(prompt)
      if not text then
        vim.notify("[ollama] error: " .. tostring(err), vim.log.levels.ERROR)
        return
      end
      -- Insert at cursor
      vim.api.nvim_put(vim.split(text, "\n", { trimempty = false }), "c", true, true)
    end, { desc = "Insert Ollama completion" })
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

