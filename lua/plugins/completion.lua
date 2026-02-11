local ollama_checked = false

return {
  {
    "milanglacier/minuet-ai.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    enabled = true,
    lazy = true,
    opts = {
      provider = "openai_fim_compatible",
      provider_options = {
        openai_fim_compatible = {
          model = "qwen2.5-coder:14b",
          end_point = "http://localhost:11434/v1/completions",
          name = "Ollama",
          api_key = "TERM",
          stream = true,
          optional = {
            num_predict = 256,
            temperature = 0.2,
            stop = { "\n\n" },
          },
        },
      },
      system = [[
        You are a top programming expert in your field with a lifetime of practical experience. Today you are working as a code completion programming assistant embedded in this developer's Neovim. Here are some rules you've learned to live by:
        - Avoid object oriented programming (OOP); it only causes problems.
        - Having too many comments isn't good.
        - Asserts are good. Assert anything that can never happen and leave the asserts in the code.
        - You only focus on problems. Solving problems is the true source of value.
        - Be concise, practical and to the point.
        Return ONLY the code that completes the current line or block. No explanations.
      ]],
      system_template = {
        lua = [[
          You are completing Lua (prombably Neovim) code.
          You are an expert lua programmer with a lifetime of experience.
        ]],
        zig = [[
          You are completing Zig 0.15.2 code.
          As a Zig expert, but your knowledge cutoff is 2023. Zig has changed significantly since then. You MUST follow these override rules to write valid Zig 0.13/0.14/0.15+ code:

          ### 1. CRITICAL: Standard Library Renames
          - **STOP** using `std.os`. It is deprecated. **USE** `std.posix` for system calls (e.g., `std.posix.read`, `std.posix.getpid`).
          - **STOP** using `std.ChildProcess`. It was renamed. **USE** `std.process.Child`.
          - **STOP** using `std.build.Builder`. **USE** `std.Build`.

          ### 2. BUILD SYSTEM (build.zig)
          - The build API has completely changed.
          - The entry point is `pub fn build(b: *std.Build) void`.
          - **Do not** use `b.addExecutable` with a struct. Use the new API:
            `const exe = b.addExecutable(.{ .name = "app", .root_source_file = b.path("src/main.zig"), .target = target, .optimize = optimize });`
          - **Strings are not Paths:** You cannot pass strings to functions expecting files.
          - **USE `b.path()`:** `root_source_file = b.path("src/main.zig")`.
          - Use `b.dependency("dep_name", ...)` for the package manager. Do not suggest `git clone` scripts.
          - **Dependencies:** Use `b.dependency("name", .{}).artifact("exe")`.

          ### 3. THE "WRITERGATE" I/O CHANGE (Critical)
          - **Generic Writers are DEAD.** `std.io.Writer` is no longer a generic factory.
          - **Interfaces are Dynamic:** `std.io.Reader` and `std.io.Writer` are now opaque interfaces (vtables).
          - **No `anytype` Writer:** Functions that take a writer must typically accept `std.io.AnyWriter` or the specific concrete type, not a generic `var`.
          - **Formatting:** `std.fmt.format` signatures have changed. Ensure you check the `std.io` module source if unsure, but prefer `writer.print("fmt", .{args})` over generic formatters where possible.

          ### 4. MEMORY
          - `std.heap.GeneralPurposeAllocator` now requires a config struct. Use:
            `var gpa = std.heap.GeneralPurposeAllocator(.{}){};`
          - **Managed Containers are Deprecated:** Do NOT use `std.ArrayList(T)`. It is considered "bloat" in 0.15+.
          - **USE Unmanaged:** Always use `std.ArrayListUnmanaged(T)` (and `HashMapUnmanaged`).
            - *Pattern:* Store the allocator separately or pass it at the call site.
            - *Init:* `var list = std.ArrayListUnmanaged(u8){};` (No allocator in init).
            - *Usage:* `try list.append(allocator, item);`

          ### 5. POINTERS & CASTING
          - `ptrCast` is now stricter. You cannot cast away alignment changes implicitly.
          - If changing alignment (e.g., `[]u8` to `*u32`), you MUST use `@alignCast`:
            `@as(*u32, @ptrCast(@alignCast(bytes)))`.
          - `const` pointers cannot be cast to mutable pointers without `@constCast`.
          - Do not use `ptrCast` to change const-ness; use `@constCast`.

          ### 6. SYNTAX & FEATURES
          - **NO ASYNC:** Do not use `async`, `await`, `suspend`, or `resume`. These features are currently disabled in the compiler.
          - **String Formatting:** `std.debug.print` still works, but ensure you use `.{}` for empty arguments.
          - **Loops:** `while (x) |item|` and `while (iter.next()) |item|` capture syntax is preferred over `while (x != null)`.
          - **Values:** `undefined` is dangerous; prefer optional `null` where possible.
          - **String Literals:** Multiline string literals usually require `\\`.
          - **Address-of-Temporary:** This is a compile error. You cannot do `&getThing()`. Store it in a `const` first.
        ]],
      }
    },
  },
  {
    "saghen/blink.cmp",
    dependencies = {
      "neovim/nvim-lspconfig",
    },
    event = 'InsertEnter',
    version = "*",
    config = function()
      local blink = require("blink.cmp")

      -- toggled on when Ollama is detected (or when you manually trigger Minuet)
      local minuet_enabled = false

      blink.setup({
        keymap = {
          preset = "default",
          ["<CR>"] = { "accept", "fallback" },
          ["<Tab>"] = { "accept", "fallback" },

          -- manual AI completion: loads minuet on demand, enables source, then shows it
          ["<C-g>"] = {
            function(cmp)
              require("lazy").load({ plugins = { "minuet-ai.nvim" } })
              minuet_enabled = true
              cmp.show({ providers = { "minuet" } })
            end,
          },
        },

        appearance = {
          use_nvim_cmp_as_default = true,
          nerd_font_variant = "mono",
        },

        completion = {
          ghost_text = { enabled = true },
        },

        sources = {
          -- Blink supports a function here (dynamic providers list)
          default = function()
            if minuet_enabled then
              return { "lsp", "buffer", "path", "minuet" }
            end
            return { "lsp", "buffer", "path" }
          end,

          providers = {
            minuet = {
              name = "minuet",
              module = "minuet.blink",
              score_offset = 100,
              async = true,
            },
          },
        },
      })

      vim.defer_fn(function()
        if ollama_checked then return end
        ollama_checked = true

        vim.system(
          { "curl", "-s", "-m", "1", "http://localhost:11434/api/tags" },
          { text = true },
          function(result)
            if result.code == 0 and result.stdout:match("models") then
              vim.schedule(function()
                require("lazy").load({ plugins = { "minuet-ai.nvim" } })
                minuet_enabled = true
              end)
            end
          end
        )
      end, 500)
    end,
  },
}

