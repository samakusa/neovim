-- Setup nvim-treesitter.
--
-- NOTE: nvim-treesitter's `main` branch (the plugin's default branch since
-- the 2024 rewrite; see load_dein.vim) is a full, incompatible rewrite of
-- the old `master` branch: it has no `nvim-treesitter.configs` module and no
-- `nvim-treesitter.query_predicates` module, so the old
-- `require('nvim-treesitter.configs').setup{ ensure_installed = ..., highlight = ... }`
-- style no longer works and only errors. `main` requires Neovim 0.12+ and is
-- actively maintained, whereas `master` is frozen and explicitly does not
-- support Neovim 0.12 (see https://github.com/nvim-treesitter/nvim-treesitter).
-- Highlighting is now enabled per-buffer via vim.treesitter.start()
-- (see :help treesitter-highlight), and parser installation goes through
-- require('nvim-treesitter').install().
local ts_ok, ts = pcall(require, 'nvim-treesitter')
if not ts_ok then
  vim.notify("Failed to load nvim-treesitter", vim.log.levels.ERROR)
  return
end

-- 起動時によく使う言語のパーサーを確実にインストールしておく(旧ensure_installedに相当)
ts.install({ "c", "lua", "vim", "vimdoc", "query", "python" })

-- ファイルタイプに対応するパーサーが未インストールであれば自動インストールし、
-- インストール済み(またはインストールできた)であればハイライトを有効化する
-- (旧auto_install = true と highlight.enable = true に相当)。
-- vim.treesitter.start()はデフォルトでレガシーな正規表現ベースのsyntaxハイライトを
-- 無効化するため、旧設定のadditional_vim_regex_highlighting = falseと同等の挙動になる。
vim.api.nvim_create_autocmd('FileType', {
  pattern = '*',
  callback = function(args)
    local ft = args.match
    local lang = vim.treesitter.language.get_lang(ft) or ft

    if not vim.list_contains(ts.get_installed('parsers'), lang) then
      if not vim.list_contains(ts.get_available(), lang) then
        -- このファイルタイプに対応するパーサーが存在しない
        return
      end

      local install_ok = pcall(function()
        ts.install({ lang }):wait(30000)
      end)
      if not install_ok then
        vim.notify("Failed to install treesitter parser for: " .. lang, vim.log.levels.WARN)
        return
      end
    end

    pcall(vim.treesitter.start, args.buf)
  end,
})
