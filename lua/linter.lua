local M = {}

-- Add patterns for common mistakes
M.patterns = {
    { regex = ">%s*[%w_%.]*[Mm]ax[_%w]*",  message = "'>' points away from the Max. | " },
    { regex = "<%s*[%w_%.]*[Mm]in[_%w]*",  message = "'<' points away from the Min. | " },
    { regex = "[%w_%.]*[Mm]ax[_%w]*%s*<",  message = "'<' points away from the Max. | " },
    { regex = "[%w_%.]*[Mm]in[_%w]*%s*>",  message = "'>' points away from the Min. | " },
}

local comment_markers = {
    lua   = "%-%-",
    python= "#",  
    sh    = "#", 
    bash  = "#",
    c     = "//",
    cpp   = "//",
    java  = "//",
    javascript = "//", 
    typescript = "//",
    rust  = "//",    
    zig  = "//",    
}

local function is_text_file(path)
    local stat = vim.loop.fs_stat(path)
    if not stat or stat.size == 0 then
        return false
    end

    local fd = vim.loop.fs_open(path, "r", 438)
    if not fd then return false end

    local max_read = math.min(2048, stat.size)
    local chunk = vim.loop.fs_read(fd, max_read, 0)
    vim.loop.fs_close(fd)

    return chunk and not chunk:find("\0")
end

local function truncate_line(line, max_len)
    max_len = max_len or 80
    line = line:match("^%s*(.-)%s*$") -- trim
    if #line > max_len then
        return line:sub(1, max_len) .. "…"
    end
    return line
end

function M.lint_current_buffer(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local ft = vim.api.nvim_buf_get_option(bufnr, "filetype") or ""
    local comment_marker = comment_markers[ft]

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local full_path = vim.api.nvim_buf_get_name(bufnr)
    local results = {}

    for i, line in ipairs(lines) do
        local trimmed = line:match("^%s*(.-)%s*$")
        -- Skip if it's a comment line
        if not (comment_marker and trimmed:match("^" .. comment_marker)) then
            for _, p in ipairs(M.patterns) do
                if string.find(line, p.regex) then
                    table.insert(results, {
                        filename = full_path,
                        lnum = i,
                        col = 0,
                        text = p.message .. truncate_line(line, 60),
                        type = "W",
                    })
                end
            end
        end
    end

    return results
end

function M.lint_file()
    local buf = vim.api.nvim_get_current_buf()
    local items = M.lint_current_buffer(buf)
    vim.fn.setloclist(0, items, "r")
    vim.cmd("lopen")
end

vim.keymap.set("n", "<leader>lf", function()
    M.lint_file()
end, { desc = '[l]int [f]ile' })

return M

