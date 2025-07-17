" Vista.vim の設定
let g:vista_icon_indent = ['╰─▸ ', '├─▸ ']
let g:vista_default_executive = 'ctags'

" Markdownの見出しを検出するためにctagsの設定を調整
" Universal Ctagsがインストールされている必要があります。
" ctagsのインストールについては後述の「必要な外部ツール」を参照ください。
let g:vista_ctags_cmd = {
\ 'markdown': 'ctags --language-force=markdown --markdown-kinds=h --fields=+K',
\ }

" 自動非表示機能を制御するグローバル変数を定義
" 0で無効、1で有効
let g:vista_auto_close_outline = 1

" Vista の表示をトグルするコマンド
nnoremap <silent> <Leader>o :Vista!!<CR>

" Vista で選択後、アウトラインを自動的に閉じる
autocmd User VistaJumpPost execute g:vista_auto_close_outline ? ':Vista! -c' : ''
" または
" autocmd User VistaJumpPost if g:vista_auto_close_outline | Vista! -c | endif

" Markdown ファイルタイプでのみ Vista を有効にする例
autocmd FileType markdown silent! Vista!
