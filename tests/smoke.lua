local ok, err = xpcall(function()
  assert(vim.g.colors_name and vim.g.colors_name:find("catppuccin"), "Theme did not load")
  assert(vim.fn.maparg("<Space>e", "n") ~= "", "File explorer mapping is missing")
  for _, language in ipairs(require("config.parsers")) do
    assert(vim.treesitter.language.add(language), "Parser missing: " .. language)
  end
  require("lazy").load({ plugins = { "blink.cmp", "telescope.nvim", "neo-tree.nvim" } })
  assert(require("blink.cmp").get_lsp_capabilities().textDocument.completion, "Completion did not load")
  assert(require("telescope.builtin").find_files, "File search did not load")
  if vim.env.DOTFILES_TEST_DEV == "1" then
    local required = vim.bo.filetype == "rust" and { "rust_analyzer" } or { "basedpyright", "ruff" }
    assert(vim.wait(60000, function()
      local attached = {}
      for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
        if client.initialized then attached[client.name] = true end
      end
      for _, name in ipairs(required) do
        if not attached[name] then return false end
      end
      return true
    end, 100), "Language servers did not attach: " .. table.concat(required, ", "))
  else
    assert(#vim.lsp.get_clients({ bufnr = 0 }) == 0, "Default setup unexpectedly started a language server")
  end
  assert(vim.v.errmsg == "", "Neovim reported: " .. vim.v.errmsg)
end, debug.traceback)
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
