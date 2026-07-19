std = "luajit"

globals = {
  "vim",
  "MiniBufremove", -- injected by mini.nvim's mini.bufremove module, not a real undefined global
}

-- This config has no line-length convention (long rule-description strings,
-- multi-line templates); the default 120-col check is pure noise here.
max_line_length = false
