-- completion.lua
-- Minimal Ollama-powered ghost-text for nvim-cmp
-- Simple: auto-setup on require, returns table { setup = fn, toggle = fn }

local M = {}

local ok_cmp, cmp = pcall(require, "cmp")
if not ok_cmp then
  vim.notify("nvim-cmp not available: completion.lua disabled", vim.log.levels.WARN)
  return { setup = function() end, toggle = function() end }
end

local ok_job, Job = pcall(require, "plenary.job")
if not ok_job then
  vim.notify("plenary.job not available: completion.lua disabled", vim.log.levels.WARN)
  return { setup = function() end, toggle = function() end }
end

-- Defaults
local defaults = {
  ollama_cmd = "ollama",
  model = "qwen2.5-coder:1.5b",
  max_tokens = 24,
  temperature = 0.0,
  context_lines = 6,
  system_prefix = "System: Be concise. Return ONLY the completion snippet. No explanations.",
  prompt_suffix = "Return only the code continuation (no explanation).",
}

-- tiny LRU-ish cache (map with simple size limit)
local function new_cache(size)
  local t = { map = {}, order = {}, size = size or 200 }
  local function set(k, v)
    if t.map[k] == nil then
      table.insert(t.order, 1, k)
      if #t.order > t.size then
        local rem = table.remove(t.order)
        t.map[rem] = nil
      end
    end
    t.map[k] = v
  end
  local function get(k) return t.map[k] end
  return { set = set, get = get }
end

local function build_prompt(opts, ctx, prefix)
  return table.concat({
    opts.system_prefix,
    "",
    "Context:",
    (ctx ~= "" and ctx) or "(empty)",
    "",
    ("Prefix: %s"):format(prefix),
    "",
    opts.prompt_suffix,
  }, "\n")
end

-- call ollama generate <model> "<prompt>" --format json
local function call_ollama(opts, prompt, cb)
  -- Use plenary job; pass prompt as a single arg so we avoid shell quoting issues
  local args = { "generate", opts.model, prompt, "--format", "json" }
  local out = {}
  local err = {}
  local j = Job:new({
    command = opts.ollama_cmd,
    args = args,
    on_stdout = function(_, line) if line then table.insert(out, line) end end,
    on_stderr = function(_, line) if line then table.insert(err, line) end end,
  })
  j:after(function()
    if #err > 0 then return cb(nil, table.concat(err, "\n")) end
    local resp = table.concat(out, "\n")
    local ok, dec = pcall(vim.fn.json_decode, resp)
    if not ok or not dec then
      -- fallback: return raw text if parse fails
      if resp and resp ~= "" then return cb(resp, nil) end
      return cb(nil, "ollama parse error: " .. resp)
    end
    local text = dec["generated_text"] or dec["content"] or dec["text"] or dec["result"] or ""
    text = tostring(text):gsub("^%s+", ""):gsub("%s+$", "")
    text = text:gsub("^%s*```[%w_-]*\n?", ""):gsub("```%s*$", "")
    cb(text, nil)
  end)
  j:start()
end

-- create source factory
local function make_source(opts, cache)
  local S = {}
  S.new = function() return setmetatable({}, { __index = S }) end

  function S:is_available() return true end
  function S:get_debug_name() return "local_llm" end

  function S:complete(request, callback)
    local ctx = request.context
    local bufnr = ctx.buffer:bufnr()
    local row = ctx.cursor.row
    local col = ctx.cursor.col
    if not row or not col then return callback({ items = {}, isIncomplete = false }) end

    local start_line = math.max(0, row - opts.context_lines - 1)
    local recent_lines = vim.api.nvim_buf_get_lines(bufnr, start_line, row - 1, false) or {}
    local recent = table.concat(recent_lines, "\n")
    local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
    local prefix = line:sub(1, math.max(0, col - 1))
    if prefix == "" then return callback({ items = {}, isIncomplete = false }) end

    local cached = cache:get(prefix)
    if cached then
      return callback({ items = { { label = cached, insertText = cached, documentation = { kind = "plaintext", value = "Cached" }, sortText = "0000" } }, isIncomplete = false })
    end

    local prompt = build_prompt(opts, recent, prefix)
    call_ollama(opts, prompt, function(text, err)
      if err or not text or text == "" then return callback({ items = {}, isIncomplete = false }) end
      local single = text:gsub("\r", ""):gsub("\n", " ")
      cache:set(prefix, single)
      local item = { label = single, insertText = single, documentation = { kind = "plaintext", value = "Ollama" }, sortText = "0000" }
      callback({ items = { item }, isIncomplete = false })
    end)
  end

  return S
end

-- main setup (callable)
function M.setup(user_opts)
  local opts = vim.tbl_deep_extend("force", defaults, user_opts or {})
  local cache = new_cache( (opts.cache_size or 200) )

  -- register source
  local src = make_source(opts, cache)
  pcall(function() cmp.register_source("local_llm", src.new()) end)

  -- minimal cmp config: enable ghost_text and ensure local_llm is first
  local base = {
    experimental = { ghost_text = true },
    mapping = cmp.mapping.preset.insert({ ["<CR>"] = cmp.mapping.confirm({ select = true }) }),
    sources = {
      { name = "local_llm" },
      { name = "nvim_lsp" },
      { name = "buffer" },
      { name = "path" },
    },
    formatting = {
      format = function(entry, vim_item)
        if entry.source.name == "local_llm" then vim_item.menu = "[OLLAMA]" end
        return vim_item
      end,
    },
  }

  -- merge with existing config if present (non-destructive)
  local ok, existing = pcall(function() return cmp.get_config() end)
  if ok and existing and type(existing) == "table" and next(existing or {}) ~= nil then
    existing.experimental = existing.experimental or {}
    existing.experimental.ghost_text = true
    existing.formatting = existing.formatting or base.formatting
    existing.mapping = existing.mapping or {}
    for k, v in pairs(base.mapping or {}) do if existing.mapping[k] == nil then existing.mapping[k] = v end end
    -- ensure local_llm first
    existing.sources = existing.sources or {}
    local found = false
    for _, s in ipairs(existing.sources) do if s.name == "local_llm" then found = true break end end
    if not found then table.insert(existing.sources, 1, { name = "local_llm" }) end
    pcall(function() cmp.setup(existing) end)
  else
    pcall(function() cmp.setup(base) end)
  end

  vim.notify("completion.lua: local Ollama source registered (model=" .. opts.model .. ")", vim.log.levels.INFO)
end

-- simple toggle (advisory)
local enabled = true
function M.toggle()
  enabled = not enabled
  vim.notify("Local LLM completion " .. (enabled and "enabled" or "disabled"), vim.log.levels.INFO)
end

-- auto-run setup on require with defaults (satisfies your plugin loading flow)
M.setup()

-- return the module table (so require returns { setup = fn, toggle = fn })
return M
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

