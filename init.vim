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

" Load dein.vim configuration
let g:dein_plugin_root_dir = expand('~/AppData/Local/nvim-plugins/dein')
source ~/AppData/Local/nvim/load_dein.vim

source $HOME/AppData/Local/nvim/load_ime_control.vim
source $HOME/AppData/Local/nvim/outline_settings.vim

lua << EOF
  local config_path = vim.fn.stdpath('config')
  package.path = package.path .. ';' .. config_path .. '/?.lua'
  require('lsp_settings')
EOF

source $HOME/AppData/Local/nvim/markdown-preview-settings.vim
