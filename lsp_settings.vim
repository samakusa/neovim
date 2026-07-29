" preservim/vim-markdown が同梱する独自の syntax/markdown.vim が
" (Neovim組み込みのsyntax/markdown.vimと衝突し) markdownId等のハイライト
" グループを定義しないため、syntax/java.vim側のJavadoc用Markdown連携
" (JEP 467, `///` コメント)が `:syn clear` 時にE28で失敗し、.javaを開く
" たびにエラーメッセージが出る。公式ドキュメント(:h ft-java-plugin)で
" 案内されている回避策として、この連携機能自体を無効化する。
let g:java_ignore_markdown = 1
