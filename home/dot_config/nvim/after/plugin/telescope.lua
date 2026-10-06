local fb_actions = require "telescope".extensions.file_browser.actions

require('telescope').setup {
  defaults = {
    mappings = {
      n = {
        ['<C-d>'] = require('telescope.actions').delete_buffer,
        ['<S-d>'] = fb_actions.remove,
        ['<C-r>'] = fb_actions.rename,
        ['<C-n>'] = fb_actions.create,
        -- ['<C-m>'] = fb_actions.move,
      },
      i = {
        ["<C-h>"] = "which_key",
        ['<C-d>'] = require('telescope.actions').delete_buffer,
        ['<S-d>'] = fb_actions.remove,
        ['<C-r>'] = fb_actions.rename,
        ['<C-n>'] = fb_actions.create,
        -- ['<C-m>'] = fb_actions.move,
      }
    }
  },
  ...
}
