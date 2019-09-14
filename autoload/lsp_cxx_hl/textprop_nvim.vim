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

function! lsp_cxx_hl#textprop_nvim#buf_add_hl_offset(buf, ns_id, hl_group,
            \ offsets) abort
    let l:s_byte = a:offsets['L']
    let l:e_byte = a:offsets['R']
    let l:s_line = byte2line(l:s_byte)
    let l:e_line = byte2line(l:e_byte)

    return s:buf_add_hl(a:buf, a:ns_id, a:hl_group,
                \ l:s_line - 1,
                \ l:s_byte - line2byte(l:s_line) - 1,
                \ l:e_line - 1,
                \ l:e_byte - line2byte(l:e_line) - 1
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

    " multiline symbol
    let l:s_line = a:s_line < 0 ? 0 : a:s_line
    let l:e_line = a:e_line > line('$') - 1 ? line('$') - 1 : a:e_line

    let l:s_line_end = col([l:s_line, '$'])

    if l:s_line_end - a:s_char > 0
        call nvim_buf_add_highlight(a:buf, a:ns_id, a:hl_group,
                    \ l:s_line, a:s_char, -1)
    endif

    if l:s_line + 1 <= l:e_line - 1
        for l:line in range(l:s_line + 1, l:e_line - 1)
            call nvim_buf_add_highlight(a:buf, a:ns_id, a:hl_group,
                        \ l:line, 0, -1)
        endfor
    endif

    if a:e_char > 0
        call nvim_buf_add_highlight(a:buf, a:ns_id, a:hl_group,
                    \ l:e_line, 0, a:e_char)
    endif
endfunction

function! lsp_cxx_hl#textprop_nvim#buf_add_hl_skipped_range(buf, ns_id, hl_group,
            \ range) abort

    let l:s_line = a:range['start']['line']
    let l:s_line = l:s_line < 0 ? 0 : l:s_line

    let l:e_line = a:range['end']['line']
    let l:e_line = l:e_line > line('$') - 1 ? line('$') - 1 : l:e_line

    if l:s_line + 1 <= l:e_line - 2
        for l:line in range(l:s_line + 1, l:e_line - 2)
            call nvim_buf_add_highlight(a:buf, a:ns_id, a:hl_group,
                        \ l:line, 0, -1)
        endfor
    endif
endfunction
