" text properties implementation of preprocessor skipped regions
"
" b:lsp_cxx_hl_skipped_cur_ns
"   0 or 1 depending whether lsp_cxx_hl_skipped_<bufnr>_0 or
"   lsp_cxx_hl_skipped_<bufnr>_1 is used to highlight
"
" b:lsp_cxx_hl_skipped
"   Skipped regions
"
" g:lsp_cxx_hl_skipped_timer
"   if timers are available this is the timer
"   id for skipped regions

let s:has_timers = has('timers')

function! lsp_cxx_hl#textprop_nvim#skipped#notify(bufnr, skipped) abort
    call setbufvar(a:bufnr, 'lsp_cxx_hl_skipped', a:skipped)

    call lsp_cxx_hl#verbose_log('textprop nvim notify ', len(a:skipped),
                \ ' skipped regions for ', bufname(a:bufnr))

    call lsp_cxx_hl#textprop_nvim#skipped#highlight(a:bufnr)
endfunction

function! lsp_cxx_hl#textprop_nvim#skipped#highlight(bufnr) abort
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

function! s:get_ns_id(bufnr) abort
    let l:cur_ns = getbufvar(a:bufnr, 'lsp_cxx_hl_skipped_cur_ns', 0)

    return nvim_create_namespace('lsp_cxx_hl_skipped_' . a:bufnr . '_' . l:cur_ns)
endfunction

function! s:toggle_ns_id(bufnr) abort
    let l:cur_ns = getbufvar(a:bufnr, 'lsp_cxx_hl_skipped_cur_ns', 0)

    if l:cur_ns == 0
        call setbufvar(a:bufnr, 'lsp_cxx_hl_skipped_cur_ns', 1)
    else
        call setbufvar(a:bufnr, 'lsp_cxx_hl_skipped_cur_ns', 0)
    endif
endfunction

function! lsp_cxx_hl#textprop_nvim#skipped#clear(bufnr) abort
    let l:ns_id = s:get_ns_id(a:bufnr)

    call nvim_buf_clear_namespace(a:bufnr, l:ns_id, 0, -1)
endfunction

function! s:hl_skipped_wrap(bufnr, timer) abort
    let l:begintime = lsp_cxx_hl#profile_begin()

    call s:hl_skipped(a:bufnr, a:timer)

    unlet! g:lsp_cxx_hl_skipped_timer

    call lsp_cxx_hl#profile_end(l:begintime, 'hl_skipped (textprop nvim) ',
                \ bufname(a:bufnr))
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

    let l:old_ns_id = s:get_ns_id(a:bufnr)

    call s:toggle_ns_id(a:bufnr)

    let l:ns_id = s:get_ns_id(a:bufnr)

    for l:range in l:skipped
        call lsp_cxx_hl#textprop_nvim#buf_add_hl_skipped_range(a:bufnr,
                    \ l:ns_id, 'LspCxxHlSkippedRegion', l:range)
    endfor

    call lsp_cxx_hl#log('hl_skipped (textprop nvim) highlighted ',
                \ len(l:skipped),
                \ ' skipped preprocessor regions',
                \ ' in file ', bufname(a:bufnr))

    call nvim_buf_clear_namespace(a:bufnr, l:old_ns_id, 0, -1)
endfunction
