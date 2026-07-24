return {
  "mattn/emmet-vim",
  ft = { "html", "css", "javascript" },
  config = function()
    -- Skip emmet-vim's own leader-key+suffix mechanism (defaults collide
    -- with blink.cmp's <C-e>/<C-y>, and the two-key ",%-suffix" is awkward
    -- either way). Bind the <Plug> mapping directly instead: one key, and
    -- <C-j> isn't claimed by blink or anything else in this config.
    local function map_expand(bufnr)
      vim.keymap.set("i", "<C-l>", "<Plug>(emmet-expand-abbr)", {
        buffer = bufnr,
        desc = "Emmet: expand abbreviation",
      })
    end

    map_expand(0) -- the buffer that triggered this ft-lazy load

    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("EmmetKeymaps", { clear = true }),
      pattern = { "html", "css", "javascript" },
      callback = function(args)
        map_expand(args.buf)
      end,
    })
  end,
}

