" Textprops neovim
" 
" It should be noted that neovim uses zero based indexing like LSP
" this is unlike regular vim APIs which are 1 based.

function! lsp_cxx_hl#textprop_nvim#buf_add_hl_lsrange(buf, ns_id, hl_group,
            \ range) abort
    return s:buf_add_hl(a:buf, a:ns_id, a:hl_group,
                \ a:range['start']['line'],
                \ a:range['start']['character'],
                \ a:range['end']['line'],
                \ a:range['end']['character']
                \ )
endfunction

function! s:buf_add_hl(buf, ns_id, hl_group,
            \ s_line, s_char, e_line, e_char) abort

    " single line symbol
    if a:s_line == a:e_line
        if a:e_char - a:s_char > 0
            call nvim_buf_add_highlight(a:buf, a:ns_id, a:hl_group,
                        \ a:s_line, a:s_char, a:e_char)
            return
        else
            return
        endif
    endif

    call lsp_cxx_hl#log('Error (textprop_nvim): symbol (', a:hl_group,
                \ ') spans multiple lines: ', a:s_line, ':', a:s_char,
                \ ' to ', a:e_line, ':', a:e_char)
endfunction

function! lsp_cxx_hl#textprop_nvim#buf_add_hl_skipped_range(buf, ns_id, hl_group,
            \ range) abort

    let l:s_line = a:range['start']['line']
    let l:s_line = l:s_line < 0 ? 0 : l:s_line

    let l:buf_nl = nvim_buf_line_count(a:buf)

    let l:e_line = a:range['end']['line']
    let l:e_line = l:e_line > l:buf_nl - 1 ? l:buf_nl - 1 : l:e_line

    if l:s_line + 1 <= l:e_line - 1
        for l:line in range(l:s_line + 1, l:e_line - 1)
            call nvim_buf_add_highlight(a:buf, a:ns_id, a:hl_group,
                        \ l:line, 0, -1)
        endfor
    endif
endfunction
