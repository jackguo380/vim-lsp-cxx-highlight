" matchaddpos implementation of preprocessor skipped regions
"
" Variables:
"
" b:lsp_cxx_hl_skipped_version
"   a incrementing counter increased once
"   b:lsp_cxx_hl_skipped is changed
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
" w:lsp_cxx_hl_skipped_version
"   check against b:lsp_cxx_hl_skipped_version
"   to determine if highlighting needs to be updated
"
" g:lsp_cxx_hl_skipped_timer
"   if timers are available this is the timer
"   id for preprocessor skipped regions

let s:has_timers = has('timers')

function! lsp_cxx_hl#match#skipped#notify(bufnr, skipped) abort
    let l:version = getbufvar(a:bufnr, 'lsp_cxx_hl_skipped_version', 0)
    " No conversion done since ccls and cquery both use the same format
    call setbufvar(a:bufnr, 'lsp_cxx_hl_skipped', a:skipped)
    call setbufvar(a:bufnr, 'lsp_cxx_hl_skipped_version', l:version + 1)
endfunction

function lsp_cxx_hl#match#skipped#check(force) abort
    let l:bufnr = winbufnr(0)

    call lsp_cxx_hl#verbose_log('match check skipped ',
                \ a:force ? '(force) ' : '',
                \ 'started for ', bufname(l:bufnr))

    " preprocessor skipped
    if a:force || !exists('w:lsp_cxx_hl_skipped_matches') ||
                \ get(w:, 'lsp_cxx_hl_skipped_bufnr', -1) != l:bufnr ||
                \ get(w:, 'lsp_cxx_hl_skipped_version', -1) !=
                \ get(b:, 'lsp_cxx_hl_skipped_version', 0)
        call s:dispatch(a:force)
    endif
endfunction

function! lsp_cxx_hl#match#skipped#clear() abort
    let l:matches = get(w:, 'lsp_cxx_hl_skipped_matches', [])
    unlet! w:lsp_cxx_hl_skipped_matches
    unlet! w:lsp_cxx_hl_skipped_bufnr

    call lsp_cxx_hl#match#clear_matches(l:matches)
endfunction

function! s:dispatch(force) abort
    if s:has_timers
        if get(g:, 'lsp_cxx_hl_skipped_timer', -1) != -1
            call lsp_cxx_hl#verbose_log('stopped hl_skipped timer')
            call timer_stop(g:lsp_cxx_hl_skipped_timer)
        endif

        let g:lsp_cxx_hl_skipped_timer = timer_start(10,
                    \ function('s:hl_skipped_wrap', [a:force, winbufnr(0)]))
    else
        call s:hl_skipped_wrap(a:force, winbufnr(0), 0)
    endif
endfunction

function! s:hl_skipped_wrap(force, bufnr, timer) abort
    let l:begintime = lsp_cxx_hl#profile_begin()

    let l:matches = get(w:, 'lsp_cxx_hl_skipped_matches', [])
    unlet! w:lsp_cxx_hl_skipped_matches
    unlet! w:lsp_cxx_hl_skipped_bufnr

    let l:bufnr = winbufnr(0)

    call s:hl_skipped(a:force, l:bufnr, a:timer)

    " Clear old highlighting after finishing highlighting
    call lsp_cxx_hl#match#clear_matches(l:matches)

    redraw

    unlet! g:lsp_cxx_hl_skipped_timer
    call lsp_cxx_hl#profile_end(l:begintime, 'hl_skipped ', bufname(l:bufnr))
endfunction

function! s:hl_skipped(force, bufnr, timer) abort
    " Bad filetype
    if !a:force && count(g:lsp_cxx_hl_ft_whitelist, &filetype) == 0
        return
    endif

    " No data yet
    if !exists('b:lsp_cxx_hl_skipped') ||
                \ !exists('b:lsp_cxx_hl_skipped_version')
        return
    endif

    let l:skipped = b:lsp_cxx_hl_skipped

    let l:begin_end_pos = []
    let l:positions = []
    for l:range in l:skipped
        let l:cur_positions = lsp_cxx_hl#match#lsrange2match(l:range)

        if len(l:cur_positions) >= 1
            call add(l:begin_end_pos, l:cur_positions[0])
        endif

        if len(l:cur_positions) >= 2
            call add(l:begin_end_pos, l:cur_positions[-1])
            let l:positions += l:cur_positions[1:-2]
        endif

    endfor

    let l:matches = lsp_cxx_hl#match#matchaddpos_long(
                \ 'LspCxxHlSkippedRegion',
                \ l:positions,
                \ g:lsp_cxx_hl_inactive_region_priority)

    let l:matches += lsp_cxx_hl#match#matchaddpos_long(
                \ 'LspCxxHlSkippedRegionBeginEnd',
                \ l:begin_end_pos,
                \ g:lsp_cxx_hl_inactive_region_priority)


    let w:lsp_cxx_hl_skipped_matches = l:matches
    let w:lsp_cxx_hl_skipped_bufnr = a:bufnr
    let w:lsp_cxx_hl_skipped_version = b:lsp_cxx_hl_skipped_version

    call lsp_cxx_hl#log('hl_skipped highlighted ', len(l:skipped),
                \ ' skipped preprocessor regions',
                \ ' in file ', bufname(a:bufnr))
endfunction
