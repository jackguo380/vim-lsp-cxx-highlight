" matchaddpos implementation of symbol highlighting
"
" Variables:
"
" b:lsp_cxx_hl_symbols_version
"   a incrementing counter increased once
"   everytime b:lsp_cxx_hl_symbols is changed
"
" b:lsp_cxx_hl_symbols
"   ast symbol list from
"   lsp_cxx_hl#notify_symbol_data
"
" b:lsp_cxx_hl_symbols_positions
"   cached position data for faster
"   re-highlighting
"
" b:lsp_cxx_hl_symbols_positions_version
"   check against b:lsp_cxx_hl_symbols_version
"   to determine if cached postions needs to be updated
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
" w:lsp_cxx_hl_symbols_version
"   check against b:lsp_cxx_hl_symbols_version
"   to determine if highlighting needs to be updated
" 
" g:lsp_cxx_hl_symbols_timer
"   if timers are available this is the timer
"   id for symbols

let s:has_timers = has('timers')
let s:has_byte_offset = has('byte_offset')

function! lsp_cxx_hl#match#symbols#notify(bufnr, symbols) abort
    let l:version = getbufvar(a:bufnr, 'lsp_cxx_hl_symbols_version', 0)
    call setbufvar(a:bufnr, 'lsp_cxx_hl_symbols', a:symbols)
    call setbufvar(a:bufnr, 'lsp_cxx_hl_symbols_version', l:version + 1)
endfunction

function! lsp_cxx_hl#match#symbols#check(force) abort
    let l:bufnr = winbufnr(0)

    call lsp_cxx_hl#verbose_log('match check symbols ',
                \ a:force ? '(force) ' : '',
                \ 'started for ', bufname(l:bufnr))

    " symbols
    if a:force || !exists('w:lsp_cxx_hl_symbols_matches') ||
                \ get(w:, 'lsp_cxx_hl_symbols_bufnr', -1) != l:bufnr ||
                \ get(w:, 'lsp_cxx_hl_symbols_version', -1) !=
                \ get(b:, 'lsp_cxx_hl_symbols_version', 0)
        call s:dispatch(a:force)
    endif
endfunction

function! lsp_cxx_hl#match#symbols#clear() abort
    let l:matches = get(w:, 'lsp_cxx_hl_symbols_matches', [])
    unlet! w:lsp_cxx_hl_symbols_matches
    unlet! w:lsp_cxx_hl_symbols_bufnr

    call lsp_cxx_hl#match#clear_matches(l:matches)
endfunction

function! s:dispatch(force) abort
    if s:has_timers
        if get(g:, 'lsp_cxx_hl_symbols_timer', -1) != -1
            call lsp_cxx_hl#verbose_log('stopped hl_symbols timer')
            call timer_stop(g:lsp_cxx_hl_symbols_timer)
        endif

        let g:lsp_cxx_hl_symbols_timer = timer_start(10,
                    \ function('s:hl_symbols_wrap', [a:force, winbufnr(0)]))
    else
        call s:hl_symbols_wrap(a:force, winbufnr(0), 0)
    endif
endfunction

function! s:hl_symbols_wrap(force, bufnr, timer) abort
    let l:begintime = lsp_cxx_hl#profile_begin()

    let l:matches = get(w:, 'lsp_cxx_hl_symbols_matches', [])
    unlet! w:lsp_cxx_hl_symbols_matches
    unlet! w:lsp_cxx_hl_symbols_bufnr

    let l:bufnr = winbufnr(0)

    call s:hl_symbols(a:force, l:bufnr, a:timer)

    " Clear old highlighting after finishing highlighting
    call lsp_cxx_hl#match#clear_matches(l:matches)

    unlet! g:lsp_cxx_hl_symbols_timer
    redraw

    call lsp_cxx_hl#profile_end(l:begintime, 'hl_symbols ', bufname(l:bufnr))
endfunction

function! s:hl_symbols(force, bufnr, timer) abort
    " Bad filetype
    if !a:force && count(g:lsp_cxx_hl_ft_whitelist, &filetype) == 0
        return
    endif

    " No data yet
    if !exists('b:lsp_cxx_hl_symbols') ||
                \ !exists('b:lsp_cxx_hl_symbols_version')
        return
    endif

    let l:symbols = b:lsp_cxx_hl_symbols

    " Check for cached positions, ignore if forced highlighting
    if a:force || !exists('b:lsp_cxx_hl_symbols_positions') ||
                \ b:lsp_cxx_hl_symbols_version !=
                \ get(b:, 'lsp_cxx_hl_symbols_positions_version', -1)
        let [l:hl_group_positions, l:missing_groups] =
                    \ s:hl_symbols_to_positions(l:symbols)

        let b:lsp_cxx_hl_symbols_positions = l:hl_group_positions
        let b:lsp_cxx_hl_symbols_positions_version = b:lsp_cxx_hl_symbols_version
        let w:lsp_cxx_hl_ignored_symbols = l:missing_groups
        let l:cached = 0
    else
        let l:hl_group_positions = b:lsp_cxx_hl_symbols_positions
        let l:cached = 1
    endif

    let l:matches = []
    for [l:hl_group, l:positions] in items(l:hl_group_positions)
        let l:matches += lsp_cxx_hl#match#matchaddpos_long(
                    \ l:hl_group, l:positions,
                    \ g:lsp_cxx_hl_syntax_priority)
    endfor

    let w:lsp_cxx_hl_symbols_matches = l:matches
    let w:lsp_cxx_hl_symbols_bufnr = a:bufnr
    let w:lsp_cxx_hl_symbols_version = b:lsp_cxx_hl_symbols_version

    call lsp_cxx_hl#log('hl_symbols highlighted ', l:cached ? '(cached) ' : '',
                \ len(l:symbols), ' symbols in file ', bufname(a:bufnr))
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
            let l:positions += lsp_cxx_hl#match#lsrange2match(l:range)
        endfor

        let l:offsets = get(l:sym, 'offsets', [])
        if s:has_byte_offset
            for l:offset in l:offsets
                let l:positions += lsp_cxx_hl#match#offsets2match(l:offset)
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

