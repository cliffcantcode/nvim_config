local M = {}

vim.g.switch_custom_definitions = vim.g.switch_custom_definitions or {
  { "0", "1" },
  { "true", "false" },
  { "True", "False" },
  { "TRUE", "FALSE" },
  { "RESUME", "TODO" },
  { "*", "&" },
  { "Hight", "Width" },
  { "hight", "width" },
  { "Min", "Max" },
  { "min", "max" },
  { "<=", ">=" },
  { "<", ">" },
  { "+", "-" },
  { "!=", "==" },
  { "X", "Y", "Z" },
  { "x", "y", "z" },
  { "New", "Old" },
  { ":", ";" },
  { "upper", "lower" },
  { "High", "Low" },
  { "high", "low" },
  { "RIGHT", "LEFT" },
  { "Right", "Left" },
  { "right", "left" },
  { "permanent", "transient" },
  { "kibi", "mebi", "gibi", "tibi" },
  { "kilo", "mega", "giga", "tera" },
  { "UP", "DOWN" },
  { "Up", "Down" },
  { "up", "down" },
  { "Old", "New" },
  { "old", "new" },
  { "next", "prev" },
  { "in", "out" },
  { "A", "B", "C" },
  { "R,",  "G,",  "B,",  "A," },
  { "R =", "G =", "B =", "A =" },
  { "u8", "i8" },
  { "u16", "i16" },
  { "u32", "i32", "f32" },
  { "u64", "i64", "f64" },
  { "on", "off" },
  { "'", '"' },
  { "initial", "desired", "current" },
  { "get", "set" },
  { "north", "south" },
  { "east", "west" },
  { "North", "South" },
  { "East", "West" },
  { "NORTH", "SOUTH" },
  { "EAST", "WEST" },
  { "pushed", "raised" },
  { "pitch", "yaw", "roll" },
}

local ft_defaults = {
  zig = { { "var", "const" },
          { "init", "deinit" }, },
  cpp = { { ".", "->" },
          { "struct", "enum" }, },
  sql = { { "where", "and" },
          { "inner", "left", "right"},
          { "group", "order"}, },
  swift = { { "let", "var" },
            { "insert", "remove" }, },
}

local buf_state = setmetatable({}, { __mode = "k" })

local function try_cycle_zig_enum(bufnr, row, l, r, word)
  if vim.bo[bufnr].filetype ~= "zig" then return false end

  -- Find last '.' so it works for both `.tag` and `EnumType.tag`
  local dot_index = word:match(".*()%.")
  if not dot_index or dot_index >= #word then return false end

  local tag = word:sub(dot_index + 1)
  if not tag:match("^[A-Za-z_][A-Za-z0-9_]*$") then return false end

  -- Pick an encoding from the attached completion-capable client (zls)
  local clients = {}
  if vim.lsp.get_clients then
    clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/completion" })
  else
    clients = vim.lsp.get_active_clients({ bufnr = bufnr }) or {}
  end
  if not clients or #clients == 0 then return false end

  local encoding = "utf-16"
  for _, c in ipairs(clients) do
    if c.name == "zls" and c.offset_encoding then
      encoding = c.offset_encoding
      break
    end
  end
  if encoding == "utf-16" then
    for _, c in ipairs(clients) do
      if c.offset_encoding then
        encoding = c.offset_encoding
        break
      end
    end
  end

  local line_text = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""

  local function byte_to_lsp_char(bytecol0)
    if vim.lsp.util._str_utfindex_enc then
      return vim.lsp.util._str_utfindex_enc(line_text, bytecol0, encoding)
    end
    if encoding == "utf-16" and vim.lsp.util._str_utfindex then
      return vim.lsp.util._str_utfindex(line_text, bytecol0)
    end
    return bytecol0 -- ASCII-safe fallback
  end

  local function request_completion(bytecol0, triggered_by_dot)
    -- Neovim 0.11+ wants position_encoding here
    local params = vim.lsp.util.make_position_params(0, encoding)
    params.textDocument = { uri = vim.uri_from_bufnr(bufnr) }
    params.position = {
      line = row - 1,
      character = byte_to_lsp_char(bytecol0),
    }
    if triggered_by_dot then
      params.context = { triggerKind = 2, triggerCharacter = "." }
    else
      params.context = { triggerKind = 1 }
    end
    return vim.lsp.buf_request_sync(bufnr, "textDocument/completion", params, 800)
  end

  local EnumMemberKind = vim.lsp.protocol
    and vim.lsp.protocol.CompletionItemKind
    and vim.lsp.protocol.CompletionItemKind.EnumMember

  local function extract_ident(raw)
    if type(raw) ~= "string" then return nil end
    raw = raw:gsub("^%s+", ""):gsub("%s+$", "")
    raw = raw:gsub("%s.*$", "")               -- cut snippet tail (e.g. "=> {")
    raw = raw:gsub("[^A-Za-z0-9_\\.].*$", "") -- cut weird punctuation (keep dots)
    raw = raw:gsub("^%.+", "")                -- strip leading dots
    return raw:match("([A-Za-z_][A-Za-z0-9_]*)$") -- last identifier
  end

  local function collect_candidates(responses)
    local candidates, seen = {}, {}
    for _, resp in pairs(responses or {}) do
      local result = resp and resp.result or nil
      local items = result and (result.items or result) or nil
      if type(items) == "table" then
        for _, item in ipairs(items) do
          local raw =
            item.label
            or item.filterText
            or item.insertText
            or (item.textEdit and item.textEdit.newText)

          local ok_candidate = false
          if type(raw) == "string" and raw:match("^%.") then ok_candidate = true end
          if EnumMemberKind and item.kind == EnumMemberKind then ok_candidate = true end

          if ok_candidate then
            local ident = extract_ident(raw)
            if ident and not seen[ident] then
              seen[ident] = true
              table.insert(candidates, ident)
            end
          end
        end
      end
    end
    return candidates
  end

  local start_byte0 = l - 1
  local after_dot_byte0 = start_byte0 + dot_index  -- position after '.'
  local end_byte0 = r                              -- r is already end-exclusive in 0-based
  local cursor_byte0 = vim.api.nvim_win_get_cursor(0)[2]

  local attempts = {
    { after_dot_byte0, true },  -- best chance to get full enum-tag list
    { end_byte0, false },
    { cursor_byte0, false },
  }

  local candidates
  for _, a in ipairs(attempts) do
    candidates = collect_candidates(request_completion(a[1], a[2]))
    if #candidates >= 2 then
      local has = false
      for _, v in ipairs(candidates) do
        if v == tag or v:lower() == tag:lower() then
          has = true
          break
        end
      end
      if has then break end
    end
  end

  if not candidates or #candidates < 2 then return false end

  local idx
  for i, v in ipairs(candidates) do
    if v == tag or v:lower() == tag:lower() then
      idx = i
      break
    end
  end
  if not idx then return false end

  local next_idx = (idx % #candidates) + 1
  local prefix = word:sub(1, dot_index) -- keeps '.' or 'EnumType.'
  local new_word = prefix .. candidates[next_idx]

  vim.api.nvim_buf_set_text(bufnr, row - 1, l - 1, row - 1, r, { new_word })
  return true
end


local function build_index(defs)
  local idx = {}
  local keys = {}
  local seen = {}

  for _, cycle in ipairs(defs) do
    local clean = {}
    for i = 1, #cycle do clean[i] = tostring(cycle[i]) end
    for i = 1, #clean do
      local k = clean[i]
      idx[k] = { list = clean, pos = i }

      if not seen[k] then
        seen[k] = true
        table.insert(keys, k)
      end
    end
  end

  local keys_sorted = vim.deepcopy(keys)
  table.sort(keys_sorted, function(a, b)
    if #a ~= #b then return #a > #b end
    return a < b
  end)

  return idx, keys_sorted
end

local function get_defs_for_buf(bufnr)
  local bdefs = vim.b[bufnr].switch_definitions
  if bdefs and type(bdefs) == "table" then return bdefs end

  local ft = vim.bo[bufnr].filetype
  local merged = {}

  if vim.g.switch_custom_definitions then
    for _, c in ipairs(vim.g.switch_custom_definitions) do table.insert(merged, c) end
  end

  if ft and ft_defaults[ft] then
    for _, c in ipairs(ft_defaults[ft]) do table.insert(merged, c) end
  end

  return merged
end

local function ensure_buf_index(bufnr)
  local st = buf_state[bufnr]
  local defs = get_defs_for_buf(bufnr)

  local function same_defs(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then return false end
    for i = 1, #a do
      local ai, bi = a[i], b[i]
      if type(ai) ~= "table" or type(bi) ~= "table" or #ai ~= #bi then return false end
      for j = 1, #ai do if tostring(ai[j]) ~= tostring(bi[j]) then return false end end
    end
    return true
  end

  if not st or not same_defs(st.defs, defs) then
    local index, keys_sorted = build_index(defs)
    buf_state[bufnr] = {
      defs = defs,
      index = index,
      keys_sorted = keys_sorted,
    }
  end

  return buf_state[bufnr]
end

local function current_word_bounds(line, col)
  local s = vim.api.nvim_get_current_line()
  if #s == 0 then return nil end

  local i = col + 1
  if i < 1 then i = 1 end
  if i > #s then i = #s end

  -- Helper: treat non-space, non-bracket characters as part of a token
  local function is_token_char(c)
    return c and not c:match("[%s(){}%[%],;]")
  end

  -- Detect if inside quotes
  local quote_char = nil
  for _, q in ipairs({ '"', "'", "`" }) do
    local before = s:sub(1, i - 1)
    local count = select(2, before:gsub(q, ""))
    if count % 2 == 1 then
      quote_char = q
      break
    end
  end

  if quote_char then
    -- Inside quotes: return inside bounds
    local left = s:sub(1, i):find(quote_char .. "[^" .. quote_char .. "]*$")
    local right = s:find(quote_char, i + 1)
    if left and right then
      return left + 1, right - 1
    end
  end

  -- If on punctuation (like '.', '->', '==', etc.), capture operator token
  local c = s:sub(i, i)
  local prev = (i > 1) and s:sub(i - 1, i - 1) or ""
  local nextc = (i < #s) and s:sub(i + 1, i + 1) or ""
  local dot_is_member_access = (c == "." and (prev:match("[%w_]") or nextc:match("[%w_]")))

  if c:match("[%p]") and not c:match("[\"'%s]") and not dot_is_member_access then
    -- Special-case '.' when it's adjacent to an identifier, so `.none` / `Enum.tag`
    -- are treated as a single token instead of just '.'
    if c == "." then
      local prev = (i > 1) and s:sub(i - 1, i - 1) or ""
      local nextc = (i < #s) and s:sub(i + 1, i + 1) or ""
      if prev:match("[%w_]") or nextc:match("[%w_]") then
        -- fall through to "Normal alphanumeric tokens"
      else
        local left, right = i, i
        while left > 1
          and s:sub(left - 1, left - 1):match("[%p]")
          and not s:sub(left - 1, left - 1):match("[\"'%s]") do
          left = left - 1
        end
        while right < #s
          and s:sub(right + 1, right + 1):match("[%p]")
          and not s:sub(right + 1, right + 1):match("[\"'%s]") do
          right = right + 1
        end
        return left, right
      end
    else
      local left, right = i, i
      while left > 1
        and s:sub(left - 1, left - 1):match("[%p]")
        and not s:sub(left - 1, left - 1):match("[\"'%s]") do
        left = left - 1
      end
      while right < #s
        and s:sub(right + 1, right + 1):match("[%p]")
        and not s:sub(right + 1, right + 1):match("[\"'%s]") do
        right = right + 1
      end
      return left, right
    end
  end

  -- Normal alphanumeric tokens
  if not is_token_char(s:sub(i, i)) then
    if i < #s and is_token_char(s:sub(i + 1, i + 1)) then
      i = i + 1
    elseif i > 1 and is_token_char(s:sub(i - 1, i - 1)) then
      i = i - 1
    else
      return nil
    end
  end

  local left, right = i, i
  while left > 1 and is_token_char(s:sub(left - 1, left - 1)) do left = left - 1 end
  while right < #s and is_token_char(s:sub(right + 1, right + 1)) do right = right + 1 end

  return left, right
end

local function switch_text(bufnr, row, start_col, end_col, text)
  local st = ensure_buf_index(bufnr)
  if not st or not st.index or next(st.index) == nil then
    vim.notify("[switch] no definitions", vim.log.levels.INFO)
    return
  end

  local word = text
  local cursor_col = vim.api.nvim_win_get_cursor(0)[2] + 1
  local cursor_pos = cursor_col - start_col

  -- Try full-word match first
  local entry = st.index[word]
  if not entry then
    local lower = word:lower()
    for k, v in pairs(st.index) do
      if k:lower() == lower then
        entry = v
        break
      end
    end
  end

  local replacement = nil
  if not entry then
    -- Search for substring under the cursor
    for _, k in ipairs(st.keys_sorted or {}) do
      local v = st.index[k]
      local start_pos, end_pos = word:find(k, 1, true)
      while start_pos do
        if cursor_pos >= start_pos and cursor_pos <= end_pos then
          local list, posidx = v.list, v.pos
          local nextidx = (posidx % #list) + 1
          local sub_replacement = list[nextidx]
          replacement = word:sub(1, start_pos - 1)
            .. sub_replacement
            .. word:sub(end_pos + 1)
          break
        end
        start_pos, end_pos = word:find(k, end_pos + 1, true)
      end
      if replacement then break end
    end
    if not replacement then return end
  else
    -- Normal full-word replacement
    local list, posidx = entry.list, entry.pos
    local nextidx = (posidx % #list) + 1
    replacement = list[nextidx]
  end

  -- Case matching helper
  local function match_case(src, tgt)
    if src:match("^[A-Z_]+$") then return tgt:upper() end
    if src:match("^[A-Z][a-z0-9]*$") then
      return tgt:sub(1, 1):upper() .. tgt:sub(2)
    end
    return tgt
  end

  replacement = match_case(word, replacement)

  vim.api.nvim_buf_set_text(bufnr, row - 1, start_col, row - 1, end_col, { replacement })
end

local function switch_token()
  local bufnr = vim.api.nvim_get_current_buf()
  local mode = vim.fn.mode()

  if mode:match("[vV]") then
    -- Visual mode
    local start_pos = vim.fn.getpos("v")
    local end_pos = vim.fn.getpos(".")
    local row1, col1 = start_pos[2], start_pos[3]
    local row2, col2 = end_pos[2], end_pos[3]
    if row1 > row2 or (row1 == row2 and col1 > col2) then
      row1, row2, col1, col2 = row2, row1, col2, col1
    end
    if row1 ~= row2 then
      vim.notify("[switch] multi-line selection not supported", vim.log.levels.WARN)
      return
    end
    local line = vim.api.nvim_buf_get_lines(bufnr, row1 - 1, row1, false)[1]
    local text = string.sub(line, col1, col2)
    switch_text(bufnr, row1, col1 - 1, col2, text)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
  else
    -- Normal mode
    local pos = vim.api.nvim_win_get_cursor(0)
    local row, col = pos[1], pos[2]
    local l, r = current_word_bounds(row, col)
    if not l then return end
    local line = vim.api.nvim_get_current_line()
    local word = string.sub(line, l, r)

    if try_cycle_zig_enum(bufnr, row, l, r, word) then return end

    switch_text(bufnr, row, l - 1, r, word)
  end
end

local function setup_buffer_bindings(bufnr)
  if not vim.b[bufnr]._switch_cmd then
    vim.api.nvim_buf_create_user_command(bufnr, "Switch", switch_token, {
      desc = "Cycle token under cursor or selection.",
    })
    vim.b[bufnr]._switch_cmd = true
  end

  if not vim.b[bufnr]._switch_map then
    -- NOTE: Overrides mark s
    vim.keymap.set({ "n", "x" }, "ms", switch_token, {
      buffer = bufnr,
      silent = true,
      desc = "Switch token under cursor or selection.",
    })
    vim.b[bufnr]._switch_map = true
  end
end

local aug = vim.api.nvim_create_augroup("mini_switch", { clear = true })
vim.api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
  group = aug,
  callback = function(args)
    ensure_buf_index(args.buf)
    setup_buffer_bindings(args.buf)
  end,
})

return M

