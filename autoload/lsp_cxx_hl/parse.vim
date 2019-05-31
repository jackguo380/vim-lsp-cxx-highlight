" Parse symbols and put them in a unified format
" Note that cquery and ccls use different key names for somethings
"                   cquery     ccls
" symbol id:       'stableId'  'id'
" highlight range: 'ranges'    'lsRanges'
" offsets (ccls):  N/A         'ranges'
function! lsp_cxx_hl#parse#normalize_symbols(symbols, is_ccls) abort
    if a:is_ccls
        let l:id_key = 'id'
        let l:range_key = 'lsRanges'
        let l:is_offset = 0

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
