local M = {}

M.replacements = {
  ["resctangle"] = "rectangle",
  ["Resctangle"] = "Rectangle",
  ["Spaceing"] = "Spacing",
  -- We need to avoid things like (backgroun => background => backgroundd).
  ["Backgroun(%f[%s])"] = "Background%1",
  ["backgroun(%f[%s])"] = "background%1",
  ["globabl"] = "global",
  ["Inpute"] = "Input",
  ["inpute"] = "input",
  ["sount"] = "sound",
  ["Sount"] = "Sound",
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
  },
}

M.excluded_files = {
  "autocorrect.lua", -- this file itself
}

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

local function autocorrect_buffer(bufnr, rules)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local changed = false

  for i, line in ipairs(lines) do
    local orig = line
    for wrong, right in pairs(rules) do
      line = line:gsub(wrong, right)
    end
    if line ~= orig then
      lines[i] = line
      changed = true
    end
  end

  if changed then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  end
end

local function setup_autocmd()
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
      local combined = vim.tbl_extend("force", M.replacements, M.filetype_replacements[ft] or {})
      autocorrect_buffer(bufnr, combined)
    end,
  })
end

setup_autocmd()

return M

