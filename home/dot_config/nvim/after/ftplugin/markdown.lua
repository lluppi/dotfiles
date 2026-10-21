-- prose-friendly view: soft wrap at word boundaries, keep list indent on wrapped lines
vim.opt_local.wrap = true
vim.opt_local.linebreak = true
vim.opt_local.breakindent = true
vim.opt_local.breakindentopt = "list:-1"
vim.opt_local.colorcolumn = ""
vim.opt_local.spell = true
vim.opt_local.spelllang = "en_au"

-- move by screen line unless a count is given (so 5j still jumps real lines)
vim.keymap.set({ "n", "x" }, "j", "v:count ? 'j' : 'gj'", { buffer = true, expr = true })
vim.keymap.set({ "n", "x" }, "k", "v:count ? 'k' : 'gk'", { buffer = true, expr = true })

vim.keymap.set("n", "<leader>mr", "<cmd>RenderMarkdown buf_toggle<cr>", { buffer = true, desc = "toggle markdown render" })
vim.keymap.set("n", "<leader>mw", function() vim.wo.wrap = not vim.wo.wrap end, { buffer = true, desc = "toggle wrap" })
