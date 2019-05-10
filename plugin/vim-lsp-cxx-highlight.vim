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

function s:initialize() abort
    let l:ok = 0

    call lsp_cxx_hl#log('lsp_cxx_hl beginning initialization...')

    try
        call lsp_cxx_hl#client#vim_lsp#init()
        call lsp_cxx_hl#log('vim-lsp successfully registered')
        let l:ok = 1
    catch /E117:.*lsp#register_notifications/
        call lsp_cxx_hl#log('vim-lsp not detected')
    catch
        call lsp_cxx_hl#log('vim-lsp failed to register: ',
                    \ v:exception)
    endtry

    try
        call lsp_cxx_hl#client#LanguageClient#init()
        call lsp_cxx_hl#log('LanguageClient-neovim successfully registered')
        let l:ok = 1
    catch /E117:.*LanguageClient#registerHandlers/
        call lsp_cxx_hl#log('LanguageClient-neovim not detected')
    catch
        call lsp_cxx_hl#log('LanguageClient-neovim failed to register: ',
                    \ v:exception)
    endtry

    if l:ok != 1
        call lsp_cxx_hl#log('Failed to find a compatible LSP client')
        echohl ErrorMsg
        echomsg 'Lsp client not found!'
        echohl NONE
    endif
endfunction

augroup lsp_cxx_highlight
    autocmd!
    autocmd VimEnter * call s:initialize()
    autocmd VimEnter,ColorScheme * runtime syntax/lsp_cxx_highlight.vim
    autocmd ColorScheme * call lsp_cxx_hl#buffer#check(1, 0)
    autocmd BufEnter,WinEnter * call lsp_cxx_hl#buffer#check(0, 0)
    autocmd User lsp_cxx_highlight_check call lsp_cxx_hl#buffer#check(0, 0)
augroup END

command! LspCxxHighlight call lsp_cxx_hl#buffer#check(1, 1)
command! LspCxxHighlightDisable call lsp_cxx_hl#buffer#disable()

" Debug Commands
command! LspCxxHlIgnoredSyms call lsp_cxx_hl#debug#ignored_symbols()
command! LspCxxHlDumpSyms call lsp_cxx_hl#debug#dump_symbols()
command! LspCxxHlCursorSym call lsp_cxx_hl#debug#cursor_symbol()
