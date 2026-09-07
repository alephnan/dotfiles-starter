-- LSP servers.
-- Nvim 0.12 loads server definitions from `lsp/` on the runtimepath, so
-- nvim-lspconfig is here only to ship those definitions -- we just enable
-- the servers we want.
--
-- ./bootstrap.sh --with-dev-tools installs these optional executables.
local servers = {
  basedpyright = "basedpyright-langserver",
  ruff = "ruff",
  rust_analyzer = "rust-analyzer",
}

return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    for server, executable in pairs(servers) do
      if vim.fn.executable(executable) == 1 then
        vim.lsp.enable(server)
      end
    end

    -- Show diagnostics beside the affected lines.
    vim.diagnostic.config({
      virtual_text = true,
      severity_sort = true,
    })

    -- 0.11+ already maps K, grn, gra, grr, gri, gO and insert-mode <C-s>
    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        vim.keymap.set("n", "gd", vim.lsp.buf.definition,
          { buffer = args.buf, desc = "Go to definition" })
      end,
    })
  end,
}
