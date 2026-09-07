-- =========================
-- Leader keys (set before loading lazy.nvim)
-- =========================
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- =========================
-- Bootstrap lazy.nvim
-- =========================
require("config.lazy")

-- =========================
-- Core configuration
-- =========================
require("config.options")
require("config.keymaps")
require("config.autocmds")

-- =========================
-- Plugins
-- =========================
require("lazy").setup("plugins", {
  change_detection = { notify = false },
  rocks = { enabled = false },
})
