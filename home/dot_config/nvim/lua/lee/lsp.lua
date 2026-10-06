local M = {}

M.core_servers = {
    "lua_ls",
    "marksman",
}

M.npm_servers = {
    "html",
    "svelte",
    "cssls",
    "ts_ls",
    "biome",
}

function M.ensure_installed()
    local servers = vim.deepcopy(M.core_servers)

    if vim.fn.executable("npm") == 1 then
        vim.list_extend(servers, M.npm_servers)
    end

    return servers
end

function M.has_npm_servers()
    return vim.fn.executable("npm") == 1
end

return M
