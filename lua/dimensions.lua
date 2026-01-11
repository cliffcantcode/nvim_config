local M = {}
M.dimension_exclusion_list = {
  MAX = true,
  max = true,
  INDEX = true,
  index = true,
}

local exclusion_keys = vim.tbl_keys(M.dimension_exclusion_list)

M.cycles = {
  { "X",  "Y",  "Z"  },
  { "_x", "_y", "_z" },
  { "x_", "y_", "z_" },
  { "dx", "dy", "dz" },
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

local function transform_segment(tok, cycle_map)
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

-- Rotate a single lowercase axis char x/y/z using the _x/_y/_z cycle,
-- without introducing a global { "x","y","z" } cycle.
local function cycle_lower_axis_char(cycle_map, ch)
  if ch == "x" and cycle_map["_x"] then
    local next = cycle_map["_x"]
    if #next == 2 and next:sub(1, 1) == "_" then
      return next:sub(2)
    end
  elseif ch == "y" and cycle_map["_y"] then
    local next = cycle_map["_y"]
    if #next == 2 and next:sub(1, 1) == "_" then
      return next:sub(2)
    end
  elseif ch == "z" and cycle_map["_z"] then
    local next = cycle_map["_z"]
    if #next == 2 and next:sub(1, 1) == "_" then
      return next:sub(2)
    end
  end
  return ch
end

local function transform_token(tok, cycle_map)
  if M.dimension_exclusion_list[tok] then return tok end

  -- Exclusion prefix + '_' + tail, e.g. MAX_X -> MAX_Y
  for _, ex in pairs(exclusion_keys) do
    local ex_len = #ex
    if #tok > ex_len + 1
      and tok:sub(1, ex_len) == ex
      and tok:sub(ex_len + 1, ex_len + 1) == "_" then
        local head = ex
        local sep = "_"
        local tail = tok:sub(ex_len + 2) -- after "EX_"

        local new_tail

        -- Special case: single lowercase axis char (x/y/z) like max_x
        if tail:match("^[xyz]$") then
          new_tail = cycle_lower_axis_char(cycle_map, tail)
        else
          new_tail = transform_segment(tail, cycle_map)
        end

        return head .. sep .. new_tail
    end
  end

  return transform_segment(tok, cycle_map)
end

local function cycle_access(text, cycle_map)
  -- Match .x followed by end of string
  text = text:gsub("%.([xyz])$", function(axis)
    return "." .. cycle_lower_axis_char(cycle_map, axis)
  end)

  -- Match .x followed by non-word character
  text = text:gsub("%.([xyz])([^%w_])", function(axis, suffix)
    return "." .. cycle_lower_axis_char(cycle_map, axis) .. suffix
  end)

  -- Match " x" followed by end of string
  text = text:gsub("(%s)([xyz])$", function(ws, axis)
    return ws .. cycle_lower_axis_char(cycle_map, axis)
  end)

  -- Match " x" followed by close parens ")"
  text = text:gsub("(%s)([xyz])(%))", function(ws, axis, suffix)
    return ws .. cycle_lower_axis_char(cycle_map, axis) .. suffix
  end)

  return text
end

local function cycle_dimensions_line(text, cycle_map)
  text = cycle_access(text, cycle_map)

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

-- Tests.
local function run_tests()
  local f = forward_cycle_map
  local b = backward_cycle_map

  local tests = {
    -- forward cycles
    { "value_x",       "value_y",       f },
    { "value_z",       "value_x",       f },
    { "Y",             "Z",             f },
    { "localPoint.x",  "localPoint.y",  f },
    { "self.x_offset += dx;", "self.y_offset += dy;", f},
    -- TODO: We need the dimensions to rotate if they are alone at the end of a line.
    { "= x",           "= y",           f },
    { "min(min_x, x)", "min(min_y, y)", f },

    -- backward cycles
    { "value_x",      "value_z",      b },
    { "_x",           "_z",           b },
    { "Z",            "Y",            b },

    -- exclusion list
    { "MAX",          "MAX",          f },
    { "MAX_X",        "MAX_Y",        f },
    { "max_x",        "max_y",        f },
    { "index",        "index",        f },

    -- multi-match in one token
    { "z_to_x",       "x_to_y",       f },
  }

  for _, t in ipairs(tests) do
    local input, expected, map = t[1], t[2], t[3]
    local output = cycle_dimensions_line(input, map)
    assert(
      output == expected,
      string.format("Test failed: '%s' => '%s', expected '%s'", input, output, expected)
    )
  end
end

run_tests()

return M


