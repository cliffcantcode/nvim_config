-- LSP Plugins
return {
  "neovim/nvim-lspconfig",
  event = 'BufReadPre',
  config = function()
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities.textDocument.completion.completionItem.snippetSupport = true
    capabilities.textDocument.completion.completionItem.resolveSupport = {
      properties = { "documentation", "detail", "additionalTextEdits" },
    }

    vim.lsp.config("zls", {
      capabilities = capabilities,
      root_dir = function(bufnr)
        return vim.fs.root(bufnr, { "build.zig", "build.zig.zon", ".git" })
      end,
      single_file_support = true,
      settings = {
        zls = {
          enable_snippets = true,
          enable_autofix = true,
        },
      },
    })

    -- Autostart the server (also new API)
    vim.lsp.enable("zls")

    vim.lsp.config("sourcekit", {
      capabilities = capabilities,
      cmd = { "xcrun", "sourcekit-lsp"},
      filetypes = { "swift" },
      root_dir = vim.fs.root(0, {
        "Package.swift",
        ".git",
        "*.xcodeproj",
        "*.xcworkspace",
      }),

      single_file_support = true,
    })
    vim.lsp.enable("sourcekit")

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

        map("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")
        map('<leader>gd', function() require('telescope.builtin').lsp_definitions() end,      '[G]oto [D]efinition')
        map('<leader>gr', function() require('telescope.builtin').lsp_references() end,       '[G]oto [R]eferences')
        map('<leader>gt', function() require('telescope.builtin').lsp_type_definitions() end, '[G]oto [T]ype Definition')
        map('<leader>gi', function() require('telescope.builtin').lsp_implementations() end,  '[G]oto [I]mplementations')
        map("<leader>ds", function() require('telescope.builtin').lsp_document_symbols() end, '[d]ocument [s]ymbols')
        map("<leader>th", function()
          local ih = vim.lsp.inlay_hint
          if not ih then return end

          local buf = event.buf
          local enabled = ih.is_enabled({ bufnr = buf })
          ih.enable(not enabled, { bufnr = buf })
        end, "[t]oggle [h]ints.")
      end,
    })
  end
}

