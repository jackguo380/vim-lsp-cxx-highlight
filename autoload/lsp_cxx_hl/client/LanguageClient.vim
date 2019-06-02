" LanguageClient Neovim support

function! lsp_cxx_hl#client#LanguageClient#init() abort
    " This may do nothing if started up without a file open
    call s:doinit()

    augroup lsp_cxx_hl_language_client_init
        autocmd! 
        autocmd User LanguageClientStarted call s:doinit()
    augroup END
endfunction

function! s:doinit() abort
    let l:ret = LanguageClient#registerHandlers({
                \ '$cquery/publishSemanticHighlighting':
                \ 'lsp_cxx_hl#client#LanguageClient#cquery_hl',
                \ '$cquery/setInactiveRegions':
                \ 'lsp_cxx_hl#client#LanguageClient#cquery_regions',
                \ '$ccls/publishSemanticHighlight':
                \ 'lsp_cxx_hl#client#LanguageClient#ccls_hl',
                \ '$ccls/publishSkippedRanges':
                \ 'lsp_cxx_hl#client#LanguageClient#ccls_regions'
                \ })

    call lsp_cxx_hl#verbose_log('LanguageClient#registerHandlers() ret = ',
                \ l:ret)
endfunction


function! lsp_cxx_hl#client#LanguageClient#cquery_hl(params) abort
    "call lsp_cxx_hl#log('cquery hl:', a:params)

    call lsp_cxx_hl#notify_symbols('cquery', a:params['uri'],
                \ a:params['symbols'])
endfunction

function! lsp_cxx_hl#client#LanguageClient#cquery_regions(params) abort
    "call lsp_cxx_hl#log('cquery regions:', a:params)

    call lsp_cxx_hl#notify_skipped('cquery', a:params['uri'],
                \ a:params['inactiveRegions'])
endfunction

function! lsp_cxx_hl#client#LanguageClient#ccls_hl(params) abort
    "call lsp_cxx_hl#log('ccls hl:', a:params)

    call lsp_cxx_hl#notify_symbols('ccls', a:params['uri'],
                \ a:params['symbols'])
endfunction

function! lsp_cxx_hl#client#LanguageClient#ccls_regions(params) abort
    "call lsp_cxx_hl#log('ccls regions:', a:params)

    call lsp_cxx_hl#notify_skipped('ccls', a:params['uri'],
                \ a:params['skippedRanges'])
endfunction
