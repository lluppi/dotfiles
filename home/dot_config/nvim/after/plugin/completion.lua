-- blink.cmp: replaces nvim-cmp, its 5 sources, LuaSnip and lspkind (snippets via vim.snippet + friendly-snippets)
require("blink.cmp").setup({
    keymap = {
        preset = "none",
        ["<C-b>"] = { "scroll_documentation_up", "fallback" },
        ["<C-f>"] = { "scroll_documentation_down", "fallback" },
        ["<A-i>"] = { "show", "fallback" },
        ["<CR>"] = { "accept", "fallback" },
        ["<C-n>"] = { "select_next", "fallback" },
        ["<C-p>"] = { "select_prev", "fallback" },
        ["<Tab>"] = { "select_and_accept", "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
        ["<Esc>"] = { "cancel", "fallback" },
    },

    completion = {
        list = { selection = { preselect = true, auto_insert = true } },
        menu = { border = "single" },
        documentation = { auto_show = true, window = { border = "single" } },
    },

    sources = {
        default = { "lsp", "snippets", "buffer", "path" },
        min_keyword_length = 2,
        per_filetype = {
            -- issues / PRs / mentions while writing a commit message
            gitcommit = { "git", "buffer" },
        },
        providers = {
            git = { module = "blink-cmp-git", name = "Git" },
        },
    },

    cmdline = {
        keymap = {
            preset = "cmdline",
            ["<Tab>"] = { "select_and_accept", "show" },
            ["<A-i>"] = { "show" },
        },
        completion = { menu = { auto_show = true } },
    },
})
