-- 診断マーク(E, Wなど)を左端に表示しないようにする
vim.diagnostic.config({
  virtual_text = true,
  signs = false,
  severity_sort = true,
})

-- Setup nvim-cmp.
local cmp = require'cmp'
local luasnip = require'luasnip'

require("luasnip.loaders.from_vscode").lazy_load()

cmp.setup({
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  mapping = cmp.mapping.preset.insert({
    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<C-e>'] = cmp.mapping.abort(),
    ['<CR>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
  }),
  sources = cmp.config.sources({
    { name = 'nvim_lsp' },
    { name = 'luasnip' },
  }, {
    { name = 'buffer' },
    { name = 'path' },
  })
})

-- Setup lspconfig.
local capabilities = require('cmp_nvim_lsp').default_capabilities()
local lspconfig = require'lspconfig'

-- Generic keymappings
local on_attach = function(client, bufnr)
  local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
  local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end

  buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

  -- Mappings.
  local opts = { noremap=true, silent=true }

  -- カーソルホバーで診断メッセージをフロート表示する
  vim.api.nvim_create_autocmd('CursorHold', {
    buffer = bufnr,
    callback = function()
      vim.diagnostic.open_float(nil, {
        scope = 'line',      -- 現在行の診断のみ表示
        source = 'always',   -- 診断のソース元(LSP名等)を常に表示
        focusable = false,   -- フロートウィンドウにフォーカスしない
      })
    end
  })

  buf_set_keymap('n', 'gD', '<Cmd>lua vim.lsp.buf.declaration()<CR>', opts)
  buf_set_keymap('n', 'gd', '<Cmd>lua vim.lsp.buf.definition()<CR>', opts)
  buf_set_keymap('n', 'K', '<Cmd>lua vim.lsp.buf.hover()<CR>', opts)
  buf_set_keymap('n', 'gi', '<Cmd>lua vim.lsp.buf.implementation()<CR>', opts)
  buf_set_keymap('n', '<C-k>', '<Cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
  buf_set_keymap('n', '<space>wa', '<Cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', opts)
  buf_set_keymap('n', '<space>wr', '<Cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', opts)
  buf_set_keymap('n', '<space>wl', '<Cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>', opts)
  buf_set_keymap('n', '<space>D', '<Cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
  buf_set_keymap('n', '<space>rn', '<Cmd>lua vim.lsp.buf.rename()<CR>', opts)
  buf_set_keymap('n', '<space>ca', '<Cmd>lua vim.lsp.buf.code_action()<CR>', opts)
  buf_set_keymap('n', 'gr', '<Cmd>lua vim.lsp.buf.references()<CR>', opts)
  buf_set_keymap('n', '<space>e', '<Cmd>lua vim.diagnostic.open_float()<CR>', opts)
  buf_set_keymap('n', '[d', '<Cmd>lua vim.diagnostic.goto_prev()<CR>', opts)
  buf_set_keymap('n', ']d', '<Cmd>lua vim.diagnostic.goto_next()<CR>', opts)
  buf_set_keymap('n', '<space>q', '<Cmd>lua vim.diagnostic.setloclist()<CR>', opts)
end

-- Define all servers to be managed by lspconfig
local servers = {
  'pyright', 'rust_analyzer', 'ts_ls', 'clangd', 'jdtls', 'csharp_ls', 
  'vimls', 'html', 'cssls', 'jsonls', 'lua_ls', 'powershell_es'
}

-- Servers that need a specific command different from the lspconfig default
local custom_cmds = {
  pyright = { "pyright-langserver", "--stdio" },
  ts_ls = { "typescript-language-server", "--stdio" },
  vimls = { "vim-language-server", "--stdio" },
  html = { "html-languageserver", "--stdio" },
  cssls = { "css-languageserver", "--stdio" },
  jsonls = { "json-languageserver", "--stdio" }
}

-- Servers that need more complex, custom options (overrides custom_cmds)
local custom_opts = {
  lua_ls = {
    settings = {
      Lua = {
        runtime = { version = 'LuaJIT' },
        diagnostics = { globals = {'vim'} },
        workspace = { library = vim.api.nvim_get_runtime_file("", true) },
        telemetry = { enable = false },
      },
    },
  },
  powershell_es = {
    cmd = {
        "pwsh",
        "-NoLogo",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
        string.format(
            "[System.Console]::InputEncoding=[System.Text.Encoding]::UTF8; [System.Console]::OutputEncoding=[System.Text.Encoding]::UTF8; PowerShellEditorServices.Hosting.EditorServicesHost start --hostName 'Neovim' --hostProfileId 'neovim' --hostVersion 0.1.0 --additionalModules @() --featureFlags @() --logLevel 'Normal' --logPath '%s' --sessionDetailsPath '%s' --bundledModulesPath '%s'",
            vim.fn.expand("~/.cache/nvim/pses.log"),
            vim.fn.expand("~/.cache/nvim/pses-session.json"),
            vim.fn.expand("~/AppData/Local/lsp-server/PowerShellEditorServices")
        )
    }
  }
}

-- Setup all servers in a single loop
for _, server_name in ipairs(servers) do
  local opts = {
    on_attach = on_attach,
    capabilities = capabilities,
  }

  if custom_opts[server_name] then
    -- If full custom options exist, merge them
    opts = vim.tbl_deep_extend('force', opts, custom_opts[server_name])
  elseif custom_cmds[server_name] then
    -- Otherwise, if a custom command exists, use it
    opts.cmd = custom_cmds[server_name]
  end

  lspconfig[server_name].setup(opts)
end

-- For jdtls, you need to specify the data directory.
-- This path needs to be adjusted to your environment.
-- local jdtls_path = vim.fn.expand('~/AppData/Local/nvim/plugin/jdtls')
-- lspconfig.jdtls.setup{
--     on_attach = on_attach,
--     capabilities = capabilities,
--     cmd = { 'java', '-Declipse.application=org.eclipse.jdt.ls.core.id1.XmlServerApplication', '-Dosgi.bundles.defaultStartLevel=4', '-Declipse.product=org.eclipse.jdt.ls.core.product', '-Dlog.protocol=true', '-Dlog.level=ALL', '-javaagent:' .. jdtls_path .. '/lombok.jar', '-Xms1g', '--add-modules=ALL-SYSTEM', '--add-opens', 'java.base/java.util=ALL-UNNAMED', '--add-opens', 'java.base/java.lang=ALL-UNNAMED', '-jar', vim.fn.glob(jdtls_path .. '/plugins/org.eclipse.equinox.launcher_*.jar') },
--     root_dir = require('jdtls.setup').find_root({'.git', 'mvnw', 'gradlew'}),
-- }

