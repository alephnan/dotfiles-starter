-- Parsers to install, and the filetypes that should use them.
-- The `main` branch no longer has highlight/indent modules -- we enable them
-- ourselves via `vim.treesitter.start()` on FileType.
local parsers = require("config.parsers")
local filetypes = { "lua", "vim", "help", "sh", "bash", "python", "rust", "toml", "json" }

return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false, -- the main branch does not support lazy-loading
  build = function()
    require("nvim-treesitter").install(parsers):wait(300000)
  end,
  config = function()

    -- `sh` files are parsed by the bash grammar
    vim.treesitter.language.register("bash", "sh")

    vim.api.nvim_create_autocmd("FileType", {
      pattern = filetypes,
      callback = function()
        if pcall(vim.treesitter.start) then
          vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })
  end,
}
