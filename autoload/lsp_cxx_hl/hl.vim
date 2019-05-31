" Helper functions for unifying match and textprop
" Variables:
" b:lsp_cxx_hl_disabled - disable highlighting for this buffer

" Check if highlighting in the current buffer needs updating
function! lsp_cxx_hl#hl#check(...) abort
    let l:force = (a:0 > 0 && a:1)

    if get(b:, 'lsp_cxx_hl_disabled', 0)
        call lsp_cxx_hl#hl#clear()
        return
    endif

    if g:lsp_cxx_hl_use_text_props
        echohl Error
        echoerr "textprops not implemented!"
        echohl None
    else
        call lsp_cxx_hl#match#symbols#check(l:force)
        call lsp_cxx_hl#match#skipped#check(l:force)
    endif
endfunction

" Clear highlighting in this buffer
function! lsp_cxx_hl#hl#clear() abort
    if g:lsp_cxx_hl_use_text_props
        echohl Error
        echoerr "textprops not implemented!"
        echohl None
    else
        call lsp_cxx_hl#match#symbols#clear()
        call lsp_cxx_hl#match#skipped#clear()
    endif
endfunction

" Enable the highlighting for this buffer
function! lsp_cxx_hl#hl#enable() abort
    if g:lsp_cxx_hl_use_text_props
        echohl Error
        echoerr "textprops not implemented!"
        echohl None
    else
        unlet! b:lsp_cxx_hl_disabled
    endif

    call lsp_cxx_hl#hl#check(1)
endfunction

" Disable the highlighting for this buffer
function! lsp_cxx_hl#hl#disable() abort
    if g:lsp_cxx_hl_use_text_props
        echohl Error
        echoerr "textprops not implemented!"
        echohl None
    else
        let b:lsp_cxx_hl_disabled = 1
    endif

    call lsp_cxx_hl#hl#clear()
endfunction

" Notify of new semantic highlighting symbols
function! lsp_cxx_hl#hl#notify_symbols(bufnr, symbols) abort
    if g:lsp_cxx_hl_use_text_props
        echohl Error
        echoerr "textprops not implemented!"
        echohl None
    else
        call lsp_cxx_hl#match#symbols#notify(a:bufnr, a:symbols)

        if get(b:, 'lsp_cxx_hl_disabled', 0)
            call lsp_cxx_hl#hl#clear()
        else
            call lsp_cxx_hl#match#symbols#check(0)
        endif
    endif
endfunction

" Notify of new preprocessor skipped regions
function! lsp_cxx_hl#hl#notify_skipped(bufnr, skipped) abort
    if g:lsp_cxx_hl_use_text_props
        echohl Error
        echoerr "textprops not implemented!"
        echohl None
    else
        call lsp_cxx_hl#match#skipped#notify(a:bufnr, a:skipped)

        if get(b:, 'lsp_cxx_hl_disabled', 0)
            call lsp_cxx_hl#hl#clear()
        else
            call lsp_cxx_hl#match#skipped#check(0)
        endif
    endif
endfunction
