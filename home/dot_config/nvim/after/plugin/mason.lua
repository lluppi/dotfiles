require("mason").setup({
    PATH = "prepend",
    registries = {
        'github:Crashdummyy/mason-registry',
        'github:mason-org/mason-registry',
    },
})
local servers = require("lee.lsp")

require("mason-lspconfig").setup({
    ensure_installed = servers.ensure_installed(),
    automatic_enable = false,
})
