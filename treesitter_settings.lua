-- Setup nvim-treesitter
local ts_ok, ts = pcall(require, 'nvim-treesitter.configs')
if ts_ok then
  ts.setup {
    ensure_installed = { "c", "lua", "vim", "vimdoc", "query", "python" },
    sync_install = false,
    auto_install = true,
    highlight = {
      enable = true,
      additional_vim_regex_highlighting = false,
    },
  }
else
  vim.notify("Failed to load nvim-treesitter.configs", vim.log.levels.ERROR)
end
