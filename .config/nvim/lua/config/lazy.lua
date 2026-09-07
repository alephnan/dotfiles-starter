-- Bootstrap lazy.nvim at the same commit as the other locked plugins.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json"
local lock = vim.json.decode(table.concat(vim.fn.readfile(lockfile), "\n"))
local function git(args)
  local output = vim.fn.system(args)
  if vim.v.shell_error ~= 0 then
    error("lazy.nvim bootstrap failed: " .. output)
  end
end
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  git({
    "git", "clone", "--filter=blob:none", "--no-checkout",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
  git({ "git", "-C", lazypath, "checkout", "--detach", lock["lazy.nvim"].commit })
end
local head = vim.fn.system({ "git", "-C", lazypath, "rev-parse", "HEAD" }):gsub("%s+$", "")
assert(head == lock["lazy.nvim"].commit,
  "Existing lazy.nvim differs from lazy-lock.json. Move it aside to reinstall the pinned version.")
vim.opt.rtp:prepend(lazypath)
