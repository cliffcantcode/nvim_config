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
    local cmp = require("cmp")
    local Job = require("plenary.job")

    -- Config
    local opts = {
      ollama_cmd = "ollama",
      model = "qwen2.5-coder:1.5b",
      context_lines = 6,
      cache_size = 200,
    }

    -- Simple cache
    local cache = { map = {}, order = {} }
    local function cache_set(k, v)
      if not cache.map[k] then
        table.insert(cache.order, 1, k)
        if #cache.order > opts.cache_size then
          local rem = table.remove(cache.order)
          cache.map[rem] = nil
        end
      end
      cache.map[k] = v
    end
    local function cache_get(k) return cache.map[k] end

    -- Build prompt
    local function build_prompt(ctx, prefix)
      return table.concat({
        "System: Return ONLY code completion. No explanations.",
        "",
        "Context:",
        ctx ~= "" and ctx or "(empty)",
        "",
        "Prefix: " .. prefix,
        "",
        "Return only the code continuation:",
      }, "\n")
    end

    -- Call Ollama
    local function call_ollama(prompt, cb)
      local out = {}
      Job:new({
        command = opts.ollama_cmd,
        args = { "generate", opts.model, prompt, "--format", "json" },
        on_stdout = function(_, line) table.insert(out, line) end,
        on_exit = function()
          local resp = table.concat(out, "\n")
          local ok, dec = pcall(vim.fn.json_decode, resp)
          if ok and dec then
            local text = dec.response or dec.content or ""
            text = text:gsub("^%s+", ""):gsub("%s+$", "")
            text = text:gsub("```[%w]*\n?", ""):gsub("```", "")
            cb(text)
          else
            cb(nil)
          end
        end,
      }):start()
    end

    -- Create custom source
    local llm_source = {}
    llm_source.new = function()
      return setmetatable({}, { __index = llm_source })
    end

    function llm_source:is_available() return true end
    function llm_source:get_debug_name() return "local_llm" end

    function llm_source:complete(request, callback)
      print("LLM COMPLETE CALLED.")
      local ctx = request.context
      local bufnr = ctx.bufnr
      local row = ctx.cursor.row
      local col = ctx.cursor.col

      print(string.format("bufnr=%s, row=%s, col=%s", bufnr, row, col))

      local start_line = math.max(0, row - opts.context_lines - 1)
      local recent_lines = vim.api.nvim_buf_get_lines(bufnr, start_line, row - 1, false)
      local recent = table.concat(recent_lines, "\n")
      local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
      local prefix = line:sub(1, col - 1)

      print(string.format("prefix='%s'", prefix))

      if prefix == "" then
        return callback({ items = {}, isIncomplete = false })
      end

      local cached = cache_get(prefix)
      if cached then
        print("CACHE HIT: " .. cached)
        return callback({
          items = {{ label = cached, insertText = cached }},
          isIncomplete = false
        })
      end

      print("CACHE MISS - CALLING OLLAMA")
      local prompt = build_prompt(recent, prefix)
      print("PROMPT: " .. prompt)

      -- RESUME: Get ollama to start so there is a model for autocomplete.
      call_ollama(prompt, function(text)
        print("OLLAMA CALLBACK - text: " .. (text or "nil"))  -- Add this
        if not text or text == "" then
          print("NO TEXT FROM OLLAMA")  -- Add this
          return callback({ items = {}, isIncomplete = false })
        end
        local single = text:gsub("\n", " ")
        print("RETURNING COMPLETION: " .. single)  -- Add this
        cache_set(prefix, single)
        callback({
          items = {{ label = single, insertText = single }},
          isIncomplete = false
        })
      end)
    end

    -- Register source
    cmp.register_source("local_llm", llm_source.new())

    -- Setup cmp
    cmp.setup({
      performance = {
        max_view_entries = 50,
      },
      snippet = {
        expand = function(args)
          require("luasnip").lsp_expand(args.body)
        end,
      },
      experimental = {
        ghost_text = true,
      },
      mapping = cmp.mapping.preset.insert({
        ["<CR>"] = cmp.mapping.confirm({ select = true }),
        ["<C-n>"] = cmp.mapping.select_next_item(),
        ["<C-p>"] = cmp.mapping.select_prev_item(),
      }),
      sources = {
        { name = "local_llm", keyword_length = 0 },
        { name = "nvim_lsp" },
        { name = "luasnip" },
        { name = "buffer" },
        { name = "path" },
      },
      formatting = {
        format = function(entry, vim_item)
          vim_item.menu = ({
            local_llm = "[AI]",
            nvim_lsp = "[LSP]",
            luasnip = "[Snip]",
            buffer = "[Buf]",
            path = "[Path]",
          })[entry.source.name]
          return vim_item
        end,
      },
    })
  end
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

