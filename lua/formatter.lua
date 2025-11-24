local M = {}

local formatters = {
  zig = "zig fmt",
}

vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*",
  callback = function()
    local ft = vim.bo.filetype
    local fmt = formatters[ft]

    if fmt then
      local cmd = ""
      if fmt == "zig fmt" then
        cmd = string.format("%s %s", fmt, vim.fn.shellescape(vim.api.nvim_buf_get_name(0)))
      end
      vim.fn.jobstart(cmd, { stdout_buffered = true })
    end
  end,
})

return M

