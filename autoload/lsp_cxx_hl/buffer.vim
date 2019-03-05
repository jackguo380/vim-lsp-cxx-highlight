" Buffer/Window specific functionality
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
let s:has_reltime = has('reltime')

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
        call timer_start(25, function('s:hl_skipped'))
    else
        call s:hl_skipped()
    endif
endfunction

function! s:clear_skipped() abort
    let l:matches = get(w:, 'lsp_cxx_hl_skipped_matches', [])
    let w:lsp_cxx_hl_skipped_matches = []

    try
        for l:match in l:matches
            call matchdelete(l:match)
        endfor
    catch /E803: ID not found:/
    endtry
endfunction

function! s:hl_skipped(...) abort
    let l:begintime = lsp_cxx_hl#profile_begin()

    call s:clear_skipped()

    let l:skipped = get(b:, 'lsp_cxx_hl_skipped', [])

    let l:positions = []
    for l:range in l:skipped
        let l:positions += lsp_cxx_hl#buffer#lsrange2pos(l:range)
    endfor

    let l:matches = lsp_cxx_hl#hl_helpers#matchaddpos_long(
                \ 'LspCxxHlSkippedRegion',
                \ l:positions,
                \ g:lsp_cxx_hl_inactive_region_priority)

    let w:lsp_cxx_hl_skipped_matches = l:matches
    call lsp_cxx_hl#log('hl_skipped highlighted ', len(l:skipped),
                \ ' skipped preprocessor regions',
                \ ' in file ', s:curbufname())
    call lsp_cxx_hl#profile_end(l:begintime, 'hl_skipped ', s:curbufname())
endfunction

function! s:dispatch_hl_symbols() abort
    if s:has_timers
        call timer_start(25, function('s:hl_symbols'))
    else
        call s:hl_symbols()
    endif
endfunction

function! s:clear_symbols() abort
    let l:matches = get(w:, 'lsp_cxx_hl_symbols_matches', [])
    let w:lsp_cxx_hl_symbols_matches = []

    try
        for l:match in l:matches
            call matchdelete(l:match)
        endfor
    catch /E803: ID not found:/
    endtry
endfunction

function! s:hl_symbols(...) abort
    let l:begintime = lsp_cxx_hl#profile_begin()

    call s:clear_symbols()

    let l:byte_offset_warn_done = 0

    let l:hl_group_positions = {}
    let l:missing_groups = {}

    " Cache results per session to ensure consistent highlighting
    " and reduce the number of times highlight groups are re resolved
    let l:hl_group_cache = {}

    let l:symbols = get(b:, 'lsp_cxx_hl_symbols', [])
    for l:sym in l:symbols
        " Match Positions
        let l:positions = []

        for l:range in get(l:sym, 'ranges', [])
            let l:positions += lsp_cxx_hl#buffer#lsrange2pos(l:range)
        endfor

        let l:offsets = get(l:sym, 'offsets', [])
        if s:has_byte_offset
            for l:offset in l:offsets
                let l:positions += lsp_cxx_hl#buffer#offsets2pos(l:offset)
            endfor
        elseif !l:byte_offset_warn_done
            call lsp_cxx_hl#log('Cannot highlight, +byte_offset required')
            let l:byte_offset_warn_done = 1
        endif

        " Highlight group
        let l:hl_group = 'LspCxxHlSym'
                    \ . l:sym['parentKind']
                    \ . l:sym['kind']
                    \ . l:sym['storage']

        if !has_key(l:hl_group_cache, l:hl_group)
            let l:hl_group_c = lsp_cxx_hl#hl_helpers#resolve_hl_group(
                        \ l:sym['parentKind'],
                        \ l:sym['kind'],
                        \ l:sym['storage'])

            let l:hl_group_cache[l:hl_group] = l:hl_group_c
        else
            let l:hl_group_c = l:hl_group_cache[l:hl_group]
        endif

        if len(l:hl_group_c) > 0
            if !has_key(l:hl_group_positions, l:hl_group_c)
                let l:hl_group_positions[l:hl_group_c] = []
            endif

            let l:hl_group_positions[l:hl_group_c] += l:positions
        else
            if !has_key(l:missing_groups, l:hl_group)
                let l:missing_groups[l:hl_group] = []
            endif

            let l:missing_groups[l:hl_group] += l:positions
        endif
    endfor

    let l:matches = []
    for [l:hl_group, l:positions] in items(l:hl_group_positions)
        let l:matches += lsp_cxx_hl#hl_helpers#matchaddpos_long(
                    \ l:hl_group, l:positions,
                    \ g:lsp_cxx_hl_syntax_priority)
    endfor

    let w:lsp_cxx_hl_symbols_matches = l:matches
    let w:lsp_cxx_hl_ignored_symbols = l:missing_groups

    let l:missing_sym_count = 0
    for l:pos in values(l:missing_groups)
        let l:missing_sym_count += len(l:pos)
    endfor

    call lsp_cxx_hl#log('hl_symbols highlighted ', len(l:symbols),
                \ ' symbols, ignored ', l:missing_sym_count, ' symbols',
                \ ' in file ', s:curbufname())

    call lsp_cxx_hl#verbose_log('hl resolve table:')
    for [l:hl_group, l:hl_group_c] in items(l:hl_group_cache)
        call lsp_cxx_hl#verbose_log('  ', l:hl_group, ' -> ', l:hl_group_c)
    endfor
    call lsp_cxx_hl#profile_end(l:begintime, 'hl_symbols ', s:curbufname())
endfunction

" Section: Helpers
function! s:curbufname() abort
    return bufname(winbufnr(0))
endfunction

" Section: Conversion Functions
function! lsp_cxx_hl#buffer#lsrange2pos(range) abort
    return s:range_to_matches(
                \ a:range['start']['line'] + 1,
                \ a:range['start']['character'] + 1,
                \ a:range['end']['line'] + 1,
                \ a:range['end']['character'] + 1
                \ )
endfunction

function! lsp_cxx_hl#buffer#offsets2pos(offsets) abort
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
