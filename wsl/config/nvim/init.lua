-- Managed by personal-app-catalog. Sanitized template only -- no secrets, no identity.
-- Copied to ~/.config/nvim/init.lua by `wsl/bootstrap.sh --config`.
-- Bootstraps lazy.nvim and installs a small curated plugin set on first launch.

-- Leader must be set before lazy.nvim loads.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Sensible options.
local opt = vim.opt
opt.number = true
opt.relativenumber = true
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true
opt.wrap = false
opt.ignorecase = true
opt.smartcase = true
opt.termguicolors = true
opt.signcolumn = "yes"
opt.undofile = true
opt.scrolloff = 8
opt.splitright = true
opt.splitbelow = true
opt.clipboard = "unnamedplus"

-- Bootstrap lazy.nvim.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Curated plugin set.
require("lazy").setup({
  { "folke/tokyonight.nvim", priority = 1000, config = function()
      vim.cmd.colorscheme("tokyonight-night")
  end },
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate", config = function()
      require("nvim-treesitter.configs").setup({
        auto_install = true,
        highlight = { enable = true },
        indent = { enable = true },
      })
  end },
  { "nvim-telescope/telescope.nvim", branch = "0.1.x",
    dependencies = { "nvim-lua/plenary.nvim" }, config = function()
      local builtin = require("telescope.builtin")
      vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
      vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Live grep" })
      vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Buffers" })
  end },
  { "williamboman/mason.nvim", config = true },
  { "williamboman/mason-lspconfig.nvim", dependencies = { "neovim/nvim-lspconfig" },
    config = function()
      require("mason-lspconfig").setup()
  end },
  { "lewis6991/gitsigns.nvim", config = true },
  { "nvim-lualine/lualine.nvim", config = function()
      require("lualine").setup({ options = { theme = "tokyonight" } })
  end },
  { "folke/which-key.nvim", event = "VeryLazy", config = true },
  { "numToStr/Comment.nvim", config = true },
  { "windwp/nvim-autopairs", event = "InsertEnter", config = true },
}, {
  ui = { border = "rounded" },
  checker = { enabled = false },
})

-- A couple of editor keymaps.
vim.keymap.set("n", "<leader>w", "<cmd>write<cr>", { desc = "Write buffer" })
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
