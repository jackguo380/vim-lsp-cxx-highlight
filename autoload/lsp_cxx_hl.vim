" Common entrypoint for receiving LSP notifications
let s:has_reltime = has('reltime')

" Receive the full JSON RPC message possibly in string form
function! lsp_cxx_hl#notify_json_rpc(json) abort
    try
        call s:notify_json_rpc(a:json)
    catch
        call lsp_cxx_hl#log('notify_json_rpc error: ', v:exception, 'at',
                    \ v:throwpoint)
    endtry
endfunction

function! s:notify_json_rpc(json) abort
    if type(a:json) ==# type('')
        let l:msg = json_decode(a:json)
    else
        let l:msg = a:json
    endif

    if type(l:msg) !=# type({})
        call lsp_cxx_hl#log('Received malformed message: ', l:msg)
        return
    endif

    let l:method = get(l:msg, 'method', '')

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
        " Silently ignore unwanted messages
        call lsp_cxx_hl#log('Skipped Message: ', l:method)
        return
    endif

    call lsp_cxx_hl#log('Received Message: ', l:method)

    if !has_key(l:msg, 'params') ||
                \ !has_key(l:msg['params'], l:data_key) ||
                \ !has_key(l:msg['params'], 'uri')
        call lsp_cxx_hl#log('Response has invalid parameters: ', l:msg)
        return
    endif

    let l:bufnr = s:uri2bufnr(l:msg['params']['uri'])

    if l:is_skipped
        call lsp_cxx_hl#notify_skipped(l:server,
                    \ l:bufnr, l:msg['params'][l:data_key])
    else
        call lsp_cxx_hl#notify_symbols(l:server,
                    \ l:bufnr, l:msg['params'][l:data_key])
    endif
endfunction

" Receive already extracted skipped region data
function! lsp_cxx_hl#notify_skipped(server, buffer, skipped) abort
    let l:bufnr = s:common_notify_checks(a:server, a:buffer, a:skipped)

    try
        call s:notify_skipped(a:server, l:bufnr, a:skipped)
    catch
        call lsp_cxx_hl#log('notify_skipped error: ', v:exception, 'at',
                    \ v:throwpoint)
    endtry
endfunction

function! s:notify_skipped(server, bufnr, skipped) abort
    let l:begintime = lsp_cxx_hl#profile_begin()

    " No conversion done since ccls and cquery both use the same format
    call setbufvar(a:bufnr, 'lsp_cxx_hl_skipped', a:skipped)
    call setbufvar(a:bufnr, 'lsp_cxx_hl_new_skipped', 1)
    call lsp_cxx_hl#profile_end(l:begintime,
                \ 'notify_skipped ', bufname(a:bufnr))
    doautocmd User lsp_cxx_highlight_check
endfunction!

" Receive already extracted symbol data
function! lsp_cxx_hl#notify_symbols(server, buffer, symbols) abort
    let l:bufnr = s:common_notify_checks(a:server, a:buffer, a:symbols)

    try
        call s:notify_symbols(a:server, l:bufnr, a:symbols)
    catch
        call lsp_cxx_hl#log('notify_symbols error: ', v:exception, 'at',
                    \ v:throwpoint)
    endtry
endfunction

function! s:notify_symbols(server, bufnr, symbols)
    let l:begintime = lsp_cxx_hl#profile_begin()

    let l:is_ccls = (a:server ==# 'ccls')
    let l:n_symbols = s:normalize_symbols(a:symbols, l:is_ccls)

    call setbufvar(a:bufnr, 'lsp_cxx_hl_symbols', l:n_symbols)
    call setbufvar(a:bufnr, 'lsp_cxx_hl_new_symbols', 1)
    call lsp_cxx_hl#profile_end(l:begintime,
                \ 'notify_symbols ', bufname(a:bufnr))
    doautocmd User lsp_cxx_highlight_check
endfunction

" Log
function! lsp_cxx_hl#verbose_log(...) abort
    if get(g:, 'lsp_cxx_hl_verbose_log', 0)
        if len(get(g:, 'lsp_cxx_hl_log_file', '')) > 0
            call writefile([strftime('%c') . ': ' . join(a:000, '')],
                        \ g:lsp_cxx_hl_log_file, 'a')
        endif
    endif
endfunction

function! lsp_cxx_hl#log(...) abort
    if len(get(g:, 'lsp_cxx_hl_log_file', '')) > 0
        call writefile([strftime('%c') . ': ' . join(a:000, '')],
                    \ g:lsp_cxx_hl_log_file, 'a')
    endif
endfunction

function! lsp_cxx_hl#profile_begin() abort
    if s:has_reltime
        return reltime()
    else
        return 0
    endif
endfunction

function! lsp_cxx_hl#profile_end(begin, ...) abort
    if s:has_reltime
        let l:name = join(a:000, '')
        call lsp_cxx_hl#log('operation ', l:name, ' took ',
                    \ reltimestr(reltime(a:begin)), 's to complete')
    endif
endfunction

" Section: Helpers

function! s:common_notify_checks(server, buffer, data) abort
    if type(a:buffer) ==# type("")
        let l:bufnr = s:uri2bufnr(a:buffer)
    elseif type(a:buffer) ==# type(0)
        let l:bufnr = a:buffer
    else
        throw 'buffer must be a string or number'
    endif

    if !bufexists(l:bufnr)
        throw 'buffer does not exist!'
    endif

    if type(a:data) !=# type([])
        throw 'symbols must be a list'
    endif

    if a:server !=# 'cquery' && a:server !=# 'ccls'
        throw 'only cquery or ccls is supported'
    endif

    return l:bufnr
endfunction

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
        if and(a:role_int, l:bit) != 0
            let l:role_dict[l:role] = 1
        endif

        let l:bit = l:bit * 2
    endfor

    return l:role_dict
endfunction

" Section: Misc Helpers
function! s:uri2bufnr(uri) abort
    " Remove the leading file:// or whatever protocol is used
    let l:filename = substitute(a:uri, '\c[a-z]\+://', '', '')
    let l:bufnr = bufnr(l:filename)

    if l:bufnr == -1
        " Some characters get escaped by ccls into url encoded format.
        " Only try this if received filename doesn't exist.
        let l:bufnr = bufnr(s:unescape_urlencode(l:filename))
    endif

    return l:bufnr
endfunction

" A simple url format decoder
function! s:unescape_urlencode(str) abort
    let l:matches = []
    let l:start = 0

    while l:start != -1
        let l:match = matchstrpos(a:str, '%[0-9A-Fa-f][0-9A-Fa-f]', l:start)
        let l:start = l:match[2]

        if l:start != -1
            call add(l:matches, l:match)
        endif
    endwhile

    let l:str = a:str
    for l:match in l:matches
        let l:str = l:str[:l:match[1] - 1] . nr2char(str2nr(l:match[0][1:], 16)) .
                    \ l:str[l:match[2]:]
    endfor

    call lsp_cxx_hl#verbose_log('unescape_urlencode unescaped filename: ', l:str)
    return l:str
endfunction!
