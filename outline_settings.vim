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
let g:vista_close_on_jump = 1

" Vista の表示をトグルするコマンド
nnoremap <silent> <C-k> :Vista!!<CR>

" Markdown ファイルタイプでのみ Vista を有効にする例
autocmd FileType markdown silent! Vista!
