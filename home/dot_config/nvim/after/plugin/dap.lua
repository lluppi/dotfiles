local dap = require('dap')

-- dap.adapters.lldb = {
--   type = 'executable',
--   command = '/usr/bin/lldb', -- adjust as needed, must be absolute path
--   name = 'lldb'
-- }

-- dap.configurations.zig = {
--     {
--         type = 'lldb',
--         request = 'launch',
--         program = function()
--             return vim.fn.input('Path to executable: ', vim.fn.getcwd()..'/', 'file')
--         end,
--         cwd = '${workspaceFolder}',
--         terminal = 'integrated',
--         args = {},
--     },
-- }
