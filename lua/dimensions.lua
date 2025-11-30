local M = {}

M.dimension_exclusion_list = {
  MAX = true,
  max = true,
  INDEX = true,
  index = true,
}

M.cycles = {
   { "X", "Y", "Z" },
   { "_x", "_y", "_z" },
   { "x_", "y_", "z_" },
}

local cycle_map = {}

for _, cycle in ipairs(M.cycles) do
  for i, c in ipairs(cycle) do
    local next = cycle[(i % #cycle) + 1]
    cycle_map[c] = next
  end
end

local function cycle_word(word)
  if M.dimension_exclusion_list[word] then return word end

  return word:gsub(".", function(c)
    return cycle_map[c] or c
  end)
end

-- Exchange coordinates more quickly. (X->Y->Z->X)
local function cycle_dimensions_line(text)
  return (text:gsub("%w+", cycle_word))
end

vim.keymap.set("n", "<leader>cd", function()
  local line = vim.api.nvim_get_current_line()
  vim.api.nvim_set_current_line(cycle_dimensions_line(line))
end, { desc = "[c]ycle [d]imensions across a line." })

return M

