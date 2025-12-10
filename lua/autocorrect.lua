local M = {}

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
  "autocorrect.lua",
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

-- Apply replacements using nvim_buf_set_text so we only touch changed spans
local function autocorrect_buffer(bufnr, rules)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local changed_any = false

  for lnum = 0, line_count - 1 do
    local orig_line = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1]
    if orig_line and orig_line ~= "" then

      local edits = {}
      local line = orig_line

      -- Collect edits
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
            start_col = s - 1,  -- 0-based
            end_col   = e,      -- exclusive
            text      = replacement,
          })

          start = e + 1
        end
      end

      -- Apply edits right–to–left
      if #edits > 0 then
        changed_any = true

        table.sort(edits, function(a, b)
          return a.start_col > b.start_col
        end)

        for _, edit in ipairs(edits) do
          vim.api.nvim_buf_set_text(
            bufnr,
            lnum,
            edit.start_col,
            lnum,
            edit.end_col,
            { edit.text }
          )
        end
      end
    end
  end

  return changed_any
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

      -- Merge into previous undo block when possible
      pcall(vim.cmd, "silent keepjumps keepalt undojoin")

      autocorrect_buffer(bufnr, combined)
    end,
  })
end

setup_autocmd()

return M

