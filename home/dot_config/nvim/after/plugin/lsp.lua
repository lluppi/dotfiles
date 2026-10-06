local capabilities = require("cmp_nvim_lsp").default_capabilities()
local servers = require("lee.lsp")

vim.diagnostic.config({
    virtual_text = true,
    severity_sort = true,
    float = {
        border = "single",
        source = "if_many",
    },
})

local on_attach = function(client, bufnr)
    local opts = { buffer = bufnr, silent = true }

    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)

    if client.name == "lua_ls" then
        client.server_capabilities.semanticTokensProvider = nil
    end
end

local function with_defaults(opts)
    opts = opts or {}
    opts.capabilities = vim.tbl_deep_extend("force", {}, capabilities, opts.capabilities or {})

    local user_on_attach = opts.on_attach
    opts.on_attach = function(client, bufnr)
        on_attach(client, bufnr)
        if user_on_attach then
            user_on_attach(client, bufnr)
        end
    end

    return opts
end

vim.lsp.config("lua_ls", with_defaults({
    settings = {
        Lua = {
            diagnostics = {
                globals = { "vim" },
            },
            workspace = {
                checkThirdParty = false,
            },
            telemetry = {
                enable = false,
            },
        },
    },
}))
vim.lsp.enable("lua_ls")

vim.lsp.config("marksman", with_defaults())
vim.lsp.enable("marksman")

if vim.fn.executable("gopls") == 1 then
    vim.lsp.config("gopls", with_defaults())
    vim.lsp.enable("gopls")
end

if vim.fn.executable("rust-analyzer") == 1 then
    vim.lsp.config("rust_analyzer", with_defaults({
        on_attach = function(client, bufnr)
            if client.server_capabilities.inlayHintProvider then
                vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
            end
        end,
        settings = {
            ["rust-analyzer"] = {
                check = {
                    command = "clippy",
                },
                cargo = {
                    allFeatures = true,
                },
                procMacro = {
                    enable = true,
                },
                inlayHints = {
                    typeHints = { enable = false },
                    parameterHints = { enable = false },
                    chainingHints = { enable = true },
                    closingBraceHints = { enable = true, minLines = 20 },
                    lifetimeElisionHints = { enable = "never" },
                },
            },
        },
    }))
    vim.lsp.enable("rust_analyzer")
end

if vim.fn.executable("zls") == 1 then
    vim.lsp.config("zls", with_defaults({
        on_attach = function(client, bufnr)
            if client.server_capabilities.inlayHintProvider then
                vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
            end
        end,
        settings = {
            zls = {
                enable_autofix = false,
                enable_snippets = true,
                warn_style = true,
            },
        },
    }))
    vim.lsp.enable("zls")
end

if servers.has_npm_servers() then
    vim.lsp.config("html", with_defaults({
        filetypes = { "html", "templ" },
    }))
    vim.lsp.enable("html")

    vim.lsp.config("cssls", with_defaults())
    vim.lsp.enable("cssls")

    vim.lsp.config("ts_ls", with_defaults({
        on_attach = function(client, _)
            client.server_capabilities.documentFormattingProvider = false
        end,
    }))
    vim.lsp.enable("ts_ls")

    vim.lsp.config("svelte", with_defaults({
        on_attach = function(client, _)
            client.server_capabilities.documentFormattingProvider = false
            vim.api.nvim_create_autocmd("BufWritePost", {
                pattern = { "*.js", "*.ts" },
                callback = function(ctx)
                    client.notify("$/onDidChangeTsOrJsFile", { uri = ctx.file })
                end,
            })
        end,
    }))
    vim.lsp.enable("svelte")

    vim.lsp.config("biome", with_defaults({
        filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "svelte", "json", "jsonc", "css" },
        on_attach = function(client, _)
            client.server_capabilities.documentFormattingProvider = false
        end,
    }))
    vim.lsp.enable("biome")
end
