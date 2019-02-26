function! lsp_cpp_highlight#receive_json_rpc(json) abort
    if type(a:json) ==# type('')
        let l:msg = json_decode(a:json)
    else
        let l:msg = a:json
    endif

    if type(l:msg) !=# type({}) || !has_key(l:msg, 'response') ||
                \ !has_key(l:msg['response'], 'method')
        echoerr 'Received malformed message: ' . l:msg
        return
    endif

    let l:response = l:msg['response']
    let l:method = l:response['method']

    if l:method ==? '$cquery/publishSemanticHighlighting'
        let l:server = 'cquery'
    elseif l:method !=? '$ccls/publishSemanticHighlighting'
        let l:server = 'ccls'
    else
        " Silently ignore unwanted notifications since vim-lsp
        " doesn't support subscribing to a specific type
        return
    endif

    if !has_key(l:response, 'params') ||
                \ !has_key(l:response['params'], 'symbols') ||
                \ !has_key(l:response['params'], 'uri')
        echoerr 'Response has invalid parameters: ' . l:response
        return
    endif

    let l:bufnr = lsp_cpp_highlight#uri2bufnr(l:response['params']['uri'])

    lsp#cpp#highlight#receive_symbol_data(l:server,
                \ l:bufnr, l:response['params']['symbols'])
endfunction

function! lsp_cpp_highlight#receive_symbol_data(server, bufnr, symbols) abort
    " It may be possible that a delayed message arrives after a buffer closed
    if !bufexists(a:bufnr)
        return
    endif

    if type(a:symbols) !=# type([])
        echoerr 'symbols must be a list'
        return
    endif

    if len(a:symbols) == 0
        return
    endif

    echom 'Got Response:'

    if server ==# 'cquery'
        call s:parse_lsp_range_symbols(a:symbols, 'ranges')
    elseif server ==# 'ccls'
        " Check the first symbol to determine ccls schema
        if has_key(a:symbols[0]['ranges'], 'L') &&
                    \ has_key(a:symbols[0]['ranges'], 'R')
            if !g:lsp_cpp_highlight_ccls_offsets
                call s:error_msg('Cannot handle ccls message due to missing
                            \ +byte_offset')
                return
            endif

            s:parse_ccls_offset_symbols(a:symbols)
        else
            s:parse_lsp_range_symbols(a:symbols, 'lsRanges')
        endif
    else
        echoerr 'Only cquery or ccls is supported'
    endif

    echom 'End of Response'
endfunction

function! s:parse_lsp_range_symbols(symbols, rangekey) abort
    for l:sym in a:symbols
        let l:message = 'Id: ' . l:sym['stableId'] 
        let l:message .= ' Kind: ' . l:sym['kind']
        let l:message .= ' Role: ' . l:sym['role']
        let l:message .= ' Storage: ' . l:sym['storage']
        let l:message .= ' ParentKind: ' . l:sym['parentKind']
        let l:message .= ' Ranges: ' . string(l:sym[a:rangekey])

        echom l:message
    endfor
endfunction

function! s:parse_ccls_offset_symbols(symbols) abort
    for l:sym in a:symbols
        let l:message = 'Id: ' . l:sym['stableId'] 
        let l:message .= ' Kind: ' . l:sym['kind']
        let l:message .= ' Role: ' . l:sym['role']
        let l:message .= ' Storage: ' . l:sym['storage']
        let l:message .= ' ParentKind: ' . l:sym['parentKind']
        let l:message .= ' Ranges: ' . string('ranges')

        echom l:message
    endfor
endfunction

function! lsp_cpp_highlight#uri2bufnr(uri) abort
    " Remove the leading file:// or whatever protocol is used
    let l:filename = substitute(a:uri, '\c[a-z]\+://', '', '')
    return bufnr(l:filename)
endfunction

function! s:error_msg(msg) abort
    echohl ErrorMsg
    echom a:msg
    echohl NONE
endfunction
