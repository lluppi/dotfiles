-- vim.opt.guicursor = { 'a:block' }
vim.opt.termguicolors = true

-- This config uses native Lua plugins only, so remote language hosts are not needed.
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0

pcall(vim.cmd, 'language en_AU.UTF-8') -- missing locale shouldn't break startup
vim.o.cmdheight = 0

vim.opt.number = true
vim.opt.numberwidth = 1
vim.opt.relativenumber = false

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

vim.opt.smartindent = true

vim.opt.wrap = false

vim.opt.swapfile = false
vim.opt.backup = false
-- vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

vim.opt.hlsearch = false
vim.opt.incsearch = true

vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.isfname:append("@-@")

vim.opt.updatetime = 250

vim.opt.colorcolumn = "80"

vim.filetype.add({
    extension = {
        templ = "templ",
        mdx = "markdown.mdx",
    },
})

vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
    pattern = "*.rs",
    callback = function()
        if vim.bo.modified then
            vim.cmd("update")
        end
    end,
})

vim.api.nvim_create_autocmd("DiagnosticChanged", {
    callback = function()
        vim.schedule(function()
            vim.cmd.redraw()
        end)
    end,
})

vim.api.nvim_create_autocmd("FileType", {
    callback = function(args)
        pcall(vim.treesitter.start, args.buf)
    end,
})

pcall(vim.cmd, "TransparentEnable")
