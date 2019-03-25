" LanguageClient Neovim support

function! lsp_cxx_hl#client#LanguageClient#init() abort
    call LanguageClient#registerHandlers({
                \ '$cquery/publishSemanticHighlighting':
                \ 'lsp_cxx_hl#client#LanguageClient#cquery_hl',
                \ '$cquery/setInactiveRegions':
                \ 'lsp_cxx_hl#client#LanguageClient#cquery_regions',
                \ '$ccls/publishSemanticHighlight':
                \ 'lsp_cxx_hl#client#LanguageClient#ccls_hl',
                \ '$ccls/publishSkippedRegions':
                \ 'lsp_cxx_hl#client#LanguageClient#ccls_regions'
        })
endfunction


function! lsp_cxx_hl#client#LanguageClient#cquery_hl(params) abort
    call lsp_cxx_hl#log('cquery hl:', a:params)

    call lsp_cxx_hl#notify_symbols('cquery', a:params['uri'], a:params['symbols'])
endfunction

function! lsp_cxx_hl#client#LanguageClient#cquery_regions(params) abort
    call lsp_cxx_hl#log('cquery regions:', a:params)

    call lsp_cxx_hl#notify_symbols('cquery', a:params['uri'], a:params['inactiveRegions'])
endfunction

function! lsp_cxx_hl#client#LanguageClient#ccls_hl(params) abort
    call lsp_cxx_hl#log('ccls hl:', a:params)

    call lsp_cxx_hl#notify_symbols('ccls', a:params['uri'], a:params['symbols'])
endfunction

function! lsp_cxx_hl#client#LanguageClient#ccls_region(params) abort
    call lsp_cxx_hl#log('ccls regions:', a:params)

    call lsp_cxx_hl#notify_symbols('ccls', a:params['uri'], a:params['skippedRanges'])
endfunction
