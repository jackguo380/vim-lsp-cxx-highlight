" vim-lsp-cpp-highlight plugin by Jack Guo
" www.github.com/jackguo380/vim-lsp-cpp-highlight

if exists('g:lsp_cxx_hl_loaded')
    finish
endif

" Internal variables
let g:lsp_cxx_hl_loaded = 1
let g:lsp_cxx_hl_initialized = 0

" Settings
let g:lsp_cxx_hl_log_file = get(g:, 'lsp_cxx_hl_log_file', '')
let g:lsp_cxx_hl_verbose_log = get(g:, 'lsp_cxx_hl_verbose_log', 0)
let g:lsp_cxx_hl_ft_whitelist = get(g:, 'lsp_cxx_hl_ft_whitelist',
            \ ['c', 'cpp', 'objc', 'objcpp', 'cc'])
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

augroup lsp_cxx_highlight
    autocmd!
    autocmd VimEnter,ColorScheme * runtime syntax/lsp_cxx_highlight.vim
    autocmd ColorScheme * call lsp_cxx_hl#buffer#check(1)
    autocmd BufEnter,WinEnter * call lsp_cxx_hl#buffer#check(0)
    autocmd User lsp_cxx_highlight_check call lsp_cxx_hl#buffer#check(0)
augroup END

command! LspCxxHighlight call lsp_cxx_hl#buffer#check(1)

" Debug Commands
command! LspCxxHlIgnoredSyms call lsp_cxx_hl#debug#ignored_symbols()
command! LspCxxHlDumpSyms call lsp_cxx_hl#debug#dump_symbols()
command! LspCxxHlCursorSym call lsp_cxx_hl#debug#cursor_symbol()
