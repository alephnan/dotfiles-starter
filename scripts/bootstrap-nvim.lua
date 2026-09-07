-- Exit unsuccessfully if cloning, building, or parser installation fails.
local ok, err = xpcall(function()
  vim.env.DOTFILES_BOOTSTRAP = "1"
  local config = vim.fn.stdpath("config")
  vim.opt.rtp:prepend(config)
  dofile(config .. "/init.lua")
  local manager = require("lazy.manage")
  local function check_plugins()
    for name, plugin in pairs(require("lazy.core.config").plugins) do
      for _, task in ipairs(plugin._.tasks or {}) do
        assert(not task:has_errors(), "Plugin task failed: " .. name)
      end
      assert(plugin._.installed, "Plugin is missing: " .. name)
    end
  end
  manager.install({ wait = true, show = false, lockfile = true })
  check_plugins()
  manager.restore({ wait = true, show = false })
  check_plugins()
  require("lazy").load({ plugins = { "nvim-treesitter" } })
  local parsers = require("config.parsers")
  require("nvim-treesitter").install(parsers):wait(300000)
  for _, language in ipairs(parsers) do
    assert(vim.treesitter.language.add(language), "Parser unavailable: " .. language)
  end
end, debug.traceback)
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
