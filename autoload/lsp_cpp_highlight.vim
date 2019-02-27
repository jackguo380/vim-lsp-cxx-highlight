function! lsp_cpp_highlight#receive_json_rpc(json) abort
    if type(a:json) ==# type('')
        let l:msg = json_decode(a:json)
    else
        let l:msg = a:json
    endif

    if type(l:msg) !=# type({}) || !has_key(l:msg, 'response')
        echoerr 'Received malformed message: ' . string(l:msg)
        return
    endif

    let l:response = l:msg['response']
    let l:method = get(l:response, 'method', '')

    if l:method ==? '$cquery/publishSemanticHighlighting'
        let l:server = 'cquery'
    elseif l:method ==? '$ccls/publishSemanticHighlighting'
        let l:server = 'ccls'
    else
        " Silently ignore unwanted messages since vim-lsp
        " doesn't support subscribing to a specific type
        return
    endif

    if !has_key(l:response, 'params') ||
                \ !has_key(l:response['params'], 'symbols') ||
                \ !has_key(l:response['params'], 'uri')
        echoerr 'Response has invalid parameters: ' . string(l:response)
        return
    endif

    let l:bufnr = lsp_cpp_highlight#uri2bufnr(l:response['params']['uri'])

    call lsp_cpp_highlight#receive_symbol_data(l:server,
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

    if a:server ==# 'cquery'
        "let l:buf_symbols = s:parse_lsp_range_symbols(a:symbols, 'stableId', 'ranges')
    elseif a:server ==# 'ccls'
        " Check the first symbol to determine ccls schema
        if has_key(a:symbols[0]['ranges'], 'L') &&
                    \ has_key(a:symbols[0]['ranges'], 'R')
            if !g:lsp_cpp_highlight_ccls_offsets
                call s:error_msg('Cannot handle ccls message due to missing
                            \ +byte_offset')
                return
            endif

            "let l:buf_symbols = s:ccls_symbols_to_matches(a:symbols)
        else
            "let l:buf_symbols = s:lsp_symbols_to_matches(a:symbols, 'id', 'lsRanges')
        endif
    else
        echoerr 'Only cquery or ccls is supported'
    endif

    echom 'End of Response'
endfunction

function! s:lsp_range_to_matchs(range) abort
    let l:s_line = a:range['start']['line']
    let l:s_char = a:range['start']['character']
    let l:e_line = a:range['end']['line']
    let l:e_char = a:range['end']['character']

    if l:s_line == l:e_line
        return [[l:s_line + 1, l:s_char + 1, l:e_char - l:s_char]]
    endif

    for l:line in range(l:s_line, l:e_line)
        
    endfor
endfunction

" Parse cquery and ccls ranges
" Note that cquery and ccls use different key names for somethings
"                   cquery     ccls
" symbol id:       'stableID'  'id'
" highlight range: 'ranges'    'lsRanges'
function! s:normalize_lsp_symbols(symbols, id_key, range_key) abort
    let l:matches = {}

    for l:sym in a:symbols
        let l:id = l:sym[a:id_key]

        if has_key(l:matches, l:id)
            echoerr 'Duplicate Id: ' . l:id
            return
        endif

        "l:matches[l:id] = {}

        let l:message = 'Id: ' . l:sym[a:id_key] 
        let l:message .= ' Kind: ' . l:sym['kind']
        let l:message .= ' Role: ' . l:sym['role']
        let l:message .= ' Storage: ' . l:sym['storage']
        let l:message .= ' ParentKind: ' . l:sym['parentKind']
        let l:message .= ' Ranges: ' . string(l:sym[a:range_key])

        echomsg l:message
    endfor
endfunction

function! s:normalize_ccls_symbols(symbols) abort
    for l:sym in a:symbols
        let l:message = 'Id: ' . l:sym['stableId'] 
        let l:message .= ' Kind: ' . l:sym['kind']
        let l:message .= ' Role: ' . l:sym['role']
        let l:message .= ' Storage: ' . l:sym['storage']
        let l:message .= ' ParentKind: ' . l:sym['parentKind']
        let l:message .= ' Ranges: ' . string('ranges')

        echomsg l:message
    endfor
endfunction

" ==== Cquery Role ====

function! s:cquery_role_list(role_int) abort
    let l:role_list = []
    let l:k_roles = [
                \ 'Declaration',
                \ 'Definition',
                \ 'Reference',
                \ 'Read',
                \ 'Write',
                \ 'Call',
                \ 'Dynamic',
                \ 'Address',
                \ 'Implicit']

    let l:bit = 1

    for l:role in l:k_roles
        if and(a:role_int, l:bit)
            add(l:role_list, l:role)
        endif

        let l:bit = l:bit * 2
    endfor

    return l:role_list
endfunction

" ==== Storage Class ====
" libclang's enum begins with None
" but cquery puts Invalid as 0 instead
function! s:cquery_storage_class_str(sc) abort
    if a:sc == 0
        return 'None'

    return s:ccls_storage_class_str(a:sc - 1)
endfunction

function! s:ccls_storage_class_str(sc) abort
    return get(['None',
                \ 'Extern',
                \ 'Static',
                \ 'PrivateExtern',
                \ 'Auto',
                \ 'Register'],
                \ a:sc, 'None')
endfunction

" ==== Helpers ====
function! lsp_cpp_highlight#uri2bufnr(uri) abort
    " Remove the leading file:// or whatever protocol is used
    let l:filename = substitute(a:uri, '\c[a-z]\+://', '', '')
    return bufnr(l:filename)
endfunction

function! s:error_msg(msg) abort
    echohl ErrorMsg
    echomsg a:msg
    echohl NONE
endfunction
