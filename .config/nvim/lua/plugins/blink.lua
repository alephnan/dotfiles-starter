-- Completion menu. Pulls candidates from the LSP servers enabled in
-- `plugins/lsp.lua`; blink registers its own LSP capabilities globally,
-- so the two files need no wiring between them.
--
-- Prefer the prebuilt matcher; Lua remains available without a Rust toolchain.
return {
  "saghen/blink.cmp",
  version = "1.*",
  event = "InsertEnter",
  opts = {
    -- <C-space> open, <C-n>/<C-p> cycle, <C-y> accept, <C-e> dismiss
    keymap = { preset = "default" },
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
    },
    signature = { enabled = true },
    fuzzy = {
      implementation = "prefer_rust",
    },
  },
}
