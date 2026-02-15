return
{
    'numToStr/Comment.nvim',
    opts = {},

    -- TODO: This isn't working in zig. It sets the timestamp but its not commented.
    -- Paste current timestamp at the end of the line.  2025-05-30 15:27:09
    vim.keymap.set('n', '<leader>ts', "A <C-r>=strftime('%Y-%m-%d %H:%M:%S')<CR><Esc>2B<Plug>(comment_toggle_linewise)$", { desc = 'Append [t]ime[s]tamp' }),

}

