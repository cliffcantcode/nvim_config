local M = {}

---------------------------------------------------------------------------
-- Replacement rules
---------------------------------------------------------------------------

M.replacements = {
  ["resctangle"] = "rectangle",
  ["Resctangle"] = "Rectangle",
  ["Spaceing"] = "Spacing",
  ["Backgroun(%f[%s])"] = "Background%1",
  ["backgroun(%f[%s])"] = "background%1",
  ["globabl"] = "global",
  ["Inpute"] = "Input",
  ["inpute"] = "input",
  ["sount"] = "sound",
  ["Sount"] = "Sound",
  ["Aloc"] = "Alloc",
}

M.filetype_replacements = {
  lua = {
    ["funciton"] = "function",
  },
  cpp = {
    ["Hight"] = "High",
  },
  zig = {
    ["%f[%w]cont%f[%s]"] = "const",
    ["Ste%f[%W]"] = "Step",
    ["acces([^s])"] = "access%1",
  },
}

M.excluded_files = {
  "autocorrect.lua",
}

-- Helpers

local function is_readonly(bufnr)
  return vim.bo[bufnr].readonly or not vim.bo[bufnr].modifiable
end

local function is_excluded(filepath, bufnr)
  if is_readonly(bufnr) then
    return true
  end
  for _, pattern in ipairs(M.excluded_files) do
    if filepath:match(pattern) then
      return true
    end
  end
  return false
end

-- Core autocorrect logic

local function apply_rules_to_line(line, rules)
  local edits = {}

  for wrong, right in pairs(rules) do
    local start = 1
    while true do
      local s, e, cap = line:find(wrong, start)
      if not s then break end

      local replacement = right
      if cap then
        replacement = right:gsub("%%1", cap)
      end

      table.insert(edits, {
        s = s,
        e = e,
        text = replacement,
      })

      start = e + 1
    end
  end

  -- Apply right → left
  table.sort(edits, function(a, b)
    return a.s > b.s
  end)

  for _, edit in ipairs(edits) do
    line = line:sub(1, edit.s - 1)
      .. edit.text
      .. line:sub(edit.e + 1)
  end

  return line
end

-- Apply replacements using nvim_buf_set_text
local function autocorrect_buffer(bufnr, rules)
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  for lnum = 0, line_count - 1 do
    local orig_line = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1]
    if orig_line and orig_line ~= "" then
      local fixed = apply_rules_to_line(orig_line, rules)

      if fixed ~= orig_line then
        vim.api.nvim_buf_set_text(
          bufnr,
          lnum,
          0,
          lnum,
          #orig_line,
          { fixed }
        )
      end
    end
  end
end

-- Always-on tests (simple input → output)

function M.run_tests()
  local tests = {
    {
      ft = "zig",
      input = "pub fn foo(cont x: i32) void {}",
      expected = "pub fn foo(const x: i32) void {}",
    },
    {
      ft = "zig",
      input = "const CopySwiftSte = struct {",
      expected = "const CopySwiftStep = struct {",
    },
    {
      ft = "zig",
      input = 'std.fs.cwd().acces("A_Game", .{}) catch {',
      expected = 'std.fs.cwd().access("A_Game", .{}) catch {',
    },
    {
      ft = "zig",
      input = "std.fs.cwd().access(path, .{})",
      expected = "std.fs.cwd().access(path, .{})",
    },
    {
      ft = "any",
      input = "Backgroun ",
      expected = "Background ",
    },
    {
      ft = "any",
      input = "Aloc ",
      expected = "Alloc ",
    },
  }

  for _, t in ipairs(tests) do
    local rules = vim.tbl_extend(
      "force",
      M.replacements,
      M.filetype_replacements[t.ft] or {}
    )

    local out = apply_rules_to_line(t.input, rules)

    if out ~= t.expected then
      error(
        "[autocorrect test failed]\n"
        .. "Input:    " .. t.input .. "\n"
        .. "Expected: " .. t.expected .. "\n"
        .. "Got:      " .. out
      )
    end
  end
end

-- Autocmd setup

local function setup_autocmd()
  -- Fail fast if rules break
  M.run_tests()

  local aug = vim.api.nvim_create_augroup("AutoCorrect", { clear = true })

  vim.api.nvim_create_autocmd("BufWritePre", {
    group = aug,
    callback = function(args)
      local bufnr = args.buf
      local filepath = vim.api.nvim_buf_get_name(bufnr)

      if is_excluded(filepath, bufnr) then
        return
      end

      local ft = vim.bo[bufnr].filetype
      local combined = vim.tbl_extend(
        "force",
        M.replacements,
        M.filetype_replacements[ft] or {}
      )

      pcall(vim.cmd, "silent keepjumps keepalt undojoin")
      autocorrect_buffer(bufnr, combined)
    end,
  })
end

setup_autocmd()

return M

