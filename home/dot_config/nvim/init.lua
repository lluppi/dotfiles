-- leader has to exist before lazy loads plugins, or their <leader> maps bind to "\\"
vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("lee")
