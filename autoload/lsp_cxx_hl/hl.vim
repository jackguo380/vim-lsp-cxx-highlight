" Helper functions for unifying match and textprop
" Variables:
" b:lsp_cxx_hl_disabled - disable highlighting for this buffer

" Check if highlighting in the current buffer needs updating
function! lsp_cxx_hl#hl#check(...) abort
    let l:force = (a:0 > 0 && a:1)

    if get(b:, 'lsp_cxx_hl_disabled', 0)
        call lsp_cxx_hl#hl#clear()
        return
    endif

    if g:lsp_cxx_hl_use_nvim_text_props
        return
    elseif g:lsp_cxx_hl_use_text_props
        return
    else
        call lsp_cxx_hl#match#symbols#check(l:force)
        call lsp_cxx_hl#match#skipped#check(l:force)
    endif
endfunction

" Clear highlighting in this buffer
function! lsp_cxx_hl#hl#clear() abort
    let l:bufnr = winbufnr(0)

    if g:lsp_cxx_hl_use_nvim_text_props
        call lsp_cxx_hl#textprop_nvim#symbols#clear(l:bufnr)
        call lsp_cxx_hl#textprop_nvim#skipped#clear(l:bufnr)
    elseif g:lsp_cxx_hl_use_text_props
        call lsp_cxx_hl#textprop#symbols#clear(l:bufnr)
        call lsp_cxx_hl#textprop#skipped#clear(l:bufnr)
    else
        call lsp_cxx_hl#match#symbols#clear()
        call lsp_cxx_hl#match#skipped#clear()
    endif
endfunction

" Enable the highlighting for this buffer
function! lsp_cxx_hl#hl#enable() abort
    unlet! b:lsp_cxx_hl_disabled

    let l:bufnr = winbufnr(0)

    if g:lsp_cxx_hl_use_nvim_text_props
        call lsp_cxx_hl#textprop_nvim#symbols#highlight(l:bufnr)
        call lsp_cxx_hl#textprop_nvim#skipped#highlight(l:bufnr)
    elseif g:lsp_cxx_hl_use_text_props
        call lsp_cxx_hl#textprop#symbols#highlight(l:bufnr)
        call lsp_cxx_hl#textprop#skipped#highlight(l:bufnr)
    else
        call lsp_cxx_hl#hl#check(1)
    endif
endfunction

" Disable the highlighting for this buffer
function! lsp_cxx_hl#hl#disable() abort
    let b:lsp_cxx_hl_disabled = 1

    call lsp_cxx_hl#hl#clear()
endfunction

" Notify of new semantic highlighting symbols
function! lsp_cxx_hl#hl#notify_symbols(bufnr, symbols) abort
    if g:lsp_cxx_hl_use_nvim_text_props
        if get(b:, 'lsp_cxx_hl_disabled', 0)
            call lsp_cxx_hl#hl#clear()
        else
            call lsp_cxx_hl#textprop_nvim#symbols#notify(a:bufnr, a:symbols)
        endif
    elseif g:lsp_cxx_hl_use_text_props
        if get(b:, 'lsp_cxx_hl_disabled', 0)
            call lsp_cxx_hl#hl#clear()
        else
            call lsp_cxx_hl#textprop#symbols#notify(a:bufnr, a:symbols)
        endif
    else
        call lsp_cxx_hl#match#symbols#notify(a:bufnr, a:symbols)

        if get(b:, 'lsp_cxx_hl_disabled', 0)
            call lsp_cxx_hl#hl#clear()
        else
            call lsp_cxx_hl#match#symbols#check(0)
        endif
    endif
endfunction

" Notify of new preprocessor skipped regions
function! lsp_cxx_hl#hl#notify_skipped(bufnr, skipped) abort
    if g:lsp_cxx_hl_use_nvim_text_props
        if get(b:, 'lsp_cxx_hl_disabled', 0)
            call lsp_cxx_hl#hl#clear()
        else
            if !empty(a:skipped)
                call lsp_cxx_hl#textprop_nvim#skipped#notify(a:bufnr, a:skipped)
                call s:stop_clear(a:bufnr, 'skipped_clear_timer')
            else
                call s:start_clear(a:bufnr, 'skipped_clear_timer',
                            \ function('lsp_cxx_hl#textprop_nvim#skipped#clear'
                            \ ))
            endif
        endif
    elseif g:lsp_cxx_hl_use_text_props
        if get(b:, 'lsp_cxx_hl_disabled', 0)
            call lsp_cxx_hl#hl#clear()
        else
            if !empty(a:skipped)
                call lsp_cxx_hl#textprop#skipped#notify(a:bufnr, a:skipped)
                call s:stop_clear(a:bufnr, 'skipped_clear_timer')
            else
                call s:start_clear(a:bufnr, 'skipped_clear_timer',
                            \ function('lsp_cxx_hl#textprop#skipped#clear'))
            endif
        endif
    else
        call lsp_cxx_hl#match#skipped#notify(a:bufnr, a:skipped)

        if get(b:, 'lsp_cxx_hl_disabled', 0)
            call lsp_cxx_hl#hl#clear()
        else
            call lsp_cxx_hl#match#skipped#check(0)
        endif
    endif
endfunction

" Helper for running clear after some time has passed this clears the last
" symbol or skipped region leftover after a
" user deletes it
let s:has_timers = has('timers')
function! s:start_clear(bufnr, timer_var, ClearFn) abort
    if !s:has_timers
        call lsp_cxx_hl#log('WARNING: timers not available, '
                    \ 'delay cannot be done!')
        call a:ClearFn()
        return
    endif

    let l:timer = getbufvar(a:bufnr, a:timer_var, -1)
    if l:timer != -1
        call timer_stop(l:timer)
    endif

    let l:timer = timer_start(g:lsp_cxx_hl_clear_delay_ms,
                \ function('s:clear_timer_fn',
                \ [a:bufnr, a:timer_var, a:ClearFn]))
    call setbufvar(a:bufnr, a:timer_var, l:timer)
endfunction

function! s:stop_clear(bufnr, timer_var) abort
    if !s:has_timers
        return
    endif

    let l:timer = getbufvar(a:bufnr, a:timer_var, -1)
    if l:timer != -1
        call timer_stop(l:timer)
    endif
    call setbufvar(a:bufnr, a:timer_var, -1)
endfunction

function! s:clear_timer_fn(bufnr, timer_var, ClearFn, timer) abort
    call lsp_cxx_hl#verbose_log(a:timer_var, ' clear_timer_fn ', a:timer)
    call a:ClearFn(a:bufnr)
    call setbufvar(a:bufnr, a:timer_var, -1)
endfunction
