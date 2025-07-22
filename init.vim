set shiftwidth=4
set expandtab
set laststatus=2
set statusline=%F%m%r%h%w\%=[TYPE=%Y]\[FORMAT=%{&ff}]\[ENC=%{&fileencoding}]\[LOW=%l/%L]
set signcolumn=number
set list
set listchars=eol:$,tab:`\ ,trail:@
set splitright
set splitbelow
set clipboard=unnamedplus
set incsearch
set ignorecase
set encoding=utf-8
set iminsert=0
set imsearch=0
set noswapfile
set tabstop=4
set hlsearch
set fileencodings=ucs-bom,utf-8,sjis,euc-jp

nnoremap <silent> <C-n> :set number!<CR>

" Load dein.vim configuration
let g:dein_plugin_root_dir = expand('~/AppData/Local/nvim-plugins/dein')
source ~/AppData/Local/nvim/load_dein.vim

source $HOME/AppData/Local/nvim/load_ime_control.vim
source $HOME/AppData/Local/nvim/outline_settings.vim

lua << EOF
  local config_path = vim.fn.stdpath('config')
  package.path = package.path .. ';' .. config_path .. '/?.lua'
  require('lsp_settings')

  -- Theme and Treesitter settings
  -- Set colorscheme to carbonfox (a style from nightfox)
  vim.cmd('colorscheme carbonfox')

  -- Setup nvim-treesitter
  require'nvim-treesitter.configs'.setup {
    -- A list of parser names, or "all"
    ensure_installed = { "c", "lua", "vim", "vimdoc", "query", "javascript", "typescript", "python", "rust", "html", "css", "json", "markdown" },

    -- Install parsers synchronously (only applied to `ensure_installed`)
    sync_install = false,

    -- Automatically install missing parsers when entering buffer
    auto_install = true,

    highlight = {
      enable = true,
      -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
      -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
      -- Using this option may slow down your editor, and you may see some duplicate highlights.
      -- Instead of true it can also be a list of languages
      additional_vim_regex_highlighting = false,
    },
  }
EOF

source $HOME/AppData/Local/nvim/markdown-preview-settings.vim
