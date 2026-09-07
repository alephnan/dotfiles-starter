return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  event = "UIEnter",
  config = function()
    require("lualine").setup({})
  end,
}
