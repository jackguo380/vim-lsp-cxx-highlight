function! lsp_cpp_highlight#vim_lsp#init() abort
    call lsp#register_notifications('lsp_cpp_highlight', 
                \ function('s:notification_cb'))
endfunction

function! s:notification_cb(server, data) abort
    call lsp_cpp_highlight#receive_json_rpc(a:data)
endfunction

" User warnings
augroup vim_lsp_check_servers
    autocmd!
    autocmd User lsp_server_init call s:check_servers()
augroup END

let s:checked_servers = 0

function! s:check_servers() abort
    if s:checked_servers
        return
    endif

    if s:server_available('cquery')
        let l:cquery_info = lsp#get_server_info('cquery')

        " cquery disables highlight by default
        if !get(get(get(l:cquery_info, 'initialization_options', {})
                    \ , 'highlight', {}), 'enabled', 0)
            call s:error_msg('Set highlight.enabled = true in cquery
                        \ initialization_options')
        endif
    endif

    if s:server_available('ccls')
        let l:ccls_info = lsp#get_server_info('ccls')

        " check if lsRanges is enabled otherwise check if ccls' range format
        " can be parsed
        if !get(get(get(l:ccls_info, 'initialization_options', {})
                    \ , 'highlight', {}), 'lsRanges', 0) &&
                    \ !g:lsp_cpp_highlight_ccls_offsets
            call s:error_msg('vim does not have +byte_offset,
                        \ set highlight.lsRanges = true in ccls
                        \ initialization_options')
        endif
    endif

    let s:checked_servers = 1

    echomsg 'checked servers'
endfunction

function! s:server_available(server) abort
    let l:server_names = lsp#get_server_names()

    if count(l:server_names, a:server) > 0
        return 1
    else
        return 0
    endif
endfunction

function! s:error_msg(msg) abort
    echohl ErrorMsg
    echom a:msg
    echohl NONE
endfunction
