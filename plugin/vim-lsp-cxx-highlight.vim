" vim-lsp-cpp-highlight plugin by Jack Guo
" www.github.com/jackguo380/vim-lsp-cpp-highlight

if exists('g:lsp_cxx_hl_loaded')
    finish
endif

" Internal variables
let g:lsp_cxx_hl_loaded = 1

" Settings
let g:lsp_cxx_hl_log_file = get(g:, 'lsp_cxx_hl_log_file', '')
let g:lsp_cxx_hl_verbose_log = get(g:, 'lsp_cxx_hl_verbose_log', 0)
let g:lsp_cxx_hl_ft_whitelist = get(g:, 'lsp_cxx_hl_ft_whitelist',
            \ ['c', 'cpp', 'objc', 'objcpp', 'cc', 'cuda'])
let g:lsp_cxx_hl_inactive_region_priority = get(g:,
            \ 'lsp_cxx_hl_inactive_region_priority', -99)
let g:lsp_cxx_hl_syntax_priority = get(g:, 'lsp_cxx_hl_syntax_priority', -100)
let g:lsp_cxx_hl_use_text_props = get(g:, 'lsp_cxx_hl_use_text_props',
            \ (has('textprop') && v:version >= 802))
let g:lsp_cxx_hl_use_nvim_text_props = get(g:,
            \ 'lsp_cxx_hl_use_nvim_text_props', has('nvim-0.3.0'))
let g:lsp_cxx_hl_text_prop_refresh_count = get(g:,
            \ 'lsp_cxx_hl_text_prop_refresh_count', 10)
let g:lsp_cxx_hl_light_bg = get(g:, 'lsp_cxx_hl_light_bg', 0)
let g:lsp_cxx_hl_clear_delay_ms = get(g:, 'lsp_cxx_hl_clear_delay_ms', 30000)

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

    try
        call lsp_cxx_hl#client#coc#init()
        call lsp_cxx_hl#log('coc.nvim successfully registered')
        let l:ok = 1
    catch /E117:.*CocRegistNotification/
        call lsp_cxx_hl#log('coc.nvim not detected')
    catch
        call lsp_cxx_hl#log('coc.nvim failed to register: ',
                    \ v:exception)
    endtry

    try
        call lsp_cxx_hl#client#nvim_lsp#init()
        call lsp_cxx_hl#log('nvim-lsp successfully registered')
        let l:ok = 1
    catch /E5105:.*attempt to index field.*lsp.*nil value/
        call lsp_cxx_hl#log('nvim-lsp not detected')
    catch /Not Neovim/
        call lsp_cxx_hl#log('Not registering nvim-lsp as this is not Neovim')
    catch
        call lsp_cxx_hl#log('nvim-lsp failed to register: ',
                    \ v:exception)
    endtry

    if l:ok != 1
        call lsp_cxx_hl#log('Failed to find a compatible LSP client')
        echohl ErrorMsg
        echomsg 'vim-lsp-cxx-highlight cannot find a LSP client'
        echohl NONE
    endif
endfunction

augroup lsp_cxx_highlight
    autocmd!
    autocmd VimEnter * call s:initialize()
    autocmd VimEnter,ColorScheme * runtime syntax/lsp_cxx_highlight.vim
    autocmd ColorScheme * call lsp_cxx_hl#hl#check(1)
    autocmd BufEnter,WinEnter * call lsp_cxx_hl#hl#check(0)
augroup END

" Handle delayed plugin startup
if v:vim_did_enter
    runtime syntax/lsp_cxx_highlight.vim
    call s:initialize()
endif

command! LspCxxHighlight call lsp_cxx_hl#hl#enable()
command! LspCxxHighlightDisable call lsp_cxx_hl#hl#disable()

" Debug Commands
command! LspCxxHlIgnoredSyms call lsp_cxx_hl#debug#ignored_symbols()
command! LspCxxHlDumpSyms call lsp_cxx_hl#debug#dump_symbols()
command! LspCxxHlCursorSym call lsp_cxx_hl#debug#cursor_symbol()
