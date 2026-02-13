return {
  {
    "stevearc/oil.nvim",
    cmd = "Oil",
    keys = {
      { "<leader>o", "<CMD>Oil<CR>", desc = "Open file explorer." },
    },
    dependencies = { "nvim-tree/nvim-web-devicons" },

    -- Runs even before the plugin is loaded (good for startup / directory args).
    init = function()
      local group = vim.api.nvim_create_augroup("OilAutoOpen", { clear = true })
      local preview_group = vim.api.nvim_create_augroup("OilPreviewDefault", { clear = true })

      local function is_empty_unnamed_buffer(bufnr)
        if vim.bo[bufnr].buftype ~= "" then return false end
        if vim.api.nvim_buf_get_name(bufnr) ~= "" then return false end
        if vim.bo[bufnr].modified then return false end

        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        return #lines == 1 and lines[1] == ""
      end

      local function has_real_file_buffer()
        for _, b in ipairs(vim.api.nvim_list_bufs()) do
          if vim.bo[b].buflisted and vim.bo[b].buftype == "" then
            local name = vim.api.nvim_buf_get_name(b)
            if name ~= "" and vim.fn.isdirectory(name) == 0 then
              return true
            end
          end
        end
        return false
      end

      local function open_oil(path)
        -- Avoid recursion / reopening inside Oil buffers
        if vim.bo.filetype == "oil" then return end
        if vim.bo.buftype ~= "" then return end

        if path and path ~= "" then
          pcall(vim.cmd, "Oil " .. vim.fn.fnameescape(path))
        else
          pcall(vim.cmd, "Oil")
        end
      end

      vim.api.nvim_create_autocmd({ "VimEnter", "BufEnter" }, {
        group = group,
        desc = "Auto-open Oil for directories or when landing on an empty buffer",
        callback = function()
          -- schedule() prevents fighting UI plugin windows during startup
          vim.schedule(function()
            if vim.bo.buftype ~= "" or vim.bo.filetype == "oil" then return end

            local name = vim.api.nvim_buf_get_name(0)

            -- If we are visiting a directory buffer, replace it with Oil.
            if name ~= "" and vim.fn.isdirectory(name) == 1 then
              open_oil(name)
              return
            end

            -- If we are on a blank unnamed buffer AND there are no real files open, show Oil.
            if is_empty_unnamed_buffer(0) and not has_real_file_buffer() then
              open_oil()
            end
          end)
        end,
      })

      -- Open the preview pane automatically when entering an Oil buffer.
      vim.api.nvim_create_autocmd("FileType", {
        group = preview_group,
        pattern = "oil",
        desc = "Oil: open preview window by default",
        callback = function()
          vim.schedule(function()
            local ok, oil = pcall(require, "oil")
            if not ok then return end
            pcall(oil.open_preview, {})
          end)
        end,
      })
    end,

    opts = {
      columns = { "icon" },
      keymaps = {
        ["<C-h>"] = false,
        ["<M-h>"] = "actions.select_split",
      },
      view_options = { show_hidden = true },
      default_file_explorer = true,
    },
  },
}

