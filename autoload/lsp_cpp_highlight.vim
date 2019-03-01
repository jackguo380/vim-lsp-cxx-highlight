" Receive the full JSON RPC message possibly in string form
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
        let l:is_skipped = 0
    elseif l:method ==? '$cquery/setInactiveRegions'
        let l:server = 'cquery'
        let l:is_skipped = 1
    elseif l:method ==? '$ccls/publishSemanticHighlight'
        let l:server = 'ccls'
        let l:is_skipped = 0
    elseif l:method ==? '$ccls/publishSkippedRanges'
        let l:server = 'ccls'
        let l:is_skipped = 1
    else
        " Silently ignore unwanted messages since vim-lsp
        " doesn't support subscribing to a specific type
        echomsg 'Skipped Message: ' . l:method
        return
    endif

    if l:is_skipped
        let l:data_key = (l:server ==# 'cquery') ?
                    \ 'inactiveRegions' : 'skippedRanges'
    else
        let l:data_key = 'symbols'
    endif

    if !has_key(l:response, 'params') ||
                \ !has_key(l:response['params'], l:data_key) ||
                \ !has_key(l:response['params'], 'uri')
        echoerr 'Response has invalid parameters: ' . string(l:response)
        return
    endif

    let l:bufnr = s:uri2bufnr(l:response['params']['uri'])

    if l:is_skipped
        call lsp_cpp_highlight#receive_skipped_data(l:server,
                    \ l:bufnr, l:response['params'][l:data_key])
    else
        call lsp_cpp_highlight#receive_symbol_data(l:server,
                    \ l:bufnr, l:response['params'][l:data_key])
    endif
endfunction

" Receive already extracted skipped region data
function! lsp_cpp_highlight#receive_skipped_data(server, bufnr, skipped) abort
    " It may be possible that a delayed message arrives after a buffer closed
    if !bufexists(a:bufnr)
        echoerr 'buffer does not exist!'
        return
    endif

    if type(a:skipped) !=# type([])
        echoerr 'skipped must be a list'
        return
    endif

    if len(a:skipped) == 0
        return
    endif

    echom 'Got Skipped Response:'
    echomsg string(a:skipped)
    echom 'End of Skipped Response'
endfunction!

" Receive already extracted symbol data
function! lsp_cpp_highlight#receive_symbol_data(server, bufnr, symbols) abort
    " It may be possible that a delayed message arrives after a buffer closed
    if !bufexists(a:bufnr)
        echoerr 'buffer does not exist!'
        return
    endif

    if type(a:symbols) !=# type([])
        echoerr 'symbols must be a list'
        return
    endif

    if len(a:symbols) == 0
        return
    endif

    echomsg 'Got Response:'

    if a:server ==# 'cquery' || a:server ==# 'ccls'
        let l:is_ccls = (a:server ==# 'ccls')
        let l:n_symbols = s:normalize_symbols(a:symbols, l:is_ccls)
        echomsg string(l:n_symbols)
    else
        echoerr 'Only cquery or ccls is supported'
    endif

    echom 'End of Response'
endfunction

"function! s:lsp_range_to_matchs(range) abort
"    let l:s_line = a:range['start']['line']
"    let l:s_char = a:range['start']['character']
"    let l:e_line = a:range['end']['line']
"    let l:e_char = a:range['end']['character']
"
"    if l:s_line == l:e_line
"        return [[l:s_line + 1, l:s_char + 1, l:e_char - l:s_char]]
"    endif
"
"    for l:line in range(l:s_line, l:e_line)
"        
"    endfor
"endfunction

" Parse symbols and put them in a unified format
" Note that cquery and ccls use different key names for somethings
"                   cquery     ccls
" symbol id:       'stableId'  'id'
" highlight range: 'ranges'    'lsRanges'
" offsets (ccls):  N/A         'ranges'
function! s:normalize_symbols(symbols, is_ccls) abort
    if a:is_ccls
        let l:id_key = 'id'
        let l:range_key = 'lsRanges'

        " Determine if we are using offsets
        " Finding one key should be enough
        for l:sym in a:symbols
            if len(get(l:sym, 'ranges', [])) > 0
                let l:is_offset = 1
                break
            elseif len(get(l:sym, 'lsRanges', [])) > 0
                let l:is_offset = 0
                break
            endif
        endfor
    else
        let l:id_key = 'stableId'
        let l:range_key = 'ranges'
        let l:is_offset = 0
    endif

    let l:n_symbols = {}

    for l:sym in a:symbols
        let l:id = l:sym[l:id_key]

        let l:kind = s:symbol_kind_str(get(l:sym, 'kind', 0))
        let l:pkind = s:symbol_kind_str(get(l:sym, 'parentKind', 0))

        if a:is_ccls
            let l:storage = s:ccls_storage_str(get(l:sym, 'storage', 0))
        else
            let l:storage = s:cquery_storage_str(get(l:sym, 'storage', 0))
        endif

        let l:n_symbols[l:id] = {
                    \ 'kind': l:kind,
                    \ 'parentKind': l:pkind,
                    \ 'storage': l:storage,
                    \ }

        if !a:is_ccls
            let l:n_symbols['role'] = s:cquery_role_dict(get(l:sym, 'role', 0))
        endif

        if l:is_offset
            let l:n_symbols['offsets'] = l:sym['ranges']
        else
            let l:n_symbols['ranges'] = l:sym[l:range_key]
        endif
    endfor

    return l:n_symbols
endfunction

" Section: Parse Kind/ParentKind
let s:lsp_symbol_kinds = [
            \ 'Unknown',
            \ 'File',
            \ 'Module',
            \ 'Namespace',
            \ 'Package',
            \ 'Class',
            \ 'Method',
            \ 'Property',
            \ 'Field',
            \ 'Constructor',
            \ 'Enum',
            \ 'Interface',
            \ 'Function',
            \ 'Variable',
            \ 'Constant',
            \ 'String',
            \ 'Number',
            \ 'Boolean',
            \ 'Array',
            \ 'Object',
            \ 'Key',
            \ 'Null',
            \ 'EnumMember',
            \ 'Struct',
            \ 'Event',
            \ 'Operator',
            \ 'TypeParameter'
            \ ]

" cquery and ccls use the same
" extensions to LSP
let s:cpp_symbol_kind_base = 252
let s:cpp_symbol_kinds = [
            \ 'TypeAlias',
            \ 'Parameter',
            \ 'StaticMethod',
            \ 'Macro'
            \ ]

function! s:symbol_kind_str(kind) abort
    if a:kind < 0
        return 'Unknown'
    elseif a:kind < len(s:lsp_symbol_kinds)
        return s:lsp_symbol_kinds[a:kind]
    elseif s:cpp_symbol_kind_base <= a:kind && 
                \ a:kind < (s:cpp_symbol_kind_base + len(s:cpp_symbol_kinds))
        return s:cpp_symbol_kinds[a:kind - s:cpp_symbol_kind_base]
    else
        return 'Unknown'
    endif
endfunction

" Section: Parse Storage Class
" In libclang's enum None = 0
" but cquery has Invalid = 0
function! s:cquery_storage_str(sc) abort
    if a:sc == 0
        return 'None'

    return s:ccls_storage_str(a:sc - 1)
endfunction

" ccls uses the enum directly
function! s:ccls_storage_str(sc) abort
    return get(['None',
                \ 'Extern',
                \ 'Static',
                \ 'PrivateExtern',
                \ 'Auto',
                \ 'Register'],
                \ a:sc, 'None')
endfunction

" Section: Parse Cquery Role
let s:k_roles = [
            \ 'Declaration',
            \ 'Definition',
            \ 'Reference',
            \ 'Read',
            \ 'Write',
            \ 'Call',
            \ 'Dynamic',
            \ 'Address',
            \ 'Implicit'
            \ ]

" Convert the bitmap to a map
function! s:cquery_role_dict(role_int) abort
    let l:role_dict = {}

    let l:bit = 1

    for l:role in s:k_roles
        let l:role_dict[l:role] = (and(a:role_int, l:bit) != 0)

        let l:bit = l:bit * 2
    endfor

    return l:role_dict
endfunction

" Section: Misc Helpers
function! s:uri2bufnr(uri) abort
    " Remove the leading file:// or whatever protocol is used
    let l:filename = substitute(a:uri, '\c[a-z]\+://', '', '')
    return bufnr(l:filename)
endfunction

function! s:error_msg(msg) abort
    echohl ErrorMsg
    echomsg a:msg
    echohl NONE
endfunction
