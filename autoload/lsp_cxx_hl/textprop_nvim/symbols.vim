" neovim text properties implementation of symbol highlighting
" 
" Variables:
"
" b:lsp_cxx_hl_symbols_cur_ns
"   0 or 1 depending whether lsp_cxx_hl_symbols_<bufnr>_0 or
"   lsp_cxx_hl_symbols_<bufnr>_1 is used to highlight
"
" b:lsp_cxx_hl_symbols
"   ast symbol list from
"   lsp_cxx_hl#notify_symbol_data
"
" g:lsp_cxx_hl_symbols_timer
"   if timers are available this is the timer
"   id for symbols

let s:has_timers = has('timers')

function! lsp_cxx_hl#textprop_nvim#symbols#notify(bufnr, symbols) abort
    call setbufvar(a:bufnr, 'lsp_cxx_hl_symbols', a:symbols)

    call lsp_cxx_hl#verbose_log('textprop nvim notify ', len(a:symbols),
                \' symbols for ', bufname(a:bufnr))


    call lsp_cxx_hl#textprop_nvim#symbols#highlight(a:bufnr)
endfunction

function! lsp_cxx_hl#textprop_nvim#symbols#highlight(bufnr) abort
    if s:has_timers
        if get(g:, 'lsp_cxx_hl_symbols_timer', -1) != -1
            call lsp_cxx_hl#verbose_log('stopped hl_symbols timer')
            call timer_stop(g:lsp_cxx_hl_symbols_timer)
        endif

        let g:lsp_cxx_hl_symbols_timer = timer_start(10,
                    \ function('s:hl_symbols_wrap', [a:bufnr]))
    else
        call s:hl_symbols_wrap(a:bufnr, 0)
    endif
endfunction

function! s:get_ns_id(bufnr) abort
    let l:cur_ns = getbufvar(a:bufnr, 'lsp_cxx_hl_symbols_cur_ns', 0)

    return nvim_create_namespace('lsp_cxx_hl_symbols_' . a:bufnr . '_' . l:cur_ns)
endfunction

function! s:toggle_ns_id(bufnr) abort
    let l:cur_ns = getbufvar(a:bufnr, 'lsp_cxx_hl_symbols_cur_ns', 0)

    if l:cur_ns == 0
        call setbufvar(a:bufnr, 'lsp_cxx_hl_symbols_cur_ns', 1)
    else
        call setbufvar(a:bufnr, 'lsp_cxx_hl_symbols_cur_ns', 0)
    endif
endfunction

function! lsp_cxx_hl#textprop_nvim#symbols#clear(bufnr) abort
    let l:ns_id = s:get_ns_id(a:bufnr)

    call nvim_buf_clear_namespace(a:bufnr, l:ns_id, 0, -1)
endfunction

function! s:hl_symbols_wrap(bufnr, timer) abort
    let l:begintime = lsp_cxx_hl#profile_begin()

    call s:hl_symbols(a:bufnr, a:timer)

    unlet! g:lsp_cxx_hl_symbols_timer

    call lsp_cxx_hl#profile_end(l:begintime, 'hl_symbols (textprop nvim) ',
                \ bufname(a:bufnr))
endfunction

function! s:hl_symbols(bufnr, timer) abort
    " Bad filetype
    if count(g:lsp_cxx_hl_ft_whitelist, getbufvar(a:bufnr, '&filetype')) == 0
        return
    endif

    " No data yet
    let l:symbols = getbufvar(a:bufnr, 'lsp_cxx_hl_symbols', [])
    if empty(l:symbols)
        return
    endif

    let l:old_ns_id = s:get_ns_id(a:bufnr)

    call s:toggle_ns_id(a:bufnr)

    let l:ns_id = s:get_ns_id(a:bufnr)

    " Cache results per session to ensure consistent highlighting
    " and reduce the number of times highlight groups are re resolved
    let l:hl_group_cache = {}

    let l:missing_groups = {}

    let l:byte_offset_warn_done = 0

    for l:sym in l:symbols
        " Create prop type
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

        if len(l:hl_group_c) == 0
            if !has_key(l:missing_groups, l:hl_group)
                let l:missing_groups[l:hl_group] = []
            endif

            " FIXME: unify reporting of missing hl groups
            let l:missing_groups[l:hl_group] += []
            
            continue
        endif

        " Add props
        for l:range in get(l:sym, 'ranges', [])
            call lsp_cxx_hl#textprop_nvim#buf_add_hl_lsrange(a:bufnr, l:ns_id,
                        \ l:hl_group_c, l:range)
        endfor

        let l:offsets = get(l:sym, 'offsets', [])
        if !empty(l:offsets) && !l:byte_offset_warn_done
            echohl ErrorMsg
            echomsg 'Error: ls ranges is not enabled in ccls'
            echohl NONE

            call lsp_cxx_hl#log('Error: ls ranges not enabled in ccls')
            
            let l:byte_offset_warn_done = 1
        endif
    endfor

    call lsp_cxx_hl#log('hl_symbols (textprop nvim) highlighted ',
                \ len(l:symbols), ' symbols in file ',
                \ bufname(a:bufnr))

    call setbufvar(a:bufnr, 'lsp_cxx_hl_missing_groups', l:missing_groups)

    call nvim_buf_clear_namespace(a:bufnr, l:old_ns_id, 0, -1)
endfunction
