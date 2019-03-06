" Buffer/Window specific functionality
"
" TODO: incremental highlighting
"
" List of variables
"
" Preprocessor Skipped Regions:
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
" w:lsp_cxx_hl_skipped_bufnr
"   the current buffer # which is highlighted
"   for preprocessor skipped regions
"
" g:lsp_cxx_hl_skipped_timer
"   if timers are available this is the timer
"   id for preprocessor skipped regions
"
" Symbols:
" b:lsp_cxx_hl_new_symbols
"   b:lsp_cxx_hl_symbols was updated
"
" b:lsp_cxx_hl_symbols
"   ast symbol list from
"   lsp_cxx_hl#notify_symbol_data
"
" b:lsp_cxx_hl_symbols_positions
"   cached position data for faster
"   re-highlighting
"
" w:lsp_cxx_hl_ignored_symbols
"   symbols not highlighted
"
" w:lsp_cxx_hl_symbols_matches
"   the list of match id's from matchaddpos()
"   for symbols
"
" w:lsp_cxx_hl_symbols_bufnr
"   the current buffer # which is highlighted
"   for symbols
" 
" g:lsp_cxx_hl_symbols_timer
"   if timers are available this is the timer
"   id for symbols

let s:has_timers = has('timers')
let s:has_byte_offset = has('byte_offset')

" Args: (<force> = 0)
function! lsp_cxx_hl#buffer#check(...) abort
    let l:force = (a:0 > 0 && a:1)
    let l:bufnr = winbufnr(0)

    call lsp_cxx_hl#verbose_log('buffer#check ', l:force ? '(force) ' : '',
                \ 'started for ', bufname(l:bufnr))

    if !l:force && count(g:lsp_cxx_hl_ft_whitelist, &filetype) == 0
        return
    endif

    " preprocessor skipped
    if l:force || !exists('w:lsp_cxx_hl_skipped_matches') ||
                \ get(b:, 'lsp_cxx_hl_new_skipped', 0) ||
                \ get(w:, 'lsp_cxx_hl_skipped_bufnr', -1) != l:bufnr
        let b:lsp_cxx_hl_new_skipped = 0

        call s:dispatch_hl_skipped(l:force)
    endif

    " symbols
    if l:force || !exists('w:lsp_cxx_hl_symbols_matches') ||
                \ get(b:, 'lsp_cxx_hl_new_symbols', 0) ||
                \ get(w:, 'lsp_cxx_hl_symbols_bufnr', -1) != l:bufnr
        " Dropped cached matches when we get new data
        if get(b:, 'lsp_cxx_hl_new_symbols', 0)
            unlet! b:lsp_cxx_hl_symbols_positions
        endif

        let b:lsp_cxx_hl_new_symbols = 0

        call s:dispatch_hl_symbols(l:force)
    endif
endfunction

function! s:dispatch_hl_skipped(force) abort
    if s:has_timers
        if get(g:, 'lsp_cxx_hl_skipped_timer', -1) != -1
            call lsp_cxx_hl#verbose_log('stopped hl_skipped timer')
            call timer_stop(g:lsp_cxx_hl_skipped_timer)
        endif

        let g:lsp_cxx_hl_skipped_timer = timer_start(10,
                    \ function('s:hl_skipped', [a:force, winbufnr(0)]))
    else
        call s:hl_skipped(0)
    endif
endfunction

function! s:clear_skipped() abort
    let l:matches = get(w:, 'lsp_cxx_hl_skipped_matches', [])
    unlet! w:lsp_cxx_hl_skipped_matches
    unlet! w:lsp_cxx_hl_skipped_bufnr

    try
        for l:match in l:matches
            call matchdelete(l:match)
        endfor
    catch /E803: ID not found:/
    endtry
endfunction

function! s:hl_skipped(force, bufnr, timer) abort
    let l:begintime = lsp_cxx_hl#profile_begin()
    let l:bufnr = winbufnr(0)

    if l:bufnr != a:bufnr
        " Buffers changed before the timer triggered
        unlet! g:lsp_cxx_hl_skipped_timer
        return
    endif

    call s:clear_skipped()

    if !exists('b:lsp_cxx_hl_skipped')
        " No data yet
        unlet! g:lsp_cxx_hl_skipped_timer
        return
    endif

    let l:skipped = b:lsp_cxx_hl_skipped

    let l:positions = []
    for l:range in l:skipped
        let l:positions += lsp_cxx_hl#buffer#lsrange2pos(l:range)
    endfor

    let l:matches = lsp_cxx_hl#hl_helpers#matchaddpos_long(
                \ 'LspCxxHlSkippedRegion',
                \ l:positions,
                \ g:lsp_cxx_hl_inactive_region_priority)

    let w:lsp_cxx_hl_skipped_matches = l:matches
    let w:lsp_cxx_hl_skipped_bufnr = l:bufnr

    call lsp_cxx_hl#log('hl_skipped highlighted ', len(l:skipped),
                \ ' skipped preprocessor regions',
                \ ' in file ', bufname(l:bufnr))
    call lsp_cxx_hl#profile_end(l:begintime, 'hl_skipped ', bufname(l:bufnr))

    unlet! g:lsp_cxx_hl_skipped_timer
endfunction

function! s:dispatch_hl_symbols(force) abort
    if s:has_timers
        if get(g:, 'lsp_cxx_hl_symbols_timer', -1) != -1
            call lsp_cxx_hl#verbose_log('stopped hl_symbols timer')
            call timer_stop(g:lsp_cxx_hl_symbols_timer)
        endif

        let g:lsp_cxx_hl_symbols_timer = timer_start(10,
                    \ function('s:hl_symbols', [a:force, winbufnr(0)]))
    else
        call s:hl_symbols(0)
    endif
endfunction

function! s:clear_symbols() abort
    let l:matches = get(w:, 'lsp_cxx_hl_symbols_matches', [])
    unlet! w:lsp_cxx_hl_symbols_matches
    unlet! w:lsp_cxx_hl_symbols_bufnr

    try
        for l:match in l:matches
            call matchdelete(l:match)
        endfor
    catch /E803: ID not found:/
    endtry
endfunction

function! s:hl_symbols(force, bufnr, timer) abort
    let l:begintime = lsp_cxx_hl#profile_begin()
    let l:bufnr = winbufnr(0)

    if l:bufnr != a:bufnr
        " Buffers changed before the timer triggered
        unlet! g:lsp_cxx_hl_symbols_timer
        return
    endif

    call s:clear_symbols()

    if !exists('b:lsp_cxx_hl_symbols')
        " No data yet
        unlet! g:lsp_cxx_hl_symbols_timer
        return
    endif

    let l:symbols = b:lsp_cxx_hl_symbols

    if a:force || !exists('b:lsp_cxx_hl_symbols_positions')
        let [l:hl_group_positions, l:missing_groups] =
                    \ s:hl_symbols_to_positions(l:symbols)

        let b:lsp_cxx_hl_symbols_positions = l:hl_group_positions
        let w:lsp_cxx_hl_ignored_symbols = l:missing_groups
        let l:cached = 0
    else
        let l:hl_group_positions = b:lsp_cxx_hl_symbols_positions
        let l:cached = 1
    endif

    let l:matches = []
    for [l:hl_group, l:positions] in items(l:hl_group_positions)
        let l:matches += lsp_cxx_hl#hl_helpers#matchaddpos_long(
                    \ l:hl_group, l:positions,
                    \ g:lsp_cxx_hl_syntax_priority)
    endfor

    let w:lsp_cxx_hl_symbols_matches = l:matches
    let w:lsp_cxx_hl_symbols_bufnr = l:bufnr

    call lsp_cxx_hl#log('hl_symbols highlighted ', l:cached ? '(cached) ' : '',
                \ len(l:symbols), ' symbols in file ', bufname(l:bufnr))

    call lsp_cxx_hl#profile_end(l:begintime, 'hl_symbols ', bufname(l:bufnr))

    unlet! g:lsp_cxx_hl_symbols_timer
endfunction

function! s:hl_symbols_to_positions(symbols) abort
    let l:hl_group_positions = {}
    let l:missing_groups = {}

    let l:byte_offset_warn_done = 0
    " Cache results per session to ensure consistent highlighting
    " and reduce the number of times highlight groups are re resolved
    let l:hl_group_cache = {}

    for l:sym in a:symbols
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
            echohl ErrorMsg
            echomsg 'Cannot highlight, +byte_offset required'
            echohl NONE

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

    call lsp_cxx_hl#verbose_log('hl resolve table:')
    for [l:hl_group, l:hl_group_c] in items(l:hl_group_cache)
        call lsp_cxx_hl#verbose_log('  ', l:hl_group, ' -> ', l:hl_group_c)
    endfor

    let l:missing_sym_count = 0
    for l:pos in values(l:missing_groups)
        let l:missing_sym_count += len(l:pos)
    endfor

    if l:missing_sym_count > 0
        call lsp_cxx_hl#log('hl_symbols_to_positions missing symbols for ',
                    \ l:missing_sym_count, ' symbols in file ',
                    \ bufname(winbufnr(0)))
    endif

    return [l:hl_group_positions, l:missing_groups]
endfunction


" Section: Helpers

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
    " single line symbol
    if a:s_line == a:e_line
        if a:e_char - a:s_char > 0
            return [[a:s_line, a:s_char, a:e_char - a:s_char]]
        else
            return []
        endif
    endif

    " multiline symbol
    let l:matches = []

    let l:s_line_end = col([a:s_line, '$'])

    if l:s_line_end - a:s_char >= 0
        call add(l:matches, [a:s_line, a:s_char, l:s_line_end - a:s_char])
    endif

    if (a:s_line + 1) < (a:e_line - 1)
        let l:matches += range(a:s_line + 1, a:e_line - 1)
    endif

    if a:e_char - 1 > 0
        call add(l:matches, [a:e_line, 1, a:e_char - 1])
    endif

    return l:matches
endfunction
