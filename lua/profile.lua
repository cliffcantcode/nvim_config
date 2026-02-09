-- Usage inside Neovim:
--   :StartProfile [/path/to/log]
--     (default: stdpath('config') .. "/logs/profiling/runtime.log")
--   [reproduce slow actions]
--   :StopProfile
--
-- This will produce:
--   - the raw :profile log
--   - a summary file: <log>.summary.txt with scripts sorted by total time
--   - a startup time log: <log>.startuptime.log (fresh headless start)
--   - a startup summary:  <log>.startuptime.log.summary.txt

local M = {}
local prof_file = nil

-- Startup timing (captured by spawning a headless Neovim with --startuptime)
local startup_log = nil
local startup_summary = nil
local startup_job = nil
local startup_job_err = nil

local function log(msg, level)
  vim.notify("[profile] " .. msg, level or vim.log.levels.INFO)
end

local function ensure_parent_dir(path)
  local dir = vim.fn.fnamemodify(path, ":h")
  if dir ~= "" and vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
end

local function with_suffix(path, suffix)
  if path:sub(-4) == ".log" then
    return path:sub(1, -5) .. suffix .. ".log"
  end
  return path .. suffix
end

local function get_nvim_bin()
  -- Prefer the currently-running Neovim binary.
  if vim.v.progpath and vim.v.progpath ~= "" then
    return vim.v.progpath
  end
  local p = vim.fn.exepath("nvim")
  if p and p ~= "" then
    return p
  end
  return "nvim"
end

local function summarize_startuptime(path, cmdline)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or not lines or vim.tbl_isempty(lines) then
    log("Could not read startuptime log: " .. path, vim.log.levels.ERROR)
    return nil
  end

  local events = {}
  local total_t = 0

  for _, line in ipairs(lines) do
    -- Typical format:
    --   000.012  000.004: sourcing ...
    local t, dt, msg = line:match("^%s*(%d+%.?%d*)%s+(%d+%.?%d*):%s*(.*)$")
    if t and dt and msg then
      local tt = tonumber(t) or 0
      local dtt = tonumber(dt) or 0
      total_t = math.max(total_t, tt)
      table.insert(events, { t = tt, dt = dtt, msg = msg })
    end
  end

  local function find_time(substr)
    substr = substr:lower()
    for _, e in ipairs(events) do
      if e.msg and e.msg:lower():find(substr, 1, true) then
        return e.t
      end
    end
    return nil
  end

  local function top_by_dt(filter_fn, n)
    local tmp = {}
    for _, e in ipairs(events) do
      if (not filter_fn) or filter_fn(e) then
        table.insert(tmp, e)
      end
    end
    table.sort(tmp, function(a, b)
      return (a.dt or 0) > (b.dt or 0)
    end)
    local out = {}
    for i = 1, math.min(n, #tmp) do
      table.insert(out, tmp[i])
    end
    return out
  end

  local function is_sourcing(e)
    if not e.msg then return false end
    return e.msg:match("^sourcing%s")
      or e.msg:match("^sourced%s")
      or e.msg:match("^loading%s")
  end

  local first_screen = find_time("first screen update")
  local vim_enter = find_time("VimEnter") or find_time("VimEnter autocommands")
  local ui_enter = find_time("UIEnter")

  local out = {}
  table.insert(out, "Neovim --startuptime summary")
  table.insert(out, ("Source: %s"):format(path))
  if cmdline and cmdline ~= "" then
    table.insert(out, ("Command: %s"):format(cmdline))
  end
  table.insert(out, "")
  table.insert(out, ("Total startup time (last timestamp): %.3fs"):format(total_t))
  if first_screen then
    table.insert(out, ("First screen update:               %.3fs"):format(first_screen))
  end
  if ui_enter then
    table.insert(out, ("UIEnter:                           %.3fs"):format(ui_enter))
  end
  if vim_enter then
    table.insert(out, ("VimEnter:                          %.3fs"):format(vim_enter))
  end
  table.insert(out, "")

  table.insert(out, "Top startup steps by Δ time (slowest first)")
  table.insert(out, string.format("%-10s %-10s %s", "Δ(s)", "At(s)", "Event"))
  table.insert(out, string.rep("-", 80))
  for _, e in ipairs(top_by_dt(nil, 30)) do
    table.insert(out, string.format("%10.3f %10.3f %s", e.dt or 0, e.t or 0, e.msg or ""))
  end
  table.insert(out, "")

  table.insert(out, "Top sourcing/loading steps by Δ time")
  table.insert(out, string.format("%-10s %-10s %s", "Δ(s)", "At(s)", "Event"))
  table.insert(out, string.rep("-", 80))
  for _, e in ipairs(top_by_dt(is_sourcing, 30)) do
    table.insert(out, string.format("%10.3f %10.3f %s", e.dt or 0, e.t or 0, e.msg or ""))
  end

  local summary_path = path .. ".summary.txt"
  local ok2, err = pcall(vim.fn.writefile, out, summary_path)
  if not ok2 then
    log("Failed to write startuptime summary: " .. tostring(err), vim.log.levels.ERROR)
    return nil
  end

  return summary_path
end

local function start_startuptime_capture(runtime_log_path)
  -- Build paths next to the runtime log, so everything is in one place.
  startup_log = with_suffix(runtime_log_path, ".startuptime")
  startup_summary = nil
  startup_job_err = nil

  -- Avoid showing stale results if this run fails.
  pcall(vim.fn.delete, startup_log)
  pcall(vim.fn.delete, startup_log .. ".summary.txt")
  ensure_parent_dir(startup_log)

  local nvim = get_nvim_bin()
  local cmd = {
    nvim,
    "--headless",
    "-i", "NONE", -- avoid shada contention while profiling
    "--startuptime", startup_log,
    "+qa",
  }
  local cmdline = table.concat(cmd, " ")

  startup_job = vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stderr = function(_, data)
      if data and type(data) == "table" then
        -- Capture last non-empty stderr line (useful if startup fails).
        for i = #data, 1, -1 do
          local line = data[i]
          if line and line ~= "" then
            startup_job_err = line
            break
          end
        end
      end
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        log(("startuptime capture failed (exit=%d)%s")
          :format(code, startup_job_err and (": " .. startup_job_err) or ""), vim.log.levels.WARN)
        return
      end

      if vim.fn.filereadable(startup_log) == 1 then
        startup_summary = summarize_startuptime(startup_log, cmdline)
      end
    end,
    env = (vim.env.NVIM_APPNAME and vim.env.NVIM_APPNAME ~= "")
      and { NVIM_APPNAME = vim.env.NVIM_APPNAME }
      or nil,
  })

  if startup_job <= 0 then
    startup_job = nil
    log("Failed to spawn headless Neovim for --startuptime", vim.log.levels.WARN)
    return
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

  -- Kick off a separate startup-time capture immediately.
  -- Note: this measures a fresh *headless* start of Neovim using your current config.
  start_startuptime_capture(out)

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

  -- If the startuptime job is still running for some reason, give it a moment.
  if startup_job and startup_job > 0 then
    pcall(vim.fn.jobwait, { startup_job }, 2000)
  end

  -- If the job finished but summary wasn't generated yet (e.g. you stopped quickly), try once.
  if startup_log and not startup_summary and vim.fn.filereadable(startup_log) == 1 then
    startup_summary = summarize_startuptime(startup_log, "")
  end

  local msg = {}
  table.insert(msg, "Profiling stopped.")
  table.insert(msg, ("  Runtime log:     %s"):format(log_path))
  if summary_path then
    table.insert(msg, ("  Runtime summary: %s"):format(summary_path))
  else
    table.insert(msg, "  Runtime summary: (not created)")
  end

  if startup_log then
    table.insert(msg, ("  Startup log:     %s"):format(startup_log))
    if startup_summary then
      table.insert(msg, ("  Startup summary: %s"):format(startup_summary))
    elseif startup_job_err then
      table.insert(msg, ("  Startup summary: (failed) %s"):format(startup_job_err))
    else
      table.insert(msg, "  Startup summary: (not created)")
    end
  end

  log(table.concat(msg, "\n"))
end, {
  desc = "Stop Neovim :profile and write a summary file",
})

return M

