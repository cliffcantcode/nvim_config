return {
     'andymass/vim-matchup',
     event = 'VeryLazy',
     init = function()
       vim.g.loaded_matchparen = 1  -- Also disable here for safety
       vim.g.matchup_matchparen_offscreen = { method = "popup" }
     end,
}

