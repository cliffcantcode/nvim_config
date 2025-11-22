local M = {}

local function ease_in_out_cubic(t)
    return (t < 0.5) and (4 * t * t * t) or (1 - (-2 * t + 2) ^ 3 / 2)
end

local function smooth_scroll(start_line, target_line)
    local current_line = vim.fn.line('.')
    if ((not start_line) or (not target_line) or (target_line == start_line)) then return end

    local distance = target_line - start_line
    local abs_distance = math.abs(distance)

    local max_steps = 30
    local steps = math.min(max_steps, abs_distance)
    local duration = math.min(600, 3 * abs_distance)  -- ms

    for i = 1, steps do
        vim.defer_fn(function()
            local progress = i / steps
            local eased = ease_in_out_cubic(progress)
            local new_line = math.floor(start_line + distance * eased)
            vim.api.nvim_win_set_cursor(0, {new_line, 0})
        end, (duration / steps) * i)
    end
end

local opts = { noremap = true, silent = true }

-- Jumps to top and bottom of page
vim.keymap.set('n', 'gg', function()
    local count = vim.v.count
    local target = count > 0 and count or 1
    smooth_scroll(vim.fn.line('.'), target)
end, opts)

vim.keymap.set('n', 'G', function()
    smooth_scroll(vim.fn.line('.'), vim.fn.line('$'))
end, opts)

return M

