" vim-lsp-cpp-highlight plugin by Jack Guo
" www.github.com/jackguo380/vim-lsp-cpp-highlight

if exists('g:lsp_cpp_highlight_loaded')
    finish
endif

" Internal variables
let g:lsp_cxx_hl_loaded = 1
let g:lsp_cxx_hl_initialized = 0

" Settings
let g:lsp_cxx_hl_log_file = get(g:, 'lsp_cxx_hl_log_file', '')
let g:lsp_cxx_hl_inactive_region_priority = get(g:,
            \ 'lsp_cxx_hl_inactive_region_priority', -99)
let g:lsp_cxx_hl_syntax_priority = get(g:, 'lsp_cxx_hl_syntax_priority', -100)

if exists('g:lsp_loaded')
    augroup lsp_cxx_hl_autostart
        autocmd!
        autocmd VimEnter * call lsp_cxx_hl#client#vim_lsp#init()
    augroup END
else
    echohl ErrorMsg
    echomsg 'Lsp client not found!'
    echohl NONE
    finish
endif

command! LspCxxHighlight call lsp_cxx_hl#buffer#check(1)

" Debug Commands
command! LspCxxHlIgnoredSyms call lsp_cxx_hl#debug#ignored_symbols()
command! LspCxxHlDumpSyms call lsp_cxx_hl#debug#dump_symbols()

runtime syntax/lsp_cxx_highlight.vim
