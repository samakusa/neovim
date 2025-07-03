function! IME_Off()
    silent! call system('zenhan 0')
endfunction

autocmd InsertLeave * call IME_Off()
autocmd CmdlineLeave * call IME_Off()