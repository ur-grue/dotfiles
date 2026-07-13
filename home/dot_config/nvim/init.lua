-- ~/.config/nvim/init.lua
-- Leader VOR den Plugins setzen
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Ungenutzte Remote-Provider aus (Config ist rein Lua) -> saubere :checkhealth + schnellerer Start
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0

-- lazy.nvim bootstrappen
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", repo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({ { "lazy.nvim clone fehlgeschlagen:\n", "ErrorMsg" }, { out, "WarningMsg" } }, true, {})
    -- NUR mit angehängtem UI auf Tastendruck warten. Headless (z.B. `nvim --headless
    -- +Lazy! sync` im Setup) hätte hier sonst auf getchar() geblockt — unsichtbar,
    -- weil stdout/err ins Log/Nirwana gehen -> das ganze Setup schiene einzufrieren.
    if #vim.api.nvim_list_uis() > 0 then vim.fn.getchar() end
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("config.options")

require("lazy").setup({
  spec = { { import = "plugins" } },
  install = { colorscheme = { "rose-pine" } },
  checker = { enabled = false },
  rocks = { enabled = false },   -- kein luarocks/hererocks nötig -> :checkhealth-Fehler weg
  ui = { border = "rounded", backdrop = 100 },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin", "netrwPlugin",
      },
    },
  },
})

require("config.keymaps")
require("config.autocmds")
