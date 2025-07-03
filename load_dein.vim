" NOTE: Add the following lines to your init.vim to enable dein.vim configuration:
" let g:dein_plugin_root_dir = expand('~/AppData/Local/nvim/plugin')
" source ~/.config/nvim/init_dein.vim

if &compatible
  set nocompatible
endif

" dein Scripts path
let s:dein_dir = g:dein_plugin_root_dir
let s:dein_repo_dir = expand(s:dein_dir . '/repos/github.com/Shougo/dein.vim')

" Add dein to runtimepath
let &runtimepath .= ',' . s:dein_repo_dir

if !isdirectory(s:dein_repo_dir)
  call system('git clone https://github.com/Shougo/dein.vim ' . shellescape(s:dein_repo_dir))
endif

call dein#begin(s:dein_dir)

call dein#add('Shougo/dein.vim')

" Add other plugins here
call dein#add('jw3126/nvim-hello-world')

  " --- Markdown Plugins ---
  call dein#add('godlygeek/tabular')
  call dein#add('preservim/vim-markdown')
  call dein#add('iamcco/markdown-preview.nvim', { 'build': 'call mkdp#util#install()', 'on_ft': ['markdown', 'pandoc'] })
  " -------------------------

call dein#end()
call dein#save_state()

if dein#check_install()
  call dein#install()
endif