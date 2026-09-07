-- File explorer sidebar.
--
-- Not lazy-loaded behind its keymaps the way telescope is: the netrw hijack
-- has to be registered at startup, otherwise `nvim somedir/` opens netrw
-- before neo-tree has had a chance to take over.
return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  lazy = false,
  keys = {
    { "<leader>e", "<cmd>Neotree toggle<cr>", desc = "Toggle file explorer" },
    { "<leader>ge", "<cmd>Neotree git_status toggle<cr>", desc = "Git status tree" },
  },
  opts = {
    close_if_last_window = true,
    filesystem = {
      -- Keep the tree pointed at whatever buffer is focused
      follow_current_file = { enabled = true },
      -- Reflect changes made outside Neovim without a manual refresh
      use_libuv_file_watcher = true,
      hijack_netrw_behavior = "open_default",
    },
    window = { width = 32 },
  },
}
