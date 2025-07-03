set shiftwidth=4
set expandtab
set laststatus=2
set statusline=%F%m%r%h%w\%=[TYPE=%Y]\[FORMAT=%{&ff}]\[ENC=%{&fileencoding}]\[LOW=%l/%L]
set signcolumn=number
set list
set listchars=eol:$,tab:`\ ,trail:@
set splitright
set splitbelow
set clipboard=unnamed
set incsearch
set ignorecase
set encoding=utf-8
set iminsert=0
set imsearch=0
set noswapfile
set tabstop=4
set hlsearch

source ~\AppData\Local\nvim\load_ime_control.vim

" Load dein.vim configuration
let g:dein_plugin_root_dir = expand('~/AppData/Local/nvim-plugins/dein')
source ~/AppData/Local/nvim/load_dein.vim