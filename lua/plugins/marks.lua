return {
  {
    "chentoast/marks.nvim",
    event = "VeryLazy",
    opts = {
      default_mappings = true, -- set false if you want zero new mappings
      builtin_marks = { ".", "<", ">", "^" },
      cyclic = true,

      -- Performance knob (higher = less redraw cost, more visual lag)
      refresh_interval = 250,
    },
  },
}

