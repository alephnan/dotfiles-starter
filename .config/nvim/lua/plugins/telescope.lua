return {
  "nvim-telescope/telescope.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  cmd = "Telescope",
  keys = {
    { "<leader>ff", function() require("telescope.builtin").find_files() end, desc = "Find files" },
    { "<leader>fg", function() require("telescope.builtin").live_grep() end, desc = "Live grep" },
    { "<leader>fb", function() require("telescope.builtin").buffers() end, desc = "Buffers" },
    { "<leader>fh", function() require("telescope.builtin").help_tags() end, desc = "Help tags" },
    { "<leader>fo", function() require("telescope.builtin").oldfiles() end, desc = "Recent files" },
  },
  config = function()
    local telescope = require("telescope")
    local actions_layout = require("telescope.actions.layout")

    telescope.setup({
      defaults = {
        layout_strategy = "horizontal",
        layout_config = {
          horizontal = {
            preview_width = 0.60,
            preview_cutoff = 1,
          },
        },
        mappings = {
          i = { ["<M-p>"] = actions_layout.toggle_preview },
          n = { ["<M-p>"] = actions_layout.toggle_preview },
        },
      },
    })
  end,
}
