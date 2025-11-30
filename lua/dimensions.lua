local M = {}

M.dimension_exclusion_list = {
  MAX = true,
  max = true,
  INDEX = true,
  index = true,
}

M.cycles = {
  { "X",  "Y",  "Z"  },
  { "_x", "_y", "_z" },
  { "x_", "y_", "z_" },
}

local forward_cycle_map = {}
local backward_cycle_map = {}

for _, cycle in ipairs(M.cycles) do
  for i, c in ipairs(cycle) do
    forward_cycle_map[c] = cycle[(i % #cycle) + 1]

    local prev_i = i - 1
    if prev_i == 0 then prev_i = #cycle end
    backward_cycle_map[c] = cycle[prev_i]
  end
end

-- Build and sort patterns - longer first to avoid "_x" vs "X" overlaps.
local cycle_patterns = {}
for key, _ in pairs(forward_cycle_map) do
  table.insert(cycle_patterns, key)
end
table.sort(cycle_patterns, function(a, b)
  return #a > #b
end)

local function transform_token(tok, cycle_map)
  -- Skip whole-token exclusions
  if M.dimension_exclusion_list[tok] then return tok end

  local i = 1
  local len = #tok
  local out = {}

  while i <= len do
    local replaced = false

    for _, key in ipairs(cycle_patterns) do
      local key_len = #key
      if i + key_len - 1 <= len then
        if tok:sub(i, i + key_len - 1) == key then
          local repl = cycle_map[key] or key
          table.insert(out, repl)
          i = i + key_len
          replaced = true
          break
        end
      end
    end

    if not replaced then
      table.insert(out, tok:sub(i, i))
      i = i + 1
    end
  end

  return table.concat(out)
end

local function cycle_dimensions_line(text, cycle_map)
  return text:gsub("[%w_]+", function(tok)
    return transform_token(tok, cycle_map)
  end)
end

local function perform_cycle(cycle_map)
  local line = vim.api.nvim_get_current_line()
  local new_line = cycle_dimensions_line(line, cycle_map)

  if new_line ~= line then
    vim.api.nvim_set_current_line(new_line)
  end
end

vim.keymap.set("n", "<leader>cd", function()
  perform_cycle(forward_cycle_map)
end, { desc = "[c]ycle [d]imensions across a line." })

vim.keymap.set("n", "<leader>cD", function()
  perform_cycle(backward_cycle_map)
end, { desc = "[c]ycle [d]imensions across a line backwards." })

return M

