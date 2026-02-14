-- TODO: Doesn't work for the first two.
-- const headed = false // TODO: Comment blocking end of const declaration.
--
-- const prog_fireball = Program{
--         .ops = &.{.deal_damage_enemy_hero},
--         .a = &.{6},
--     }
--
-- const headless = false; // TODO: Comment blocking end of const declaration.
-- TODO: This case is also not working:
--             const y_started_near_center = @abs(ctrl.start_y) < 0.3

local M = {}

vim.api.nvim_create_autocmd("BufWritePre", {
  desc = "Fix a few common missing-semicolon cases before formatting (Zig via TS, C-like via heuristic)",
  group = vim.api.nvim_create_augroup("ContainerSemicolonFix", { clear = true }),
  pattern = { "*.zig", "*.c", "*.h", "*.cpp", "*.hpp" },
  callback = function()
    -- Save position / window state
    local view = vim.fn.winsaveview()

    local bufnr = vim.api.nvim_get_current_buf()
    local ft = vim.bo.filetype

    -----------------------------------------------------------------------
    -- Zig: Treesitter-based fix for missing semicolons
    -----------------------------------------------------------------------
    if ft == "zig" then
      local ok_ts, ts = pcall(require, "vim.treesitter")
      if not ok_ts then
        vim.fn.winrestview(view)
        return
      end

      local ok_parser, parser = pcall(ts.get_parser, bufnr, "zig")
      if not ok_parser or not parser then
        vim.fn.winrestview(view)
        return
      end

      local tree = parser:parse()[1]
      if not tree then
        vim.fn.winrestview(view)
        return
      end
      local root = tree:root()
      if not root then
        vim.fn.winrestview(view)
        return
      end

      local function get_line(buf, row)
        return vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
      end

      -- Strip a real trailing Zig line comment (//...), but ignore:
      -- - // inside normal strings: "http://..."
      -- - Zig multiline string literals that start with \\ outside a string/char
      local function strip_zig_line_comment(s)
        local in_str, in_char, esc = false, false, false
        local i, len = 1, #s

        while i <= len - 1 do
          local ch = s:sub(i, i)
          local nxt = s:sub(i + 1, i + 1)

          if in_str or in_char then
            if esc then
              esc = false
            elseif ch == "\\" then
              esc = true
            elseif in_str and ch == "\"" then
              in_str = false
            elseif in_char and ch == "'" then
              in_char = false
            end
            i = i + 1
          else
            if ch == "\"" then
              in_str = true
              i = i + 1
            elseif ch == "'" then
              in_char = true
              i = i + 1
            elseif ch == "\\" and nxt == "\\" then
              -- Zig multiline string literal: rest of line is string content.
              return s
            elseif ch == "/" and nxt == "/" then
              return s:sub(1, i - 1)
            else
              i = i + 1
            end
          end
        end

        return s
      end

      local function rtrim(s)
        return (s:gsub("%s+$", ""))
      end

      -- Robust statement end:
      -- - Works even when TS end column is 0 (common when ';' is missing and recovery kicks in)
      -- - Inserts before trailing // comments
      local function last_code_pos_in_node(node)
        local sr, _, er, ec = node:range()
        local last_row = vim.api.nvim_buf_line_count(bufnr) - 1
        if er > last_row then er = last_row end

        for row = er, sr, -1 do
          local line = get_line(bufnr, row) or ""
          local upto = #line

          if row == er then
            -- ec is 0-based exclusive
            upto = math.min(ec, #line)
          end

          if upto > 0 then
            local prefix = line:sub(1, upto)
            prefix = rtrim(strip_zig_line_comment(prefix))
            if #prefix > 0 then
              -- insertion col is 0-based == prefix length
              return row, #prefix
            end
          end
        end

        return nil
      end

      -- Collect edits first; apply from bottom->top so earlier inserts don't shift later ranges.
      local inserts = {}
      local seen = {}

      local function add_insert(row, col)
        if row < 0 or col < 0 then return end
        local key = row .. ":" .. col
        if seen[key] then return end
        seen[key] = true
        table.insert(inserts, { row = row, col = col })
      end

      local function needs_semicolon(row, col)
        local line = get_line(bufnr, row)
        if not line then return false end

        -- Clamp insertion to EOL.
        if col > #line then col = #line end

        -- If there's already a ';' or ',' at/after insertion point, do nothing.
        local after = line:sub(col + 1) -- col is 0-based
        if after:match("^%s*[;,]") then
          return false
        end

        -- If the last non-space char before insertion is already ';' or ',', do nothing.
        local before = line:sub(1, col)
        if before:match("[;,]%s*$") then
          return false
        end

        return true
      end

      local function node_text(node)
        -- Neovim API moved this over time; support both.
        if vim.treesitter.get_node_text then
          local ok, txt = pcall(vim.treesitter.get_node_text, node, bufnr)
          if ok then return txt end
        end
        if vim.treesitter.query and vim.treesitter.query.get_node_text then
          local ok, txt = pcall(vim.treesitter.query.get_node_text, node, bufnr)
          if ok then return txt end
        end
        return nil
      end

      local const_modifiers = {
        pub = true,
        export = true,
        extern = true,
        comptime = true,
        inline = true,
        noinline = true,
        threadlocal = true,
      }

      local function is_const_variable_declaration(node)
        local txt = node_text(node)
        if not txt then return false end

        local seen_tok = 0
        for tok in txt:gmatch("%S+") do
          seen_tok = seen_tok + 1
          if not const_modifiers[tok] then
            return tok == "const" or tok == "var"
          end
          if seen_tok >= 12 then
            break
          end
        end
        return false
      end

      local container_kinds = {
        struct_declaration = true,
        union_declaration = true,
        enum_declaration = true,
        opaque_declaration = true,
      }

      local function visit(node)
        local kind = node:type()

        -- 1) struct/union/enum/opaque literals: ensure `};` (or `},` in comma contexts).
        if container_kinds[kind] then
          local row, col = last_code_pos_in_node(node)
          if row and col then
            local line = get_line(bufnr, row)
            local last_ch = line and line:sub(col, col) or nil -- col is len(prefix) => last char (1-based)
            if last_ch == "}" then
              add_insert(row, col) -- insert after last char
            end
          end
        end

        -- 2) `const` variable declarations: ensure they end with `;`.
        if kind == "variable_declaration" and is_const_variable_declaration(node) then
          local row, col = last_code_pos_in_node(node)
          if row and col then
            add_insert(row, col)
          end
        end

        local n = node:named_child_count()
        for i = 0, n - 1 do
          local child = node:named_child(i)
          if child then visit(child) end
        end
      end

      visit(root)

      table.sort(inserts, function(a, b)
        if a.row ~= b.row then
          return a.row > b.row
        end
        return a.col > b.col
      end)

      for _, pos in ipairs(inserts) do
        if needs_semicolon(pos.row, pos.col) then
          vim.api.nvim_buf_set_text(bufnr, pos.row, pos.col, pos.row, pos.col, { ";" })
        end
      end

      -- Restore the cursor / view
      vim.fn.winrestview(view)
      return
    end

    -----------------------------------------------------------------------
    -- C / C++ / headers: simple heuristic
    -----------------------------------------------------------------------
    local is_c_like = (ft == "cpp" or ft == "c" or ft == "h" or ft == "hpp")
    if not is_c_like then
      vim.fn.winrestview(view)
      return
    end

    local line_count = vim.api.nvim_buf_line_count(bufnr)
    if line_count == 0 then
      vim.fn.winrestview(view)
      return
    end

    -- Find the last nonblank line
    local end_line = nil
    for l = line_count - 1, 0, -1 do
      local txt = vim.api.nvim_buf_get_lines(bufnr, l, l + 1, false)[1]
      if txt and txt:find("%S") then
        end_line = l
        break
      end
    end
    if not end_line then
      vim.fn.winrestview(view)
      return
    end

    local text = vim.api.nvim_buf_get_lines(bufnr, end_line, end_line + 1, false)[1]
    if not text then
      vim.fn.winrestview(view)
      return
    end

    -- Only touch "}"/";" shaped endings
    if not text:match("^%s*}%s*$") then
      vim.fn.winrestview(view)
      return
    end

    -- Already has semicolon like "};"
    if text:match(";%s*$") then
      vim.fn.winrestview(view)
      return
    end

    -- Look upward for struct/union/enum on previous nonblank line
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

    if not has_container then
      vim.fn.winrestview(view)
      return
    end

    -- Append semicolon at end of last line
    vim.api.nvim_buf_set_lines(bufnr, end_line, end_line + 1, false, {
      text .. ";",
    })

    vim.fn.winrestview(view)
  end,
})

---------------------------------------------------------------------------
-- Formatter: only rewrite when there are real changes
---------------------------------------------------------------------------

M.formatters = {
  zig = "zig fmt --stdin",
}

local function format_buffer(cmd)
  local buf = vim.api.nvim_get_current_buf()
  local view = vim.fn.winsaveview()

  -- Capture current buffer text
  local old_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local old_text = table.concat(old_lines, "\n")

  -- Run formatter
  local formatted = vim.fn.system(cmd, old_text)

  if vim.v.shell_error ~= 0 then
    vim.notify("Formatter error:\n" .. formatted, vim.log.levels.ERROR)
    vim.fn.winrestview(view)
    return
  end

  -- If nothing changed (allow for trailing newline differences), skip rewrite
  if formatted == old_text or formatted == old_text .. "\n" then
    vim.fn.winrestview(view)
    return
  end

  -- Split and replace the buffer with formatted text
  local new_lines = vim.split(formatted, "\n", { trimempty = false })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)

  -- Restore the cursor / view
  vim.fn.winrestview(view)
end

vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.zig",
  callback = function()
    local ft = vim.bo.filetype
    local cmd = M.formatters[ft]
    if cmd then
      format_buffer(cmd)
    end
  end,
})

return M

