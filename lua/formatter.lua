-- TODO: In a switch statement add the , to the end of the switch block.
-- TODO: In a switch statement add change the ; to a , if it's a single line.
-- TODO: The formatter also adds ';' to the end of a struct if it is meant to be the return type of a function, it should not as that isn't valid syntax and won't compile. :
--[[
fn Win32CircularDeadzone(raw_x: f32, raw_y: f32, deadzone: f32) struct { x: f32, y: f32 }; {
    var result = .{ .x = 0.0, .y = 0.0 };

    const magnitude = @sqrt((raw_x * raw_x) + (raw_y * raw_y));
    if (magnitude > deadzone) {
        const clipped_magnitude = @min(magnitude, 1.0);
        const scaled_magnitude = (clipped_magnitude - deadzone) / (1.0 - deadzone);

        raw_x *= (scaled_magnitude / magnitude);
        raw_y *= -(scaled_magnitude / magnitude);

        result.stick_x = raw_x;
        result.stick_y = raw_y;
    }

    return result;
}
]]--

local M = {}

--------------------------------------------------------------------------------
-- Zig semicolon fixer (Tree-sitter + conservative fallbacks)
--------------------------------------------------------------------------------

local function zig_fix_missing_semicolons(bufnr)
  local ok_ts, ts = pcall(require, "vim.treesitter")
  if not ok_ts then
    return false
  end

  local ok_parser, parser = pcall(ts.get_parser, bufnr, "zig")
  if not ok_parser or not parser then
    return false
  end

  local tree = parser:parse()[1]
  if not tree then
    return false
  end

  local root = tree:root()
  if not root then
    return false
  end

  local function get_line(row)
    return vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
  end

  local function rtrim(s)
    return (s:gsub("%s+$", ""))
  end

  -- Strip a real trailing Zig line comment (//...), but ignore:
  -- - // inside normal strings: "http://..."
  -- - Zig multiline string literals that start with \\ outside a string/char
  local function strip_zig_line_comment(s)
    local in_str, in_char, esc = false, false, false
    local i, len = 1, #s

    while i <= len - 1 do
      local ch = s:sub(i, i)
      local nxt = s:sub(i + 1, i + 1)

      if in_str or in_char then
        if esc then
          esc = false
        elseif ch == "\\" then
          esc = true
        elseif in_str and ch == "\"" then
          in_str = false
        elseif in_char and ch == "'" then
          in_char = false
        end
        i = i + 1
      else
        if ch == "\"" then
          in_str = true
          i = i + 1
        elseif ch == "'" then
          in_char = true
          i = i + 1
        elseif ch == "\\" and nxt == "\\" then
          -- Zig multiline string literal: rest of line is string content.
          return s
        elseif ch == "/" and nxt == "/" then
          return s:sub(1, i - 1)
        else
          i = i + 1
        end
      end
    end

    return s
  end

  -- Count { and } outside strings/chars, stopping at // comments.
  local function brace_delta(s)
    local in_str, in_char, esc = false, false, false
    local i, len = 1, #s
    local delta = 0

    while i <= len do
      local ch = s:sub(i, i)
      local nxt = (i < len) and s:sub(i + 1, i + 1) or ""

      if in_str or in_char then
        if esc then
          esc = false
        elseif ch == "\\" then
          esc = true
        elseif in_str and ch == "\"" then
          in_str = false
        elseif in_char and ch == "'" then
          in_char = false
        end
        i = i + 1
      else
        if ch == "\"" then
          in_str = true
          i = i + 1
        elseif ch == "'" then
          in_char = true
          i = i + 1
        elseif ch == "\\" and nxt == "\\" then
          -- Zig multiline string literal: ignore rest of line.
          break
        elseif ch == "/" and nxt == "/" then
          -- line comment starts, ignore rest
          break
        elseif ch == "{" then
          delta = delta + 1
          i = i + 1
        elseif ch == "}" then
          delta = delta - 1
          i = i + 1
        else
          i = i + 1
        end
      end
    end

    return delta
  end

  -- Robust statement end:
  -- - Works even when TS end column is 0 (common when ';' is missing and recovery kicks in)
  -- - Inserts before trailing // comments
  local function last_code_pos_in_node(node)
    local sr, _, er, ec = node:range()
    local last_row = vim.api.nvim_buf_line_count(bufnr) - 1
    if er > last_row then er = last_row end

    for row = er, sr, -1 do
      local line = get_line(row)
      local upto = #line

      if row == er then
        -- ec is 0-based exclusive
        upto = math.min(ec, #line)
      end

      if upto > 0 then
        local prefix = line:sub(1, upto)
        prefix = rtrim(strip_zig_line_comment(prefix))
        if #prefix > 0 then
          -- insertion col is 0-based == prefix length
          return row, #prefix
        end
      end
    end

    return nil
  end

  -- Collect edits first; apply from bottom->top so earlier inserts don't shift later ranges.
  local inserts = {}
  local seen = {}

  local function add_insert(row, col)
    if row < 0 or col < 0 then return end
    local key = row .. ":" .. col
    if seen[key] then return end
    seen[key] = true
    table.insert(inserts, { row = row, col = col })
  end

  local function needs_semicolon(row, col)
    local line = get_line(row)

    -- Clamp insertion to EOL.
    if col > #line then col = #line end

    -- Already has ';' or ',' at/after insertion point.
    local after = line:sub(col + 1) -- col is 0-based
    if after:match("^%s*[;,]") then
      return false
    end

    -- Already ends with ';' or ','
    local before = line:sub(1, col)
    if before:match("[;,]%s*$") then
      return false
    end

    -- Avoid terminating obvious continuations.
    local code = rtrim(strip_zig_line_comment(before))
    if code == "" then return false end
    if code:match("[%({%[]%s*$") then return false end
    if code:match("[=+*/%-%^&|<>!,]%s*$") then return false end

    return true
  end

  local function node_text(node)
    -- Neovim API moved this over time; support both.
    if vim.treesitter.get_node_text then
      local ok, txt = pcall(vim.treesitter.get_node_text, node, bufnr)
      if ok then return txt end
    end
    if vim.treesitter.query and vim.treesitter.query.get_node_text then
      local ok, txt = pcall(vim.treesitter.query.get_node_text, node, bufnr)
      if ok then return txt end
    end
    return nil
  end

  local const_modifiers = {
    pub = true,
    export = true,
    extern = true,
    comptime = true,
    inline = true,
    noinline = true,
    threadlocal = true,
  }

  local function is_const_variable_declaration(node)
    local txt = node_text(node)
    if not txt then return false end

    local seen_tok = 0
    for tok in txt:gmatch("%S+") do
      seen_tok = seen_tok + 1
      if not const_modifiers[tok] then
        return tok == "const" or tok == "var"
      end
      if seen_tok >= 12 then
        break
      end
    end
    return false
  end

  -- NOTE: This is for actual container declarations, not struct literals.
  local container_kinds = {
    struct_declaration = true,
    union_declaration = true,
    enum_declaration = true,
    opaque_declaration = true,
  }

  local function visit(node)
    local kind = node:type()

    -- 1) container declarations (cheap, and sometimes useful)
    if container_kinds[kind] then
      local row, col = last_code_pos_in_node(node)
      if row and col then
        local line = get_line(row)
        local last_ch = line:sub(col, col) -- col is len(prefix), 1-based index of last char
        if last_ch == "}" then
          add_insert(row, col)
        end
      end
    end

    -- 2) `const`/`var` declarations: ensure they end with `;`.
    if kind == "variable_declaration" and is_const_variable_declaration(node) then
      local row, col = last_code_pos_in_node(node)
      if row and col then
        add_insert(row, col)
      end
    end

    local n = node:named_child_count()
    for i = 0, n - 1 do
      local child = node:named_child(i)
      if child then visit(child) end
    end
  end

  visit(root)

  -------------------------------------------------------------------
  -- Fallback #1: TS recovery can swallow a decl when the next line starts
  -- with another decl (classic: missing ';' before next `const`).
  -- Only terminate when next nonblank line proves the statement ended.
  -------------------------------------------------------------------
  local function line_starts_with_decl(line)
    local code = rtrim(strip_zig_line_comment(line or ""))
    if code == "" then return false end

    local seen_tok = 0
    for tok in code:gmatch("%S+") do
      seen_tok = seen_tok + 1
      if not const_modifiers[tok] then
        return tok == "const" or tok == "var"
      end
      if seen_tok >= 12 then break end
    end
    return false
  end

  local function insert_col_for_line(line)
    local code = rtrim(strip_zig_line_comment(line or ""))
    if code == "" then return nil end

    -- already terminated
    if code:match("[;,]%s*$") then return nil end

    -- obvious multi-line continuations
    if code:match("[%({%[]%s*$") then return nil end
    if code:match("[=+*/%-%^&|<>!,]%s*$") then return nil end

    return #code -- 0-based insertion col
  end

  local function next_nonblank(row)
    local last = vim.api.nvim_buf_line_count(bufnr) - 1
    for r = row + 1, last do
      local l = get_line(r)
      if l and l:find("%S") then
        return r, l
      end
    end
    return nil, nil
  end

  local last = vim.api.nvim_buf_line_count(bufnr) - 1
  for row = 0, last do
    local line = get_line(row)
    if line_starts_with_decl(line) then
      local col = insert_col_for_line(line)
      if col then
        local _, nxt = next_nonblank(row)
        local nxt_code = rtrim(strip_zig_line_comment(nxt or ""))

        if (not nxt)
          or line_starts_with_decl(nxt)
          or nxt_code:match("^%s*}") then
          add_insert(row, col)
        end
      end
    end
  end

  -------------------------------------------------------------------
  -- Fallback #2: Braced initializers (the one your test is failing).
  --
  -- If a decl line ends with '{', Tree-sitter recovery may not give us a
  -- node range that reaches the matching '}'.
  --
  -- So: find the matching closing '}' by counting braces, then insert ';'
  -- right after that '}' line (before any trailing // comment).
  -------------------------------------------------------------------
  for row = 0, last do
    local line = get_line(row)
    if line_starts_with_decl(line) then
      local code = rtrim(strip_zig_line_comment(line))
      if code:match("{%s*$") and not code:match("[;,]%s*$") then
        local depth = 0
        for r = row, last do
          depth = depth + brace_delta(get_line(r))
          if depth == 0 and r > row then
            local end_line = get_line(r)
            local end_code = rtrim(strip_zig_line_comment(end_line))
            if end_code:match("}%s*$") then
              add_insert(r, #end_code)
            end
            break
          end
        end
      end
    end
  end

  table.sort(inserts, function(a, b)
    if a.row ~= b.row then
      return a.row > b.row
    end
    return a.col > b.col
  end)

  local changed = false
  for _, pos in ipairs(inserts) do
    if needs_semicolon(pos.row, pos.col) then
      vim.api.nvim_buf_set_text(bufnr, pos.row, pos.col, pos.row, pos.col, { ";" })
      changed = true
    end
  end

  return changed
end

--------------------------------------------------------------------------------
-- C / C++ / headers: simple heuristic
--------------------------------------------------------------------------------

local function c_like_container_semicolon_fix(bufnr, ft)
  local is_c_like = (ft == "cpp" or ft == "c" or ft == "h" or ft == "hpp")
  if not is_c_like then
    return false
  end

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if line_count == 0 then
    return false
  end

  -- Find the last nonblank line
  local end_line = nil
  for l = line_count - 1, 0, -1 do
    local txt = vim.api.nvim_buf_get_lines(bufnr, l, l + 1, false)[1]
    if txt and txt:find("%S") then
      end_line = l
      break
    end
  end
  if not end_line then
    return false
  end

  local text = vim.api.nvim_buf_get_lines(bufnr, end_line, end_line + 1, false)[1]
  if not text then
    return false
  end

  -- Only touch "}"/";" shaped endings
  if not text:match("^%s*}%s*$") then
    return false
  end

  -- Already has semicolon like "};"
  if text:match(";%s*$") then
    return false
  end

  -- Look upward for struct/union/enum on previous nonblank line
  local has_container = false
  for l = end_line - 1, 0, -1 do
    local up = vim.api.nvim_buf_get_lines(bufnr, l, l + 1, false)[1]
    if up and up:find("%S") then
      if up:find("%f[%w]struct%f[%W]")
        or up:find("%f[%w]union%f[%W]")
        or up:find("%f[%w]enum%f[%W]") then
        has_container = true
      end
      break
    end
  end

  if not has_container then
    return false
  end

  -- Append semicolon at end of last line
  vim.api.nvim_buf_set_lines(bufnr, end_line, end_line + 1, false, {
    text .. ";",
  })

  return true
end

--------------------------------------------------------------------------------
-- Self-tests (run once on first Zig formatter use)
--------------------------------------------------------------------------------

function M.run_tests()
  local ok_ts, ts = pcall(require, "vim.treesitter")
  if not ok_ts then
    error("[formatter self-test] vim.treesitter not available")
  end

  do
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "zig"
    local ok = pcall(ts.get_parser, buf, "zig")
    vim.api.nvim_buf_delete(buf, { force = true })

    if not ok then
      error("[formatter self-test] Zig TS parser missing. Run :TSInstall zig")
    end
  end

  local function run_case(name, input_lines, expected_lines)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "zig"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, input_lines)

    zig_fix_missing_semicolons(buf)

    local out = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    vim.api.nvim_buf_delete(buf, { force = true })

    if not vim.deep_equal(out, expected_lines) then
      error(
        "[formatter self-test failed] " .. name .. "\n\n"
        .. "Input:\n" .. table.concat(input_lines, "\n") .. "\n\n"
        .. "Expected:\n" .. table.concat(expected_lines, "\n") .. "\n\n"
        .. "Got:\n" .. table.concat(out, "\n")
      )
    end
  end

  run_case(
    "trailing // comment",
    { "const headless = false // TODO: Comment blocking end of const declaration." },
    { "const headless = false; // TODO: Comment blocking end of const declaration." }
  )

  run_case(
    "two adjacent const decls",
    {
      "const headless = false // TODO: Comment blocking end of const declaration.",
      "const y_started_near_center = @abs(ctrl.start_y) < 0.3",
    },
    {
      "const headless = false; // TODO: Comment blocking end of const declaration.",
      "const y_started_near_center = @abs(ctrl.start_y) < 0.3;",
    }
  )

  run_case(
    "multiline initializer + next decl",
    {
      "const prog_fireball = Program{",
      "    .ops = &.{.deal_damage_enemy_hero},",
      "    .a = &.{6},",
      "}",
      "const headless = false",
    },
    {
      "const prog_fireball = Program{",
      "    .ops = &.{.deal_damage_enemy_hero},",
      "    .a = &.{6},",
      "};",
      "const headless = false;",
    }
  )

  run_case(
    "already terminated stays unchanged",
    { "const already = true;" },
    { "const already = true;" }
  )
end

local _selftest_state = 0 -- 0 = not run, 1 = passed, -1 = failed
local function ensure_selftests_once()
  if vim.g.formatter_disable_selftests then
    return true
  end

  if _selftest_state ~= 0 then
    return _selftest_state == 1
  end

  local ok, err = pcall(M.run_tests)
  if ok then
    _selftest_state = 1
    return true
  end

  _selftest_state = -1
  vim.schedule(function()
    vim.notify(err, vim.log.levels.ERROR)
  end)
  return false
end

--------------------------------------------------------------------------------
-- Autocmd: semicolon fixes
--------------------------------------------------------------------------------

vim.api.nvim_create_autocmd("BufWritePre", {
  desc = "Fix a few common missing-semicolon cases before formatting (Zig via TS, C-like via heuristic)",
  group = vim.api.nvim_create_augroup("ContainerSemicolonFix", { clear = true }),
  pattern = { "*.zig", "*.c", "*.h", "*.cpp", "*.hpp" },
  callback = function(args)
    local view = vim.fn.winsaveview()

    local bufnr = args.buf
    local ft = vim.bo[bufnr].filetype

    if ft == "zig" then
      if ensure_selftests_once() then
        zig_fix_missing_semicolons(bufnr)
      end
      vim.fn.winrestview(view)
      return
    end

    c_like_container_semicolon_fix(bufnr, ft)
    vim.fn.winrestview(view)
  end,
})

--------------------------------------------------------------------------------
-- Formatter: only rewrite when there are real changes
--------------------------------------------------------------------------------

M.formatters = {
  zig = "zig fmt --stdin",
}

local function format_buffer(cmd, bufnr)
  local buf = bufnr or vim.api.nvim_get_current_buf()
  local view = vim.fn.winsaveview()

  local old_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local old_text = table.concat(old_lines, "\n")

  local formatted = vim.fn.system(cmd, old_text)

  if vim.v.shell_error ~= 0 then
    vim.notify("Formatter error:\n" .. formatted, vim.log.levels.ERROR)
    vim.fn.winrestview(view)
    return
  end

  if formatted == old_text or formatted == old_text .. "\n" then
    vim.fn.winrestview(view)
    return
  end

  local new_lines = vim.split(formatted, "\n", { trimempty = false })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)

  vim.fn.winrestview(view)
end

vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.zig",
  callback = function(args)
    local bufnr = args.buf
    local ft = vim.bo[bufnr].filetype
    local cmd = M.formatters[ft]
    if cmd then
      format_buffer(cmd, bufnr)
    end
  end,
})

return M

