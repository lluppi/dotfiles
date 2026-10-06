local wk = require("which-key")

vim.o.timeout = true
vim.o.timeoutlen = 300

wk.add({
    { "<leader>G", group = "git" },
    { "<leader>f", group = "file/find" },
    { "<leader>o", group = "obsidian" },
    { "<leader>s", group = "search/scratch" },
    { "<leader>t", group = "terminal" },
})
