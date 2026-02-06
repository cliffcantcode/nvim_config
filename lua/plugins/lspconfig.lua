-- LSP Plugins
return {
  "neovim/nvim-lspconfig",
  config = function()
    local capabilities = require("blink.cmp").get_lsp_capabilities()

    vim.lsp.config("zls", {
      capabilities = capabilities,
      root_dir = vim.fs.root(0, {
        "build.zig",
        "build.zig.zon",
        ".git",
      }),
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
        map('<leader>gd', require('telescope.builtin').lsp_definitions,      '[G]oto [D]efinition')
        map('<leader>gr', require('telescope.builtin').lsp_references,       '[G]oto [R]eferences')
        map('<leader>gt', require('telescope.builtin').lsp_type_definitions, '[G]oto [T]ype Definition')
        map('<leader>gi', require('telescope.builtin').lsp_implementations,  '[G]oto [I]mplementations')
        map("<leader>ds", require('telescope.builtin').lsp_document_symbols, '[d]ocument [s]ymbols')
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

