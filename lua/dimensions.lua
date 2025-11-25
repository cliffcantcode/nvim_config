local M = {}

M.dimension_exclusion_list = {
  MAX = true,
  INDEX = true,
}

local function cycle_word(word)
  if M.dimension_exclusion_list[word] then return word end

  local map = { X = "Y", Y = "Z", Z = "X" }

  return (word:gsub("[XYZ]", function(c)
    return map[c] or c
  end))
end

-- Exchange coordinates more quickly. (X->Y->Z->X)
local function cycle_dimensions_xyz(text)
  return (text:gsub("%w+", cycle_word))
end

vim.keymap.set("n", "<leader>cd", function()
  local line = vim.api.nvim_get_current_line()
  vim.api.nvim_set_current_line(cycle_dimensions_xyz(line))
end, { desc = "[c]ycle [d]imensions across a line." })

return M

