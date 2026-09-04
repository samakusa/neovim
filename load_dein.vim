" NOTE: Add the following lines to your init.vim to enable dein.vim configuration:
" let g:dein_plugin_root_dir = expand('~/AppData/Local/nvim/plugin')

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
  call dein#add('selimacerbas/live-server.nvim')
  " NOTE: no on_ft lazy-load here (unlike the old iamcco/markdown-preview.nvim) because
  " markdown_preview_settings.lua calls require('markdown_preview').setup({...}) eagerly
  " from init.vim's startup `lua << EOF` block; on_ft would keep the plugin off the
  " runtimepath until a markdown/pandoc buffer is opened, making that require() fail at
  " startup (confirmed by a real dein#install() + headless nvim run during this migration).
  " Matches the other Markdown plugins in this section (tabular, vim-markdown,
  " vim-table-mode), none of which are on_ft-restricted either.
  call dein#add('selimacerbas/markdown-preview.nvim', { 'depends': ['selimacerbas/live-server.nvim'] })
  call dein#add('dhruvasagar/vim-table-mode')
  " -------------------------

  " --- Outline/Navigation Plugins ---
  call dein#add('liuchengxu/vista.vim')
  call dein#add('junegunn/fzf', {'build': './install --all'})
  call dein#add('junegunn/fzf.vim')
  " ----------------------------------

  " --- HTML Preview Plugin ---
  call dein#add('brianhuster/live-preview.nvim', { 'on_ft': ['html'] })
  " ---------------------------

  " --- Completion Plugins ---
  call dein#add('neovim/nvim-lspconfig')
  call dein#add('hrsh7th/nvim-cmp')
  call dein#add('hrsh7th/cmp-nvim-lsp')
  call dein#add('hrsh7th/cmp-buffer')
  call dein#add('hrsh7th/cmp-path')
  call dein#add('hrsh7th/cmp-cmdline')
  call dein#add('L3MON4D3/LuaSnip')
  call dein#add('saadparwaiz1/cmp_luasnip')
  call dein#add('rafamadriz/friendly-snippets')
  call dein#add('mfussenegger/nvim-jdtls')
  " -------------------------

  " --- Git差分表示プラグイン ---
  call dein#add('lewis6991/gitsigns.nvim')
  " -----------------------------

  " --- Syntax Highlighting Plugins ---
  " NOTE: pin explicitly to the `main` branch (the new, rewritten API that
  " treesitter_settings.lua targets, requires Neovim 0.12+). The `master`
  " branch is frozen/legacy and does not support Neovim 0.12; without this
  " pin, a future upstream default-branch change could silently break setup.
  call dein#add('nvim-treesitter/nvim-treesitter', {'rev': 'main', 'do': ':TSUpdate'})
  call dein#add('tomasr/molokai')
  " ---------------------------------

call dein#end()
call dein#save_state()

if dein#check_install()
  call dein#install()
endif
