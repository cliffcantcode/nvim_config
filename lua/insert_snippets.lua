-- Insert a language-specific for-loop template.
vim.keymap.set("n", "<leader>fl", function()
  local ft = vim.bo.filetype
  local template = ""

  if ft == "cpp" or ft == "c" then
    template = [[
for (u32 i = 0; i < N; ++i)
{
}
]]
  elseif ft == "zig" then
    template = [[
for (0..N) |i| {
}
]]
  elseif ft == "lua" then
    template = [[
for i = 1, N do
end
]]
  else
    vim.notify("No for-loop template for filetype: " .. ft, vim.log.levels.WARN)
    return
  end

  -- Split into lines and insert below the current line
  local lines = vim.split(template, "\n")
  local cur_line = vim.fn.line(".")
  vim.api.nvim_put(lines, "l", true, true)

  -- Determine range of inserted lines
  local first = cur_line + 1
  local last = cur_line + #lines

  -- Re-indent the inserted lines
  vim.cmd(string.format("silent %d,%dnormal! ==", first, last))

  -- Move cursor to the loop header line
  vim.api.nvim_win_set_cursor(0, { first, 0 })

  -- Open the substitution command for changing 'i'
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(":s/i//g", true, false, true), "n", false)

end, { desc = "Insert a [f]or-[l]oop template." })

-- Insert a language-specific assert call, cursor left inside the parens.
-- Shared by the normal-mode and insert-mode triggers below.
local function insert_assert_snippet()
  local ft = vim.bo.filetype
  local text = ""

  if ft == "zig" then
    text = "std.debug.assert();"
  elseif ft == "c" or ft == "cpp" then
    text = "assert();"
  elseif ft == "lua" then
    text = "assert()"
  elseif ft == "python" then
    text = "assert "
  elseif ft == "rust" then
    text = "assert!();"
  else
    vim.notify("No assert template for filetype: " .. ft, vim.log.levels.WARN)
    return
  end

  local line = vim.fn.line(".")
  local col = vim.fn.col(".") local current = vim.fn.getline(line)
  local before = current:sub(1, col - 1)
  local after = current:sub(col)

  -- Target column (just inside the opening paren, or after "assert " for
  -- python) computed before re-indenting, since `before` is what carries
  -- whatever indentation currently exists on the line.
  local old_indent = #(current:match("^%s*") or "")
  local offset = text:find("%(") or #text
  local target_col = #before + offset

  vim.fn.setline(line, before .. text .. after)

  -- Re-indent the line to match the surrounding block. This matters most
  -- when inserting on a blank line, where `before` carries no indentation
  -- of its own (col 1 -> ""), so the snippet would otherwise land at the
  -- start of the line instead of lined up with the code around it.
  vim.cmd(string.format("silent %d,%dnormal! ==", line, line))

  local new_indent = #(vim.fn.getline(line):match("^%s*") or "")
  target_col = target_col + (new_indent - old_indent)

  vim.api.nvim_win_set_cursor(0, { line, target_col })
end

-- <M-a>s in both modes: (M is the option key on mac) normal mode drops into insert after placing the
-- cursor, insert mode is already there. Alt is otherwise unused in this
-- config, so a single keystroke works without colliding with anything
-- (unlike Ctrl, which is already heavily claimed by blink.cmp and window
-- nav binds) and without overloading a key already in regular use.
vim.keymap.set("n", "<M-a><M-s>", function()
  insert_assert_snippet()
  vim.cmd("startinsert")
end, { desc = "Insert an [a]ssert [s]tatement." })

vim.keymap.set("i", "<M-a><M-s>", insert_assert_snippet, { desc = "Insert an [a]ssert [s]tatement." })

