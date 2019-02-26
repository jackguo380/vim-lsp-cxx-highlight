if exists('g:lsp_cpp_highlight_loaded')
    finish
endif

if !exists('g:lsp_loaded')
    echohl ErrorMsg
    echom 'vim-lsp is required but not found!'
    echohl NONE
    finish
endif

" Internal variables
let g:lsp_cpp_highlight_loaded = 1
let g:lsp_cpp_highlight_initialized = 0
" Can only support ccls' range scheme if byte2line is available
let g:lsp_cpp_highlight_ccls_offsets = has('+byte_offset')

"command! LspStartHL call lsp#cquery#highlight#try_init()
