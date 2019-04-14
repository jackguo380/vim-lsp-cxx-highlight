" Misc helpers for highlighting

" find the highlighting group for the symbols
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
        catch /E411/
        endtry
    endfor

    return ''
endfunction
