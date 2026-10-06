-- import nvim-autopairs safely
local autopairs_setup, autopairs = pcall(require, "nvim-autopairs")
if not autopairs_setup then
    return
end

local Rule = require("nvim-autopairs.rule")
local cond = require("nvim-autopairs.conds")

-- configure autopairs
autopairs.setup({
    check_ts = true,                        -- enable treesitter
    ts_config = {
        lua = { "string" },                 -- don't add pairs in lua string treesitter nodes
        javascript = { "template_string" }, -- don't add pairs in JavaScript template_string treesitter nodes
        java = false,                       -- don't check treesitter on Java
    },
})


local brackets = { { '(', ')' }, { '[', ']' }, { '{', '}' } }

autopairs.add_rules {
    -- rule for a pair with left-side ' ' and right side ' '
    Rule(' ', ' ')
        -- pair will only occur if the conditional function returns true
        :with_pair(function(opts)
            -- we are checking if we are inserting a space in (), [], or {}
            local pair = opts.line:sub(opts.col - 1, opts.col)
            return vim.tbl_contains({
                brackets[1][1] .. brackets[1][2],
                brackets[2][1] .. brackets[2][2],
                brackets[3][1] .. brackets[3][2]
            }, pair)
        end)
        :with_move(cond.none())
        :with_cr(cond.none())
        -- we only want to delete the pair of spaces when the cursor is as such: ( | )
        :with_del(function(opts)
            local col = vim.api.nvim_win_get_cursor(0)[2]
            local context = opts.line:sub(col - 1, col + 2)
            return vim.tbl_contains({
                brackets[1][1] .. '  ' .. brackets[1][2],
                brackets[2][1] .. '  ' .. brackets[2][2],
                brackets[3][1] .. '  ' .. brackets[3][2]
            }, context)
        end)
}
-- for each pair of brackets we will add another rule
for _, bracket in pairs(brackets) do
    autopairs.add_rules {
        -- each of these rules is for a pair with left-side '( ' and right-side ' )' for each bracket type
        Rule(bracket[1] .. ' ', ' ' .. bracket[2])
            :with_pair(cond.none())
            :with_move(function(opts) return opts.char == bracket[2] end)
            :with_del(cond.none())
            :use_key(bracket[2])
            -- removes the trailing whitespace that can occur without this
            :replace_map_cr(function(_) return '<c-c>2xi<cr><c-c>o' end)
    }
end

-- import nvim-autopairs completion functionality safely
local cmp_autopairs_setup, cmp_autopairs = pcall(require, "nvim-autopairs.completion.cmp")
if not cmp_autopairs_setup then
    return
end

-- import nvim-cmp plugin safely (completions plugin)
local cmp_setup, cmp = pcall(require, "cmp")
if not cmp_setup then
    return
end

-- make autopairs and completion work together
cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
