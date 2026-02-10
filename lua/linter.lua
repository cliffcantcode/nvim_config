local M = {}

-- Add patterns for common mistakes
M.patterns = {
  { regex = ">%s*[%w_%.]*[Mm]ax[_%w]*",  message = "'>' points away from the Max. |=> " },
  { regex = "<%s*[%w_%.]*[Mm]in[_%w]*",  message = "'<' points away from the Min. |=> " },
  { regex = "[%w_%.]*[Mm]ax[_%w]*%s*<",  message = "'<' points away from the Max. |=> " },
  { regex = "[%w_%.]*[Mm]in[_%w]*%s*>",  message = "'>' points away from the Min. |=> " },

  -- Catch "x * @intFromFloat(...)" (risk of premature truncation)
  -- Case 1: Direct usage like "128 * @intFromFloat(...)"
  {
    regex = "%*%s*@intFromFloat",
    message = "Suspicious multiplication of truncated float. Could result in unintential multiplication by zero. If truncation is intended then be explicit (@round(), etc.). |=> "
  },
  -- Case 2: Wrapped usage like "128 * @as(i32, @intFromFloat(...))"
  -- Explanation: Match '*', optional space, '@as', '(', type name, ',', space, '@intFromFloat'
  {
    regex = "%*%s*@as%s*%(%s*[%w_]+%s*,%s*@intFromFloat",
    message = "Suspicious multiplication of truncated float. Could result in unintential multiplication by zero. If truncation is intended then be explicit (@round(), etc.). |=> "
  },
}

local comment_markers = {
  lua    = "%-%-",
  python = "#",
  sh     = "#",
  bash   = "#",
  c      = "//",
  cpp    = "//",
  rust   = "//",
  zig    = "//",
}

local function is_text_file(path)
  local stat = vim.loop.fs_stat(path)
  if not stat or stat.size == 0 then
    return false
  end

  local fd = vim.loop.fs_open(path, "r", 438)
  if not fd then return false end

  local max_read = math.min(2048, stat.size)
  local chunk = vim.loop.fs_read(fd, max_read, 0)
  vim.loop.fs_close(fd)

  return chunk and not chunk:find("\0")
end

local function truncate_line(line, max_len)
  max_len = max_len or 80
  line = line:match("^%s*(.-)%s*$") -- trim
  if #line > max_len then
    return line:sub(1, max_len) .. "…"
  end
  return line
end

-- core linter on an arbitrary set of lines + filename + filetype
local function lint_lines(lines, full_path, filetype)
  local comment_marker = comment_markers[filetype]
  local results = {}

  for i, line in ipairs(lines) do
    local trimmed = line:match("^%s*(.-)%s*$")
    -- Skip if it's a comment line
    if not (comment_marker and trimmed:match("^" .. comment_marker)) then
      for _, p in ipairs(M.patterns) do
        if string.find(line, p.regex) then
          table.insert(results, {
            filename = full_path,
            lnum = i,
            col = 0,
            text = p.message .. truncate_line(line, 60),
            type = "W",
          })
        end
      end
    end
  end

  return results
end

function M.lint_current_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ft = vim.api.nvim_buf_get_option(bufnr, "filetype") or ""
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local full_path = vim.api.nvim_buf_get_name(bufnr)
  return lint_lines(lines, full_path, ft)
end

function M.lint_file()
  local buf = vim.api.nvim_get_current_buf()
  local items = M.lint_current_buffer(buf)
  vim.fn.setloclist(0, items, "r")

  if #items > 0 then
    vim.cmd("lopen")
  else
    vim.cmd("lclose")
  end
end

-- Lint every text file in the current buffer's directory
function M.lint_directory()
  local current_path = vim.api.nvim_buf_get_name(0)
  if current_path == "" then
    vim.notify("No file name for current buffer", vim.log.levels.WARN)
    return
  end

  local dir = vim.fn.fnamemodify(current_path, ":p:h")
  local scandir, err = vim.loop.fs_scandir(dir)
  if not scandir then
    vim.notify("Cannot scan directory: " .. tostring(err), vim.log.levels.ERROR)
    return
  end

  local all_items = {}
  local current_abs = vim.fn.fnamemodify(current_path, ":p")

  while true do
    local name, t = vim.loop.fs_scandir_next(scandir)
    if not name then break end

    if t == "file" then
      local path = dir .. "/" .. name
      local abs = vim.fn.fnamemodify(path, ":p")

      -- Only lint text-like files
      if is_text_file(path) then
        local ext = name:match("%.([%w_]+)$") or ""
        local ft = ext  -- good enough for our comment_markers mapping
        local lines

        if abs == current_abs then
          -- Use the live buffer for the current file
          lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        else
          -- Read from disk for other files
          lines = vim.fn.readfile(path)
        end

        local items = lint_lines(lines, abs, ft)
        vim.list_extend(all_items, items)
      end
    end
  end

  vim.fn.setloclist(0, all_items, "r")
  vim.cmd("lopen")
end

vim.keymap.set("n", "<leader>lf", function()
  M.lint_file()
end, { desc = "[l]int [f]ile" })

vim.keymap.set("n", "<leader>ld", function()
  M.lint_directory()
end, { desc = "[l]int [d]irectory" })

vim.api.nvim_create_autocmd("BufWritePost", {
  group = vim.api.nvim_create_augroup("AutoLinter", { clear = true }),
  pattern = { "*.zig", "*.lua", "*.python", "*.c", "*.cpp", "*.rust", "*.sh", "*.bash" },
  callback = function()
    M.lint_file()
  end,
})

return M

