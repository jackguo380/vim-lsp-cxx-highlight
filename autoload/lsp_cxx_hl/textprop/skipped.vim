" text properties implementation of preprocessor skipped regions
"
" b:lsp_cxx_hl_skipped
"   Skipped regions
"
" b:lsp_cxx_hl_skipped_id
"   text prop id for skipped regions in this buffer (A random number)
"
" g:lsp_cxx_hl_skipped_timer
"   if timers are available this is the timer
"   id for skipped regions

let s:has_timers = has('timers')

function! lsp_cxx_hl#textprop#skipped#notify(bufnr, skipped) abort
    call setbufvar(a:bufnr, 'lsp_cxx_hl_skipped', a:skipped)

    call lsp_cxx_hl#verbose_log('textprop notify ', len(a:skipped),
                \ ' skipped regions for ', bufname(a:bufnr))

    call lsp_cxx_hl#textprop#skipped#highlight(a:bufnr)
endfunction

function! lsp_cxx_hl#textprop#skipped#highlight(bufnr) abort
    if s:has_timers
        if get(g:, 'lsp_cxx_hl_skipped_timer', -1) != -1
            call lsp_cxx_hl#verbose_log('stopped hl_skipped timer')
            call timer_stop(g:lsp_cxx_hl_skipped_timer)
        endif

        let g:lsp_cxx_hl_skipped_timer = timer_start(10,
                    \ function('s:hl_skipped_wrap', [a:bufnr]))
    else
        call s:hl_skipped_wrap(a:bufnr, 0)
    endif
endfunction

function! lsp_cxx_hl#textprop#skipped#clear(bufnr, ...) abort
    if a:0 >= 1
        let l:id = a:1
    else
        let l:id = getbufvar(a:bufnr, 'lsp_cxx_hl_skipped_id', -1)
        call setbufvar(a:bufnr, 'lsp_cxx_hl_skipped_id', -1)
    endif

    if l:id != -1
        call prop_remove({
                    \ 'id': l:id,
                    \ 'all': 1,
                    \ 'bufnr': a:bufnr
                    \ })
    endif
endfunction

function! s:hl_skipped_wrap(bufnr, timer) abort
    let l:begintime = lsp_cxx_hl#profile_begin()

    call s:hl_skipped(a:bufnr, a:timer)

    unlet! g:lsp_cxx_hl_skipped_timer

    call lsp_cxx_hl#profile_end(l:begintime, 'hl_skipped (textprop) ', bufname(a:bufnr))
endfunction

function! s:hl_skipped(bufnr, timer) abort
    " Bad filetype
    if count(g:lsp_cxx_hl_ft_whitelist, getbufvar(a:bufnr, '&filetype')) == 0
        return
    endif

    " No data yet
    let l:skipped = getbufvar(a:bufnr, 'lsp_cxx_hl_skipped', [])
    if empty(l:skipped)
        return
    endif

    if len(prop_type_get('LspCxxHlSkippedRegion')) == 0
        call prop_type_add('LspCxxHlSkippedRegion', {
                    \ 'highlight': 'LspCxxHlSkippedRegion',
                    \ 'start_incl': 0,
                    \ 'end_incl': 0,
                    \ 'priority': g:lsp_cxx_hl_syntax_priority
                    \ })
    endif

    let l:props = []
    for l:range in l:skipped
        let l:prop = lsp_cxx_hl#textprop#lsrange2prop(a:bufnr, l:range)

        " Remove the beginnings and ends of the region
        " since it includes them (#if/#endifs)
        if l:prop[0] < get(l:prop[2], 'end_lnum', 0)
            let l:prop[0] += 1

            if l:prop[0] < l:prop[2]['end_lnum']
                let l:prop[2]['end_lnum'] -= 1
            endif
        endif

        " Fix the # at the end getting highlighted
        if get(l:prop[2], 'end_col', 2) <= 1
            let l:prop[2]['end_lnum'] -= 1
            let l:prop[2]['end_col'] = col([l:prop[2]['end_lnum'], '$'])
        endif

        call add(l:props, l:prop)
    endfor

    let l:old_id = getbufvar(a:bufnr, 'lsp_cxx_hl_skipped_id', -1)

    let l:prop_id = lsp_cxx_hl#textprop#gen_prop_id()

    call lsp_cxx_hl#log('hl_skipped (textprop) id ', l:prop_id)

    let l:prop_extra = {
                \ 'id': l:prop_id,
                \ 'type': 'LspCxxHlSkippedRegion'
                \ }

    for l:prop in l:props
        call extend(l:prop[2], l:prop_extra)

        try
            call prop_add(l:prop[0], l:prop[1], l:prop[2])
        catch
            call lsp_cxx_hl#log('textprop prop_add skipped error: ',
                        \ v:exception)
        endtry
    endfor

    call setbufvar(a:bufnr, 'lsp_cxx_hl_skipped_id', l:prop_id)

    call lsp_cxx_hl#log('hl_skipped (textprop) highlighted ', len(l:skipped),
                \ ' skipped preprocessor regions',
                \ ' in file ', bufname(a:bufnr))

    " Clear old highlighting after finishing highlighting
    call lsp_cxx_hl#textprop#skipped#clear(a:bufnr, l:old_id)
endfunction
