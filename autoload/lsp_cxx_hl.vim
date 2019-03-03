" Receive the full JSON RPC message possibly in string form
function! lsp_cxx_hl#receive_json_rpc(json) abort
    if type(a:json) ==# type('')
        let l:msg = json_decode(a:json)
    else
        let l:msg = a:json
    endif

    if type(l:msg) !=# type({}) || !has_key(l:msg, 'response')
        call lsp_cxx_hl#log('Received malformed message: ' . string(l:msg))
        return
    endif

    let l:response = l:msg['response']
    let l:method = get(l:response, 'method', '')

    if l:method ==? '$cquery/publishSemanticHighlighting'
        let l:server = 'cquery'
        let l:is_skipped = 0
        let l:data_key = 'symbols'
    elseif l:method ==? '$cquery/setInactiveRegions'
        let l:server = 'cquery'
        let l:is_skipped = 1
        let l:data_key = 'inactiveRegions'
    elseif l:method ==? '$ccls/publishSemanticHighlight'
        let l:server = 'ccls'
        let l:is_skipped = 0
        let l:data_key = 'symbols'
    elseif l:method ==? '$ccls/publishSkippedRanges'
        let l:server = 'ccls'
        let l:is_skipped = 1
        let l:data_key = 'skippedRanges'
    else
        " Silently ignore unwanted messages since vim-lsp
        " doesn't support subscribing to a specific type
        call lsp_cxx_hl#log('Skipped Message: ' . l:method)
        return
    endif

    call lsp_cxx_hl#log('Received Message: ' . l:method)

    if !has_key(l:response, 'params') ||
                \ !has_key(l:response['params'], l:data_key) ||
                \ !has_key(l:response['params'], 'uri')
        call lsp_cxx_hl#log('Response has invalid parameters: ' .
                    \ string(l:response))
        return
    endif

    let l:bufnr = s:uri2bufnr(l:response['params']['uri'])

    if l:is_skipped
        call lsp_cxx_hl#receive_skipped_data(l:server,
                    \ l:bufnr, l:response['params'][l:data_key])
    else
        call lsp_cxx_hl#receive_symbol_data(l:server,
                    \ l:bufnr, l:response['params'][l:data_key])
    endif
endfunction

" Receive already extracted skipped region data
function! lsp_cxx_hl#receive_skipped_data(server, bufnr, skipped) abort
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

    " No conversion done since ccls and cquery both use the same format
    call setbufvar(a:bufnr, 'lsp_cxx_hl_skipped', a:skipped)
    call setbufvar(a:bufnr, 'lsp_cxx_hl_need_update', 1)
endfunction!

" Receive already extracted symbol data
function! lsp_cxx_hl#receive_symbol_data(server, bufnr, symbols) abort
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

    if a:server ==# 'cquery' || a:server ==# 'ccls'
        let l:is_ccls = (a:server ==# 'ccls')
        let l:n_symbols = s:normalize_symbols(a:symbols, l:is_ccls)

        call setbufvar(a:bufnr, 'lsp_cxx_hl_symbols', l:n_symbols)
        call setbufvar(a:bufnr, 'lsp_cxx_hl_need_update', 1)
    else
        echoerr 'Only cquery or ccls is supported'
    endif
endfunction

" Log
function! lsp_cxx_hl#log(...) abort
    if len(get(g:, 'lsp_cxx_hl_log_file', '')) > 0
        call writefile([strftime('%c') . ':' . string(a:000)],
                    \ g:lsp_cxx_hl_log_file, 'a')
    endif
endfunction

" Section: Helpers
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

    let l:n_symbols = []

    for l:sym in a:symbols
        let l:id = get(l:sym, l:id_key, 0)

        let l:kind = s:symbol_kind_str(get(l:sym, 'kind', 0))
        let l:pkind = s:symbol_kind_str(get(l:sym, 'parentKind', 0))

        if a:is_ccls
            let l:storage = s:ccls_storage_str(get(l:sym, 'storage', 0))
        else
            let l:storage = s:cquery_storage_str(get(l:sym, 'storage', 0))
        endif

        let l:n_sym = {
                    \ 'id': l:id,
                    \ 'kind': l:kind,
                    \ 'parentKind': l:pkind,
                    \ 'storage': l:storage,
                    \ }

        if !a:is_ccls
            let l:n_sym['role'] = s:cquery_role_dict(get(l:sym, 'role', 0))
        endif

        if l:is_offset
            let l:n_sym['offsets'] = get(l:sym, 'ranges', [])
        else
            let l:n_sym['ranges'] = get(l:sym, l:range_key, [])
        endif

        call add(l:n_symbols, l:n_sym)
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
let s:cxx_symbol_kind_base = 252
let s:cxx_symbol_kinds = [
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
    elseif s:cxx_symbol_kind_base <= a:kind && 
                \ a:kind < (s:cxx_symbol_kind_base + len(s:cxx_symbol_kinds))
        return s:cxx_symbol_kinds[a:kind - s:cxx_symbol_kind_base]
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
    endif

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
