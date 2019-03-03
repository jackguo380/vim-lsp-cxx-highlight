let s:has_timers = has('timers')

" Args: (<force> = 0)
function! lsp_cxx_hl#buf#check(...) abort
    if (a:0 > 0) && !a:1
        if !get(b:, 'lsp_cxx_hl_need_update', 0)
            return
        endif

        let b:lsp_cxx_hl_need_update = 0
    endif

    " TODO: incremental highlighting
    call s:hl_skipped()
    "call s:hl_symbols()
endfunction

function! s:hl_skipped() abort
    let l:matches = get(w:, 'lsp_cxx_hl_skipped_matches', [])
    let w:lsp_cxx_hl_skipped_matches = []

    for l:match in l:matches
        call matchdelete(l:match)
    endfor

    let l:skipped = get(b:, 'lsp_cxx_hl_skipped', [])

    let l:matches = []
    for l:range in l:skipped
        let l:match_lines = s:lsp_range_to_matches(l:range)

        let l:matches += s:matchaddpos_long('LspCxxHlSkippedRegion',
                    \ l:match_lines,
                    \ g:lsp_cxx_hl_inactive_region_priority)
    endfor

    let w:lsp_cxx_hl_skipped_matches = l:matches
endfunction

function! s:hl_symbols() abort
    let l:matches = get(w:, 'lsp_cxx_hl_symbols_matches', [])
    let w:lsp_cxx_hl_symbols_matches = []

    for l:match in l:matches
        call matchdelete(l:match)
    endfor

    let l:matches = []

    let l:symbols = get(b:, 'lsp_cxx_hl_symbols', [])

    for l:sym in l:symbols
        
    endfor
endfunction

" Break up long pos list into groups of 8
function! s:matchaddpos_long(group, pos, priority) abort
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

function! s:lsp_range_to_matches(range) abort
    return s:range_to_matches(
                \ a:range['start']['line'] + 1,
                \ a:range['start']['character'] + 1,
                \ a:range['end']['line'] + 1,
                \ a:range['end']['character'] + 1
                \ )
endfunction

function! s:offsets_to_matches(offsets) abort
    let l:s_byte = a:offsets['L']
    let l:e_byte = a:offsets['R']

    return s:range_to_matches(
                \ byte2line(l:s_byte),
                \ l:s_byte - line2byte(l:s_line),
                \ byte2line(l:e_byte),
                \ l:e_byte - line2byte(l:e_line)
                \ )
endfunction

function! s:range_to_matches(s_line, s_char, e_line, e_char) abort
    " regular symbol
    if a:s_line == a:e_line
        return [[a:s_line, a:s_char, a:e_char - a:s_char]]
    endif

    " multiline symbol
    let l:matches = [[a:s_line, a:s_char, col([a:s_line, '$']) - a:s_char]]

    if (a:s_line + 1) < (a:e_line - 1)
        let l:matches += range(a:s_line + 1, a:e_line - 1)
    endif

    call add(l:matches, [a:e_line, 1, a:e_char])

    return l:matches
endfunction
