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
let s:has_byte_offset = has('byte_offset')

function! lsp_cxx_hl#textprop#symbols#notify(bufnr, symbols) abort
    call setbufvar(a:bufnr, 'lsp_cxx_hl_symbols', a:symbols)

    call lsp_cxx_hl#verbose_log('textprop notify symbols ',
                \ 'for ', bufname(a:bufnr))

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

function! lsp_cxx_hl#textprop#symbols#clear(bufnr) abort
    let l:id = getbufvar(a:bufnr, 'lsp_cxx_hl_symbols_id', -1)
    call setbufvar(a:bufnr, 'lsp_cxx_hl_symbols_id', -1)

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

    " Clear old highlighting after finishing highlighting
    call lsp_cxx_hl#textprop#symbols#clear(a:bufnr)

    unlet! g:lsp_cxx_hl_symbols_timer
    "redraw TODO: is this needed

    call lsp_cxx_hl#profile_end(l:begintime, 'hl_symbols (textprop) ', bufname(l:bufnr))
endfunction

function! s:hl_symbols(bufnr, timer) abort
    " Bad filetype
    if count(g:lsp_cxx_hl_ft_whitelist, &filetype) == 0
        return
    endif

    " No data yet
    if !exists('b:lsp_cxx_hl_symbols')
        return
    endif

    let l:prop_id = lsp_cxx_hl#textprop#gen_prop_id()

    let l:hl_group_positions = {}
    let l:missing_groups = {}

    let l:byte_offset_warn_done = 0

    for l:sym in b:lsp_cxx_hl_symbols
        " Create prop type
        let l:hl_group = 'LspCxxHlSym'
                    \ . l:sym['parentKind']
                    \ . l:sym['kind']
                    \ . l:sym['storage']

        if len(prop_type_get(l:hl_group)) == 0
            let l:resolved_hl_group = lsp_cxx_hl#hl_helpers#resolve_hl_group(
                        \ l:sym['parentKind'],
                        \ l:sym['kind'],
                        \ l:sym['storage'])

            if len(l:resolved_hl_group) == 0
                let l:resolved_hl_group = 'None'
            endif

            call lsp_cxx_hl#textprop#syn_prop_type_add(l:hl_group,
                        \ l:resolved_hl_group)
        endif

        " Add props
        let l:props = []

        for l:range in get(l:sym, 'ranges', [])
            let l:props += lsp_cxx_hl#textprop#lsrange2prop(l:range)
        endfor

        let l:offsets = get(l:sym, 'offsets', [])
        if s:has_byte_offset
            for l:offset in l:offsets
                let l:props += lsp_cxx_hl#match#offsets2prop(l:offset)
            endfor
        elseif !l:byte_offset_warn_done
            echohl ErrorMsg
            echomsg 'Cannot highlight, +byte_offset required'
            echohl NONE

            call lsp_cxx_hl#log('Cannot highlight, +byte_offset required')
            
            let l:byte_offset_warn_done = 1
        endif

        for l:prop in l:props
            let l:prop[2]['id'] = l:prop_id
            call prop_add(l:prop[0], l:prop[1], l:prop[2])
        endfor

        " TODO: missing groups
        " if !has_key(l:missing_groups, l:hl_group)
        "     let l:missing_groups[l:hl_group] = []
        " endif

        " let l:missing_groups[l:hl_group] += l:props
    endfor

    call lsp_cxx_hl#log('hl_symbols (textprop) highlighted ',
                \ len(l:symbols), ' symbols in file ', bufname(a:bufnr))
endfunction


