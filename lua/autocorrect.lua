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
  ["Dispaly"] = "Display",
  ["gaurd"] = "guard",
  ["Gaurd"] = "Guard",
  ["amound"] = "amount",
  ["unsinged"] = "unsigned",
  ["Pinter"] = "Pointer",
  ["TOOD:"] = "TODO:",
  ["volumne"] = "volume",
  ["Visibale"] = "Visible",
  ["intialized"] = "initialized",
  ["defualt"] = "default",
  ["nvmi"] = "nvim",
  ["alliged"] = "aligned",
  ["minimmized"] = "minimized",
  ["OCCULUSION"] = "OCCLUSION",
  ["occulusion"] = "occlusion",
  ["CLOACKED"] = "CLOAKED",
  ["cloacked"] = "cloaked",
  ["Windwo"] = "Window",
  ["windwo"] = "window",
  ["MousE"] = "MouseE",
  ["deadxone"] = "deadzone",
  ["retrun"] = "return",
  ["hool_"] = "hook_",
  ["ytpe"] = "type",
  ["magnitued"] = "magnitude",
  ["utr%-8"] = "utf-8",
  ["remaineder"] = "remainder",
  ["advnace"] = "advance",
  ["Davice"] = "Device",
  ["INVALIDE_"] = "INVALID_",
  ["hanlde"] = "handle",
  ["artifcats"] = "artifacts",
  ["widht"] = "width",
  ["displaz"] = "display",
  ["nuetral"] = "neutral",
  ["bitmaks"] = "bitmask",
  ["tomosyntesis"] = "tomosynthesis",
  ["diagnositc"] = "diagnostic",
  ["indicies"] = "indices",
  ["extesion"] = "extension",
  ["Destory"] = "Destroy",
  ["destory"] = "destroy",
  ["desctroy"] = "destroy",
  ["Physcial"] = "Physical",
  ["Phystical"] = "Physical",
  ["buffes"] = "buffers",
  ["Cahce"] = "Cache",
  ["IMage"] = "Image",
  ["Pasrsing"] = "Parsing",
  ["progesteron_"] = "progesterone_",
  ["attatched"] = "attached",
  ["equivical"] = "equivocal",
  ["Vallue"] = "Value",
  ["exhauseted"] = "exhausted",
  ["Senario"] = "Scenario",
  ["intial"] = "initial",
  ["domian"] = "domain",
  ["Registerd"] = "Registered",
}

M.filetype_replacements = {
  lua = {
    ["funciton"] = "function",
  },
  cpp = {
    ["Hight"] = "High",
    ["strcut"] = "struct",
  },
  zig = {
    ["%f[%w]cont%f[%s]"] = "const",
    ["counst"] = "const",
    ["Ste%f[%W]"] = "Step",
    ["acces([^s])"] = "access%1",
    ["pun fn "] = "pub fn ",
    ["@scr%(%)"] = "@src()",
    ["scr_"] = "src_",
    ["strcut"] = "struct",
    ["impoart"] = "import",
    ["std.debug.asset"] = "std.debug.assert",
  },
  swift = {
    ["pointtee"] = "pointee",
    ["Visisible"] = "Visible",
  },
  python = {
    ["inenumerate"] = "in enumerate",
  },
  sql = {
    -- Some python items are duplicated for nested calls in sql.
    ["wher "] = "where ",
    ["inenumerate"] = "in enumerate",
  },
  markdown = {
    ["safesty"] = "safest",
    ["truely"] = "truly",
    ["responce"] = "response",
    ["regarless"] = "regardless",
    ["disposible"] = "disposable",
    ["thier"] = "their",
    ["inparticular"] = "in particular",
    ["meantion"] = "mention",
    ["comunicate"] = "communicate",
    ["secnario"] = "scenario",
    ["Teprum"] = "Tephrum",
    ["teprum"] = "tephrum",
    ["Tehprum"] = "Tephrum",
    ["tehprum"] = "tephrum",
    ["agnositc"] = "agnostic",
    ["opprotunity"] = "opportunity",
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

local function active_rules_for_text(text, rules)
  local active = {}

  for wrong, right in pairs(rules) do
    if text:find(wrong) then
      active[#active + 1] = { wrong = wrong, right = right }
    end
  end

  return active
end

local function apply_rules_to_line(line, rules)
  local edits = {}

  for _, rule in ipairs(rules) do
    local wrong, right = rule.wrong, rule.right
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

-- Apply replacements without polluting the changelist used by g; / g,.
local function autocorrect_buffer(bufnr, rules)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local active_rules = active_rules_for_text(table.concat(lines, "\n"), rules)
  if #active_rules == 0 then return end

  local changed = {}

  for i, orig_line in ipairs(lines) do
    if orig_line and orig_line ~= "" then
      local fixed = apply_rules_to_line(orig_line, active_rules)
      if fixed ~= orig_line then
        changed[#changed + 1] = { lnum = i, line = fixed }
      end
    end
  end

  if #changed == 0 then return end

  vim.api.nvim_buf_call(bufnr, function()
    local idx = 1
    while idx <= #changed do
      local start_lnum = changed[idx].lnum
      local replacement = { changed[idx].line }
      local next_idx = idx + 1

      while next_idx <= #changed and changed[next_idx].lnum == start_lnum + #replacement do
        replacement[#replacement + 1] = changed[next_idx].line
        next_idx = next_idx + 1
      end

      vim.b._autocorrect_lines = replacement
      vim.cmd(("silent keepjumps lockmarks call setline(%d, b:_autocorrect_lines)"):format(start_lnum))
      vim.b._autocorrect_lines = nil

      idx = next_idx
    end
  end)
end

-- Always-on tests (simple input → output)
function M.run_tests()
  local tests = {
    {
      ft = "zig",
      mistaken = "pub fn foo(cont x: i32) void {}",
      expected = "pub fn foo(const x: i32) void {}",
    },
    {
      ft = "zig",
      mistaken = "const CopySwiftSte = struct {",
      expected = "const CopySwiftStep = struct {",
    },
    {
      ft = "zig",
      mistaken = 'std.fs.cwd().acces("A_Game", .{}) catch {',
      expected = 'std.fs.cwd().access("A_Game", .{}) catch {',
    },
    {
      ft = "zig",
      mistaken = "std.fs.cwd().access(path, .{})",
      expected = "std.fs.cwd().access(path, .{})",
    },
    {
      ft = "any",
      mistaken = "Backgroun ",
      expected = "Background ",
    },
    {
      ft = "any",
      mistaken = "Aloc ",
      expected = "Alloc ",
    },
    {
      ft = "any",
      mistaken = "setNeedsDispaly(bounds)",
      expected = "setNeedsDisplay(bounds)",
    },
    {
      ft = "any",
      mistaken = "gaurd let buffer = ",
      expected = "guard let buffer = ",
    },
    {
      ft = "any",
      mistaken = "base_amound: i32",
      expected = "base_amount: i32",
    },
    {
      ft = "any",
      mistaken = "unsinged int",
      expected = "unsigned int",
    },
    {
      ft = "any",
      mistaken = "UnsafeMutablePinter",
      expected = "UnsafeMutablePointer",
    },
    {
      ft = "any",
      mistaken = "TOOD:",
      expected = "TODO:",
    },
    {
      ft = "swift",
      mistaken = "buffer.pointtee",
      expected = "buffer.pointee",
    },
    {
      ft = "swift",
      mistaken = "self.window?.isVisisible",
      expected = "self.window?.isVisible",
    },
    {
      ft = "any",
      mistaken = "self.tone_volumne = volume",
      expected = "self.tone_volume = volume",
    },
    {
      ft = "any",
      mistaken = "encoding: utr-8",
      expected = "encoding: utf-8",
    },
  }

  for _, t in ipairs(tests) do
    local rules = vim.tbl_extend(
      "force",
      M.replacements,
      M.filetype_replacements[t.ft] or {}
    )

    local out = apply_rules_to_line(t.mistaken, active_rules_for_text(t.mistaken, rules))

    if out ~= t.expected then
      error(
        "[autocorrect test failed]\n"
        .. "Input:    " .. t.mistaken .. "\n"
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


