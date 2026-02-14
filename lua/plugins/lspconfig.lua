-- LSP Plugins
return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities.textDocument.completion.completionItem.snippetSupport = true
    capabilities.textDocument.completion.completionItem.resolveSupport = {
      properties = { "documentation", "detail", "additionalTextEdits" },
    }

    -- Helper: find a project root, but still allow "single file" fallback
    local function root_or_file_dir(bufnr, markers)
      local root = vim.fs.root(bufnr, markers)
      if root then return root end

      local fname = vim.api.nvim_buf_get_name(bufnr)
      if fname == "" then
        return vim.fn.getcwd()
      end
      return vim.fn.fnamemodify(fname, ":p:h")
    end

    vim.lsp.config("zls", {
      capabilities = capabilities,

      root_dir = function(bufnr, on_dir)
        on_dir(root_or_file_dir(bufnr, { "build.zig", "build.zig.zon", ".git" }))
      end,

      single_file_support = true,
      settings = {
        zls = {
          enable_snippets = true,
          enable_autofix = true,
        },
      },
    })

    vim.lsp.config("sourcekit", {
      capabilities = capabilities,
      cmd = { "xcrun", "sourcekit-lsp" },
      filetypes = { "swift" },

      root_dir = function(bufnr, on_dir)
        on_dir(root_or_file_dir(bufnr, { "Package.swift", ".git" }))
      end,

      single_file_support = true,
    })

    vim.lsp.enable({ "zls", "sourcekit" })

    -- LSP keymaps (buffer-local, only when an LSP actually attaches)
    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("LspKeymaps", { clear = true }),
      callback = function(event)
        local map = function(keys, func, desc, mode)
          mode = mode or "n"
          vim.keymap.set(mode, keys, func, {
            buffer = event.buf,
            desc = "LSP: " .. desc,
          })
        end

        -- Optional: telescope fallback so gd still works even if Telescope isn't loaded yet
        local function tb(fn, fallback)
          return function()
            local ok, t = pcall(require, "telescope.builtin")
            if ok then return t[fn]() end
            return fallback()
          end
        end

        map("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")

        map("<leader>gd", tb("lsp_definitions", vim.lsp.buf.definition), "[G]oto [D]efinition")
        map("<leader>gr", tb("lsp_references", vim.lsp.buf.references), "[G]oto [R]eferences")
        map("<leader>gt", tb("lsp_type_definitions", vim.lsp.buf.type_definition), "[G]oto [T]ype Definition")
        map("<leader>gi", tb("lsp_implementations", vim.lsp.buf.implementation), "[G]oto [I]mplementations")
        map("<leader>ds", tb("lsp_document_symbols", vim.lsp.buf.document_symbol), "[d]ocument [s]ymbols")

        map("<leader>th", function()
          local ih = vim.lsp.inlay_hint
          if not ih then return end
          local buf = event.buf
          local enabled = ih.is_enabled({ bufnr = buf })
          ih.enable(not enabled, { bufnr = buf })
        end, "[t]oggle [h]ints.")
      end,
    })
  end,
}

