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

-- Results from the AI <leader>ai:
{"eval_count": 99, "context": [151644, 8948, 198, 2610, 525, 1207, 16948, 11, 3465, 553, 54364, 14817, 13, 1446, 525, 264, 10950, 17847, 13, 151645, 198, 151644, 872, 198, 2610, 525, 264, 2038, 11476, 14386, 17847, 13, 2887, 1313, 25, 20357, 271, 1972, 510, 286, 314, 829, 284, 330, 965, 3029, 1, 1153, 414, 11973, 262, 9568, 262, 1177, 10312, 22270, 83723, 369, 94106, 320, 12807, 340, 262, 26089, 25338, 25724, 1056, 35460, 341, 414, 12731, 284, 26089, 56748, 556, 9716, 25724, 1056, 3148, 414, 8173, 284, 314, 314, 829, 284, 330, 7573, 1, 335, 1153, 262, 2751, 262, 26089, 25338, 25724, 1056, 445, 12147, 341, 414, 12731, 284, 26089, 56748, 556, 9716, 25724, 1056, 3148, 414, 8173, 284, 26089, 5423, 81837, 2306, 314, 829, 284, 330, 2343, 1, 335, 2470, 314, 314, 829, 284, 330, 8710, 1056, 1, 335, 11973, 262, 9568, 262, 1177, 80648, 1376, 2186, 25, 11464, 506, 654, 3029, 15382, 9755, 320, 4208, 3856, 340, 262, 36157, 4735, 2186, 980, 445, 72, 497, 4055, 34, 6222, 1306, 21156, 729, 741, 414, 26089, 42928, 2306, 2193, 284, 314, 8173, 284, 314, 314, 829, 284, 330, 965, 3029, 1, 335, 335, 335, 2751, 262, 835, 11, 314, 308, 460, 2186, 284, 830, 11, 21059, 284, 830, 11, 6560, 284, 330, 46, 654, 3029, 9755, 1, 9568, 262, 1177, 12256, 25, 264, 4622, 14982, 35927, 13137, 198, 262, 36157, 4735, 2186, 980, 445, 77, 497, 4055, 37391, 29, 2143, 497, 729, 741, 414, 2205, 6607, 19618, 284, 36157, 6183, 1253, 41194, 3062, 11080, 10363, 741, 414, 2205, 2802, 284, 36157, 6183, 1253, 41194, 25672, 3062, 28601, 7, 15, 6620, 16, 921, 414, 2205, 1191, 6528, 284, 6888, 6678, 7, 15, 11, 2802, 481, 5635, 18323, 340, 414, 2205, 835, 6528, 284, 6888, 4358, 3747, 318, 6183, 1253, 41194, 10363, 6528, 3180, 10731, 19618, 8, 481, 220, 16, 11, 2802, 488, 5635, 18323, 340, 414, 2205, 5128, 284, 36157, 6183, 1253, 41194, 10363, 3062, 18323, 10731, 19618, 11, 1191, 6528, 11, 835, 6528, 488, 220, 16, 11, 895, 340, 414, 2205, 9934, 284, 1936, 61421, 15761, 15256, 33152, 11, 2917, 77, 3975, 36157, 61962, 9715, 1313, 340, 414, 2205, 1467, 11, 1848, 284, 2548, 62, 965, 3029, 72253, 340, 414, 421, 537, 1467, 1221, 198, 286, 36157, 24681, 10937, 965, 3029, 60, 1465, 25, 330, 5241, 70890, 3964, 701, 36157, 1665, 97757, 27858, 340, 286, 470, 198, 414, 835, 198, 414, 1177, 17101, 518, 8128, 198, 414, 36157, 6183, 1253, 41194, 15557, 3747, 318, 5289, 7235, 11, 2917, 77, 497, 314, 11013, 3194, 284, 895, 31706, 330, 66, 497, 830, 11, 830, 340, 262, 835, 11, 314, 6560, 284, 330, 13780, 506, 654, 3029, 9755, 1, 2751, 220, 835, 345, 630, 313, 18099, 504, 279, 15235, 366, 37391, 29, 2143, 24391, 313, 470, 341, 313, 256, 330, 4079, 927, 22, 339, 9612, 41194, 1786, 1307, 756, 313, 256, 19543, 284, 341, 313, 257, 330, 36941, 318, 2852, 4284, 11255, 46128, 1253, 41194, 756, 313, 257, 330, 811, 859, 318, 9612, 41194, 2852, 2154, 1676, 756, 313, 257, 330, 4079, 927, 22, 339, 2899, 1307, 5279, 41194, 2852, 2154, 756, 313, 257, 330, 4079, 927, 22, 339, 2899, 1307, 31351, 756, 313, 257, 330, 4079, 927, 22, 339, 2899, 1307, 33095, 756, 313, 257, 330, 43, 18, 21344, 19, 35, 18, 7434, 4284, 20720, 573, 756, 313, 256, 1153, 313, 256, 2193, 284, 729, 741, 313, 257, 2205, 26089, 284, 1373, 445, 7293, 1138, 313, 257, 26089, 25338, 2262, 313, 981, 43065, 284, 341, 313, 260, 9225, 284, 729, 7356, 340, 313, 1843, 1373, 445, 9835, 65536, 573, 1827, 75, 2154, 67875, 7356, 5079, 340, 313, 260, 835, 345, 313, 981, 1153, 313, 981, 12731, 284, 26089, 56748, 556, 9716, 7030, 2262, 313, 260, 4383, 27, 8973, 29, 1341, 284, 26089, 56748, 33405, 2306, 3293, 284, 830, 11973, 313, 981, 11973, 313, 981, 8173, 284, 26089, 5423, 81837, 2262, 313, 260, 314, 829, 284, 330, 36941, 318, 907, 2154, 1, 1153, 313, 260, 314, 829, 284, 330, 7573, 1, 1153, 313, 260, 314, 829, 284, 330, 2343, 1, 1153, 313, 981, 11973, 313, 257, 2751, 313, 256, 835, 198, 313, 456, 313, 1406, 65354, 448, 279, 1429, 4363, 41171, 25093, 14386, 13, 3411, 1172, 2038, 320, 2152, 16148, 568, 151645, 198, 151644, 77091, 198, 73594, 27623, 198, 7293, 25338, 2262, 220, 43065, 284, 341, 262, 9225, 284, 729, 7356, 340, 414, 1373, 445, 9835, 65536, 573, 1827, 75, 2154, 67875, 7356, 5079, 340, 262, 835, 345, 220, 1153, 220, 12731, 284, 26089, 56748, 556, 9716, 7030, 2262, 262, 4383, 27, 8973, 29, 1341, 284, 26089, 56748, 33405, 2306, 3293, 284, 830, 11973, 220, 11973, 220, 8173, 284, 26089, 5423, 81837, 2262, 262, 314, 829, 284, 330, 36941, 318, 907, 2154, 1, 1153, 262, 314, 829, 284, 330, 7573, 1, 1153, 262, 314, 829, 284, 330, 2343, 1, 1153, 220, 11973, 3518, 73594], "load_duration": 125137917, "total_duration": 2102610458, "done": true, "eval_duration": 1292864420, "created_at": "2026-02-06T17:35:50.488751Z", "model": "qwen2.5-coder:1.5b", "prompt_eval_duration": 643763125, "response": "```lua\ncmp.setup({\n  snippet = {\n    expand = function(args)\n      require(\"luasnip\").lsp_expand(args.body)\n    end,\n  },\n  mapping = cmp.mapping.preset.insert({\n    [\"<CR>\"] = cmp.mapping.confirm({ select = true }),\n  }),\n  sources = cmp.config.sources({\n    { name = \"nvim_lsp\" },\n    { name = \"buffer\" },\n    { name = \"path\" },\n  }),\n})\n```", "prompt_eval_count": 708, "done_reason": "stop"}

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

