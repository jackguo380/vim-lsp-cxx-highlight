" Do the actual highlighting with the symbols received
"
" TODO: incremental highlighting
"
" Variables:
" b:lsp_cxx_hl_new_skipped
"   b:lsp_cxx_hl_skipped was updated
"
" b:lsp_cxx_hl_skipped
"   preprocessor skipped region list from
"   lsp_cxx_hl#notify_skipped_data
"
" w:lsp_cxx_hl_skipped_matches
"   the list of match id's from matchaddpos()
"   for preprocessor skipped regions
"
" b:lsp_cxx_hl_new_symbols
"   b:lsp_cxx_hl_symbols was updated
"
" b:lsp_cxx_hl_symbols
"   ast symbol list from
"   lsp_cxx_hl#notify_symbol_data
"
" w:lsp_cxx_hl_ignored_symbols
"
" w:lsp_cxx_hl_symbols_matches
"   like w:lsp_cxx_hl_skipped_matches
"   but for symbols
"

let s:has_timers = has('timers')
let s:has_byte_offset = has('byte_offset')

" Args: (<force> = 0)
function! lsp_cxx_hl#buffer#check(...) abort
    if (a:0 > 0) && !a:1
        if !get(b:, 'lsp_cxx_hl_new_skipped', 0)
            return
        endif

        let b:lsp_cxx_hl_new_skipped = 0
    endif

    call s:dispatch_hl_skipped()

    if (a:0 > 0) && !a:1
        if !get(b:, 'lsp_cxx_hl_new_symbols', 0)
            return
        endif

        let b:lsp_cxx_hl_new_symbols = 0
    endif

    call s:dispatch_hl_symbols()
endfunction

function! s:dispatch_hl_skipped() abort
    if s:has_timers
        call s:hl_skipped()
    else
        call s:hl_skipped()
    endif
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

function! s:dispatch_hl_symbols() abort
    if s:has_timers
        call s:hl_symbols()
    else
        call s:hl_symbols()
    endif
endfunction

function! s:hl_symbols() abort
    let l:matches = get(w:, 'lsp_cxx_hl_symbols_matches', [])
    let w:lsp_cxx_hl_symbols_matches = []

    for l:match in l:matches
        call matchdelete(l:match)
    endfor

    let l:byte_offset_warn_done = 0

    let l:matches = []
    let l:missing_groups = {}
    " Map hl_group -> hl_group to reduce the number of failed try/catches
    let l:hl_group_cache = {}

    let l:symbols = get(b:, 'lsp_cxx_hl_symbols', [])
    for l:sym in l:symbols
        " Match Positions
        let l:positions = []

        for l:range in get(l:sym, 'ranges', [])
            let l:positions += s:lsp_range_to_matches(l:range)
        endfor

        let l:offsets = get(l:sym, 'offsets', [])
        if s:has_byte_offset
            for l:offset in l:offsets
                let l:positions += s:offsets_to_matches(l:offset)
            endfor
        elseif !l:byte_offset_warn_done
            call lsp_cxx_hl#log('Cannot highlight, +byte_offset required')
            let l:byte_offset_warn_done = 1
        endif

        " Do highlighting
        " Try full symbol type
        let l:hl_group = 'LspCxxHlSym'
                    \ . l:sym['parentKind']
                    \ . l:sym['kind']
                    \ . l:sym['storage']
        try
            let l:matches += s:matchaddpos_long(
                        \ get(l:hl_group_cache, l:hl_group, l:hl_group),
                        \ l:positions,
                        \ g:lsp_cxx_hl_syntax_priority)
            continue
        catch /E28: No such highlight group name:/
        endtry

        " Try without storage type
        try 
            let l:hl_group_retry = 'LspCxxHlSym'
                        \ . l:sym['parentKind']
                        \ . l:sym['kind']

            let l:matches += s:matchaddpos_long(l:hl_group_retry, l:positions,
                        \ g:lsp_cxx_hl_syntax_priority)
            let l:hl_group_cache[l:hl_group] = l:hl_group_retry
            continue
        catch /E28: No such highlight group name:/
        endtry

        " Try without parent kind
        try 
            let l:hl_group_retry = 'LspCxxHlSym'
                        \ . l:sym['kind']
                        \ . l:sym['storage']

            let l:matches += s:matchaddpos_long(l:hl_group_retry, l:positions,
                        \ g:lsp_cxx_hl_syntax_priority)
            let l:hl_group_cache[l:hl_group] = l:hl_group_retry
            continue
        catch /E28: No such highlight group name:/
        endtry

        " Try without parent kind and storage
        try 
            let l:hl_group_retry = 'LspCxxHlSym'
                        \ . l:sym['kind']

            let l:matches += s:matchaddpos_long(l:hl_group_retry, l:positions,
                        \ g:lsp_cxx_hl_syntax_priority)
            let l:hl_group_cache[l:hl_group] = l:hl_group_retry
            continue
        catch /E28: No such highlight group name:/
        endtry

        " Nothing left to try
        if !has_key(l:missing_groups, l:hl_group)
            let l:missing_groups[l:hl_group] = []
        endif

        let l:missing_groups[l:hl_group] += l:positions
    endfor

    let w:lsp_cxx_hl_symbols_matches = l:matches
    let w:lsp_cxx_hl_ignored_symbols = l:missing_groups
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
    let l:s_line = byte2line(l:s_byte)
    let l:e_line = byte2line(l:e_byte)

    return s:range_to_matches(
                \ l:s_line,
                \ l:s_byte - line2byte(l:s_line),
                \ l:e_line,
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
