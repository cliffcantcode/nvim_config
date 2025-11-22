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

