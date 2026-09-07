return {
  "catppuccin/nvim",
  name = "catppuccin",
  lazy = false,
  priority = 1000,
  config = function()
    vim.o.background = "dark"
    require("catppuccin").setup({
      flavour = "mocha",
      transparent_background = false,
    })
    vim.cmd.colorscheme("catppuccin")
    vim.api.nvim_set_hl(0, "Normal", { bg = "#0b0f14" })
  end,
}
