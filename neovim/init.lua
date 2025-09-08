-- Minimal Neovim configuration (no plugins)
-- Now bootstraps a minimal plugin set via lazy.nvim
-- leader
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- basic options
vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.mouse = 'a'
vim.opt.clipboard = 'unnamedplus'
vim.opt.termguicolors = true
vim.opt.signcolumn = 'yes'
vim.opt.updatetime = 300
vim.opt.timeoutlen = 400
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.scrolloff = 4
vim.opt.sidescrolloff = 8
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.smartindent = true

-- keymaps
local map = vim.keymap.set
map('n', '<leader>w', '<cmd>write<cr>', { silent = true, desc = 'Write' })
map('n', '<leader>q', '<cmd>quit<cr>', { silent = true, desc = 'Quit' })
map('n', '<leader>e', '<cmd>edit %<cr>', { silent = true, desc = 'Reload file' })

-- highlight yanked text
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function()
    pcall(vim.highlight.on_yank, { higroup = 'IncSearch', timeout = 120 })
  end,
})

-- disable unused providers to silence health warnings
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0  -- Ruby not in essential tools
vim.g.loaded_node_provider = 0
vim.g.loaded_python3_provider = 0

-- optionally set python host to avoid pyenv shim warnings (commented)
-- vim.g.python3_host_prog = 'C:/Path/To/Python/python.exe'

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable',
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Prefer zig for native builds (helps on Windows) and reduce memory pressure
vim.env.CC = 'zig'
vim.env.CXX = 'zig'

-- Load plugins
require('lazy').setup('plugins', {
  install = { colorscheme = { 'tokyonight' } },
  ui = { border = 'rounded' },
  change_detection = { notify = false },
  rocks = { enabled = false },
})
