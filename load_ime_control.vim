function! IME_Off()
    silent! call system('zenhan 0')
endfunction

if has('win32')
  autocmd InsertLeave * call IME_Off()
  autocmd CmdlineLeave * call IME_Off()
elseif has('mac')
  " NOTE: im-selectのインストールが必要です
  augroup ime_control_mac
    autocmd!
    " Normal Modeに入る際に英数入力モードに切り替える
    autocmd InsertLeave * call system('im-select im-select com.google.inputmethod.Japanese.Roman')
    " Insert Modeに入る際には、IMEの状態を変更しない（手動での切り替えを想定）
  augroup END
else
  " NOTE: im-selectのインストールが必要です
  " https://github.com/daipeihust/im-select
  " デスクトップ環境やIMEによって設定が異なります。
  " 以下は、iBusやFcitxなどの環境でim-selectが利用できる場合の例です。
  augroup ime_control_linux
    autocmd!
    " Normal Modeに入る際に英数入力モードに切り替える
    " `im-select`の引数は環境によって異なる場合があります
    autocmd InsertLeave * call system('im-select 1')
  augroup END
endif
