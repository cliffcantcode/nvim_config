local M = {}

local uv = vim.uv or vim.loop

local function has_min_or_max(s)
  return s and (s:match("[Mm]in") or s:match("[Mm]ax"))
end

local function is_balanced_min_max(line)
  -- Split around the first comparison operator.
  local lhs, _, rhs = line:match("^(.-)%s*([<>]=?)%s*(.-)$")
  if not lhs then
    return false
  end

  local lhs_has = has_min_or_max(lhs)
  local rhs_has = has_min_or_max(rhs)

  -- If both sides reference min/max, it is usually a bounded-range check.
  return lhs_has and rhs_has
end

-- Rules that should only run manually leave on_save = false.
-- Rules with no on_save field are assumed safe for save-time linting.
M.rules = {
  {
    regex = ">%s*[%w_%.]*[Mm]ax[_%w]*",
    message = "'>' points away from the Max. |=> ",
    on_save = false,
    skip_balanced_min_max = true,
  },
  {
    regex = "<%s*[%w_%.]*[Mm]in[_%w]*",
    message = "'<' points away from the Min. |=> ",
    on_save = false,
    skip_balanced_min_max = true,
  },
  {
    regex = "[%w_%.]*[Mm]ax[_%w]*%s*<",
    message = "'<' points away from the Max. |=> ",
    on_save = false,
    skip_balanced_min_max = true,
  },
  {
    regex = "[%w_%.]*[Mm]in[_%w]*%s*>",
    message = "'>' points away from the Min. |=> ",
    on_save = false,
    skip_balanced_min_max = true,
  },

  -- Catch "x * @intFromFloat(...)" (risk of premature truncation)
  {
    regex = "%*%s*@intFromFloat",
    message = "Suspicious multiplication of truncated float. Could result in unintential multiplication by zero. If truncation is intended then be explicit (@round(), etc.). |=> ",
  },
  {
    regex = "%*%s*@as%s*%(%s*[%w_]+%s*,%s*@intFromFloat",
    message = "Suspicious multiplication of truncated float. Could result in unintential multiplication by zero. If truncation is intended then be explicit (@round(), etc.). |=> ",
  },
}

-- Backwards-compatible alias if anything else still refers to M.patterns.
M.patterns = M.rules

local function active_rules(opts)
  opts = opts or {}

  if not opts.on_save then
    return M.rules
  end

  local selected = {}
  for _, rule in ipairs(M.rules) do
    if rule.on_save ~= false then
      table.insert(selected, rule)
    end
  end
  return selected
end

local comment_markers = {
  lua = "%-%-",
  python = "#",
  sh = "#",
  bash = "#",
  c = "//",
  cpp = "//",
  rust = "//",
  zig = "//",
}

-- Assertions are intended to "fail" for bad values, so don't flag our heuristics inside them.
-- (e.g. `assert(x <= max)` should not warn about `<= max`)
local assert_patterns = {
  lua = {
    "%f[%w_]assert%s*%(",
  },
  python = {
    "%f[%w_]assert%s",
  },
  zig = {
    "std%.debug%.assert%s*%(",
    "std%.testing%.expect%s*%(",
    "std%.testing%.expectEqual%s*%(",
    "std%.testing%.expectEqualStrings%s*%(",
  },
  rust = {
    "assert!%s*%(",
    "debug_assert!%s*%(",
    "assert_eq!%s*%(",
    "assert_ne!%s*%(",
  },
  c = {
    "%f[%w_]assert%s*%(",
    "%f[%w_]ASSERT%s*%(",
  },
  cpp = {
    "%f[%w_]assert%s*%(",
    "%f[%w_]ASSERT%s*%(",
  },
  sh = {},
  bash = {},
}

local extension_to_filetype = {
  bash = "bash",
  c = "c",
  cpp = "cpp",
  cc = "cpp",
  cxx = "cpp",
  h = "c",
  hpp = "cpp",
  hxx = "cpp",
  lua = "lua",
  py = "python",
  rs = "rust",
  sh = "sh",
  zig = "zig",
}

local auto_lint_filetypes = {
  bash = true,
  c = true,
  cpp = true,
  lua = true,
  python = true,
  rust = true,
  sh = true,
  zig = true,
}

local function filetype_from_name(name)
  local ext = (name:match("%.([%w_]+)$") or ""):lower()
  return extension_to_filetype[ext] or ext
end

local function is_assert_line(trimmed, filetype)
  local pats = assert_patterns[filetype]
  if not pats or #pats == 0 then
    return false
  end
  for _, pat in ipairs(pats) do
    if trimmed:find(pat) then
      return true
    end
  end
  return false
end

local function is_text_file(path)
  local stat = uv.fs_stat(path)
  if not stat or stat.size == 0 then
    return false
  end

  local fd = uv.fs_open(path, "r", 438)
  if not fd then
    return false
  end

  local max_read = math.min(2048, stat.size)
  local chunk = uv.fs_read(fd, max_read, 0)
  uv.fs_close(fd)

  return chunk and not chunk:find("\0")
end

local function truncate_line(line, max_len)
  max_len = max_len or 80
  line = line:match("^%s*(.-)%s*$")
  if #line > max_len then
    return line:sub(1, max_len) .. "…"
  end
  return line
end

-- Core linter on an arbitrary set of lines + filename + filetype.
local function lint_lines(lines, full_path, filetype, opts)
  local comment_marker = comment_markers[filetype]
  local rules = active_rules(opts)
  local results = {}

  for i, line in ipairs(lines) do
    local trimmed = line:match("^%s*(.-)%s*$")

    -- Skip if it's a comment line or an assertion line.
    if not (comment_marker and trimmed:match("^" .. comment_marker))
      and not is_assert_line(trimmed, filetype)
    then
      for _, rule in ipairs(rules) do
        if string.find(line, rule.regex) then
          if rule.skip_balanced_min_max and is_balanced_min_max(line) then
            goto continue
          end

          table.insert(results, {
            filename = full_path,
            lnum = i,
            col = 0,
            text = rule.message .. truncate_line(line, 60),
            type = "W",
          })
        end
        ::continue::
      end
    end
  end

  return results
end

function M.lint_current_buffer(bufnr, opts)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype or ""
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local full_path = vim.api.nvim_buf_get_name(bufnr)
  return lint_lines(lines, full_path, ft, opts)
end

function M.lint_file(opts)
  opts = opts or {}

  local buf = opts.bufnr or vim.api.nvim_get_current_buf()
  local items = M.lint_current_buffer(buf, opts)
  vim.fn.setloclist(0, items, "r")

  if #items > 0 then
    vim.cmd("lopen")
  else
    vim.cmd("lclose")
  end

  return items
end

-- Lint every text file in the current buffer's directory.
function M.lint_directory(opts)
  opts = opts or {}

  local buf = opts.bufnr or vim.api.nvim_get_current_buf()
  local current_path = vim.api.nvim_buf_get_name(buf)
  if current_path == "" then
    vim.notify("No file name for current buffer", vim.log.levels.WARN)
    return {}
  end

  local dir = vim.fn.fnamemodify(current_path, ":p:h")
  local scandir, err = uv.fs_scandir(dir)
  if not scandir then
    vim.notify("Cannot scan directory: " .. tostring(err), vim.log.levels.ERROR)
    return {}
  end

  local all_items = {}
  local current_abs = vim.fn.fnamemodify(current_path, ":p")

  while true do
    local name, filetype = uv.fs_scandir_next(scandir)
    if not name then
      break
    end

    if filetype == "file" then
      local path = dir .. "/" .. name
      local abs = vim.fn.fnamemodify(path, ":p")

      if is_text_file(path) then
        local ft = filetype_from_name(name)
        local lines

        if abs == current_abs then
          lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        else
          lines = vim.fn.readfile(path)
        end

        local items = lint_lines(lines, abs, ft, opts)
        vim.list_extend(all_items, items)
      end
    end
  end

  vim.fn.setloclist(0, all_items, "r")

  if #all_items > 0 then
    vim.cmd("lopen")
  else
    vim.cmd("lclose")
  end

  return all_items
end

function M.run_tests()
  local cases = {
    {
      name = "manual lint includes min/max rules",
      ft = "zig",
      lines = { "if (value > max_value) return;" },
      opts = {},
      expected = 1,
    },
    {
      name = "save lint skips min/max rules",
      ft = "zig",
      lines = { "if (value > max_value) return;" },
      opts = { on_save = true },
      expected = 0,
    },
    {
      name = "save lint still checks intFromFloat multiplication",
      ft = "zig",
      lines = { "const pixels = 128 * @intFromFloat(scale);" },
      opts = { on_save = true },
      expected = 1,
    },
    {
      name = "bounded min/max checks are ignored",
      ft = "zig",
      lines = { "if (min_value < value and value < max_value) return;" },
      opts = {},
      expected = 0,
    },
    {
      name = "assertions are ignored",
      ft = "zig",
      lines = { "std.debug.assert(value <= max_value);" },
      opts = {},
      expected = 0,
    },
  }

  for _, case in ipairs(cases) do
    local out = lint_lines(case.lines, "test." .. case.ft, case.ft, case.opts)
    if #out ~= case.expected then
      error(
        "[linter self-test failed] " .. case.name .. "\n"
          .. "Expected: " .. tostring(case.expected) .. " findings\n"
          .. "Got: " .. tostring(#out)
      )
    end
  end
end

M.run_tests()

vim.keymap.set("n", "<leader>lf", function()
  M.lint_file()
end, { desc = "[l]int [f]ile" })

vim.keymap.set("n", "<leader>ld", function()
  M.lint_directory()
end, { desc = "[l]int [d]irectory" })

vim.api.nvim_create_autocmd("BufWritePost", {
  group = vim.api.nvim_create_augroup("AutoLinter", { clear = true }),
  pattern = "*",
  callback = function(args)
    local ft = vim.bo[args.buf].filetype
    if not auto_lint_filetypes[ft] then
      return
    end

    M.lint_file({ bufnr = args.buf, on_save = true })
  end,
})

return M
