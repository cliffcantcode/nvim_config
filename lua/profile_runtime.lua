-- Usage inside Neovim:
--   :StartProfile [/path/to/log]
--     (default: stdpath('cache') .. "/nvim-profile.log")
--   [reproduce slow actions]
--   :StopProfile
--
-- This will produce:
--   - the raw :profile log
--   - a summary file: <log>.summary.txt with scripts sorted by total time

local M = {}
local prof_file = nil

local function log(msg, level)
  vim.notify("[profile] " .. msg, level or vim.log.levels.INFO)
end

local function ensure_parent_dir(path)
  local dir = vim.fn.fnamemodify(path, ":h")
  if dir ~= "" and vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
end

-- Parse :profile log and produce a human-readable summary
local function summarize_profile(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or not lines or vim.tbl_isempty(lines) then
    log("Could not read profile log: " .. path, vim.log.levels.ERROR)
    return nil
  end

  -- Aggregate per SCRIPT
  local scripts = {}

  local i = 1
  while i <= #lines do
    local line = lines[i]
    local script_path = line:match("^SCRIPT%s+(.*)")
    if script_path then
      local count = 1
      local total = 0.0
      local self_t = 0.0

      local l2 = lines[i + 1] or ""
      local n = l2:match("^Sourced%s+(%d+)%s+time")
      if n then count = tonumber(n) or 1 end

      local l3 = lines[i + 2] or ""
      local t = l3:match("^Total time:%s+([%d%.]+)")
      if t then total = tonumber(t) or 0 end

      local l4 = lines[i + 3] or ""
      local s = l4:match("^%s*Self time:%s+([%d%.]+)")
      if s then self_t = tonumber(s) or 0 end

      local existing = scripts[script_path]
      if existing then
        existing.count = existing.count + count
        existing.total = existing.total + total
        existing.self = existing.self + self_t
      else
        scripts[script_path] = {
          path = script_path,
          count = count,
          total = total,
          self = self_t,
        }
      end
    end
    i = i + 1
  end

  local list = {}
  for _, s in pairs(scripts) do
    table.insert(list, s)
  end

  table.sort(list, function(a, b)
    if a.total == b.total then
      return (a.self or 0) > (b.self or 0)
    end
    return (a.total or 0) > (b.total or 0)
  end)

  local out = {}
  table.insert(out, "Neovim :profile summary (slowest scripts first)")
  table.insert(out, ("Source: %s"):format(path))
  table.insert(out, "")
  table.insert(out, string.format("%-6s %-10s %-10s %s", "Count", "Total(s)", "Self(s)", "Script"))
  table.insert(out, string.rep("-", 80))

  for _, s in ipairs(list) do
    if s.total and s.total > 0 then
      table.insert(out, string.format(
        "%6d %10.3f %10.3f %s",
        s.count or 0,
        s.total or 0,
        s.self or 0,
        s.path
      ))
    end
  end

  local summary_path = path .. ".summary.txt"
  local ok2, err = pcall(vim.fn.writefile, out, summary_path)
  if not ok2 then
    log("Failed to write profile summary: " .. tostring(err), vim.log.levels.ERROR)
    return nil
  end

  return summary_path
end

-- :StartProfile [file]
vim.api.nvim_create_user_command("StartProfile", function(opts)
  if prof_file then
    log("Profile already running → " .. prof_file, vim.log.levels.WARN)
    return
  end

  local out = opts.args
  if out == "" then
    out = vim.fn.stdpath('config') .. "/logs/profiling/runtime.log"
  else
    out = vim.fn.expand(out)
  end

  ensure_parent_dir(out)
  prof_file = out

  local ok, err = pcall(function()
    vim.cmd("profile start " .. vim.fn.fnameescape(out))
    vim.cmd("profile file *")
    vim.cmd("profile func *")
  end)

  if not ok then
    log("Failed to start :profile: " .. tostring(err), vim.log.levels.ERROR)
    prof_file = nil
    return
  end

  log("Profiling started → " .. out)
end, {
  nargs = "?",
  complete = "file",
  desc = "Start Neovim :profile into a log file",
})

-- :StopProfile
vim.api.nvim_create_user_command("StopProfile", function()
  if not prof_file then
    log("No active profile. Use :StartProfile first.", vim.log.levels.WARN)
    return
  end

  local log_path = prof_file

  -- Stop profiling; wrap in pcall so old builds don’t explode
  pcall(vim.cmd, "profile pause")
  pcall(vim.cmd, "profile stop")

  -- Clear state before we do any I/O
  prof_file = nil

  local summary_path = summarize_profile(log_path)

  if summary_path then
    log(("Profiling stopped.\n  Log:     %s\n  Summary: %s")
      :format(log_path, summary_path))
  else
    log("Profiling stopped. Log: " .. log_path .. " (no summary created)")
  end
end, {
  desc = "Stop Neovim :profile and write a summary file",
})

return M

