" debug helpers

function! lsp_cxx_hl#debug#dump_symbols()
    echomsg 'Debug Dump Symbols'
    let l:count = 0
    for l:sym in get(b:, 'lsp_cxx_hl_symbols', [])
        let l:msg = string(l:count) . ":"
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
