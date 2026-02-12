-- TODO: Try this out.
return {
  {
    "cbochs/portal.nvim",
    event = "VeryLazy",
    opts = {
      labels = { "a", "s", "d", "f" },
      select_first = true,
      window_options = {
        relative = "cursor",
        width = 70,
        height = 4,
        border = "rounded",
        focusable = false,
      },
    },
    keys = {
      {
        "<leader>pj",
        function() require("portal.builtin").jumplist.tunnel_backward() end,
        desc = "Portal: jumplist back",
      },
      {
        "<leader>pJ",
        function() require("portal.builtin").jumplist.tunnel_forward() end,
        desc = "Portal: jumplist forward",
      },
      {
        "<leader>pc",
        function() require("portal.builtin").changelist.tunnel_backward() end,
        desc = "Portal: changelist back",
      },
      {
        "<leader>pC",
        function() require("portal.builtin").changelist.tunnel_forward() end,
        desc = "Portal: changelist forward",
      },
      {
        "<leader>pq",
        function() require("portal.builtin").quickfix.tunnel() end,
        desc = "Portal: quickfix portals",
      },
    },
  },
}

