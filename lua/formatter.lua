local M = {}

vim.api.nvim_create_autocmd("BufWritePre", {
  desc = "Ensure container declarations end with a semicolon (Zig via TS, C-like via heuristic)",
  group = vim.api.nvim_create_augroup("ContainerSemicolonFix", { clear = true }),
  pattern = { "*.zig", "*.c", "*.h", "*.cpp", "*.hpp" },
  callback = function()
    local bufnr = vim.api.nvim_get_current_buf()
    local ft = vim.bo.filetype

    ---------------------------------------------------------------------------
    -- Zig: Treesitter-based fix for struct/union/enum declarations
    ---------------------------------------------------------------------------
    if ft == "zig" then
      local ok_ts, ts = pcall(require, "vim.treesitter")
      if not ok_ts then return end

      local ok_parser, parser = pcall(ts.get_parser, bufnr, "zig")
      if not ok_parser or not parser then return end

      local tree = parser:parse()[1]
      if not tree then return end
      local root = tree:root()
      if not root then return end

      local function get_line(buf, row)
        return vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
      end

      local function insert_semicolon(buf, row, col_after)
        -- Insert ";" at (row, col_after) — col_after is 0-based
        vim.api.nvim_buf_set_text(buf, row, col_after, row, col_after, { ";" })
      end

      -- All container-like declarations we care about in Zig
      local container_kinds = {
        struct_declaration = true,
        union_declaration  = true,
        enum_declaration   = true,
      }

      local function visit(node)
        local kind = node:type()

        if container_kinds[kind] then
          local sr, sc, er, ec = node:range()
          local line = get_line(bufnr, er)
          if line then
            -- ec is end-exclusive, so last column in node on this line is ec - 1
            local last_col_in_node = math.min(ec, #line) - 1
            if last_col_in_node >= 0 then
              local ch = line:sub(last_col_in_node + 1, last_col_in_node + 1)
              if ch == "}" then
                local after = line:sub(last_col_in_node + 2)
                -- Only add ';' if there isn't already one right after the '}'
                if not after:match("^%s*;") then
                  insert_semicolon(bufnr, er, last_col_in_node + 1)
                end
              end
            end
          end
        end

        local n = node:named_child_count()
        for i = 0, n - 1 do
          local child = node:named_child(i)
          if child then visit(child) end
        end
      end

      visit(root)
      return
    end

    ---------------------------------------------------------------------------
    -- C / C++ / headers: simple, safe heuristic
    ---------------------------------------------------------------------------
    local is_c_like = (ft == "c" or ft == "cpp" or ft == "objc" or ft == "objcpp"
      or ft == "h" or ft == "hpp")
    if not is_c_like then
      return
    end

    local line_count = vim.api.nvim_buf_line_count(bufnr)
    if line_count == 0 then return end

    -- Find the last nonblank line
    local end_line = nil
    for l = line_count - 1, 0, -1 do
      local txt = vim.api.nvim_buf_get_lines(bufnr, l, l + 1, false)[1]
      if txt and txt:find("%S") then
        end_line = l
        break
      end
    end
    if not end_line then return end

    local text = vim.api.nvim_buf_get_lines(bufnr, end_line, end_line + 1, false)[1]
    if not text then return end

    -- Heuristic: only fix the very common pattern:
    --   struct Foo { ... }
    -- where the last line is just "}" (optionally with spaces).
    -- We do NOT try to fix 'typedef struct { ... } Foo' etc., because inserting
    -- ';' in the wrong spot can change meaning.
    if not text:match("^%s*}%s*$") then
      return
    end

    -- Already has semicolon like "};"
    if text:match(";%s*$") then
      return
    end

    -- Look upward for struct/union/enum on the previous nonblank line
    local has_container = false
    for l = end_line - 1, 0, -1 do
      local up = vim.api.nvim_buf_get_lines(bufnr, l, l + 1, false)[1]
      if up and up:find("%S") then
        if up:find("%f[%w]struct%f[%W]")
          or up:find("%f[%w]union%f[%W]")
          or up:find("%f[%w]enum%f[%W]") then
          has_container = true
        end
        break
      end
    end

    if not has_container then return end

    -- Append semicolon at end of last line
    vim.api.nvim_buf_set_lines(bufnr, end_line, end_line + 1, false, {
      text .. ";",
    })
  end,
})

-- Run language specific formatters.
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

