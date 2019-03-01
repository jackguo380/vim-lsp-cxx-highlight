" vim-lsp-cpp-highlight plugin by Jack Guo
" www.github.com/jackguo380/vim-lsp-cpp-highlight

if exists('g:lsp_cpp_highlight_loaded')
    finish
endif

" Internal variables
let g:lsp_cpp_highlight_loaded = 1
let g:lsp_cpp_highlight_initialized = 0
" Can only support ccls' range scheme if byte2line is available
let g:lsp_cpp_highlight_ccls_offsets = has('byte_offset')

if exists('g:lsp_loaded')
    augroup lsp_cpp_hl_autostart
        autocmd!
        autocmd VimEnter * call lsp_cpp_highlight#vim_lsp#init()
    augroup END
else
    echohl ErrorMsg
    echomsg 'Lsp client not found!'
    echohl NONE
    finish
endif
