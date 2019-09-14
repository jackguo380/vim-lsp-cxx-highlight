" Common helpers for matchaddpos

function! lsp_cxx_hl#match#clear_matches(matches) abort
    for l:match in a:matches
        try
            call matchdelete(l:match)
        catch /E803/
        endtry
    endfor
endfunction

" Conversion Functions
function! lsp_cxx_hl#match#lsrange2match(range) abort
    return s:range_to_matches(
                \ a:range['start']['line'] + 1,
                \ a:range['start']['character'] + 1,
                \ a:range['end']['line'] + 1,
                \ a:range['end']['character'] + 1
                \ )
endfunction

function! lsp_cxx_hl#match#offsets2match(offsets) abort
    let l:s_byte = a:offsets['L'] + 1
    let l:e_byte = a:offsets['R'] + 1
    let l:s_line = byte2line(l:s_byte)
    let l:e_line = byte2line(l:e_byte)

    return s:range_to_matches(
                \ l:s_line,
                \ l:s_byte - line2byte(l:s_line) + 1,
                \ l:e_line,
                \ l:e_byte - line2byte(l:e_line) + 1
                \ )
endfunction

function! s:range_to_matches(s_line, s_char, e_line, e_char) abort
    " single line symbol
    if a:s_line == a:e_line
        if a:e_char - a:s_char > 0
            return [[a:s_line, a:s_char, a:e_char - a:s_char]]
        else
            return []
        endif
    endif

    " multiline symbol
    let l:s_line = a:s_line < 1 ? 1 : a:s_line
    let l:e_line = a:e_line > line('$') ? line('$') : a:e_line

    let l:matches = []

    let l:s_line_end = col([l:s_line, '$'])

    if l:s_line_end - a:s_char >= 0
        call add(l:matches, [l:s_line, a:s_char, l:s_line_end - a:s_char])
    endif

    if (l:s_line + 1) < (l:e_line - 1)
        let l:matches += range(l:s_line + 1, l:e_line - 1)
    endif

    if a:e_char - 1 > 0
        call add(l:matches, [l:e_line, 1, a:e_char - 1])
    endif

    return l:matches
endfunction

" matchaddpos that accepts a unlimited number of positions
function! lsp_cxx_hl#match#matchaddpos_long(group, pos, priority) abort
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
