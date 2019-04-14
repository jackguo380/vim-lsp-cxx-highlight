" debug helpers

function! lsp_cxx_hl#debug#dump_symbols()
    echomsg 'Debug Dump Symbols'
    let l:count = 0
    for l:sym in get(b:, 'lsp_cxx_hl_symbols', [])
        let l:msg = string(l:count) . ":"
        let l:msg .= " id = " . get(l:sym, 'id', '')
        let l:msg .= " parentKind = " . get(l:sym, 'parentKind', '')
        let l:msg .= " kind = " . get(l:sym, 'kind', '')
        let l:msg .= " storage = " . get(l:sym, 'storage', '')

        let l:count += 1
        echomsg l:msg
    endfor
    echomsg 'End of Debug Dump Symbols'
endfunction

function! lsp_cxx_hl#debug#ignored_symbols()
    echomsg 'Debug Ignored Symbols'

    for [l:hl_group, l:pos] in items(get(w:, 'lsp_cxx_hl_ignored_symbols', {}))
        echomsg 'Highlight Group ' . l:hl_group . ':'

        for l:p in l:pos
            echomsg '  ' . s:pos2str(l:p)
        endfor

        echomsg 'End of Highlight Group ' . l:hl_group
    endfor

    echomsg 'End of Debug Ignored Symbols'
endfunction

function! lsp_cxx_hl#debug#cursor_symbol()
    echomsg 'Debug Find Cursor Symbol'
    echomsg 'Found:'
    let l:line = line('.')
    let l:col = col('.')

    for l:sym in get(b:, 'lsp_cxx_hl_symbols', [])
        let l:under_cursor = 0

        let l:pos = []

        for l:range in get(l:sym, 'ranges', [])
            let l:pos += lsp_cxx_hl#match#lsrange2match(l:range)
        endfor

        if has('byte_offset')
            for l:offset in get(l:sym, 'offsets', [])
                let l:pos += lsp_cxx_hl#match#offsets2match(l:offset)
            endfor
        endif

        for l:p in l:pos
            if type(l:p) ==# type(0) && l:line == l:p
                let l:under_cursor = 1
            elseif type(l:p) ==# type([])
                if len(l:p) == 1 && l:line == l:p[0]
                    let l:under_cursor = 1
                elseif len(l:p) == 2 && l:line == l:p[0] && l:col == l:p[1]
                    let l:under_cursor = 1
                elseif len(l:p) == 3 && l:line == l:p[0] && l:p[1] <= l:col
                            \ && l:col <= (l:p[1] + l:p[2])
                    let l:under_cursor = 1
                endif
            endif
        endfor

        if l:under_cursor
            let l:msg = "Symbol:"
            let l:msg .= " parentKind = " . get(l:sym, 'parentKind', '')
            let l:msg .= ", kind = " . get(l:sym, 'kind', '')
            let l:msg .= ", storage = " . get(l:sym, 'storage', '')
            let l:msg .= ", resolved hl group = " .
                        \ lsp_cxx_hl#hl_helpers#resolve_hl_group(
                        \ get(l:sym, 'parentKind', ''),
                        \ get(l:sym, 'kind', ''),
                        \ get(l:sym, 'storage', '')
                        \ )
            echomsg l:msg
        endif
    endfor

    echomsg 'End of Debug Find Cursor Symbol'
endfunction

function! lsp_cxx_hl#debug#dump_ids()
    echomsg 'Debug Dump Symbol IDs'
    echomsg 'IDs:'

    let l:id_set = {}

    for l:sym in get(b:, 'lsp_cxx_hl_symbols', [])
        let l:id_set[l:sym['id']] = 1
    endfor

    for l:id in sort(keys(l:id_set))
        echomsg l:id
    endfor

    echomsg 'End of Debug Dump Symbol IDs'
endfunction

function! s:pos2str(pos) abort
    if type(a:pos) ==# type(0)
        return 'Line ' . a:pos
    elseif type(a:pos) ==# type([])
        if len(a:pos) == 1
            return 'Line ' . a:pos[0]
        elseif len(a:pos) == 2
            return 'Line ' . a:pos[0] . ' Char ' . a:pos[1]
        elseif len(a:pos) == 3
            return 'Line ' . a:pos[0] . ' Char ' . a:pos[1] . '-'
                        \ . (a:pos[1] + a:pos[2])
        endif
    endif

    return a:pos
endfunction
