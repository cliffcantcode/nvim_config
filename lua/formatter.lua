local M = {}

M.formatters = {
  zig = "zig fmt --stdin",
}

local function format_buffer(cmd)
  local buf = vim.api.nvim_get_current_buf()
  local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")

  local formatted = vim.fn.system(cmd, text)

  if vim.v.shell_error == 0 then
    local lines = vim.split(formatted, "\n", { trimempty = false })
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  else
    vim.notify("Formatter error:\n" .. formatted, vim.log.levels.ERROR)
  end
end

vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*",
  callback = function()
    local ft = vim.bo.filetype
    local cmd = M.formatters[ft]
    if cmd then
      format_buffer(cmd)
    end
  end,
})

return M

