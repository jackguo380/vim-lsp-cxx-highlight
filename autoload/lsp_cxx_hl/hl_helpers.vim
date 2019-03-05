" Misc helpers for highlighting

" resolve highlighting
function! lsp_cxx_hl#hl_helpers#resolve_hl_group(pkind, kind, storage) abort
    let l:hl_groups = [
                \ 'LspCxxHlSym' . a:pkind . a:kind . a:storage,
                \ 'LspCxxHlSym' . a:pkind . a:kind            ,
                \ 'LspCxxHlSym' .           a:kind . a:storage,
                \ 'LspCxxHlSym' .           a:kind            ,
                \ ]

    for l:hl_group in l:hl_groups
        try " Full Match
            silent execute 'highlight' l:hl_group
            return l:hl_group
        catch /E411: highlight group not found:/
        endtry
    endfor

    return ''
endfunction

" matchaddpos that accepts a unlimited number of positions
function! lsp_cxx_hl#hl_helpers#matchaddpos_long(group, pos, priority) abort
    let l:pos = copy(a:pos)

    let l:matches = []
    while len(l:pos) > 0
        if len(l:pos) >= 8
            let l:lines = l:pos[:7]
            unlet l:pos[:7]
        else
            let l:lines = l:pos[:]
            unlet l:pos[:]
        endif

        let l:match = matchaddpos(a:group, l:lines, a:priority)

        call add(l:matches, l:match)
    endwhile

    return l:matches
endfunction
