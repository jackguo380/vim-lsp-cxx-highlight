" text properties implementation of symbol highlighting
" 
" Variables:
"
" b:lsp_cxx_hl_symbols
"   ast symbol list from
"   lsp_cxx_hl#notify_symbol_data
"
" b:lsp_cxx_hl_ignored_symbols
"   symbols not highlighted
"
" b:lsp_cxx_hl_symbols_id
"   text prop id for symbols in this buffer (A random number)
"
" g:lsp_cxx_hl_symbols_timer
"   if timers are available this is the timer
"   id for symbols

let s:has_timers = has('timers')

function! lsp_cxx_hl#textprop#symbols#notify(bufnr, symbols) abort
    call setbufvar(a:bufnr, 'lsp_cxx_hl_symbols', a:symbols)

    call lsp_cxx_hl#verbose_log('textprop notify ', len(a:symbols),
                \ ' symbols for ', bufname(a:bufnr))

    call lsp_cxx_hl#textprop#symbols#highlight(a:bufnr)
endfunction


function! lsp_cxx_hl#textprop#symbols#highlight(bufnr) abort
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

function! lsp_cxx_hl#textprop#symbols#clear(bufnr, ...) abort
    if a:0 >= 1
        let l:id = a:1
    else
        let l:id = getbufvar(a:bufnr, 'lsp_cxx_hl_symbols_id', -1)
        call setbufvar(a:bufnr, 'lsp_cxx_hl_symbols_id', -1)
    endif

    if l:id != -1
        call prop_remove({
                    \ 'id': l:id,
                    \ 'all': 1,
                    \ 'bufnr': a:bufnr
                    \ })
    endif
endfunction

function! s:hl_symbols_wrap(bufnr, timer) abort
    let l:begintime = lsp_cxx_hl#profile_begin()

    call s:hl_symbols(a:bufnr, a:timer)

    unlet! g:lsp_cxx_hl_symbols_timer

    call lsp_cxx_hl#profile_end(l:begintime, 'hl_symbols (textprop) ',
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

    let l:old_id = getbufvar(a:bufnr,  'lsp_cxx_hl_symbols_id', -1)

    let l:prop_id = lsp_cxx_hl#textprop#gen_prop_id()

    call lsp_cxx_hl#log('hl_symbols (textprop) id ', l:prop_id)

    let l:hl_group_positions = {}
    let l:missing_groups = {}

    let l:byte_offset_warn_done = 0

    for l:sym in l:symbols
        " Create prop type
        let l:hl_group = 'LspCxxHlSym'
                    \ . l:sym['parentKind']
                    \ . l:sym['kind']
                    \ . l:sym['storage']

        let l:prop_type = prop_type_get(l:hl_group)
        if len(l:prop_type) == 0
            let l:resolved_hl_group = lsp_cxx_hl#hl_helpers#resolve_hl_group(
                        \ l:sym['parentKind'],
                        \ l:sym['kind'],
                        \ l:sym['storage'])

            call lsp_cxx_hl#textprop#syn_prop_type_add(l:hl_group,
                        \ l:resolved_hl_group)

            let l:prop_type = prop_type_get(l:hl_group)
        endif

        " Add props
        let l:props = []

        for l:range in get(l:sym, 'ranges', [])
            call add(l:props, lsp_cxx_hl#textprop#lsrange2prop(a:bufnr, l:range))
        endfor

        let l:offsets = get(l:sym, 'offsets', [])
        if !empty(l:offsets) && !l:byte_offset_warn_done
            echohl ErrorMsg
            echomsg 'Error: ls ranges is not enabled in ccls'
            echohl NONE

            call lsp_cxx_hl#log('Error: ls ranges not enabled in ccls')
            
            let l:byte_offset_warn_done = 1
        endif

        if !has_key(l:prop_type, 'highlight')
            if !has_key(l:missing_groups, l:hl_group)
                let l:missing_groups[l:hl_group] = []
            endif

            let l:missing_groups[l:hl_group] += l:props

            continue
        endif

        let l:prop_extra = {
                    \ 'id': l:prop_id,
                    \ 'type': l:hl_group,
                    \ 'bufnr': a:bufnr
                    \ }

        for l:prop in l:props
            call extend(l:prop[2], l:prop_extra)

            try
                call prop_add(l:prop[0], l:prop[1], l:prop[2])
            catch
                call lsp_cxx_hl#log('textprop prop_add symbol error: ',
                            \ v:exception)
            endtry
        endfor
    endfor

    call lsp_cxx_hl#log('hl_symbols (textprop) highlighted ',
                \ len(l:symbols), ' symbols in file ',
                \ bufname(a:bufnr))

    call setbufvar(a:bufnr, 'lsp_cxx_hl_symbols_id', l:prop_id)
    call setbufvar(a:bufnr, 'lsp_cxx_hl_missing_groups', l:missing_groups)

    " Clear old highlighting after finishing highlighting
    call lsp_cxx_hl#textprop#symbols#clear(a:bufnr, l:old_id)
endfunction
