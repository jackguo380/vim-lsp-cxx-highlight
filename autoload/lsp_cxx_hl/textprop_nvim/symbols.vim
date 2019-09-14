" neovim text properties implementation of symbol highlighting
" 
" Variables:
"
" b:lsp_cxx_hl_symbols
"   ast symbol list from
"   lsp_cxx_hl#notify_symbol_data
"
" g:lsp_cxx_hl_symbols_timer
"   if timers are available this is the timer
"   id for symbols

let s:has_timers = has('timers')
let s:has_byte_offset = has('byte_offset')

function! lsp_cxx_hl#textprop_nvim#symbols#notify(bufnr, symbols) abort
    call setbufvar(a:bufnr, 'lsp_cxx_hl_symbols', a:symbols)

    call lsp_cxx_hl#verbose_log('textprop nvim notify symbols ',
                \ 'for ', bufname(a:bufnr))

    let l:curbufnr = winbufnr(0)

    if a:bufnr == l:curbufnr
        call lsp_cxx_hl#textprop_nvim#symbols#highlight()
    endif
endfunction

function! lsp_cxx_hl#textprop_nvim#symbols#highlight() abort
    let l:bufnr = winbufnr(0)

    if s:has_timers
        if get(g:, 'lsp_cxx_hl_symbols_timer', -1) != -1
            call lsp_cxx_hl#verbose_log('stopped hl_symbols timer')
            call timer_stop(g:lsp_cxx_hl_symbols_timer)
        endif

        let g:lsp_cxx_hl_symbols_timer = timer_start(10,
                    \ function('s:hl_symbols_wrap', [l:bufnr]))
    else
        call s:hl_symbols_wrap(l:bufnr, 0)
    endif
endfunction

function! lsp_cxx_hl#textprop_nvim#symbols#clear(bufnr) abort
    let l:ns_id = nvim_create_namespace('lsp_cxx_hl_symbols')

    call nvim_buf_clear_namespace(a:bufnr, l:ns_id, 0, -1)
endfunction

function! s:hl_symbols_wrap(bufnr, timer) abort
    let l:begintime = lsp_cxx_hl#profile_begin()

    call lsp_cxx_hl#textprop_nvim#symbols#clear(a:bufnr)

    call s:hl_symbols(a:bufnr, a:timer)

    unlet! g:lsp_cxx_hl_symbols_timer

    call lsp_cxx_hl#profile_end(l:begintime, 'hl_symbols (textprop nvim) ',
                \ bufname(a:bufnr))
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

    let l:ns_id = nvim_create_namespace('lsp_cxx_hl_symbols')

    " Cache results per session to ensure consistent highlighting
    " and reduce the number of times highlight groups are re resolved
    let l:hl_group_cache = {}

    let l:missing_groups = {}

    let l:byte_offset_warn_done = 0

    for l:sym in b:lsp_cxx_hl_symbols
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

        if s:has_byte_offset
            for l:offset in get(l:sym, 'offsets', [])
                call lsp_cxx_hl#textprop_nvim#buf_add_hl_offset(a:bufnr,
                            \ l:ns_id, l:hl_group_c, l:offset)
            endfor
        elseif !l:byte_offset_warn_done
            echohl ErrorMsg
            echomsg 'Cannot highlight, +byte_offset required'
            echohl NONE

            call lsp_cxx_hl#log('Cannot highlight, +byte_offset required')
            
            let l:byte_offset_warn_done = 1
        endif
    endfor

    call lsp_cxx_hl#log('hl_symbols (textprop nvim) highlighted ',
                \ len(b:lsp_cxx_hl_symbols), ' symbols in file ',
                \ bufname(a:bufnr))

    let b:lsp_cxx_hl_missing_groups = l:missing_groups
endfunction
