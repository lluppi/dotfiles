local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", -- latest stable release
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        lazy = false,
        dependencies = {
            { "nvim-treesitter/nvim-treesitter-textobjects" },
            { "romgrk/nvim-treesitter-context" },
        },
        config = function()
            local treesitter = require("nvim-treesitter")
            local parsers = {
                "javascript", "typescript", "lua", "vim", "vimdoc", "query",
                "scss", "svelte", "html", "css", "go", "rust", "toml",
                "bash", "regex", "zig",
            }

            treesitter.setup({
                install_dir = vim.fn.stdpath("data") .. "/site",
            })
            treesitter.install(parsers)
        end,
    },
    "mfussenegger/nvim-dap",
    "nvim-neotest/nvim-nio",
    "rcarriga/nvim-dap-ui",

    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim",
    "neovim/nvim-lspconfig",

    {
        "stevearc/conform.nvim",
        config = function()
            local formatters = {
                javascript      = { "biome" },
                typescript      = { "biome" },
                javascriptreact = { "biome" },
                typescriptreact = { "biome" },
                svelte          = { "biome" },
                json            = { "biome" },
                jsonc           = { "biome" },
            }

            if vim.fn.executable("rustfmt") == 1 then
                formatters.rust = { "rustfmt" }
            end

            if vim.fn.executable("zig") == 1 then
                formatters.zig = { "zigfmt" }
            end

            require("conform").setup({ formatters_by_ft = formatters })
        end,
    },

    { "onsails/lspkind.nvim" },

    -- autocompletion
    { "hrsh7th/cmp-nvim-lsp" },

    {
        "hrsh7th/nvim-cmp",
        dependencies = {
            { "neovim/nvim-lspconfig" },
            { "hrsh7th/cmp-buffer" },
            { "hrsh7th/cmp-path" },
            { "hrsh7th/cmp-cmdline" },
            { "saadparwaiz1/cmp_luasnip" },
            {
                "L3MON4D3/LuaSnip",
                build = "make install_jsregexp",
                dependencies = {
                    { "rafamadriz/friendly-snippets" },
                },
            },
            { "petertriho/cmp-git" },
        },
    },

    "folke/which-key.nvim",
    "folke/trouble.nvim",

    {
        "numToStr/Comment.nvim",
        config =
            function()
                require("Comment").setup()
            end,
    },

    { "windwp/nvim-autopairs" },

    {
        "windwp/nvim-ts-autotag",
        dependencies = { "nvim-treesitter/nvim-treesitter" },
        ft = { "html", "javascript", "javascriptreact", "typescript", "typescriptreact", "svelte", "vue", "xml", "markdown" },
        config =
            function()
                require("nvim-ts-autotag").setup()
            end,
    },

    "nvim-telescope/telescope.nvim",
    "nvim-telescope/telescope-file-browser.nvim",

    { "rebelot/kanagawa.nvim", name = "kanagawa" },

    {
        "folke/noice.nvim",
        dependencies = {
            { "rcarriga/nvim-notify" },
            { "MunifTanjim/nui.nvim" },
        },
    },

    {
        "andymass/vim-matchup",
        config =
            function()
                vim.g.matchup_matchparen_offscreen = { method = "popup" }
            end,
    },

    {
        "jinh0/eyeliner.nvim",
        config =
            function()
                require "eyeliner".setup {
                    highlight_on_key = true, -- show highlights only after keypress
                    dim = true,              -- dim all other characters if true
                }
            end,
    },

    {
        "nmac427/guess-indent.nvim",
        config = function() require("guess-indent").setup {} end,
    },

    {
        "catgoose/nvim-colorizer.lua",
        config =
            function()
                vim.opt.termguicolors = true
                require("colorizer").setup()
            end,
    },

    -- {
    --     "n-shift/scratch.nvim",
    --     config =
    --         function()
    --             require("telescope").load_extension("scratch")
    --         end,
    -- },
    {
        "LintaoAmons/scratch.nvim",
        -- event = "VeryLazy",
    },

    {
        "nvim-lualine/lualine.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" }
    },

    "rhysd/git-messenger.vim",
    "nvim-lua/plenary.nvim",
    "akinsho/bufferline.nvim",
    -- "lewis6991/gitsigns.nvim",
    "tpope/vim-repeat",
    "tpope/vim-fugitive",
    "mbbill/undotree",
    "xiyaowong/transparent.nvim",

    {
        "ThePrimeagen/harpoon",
        branch = "harpoon2",
        dependencies = { "nvim-lua/plenary.nvim" }
    },

    -- {
    --     "epwalsh/obsidian.nvim",
    --     version = "*",
    --     lazy = false,
    --     ft = "markdown"
    -- },

    -- {
    --     "akinsho/toggleterm.nvim",
    --     version = "*",
    --     config = true
    -- },

    -- {
    --     "iamcco/markdown-preview.nvim",
    --     cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    --     build = "cd app && yarn install",
    --     init = function()
    --         vim.g.mkdp_filetypes = { "markdown" }
    --     end,
    --     ft = { "markdown" },
    -- },

    {
        "OXY2DEV/markview.nvim",
        lazy = false,
    },

    {
        "saecki/crates.nvim",
        event = "BufRead Cargo.toml",
        dependencies = { "hrsh7th/nvim-cmp" },
        config = function()
            local crates = require("crates")
            crates.setup({
                completion = {
                    cmp = { enabled = true },
                },
            })
        end,
    },
}, {
    rocks = { enabled = false },
})
