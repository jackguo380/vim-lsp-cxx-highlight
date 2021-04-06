" Common entrypoint for receiving LSP notifications
let s:has_reltime = has('reltime')

" Receive the full JSON RPC message possibly in string form
function! lsp_cxx_hl#notify_json_rpc(json) abort
    try
        call s:notify_json_rpc(a:json)
    catch
        call lsp_cxx_hl#log('notify_json_rpc error: ', v:exception, 'at',
                    \ v:throwpoint)
    endtry
endfunction

function! s:notify_json_rpc(json) abort
    if type(a:json) ==# type('')
        let l:msg = json_decode(a:json)
    else
        let l:msg = a:json
    endif

    if type(l:msg) !=# type({})
        call lsp_cxx_hl#log('Received malformed message: ', l:msg)
        return
    endif

    let l:method = get(l:msg, 'method', '')

    if l:method ==? '$cquery/publishSemanticHighlighting'
        let l:server = 'cquery'
        let l:is_skipped = 0
        let l:data_key = 'symbols'
    elseif l:method ==? '$cquery/setInactiveRegions'
        let l:server = 'cquery'
        let l:is_skipped = 1
        let l:data_key = 'inactiveRegions'
    elseif l:method ==? '$ccls/publishSemanticHighlight'
        let l:server = 'ccls'
        let l:is_skipped = 0
        let l:data_key = 'symbols'
    elseif l:method ==? '$ccls/publishSkippedRanges'
        let l:server = 'ccls'
        let l:is_skipped = 1
        let l:data_key = 'skippedRanges'
    else
        " Silently ignore unwanted messages
        call lsp_cxx_hl#log('Skipped Message: ', l:method)
        return
    endif

    call lsp_cxx_hl#log('Received Message: ', l:method)

    if !has_key(l:msg, 'params') ||
                \ !has_key(l:msg['params'], l:data_key) ||
                \ !has_key(l:msg['params'], 'uri')
        call lsp_cxx_hl#log('Response has invalid parameters: ', l:msg)
        return
    endif

    let l:bufnr = s:uri2bufnr(l:msg['params']['uri'])

    if l:is_skipped
        call lsp_cxx_hl#notify_skipped(l:server,
                    \ l:bufnr, l:msg['params'][l:data_key])
    else
        call lsp_cxx_hl#notify_symbols(l:server,
                    \ l:bufnr, l:msg['params'][l:data_key])
    endif
endfunction

" Receive already extracted skipped region data
function! lsp_cxx_hl#notify_skipped(server, buffer, skipped) abort
    let l:bufnr = s:common_notify_checks(a:server, a:buffer, a:skipped)

    try
        let l:begintime = lsp_cxx_hl#profile_begin()

        call lsp_cxx_hl#hl#notify_skipped(l:bufnr, a:skipped)

        call lsp_cxx_hl#profile_end(l:begintime,
                    \ 'notify_skipped ', bufname(l:bufnr))
    catch
        call lsp_cxx_hl#log('notify_skipped error: ', v:exception, 'at',
                    \ v:throwpoint)
    endtry
endfunction

" Receive already extracted symbol data
function! lsp_cxx_hl#notify_symbols(server, buffer, symbols) abort
    let l:bufnr = s:common_notify_checks(a:server, a:buffer, a:symbols)

    try
        let l:begintime = lsp_cxx_hl#profile_begin()

        let l:n_symbols = lsp_cxx_hl#parse#normalize_symbols(a:symbols,
                    \ (a:server ==# 'ccls'))

        call lsp_cxx_hl#hl#notify_symbols(l:bufnr, l:n_symbols)

        call lsp_cxx_hl#profile_end(l:begintime,
                    \ 'notify_symbols ', bufname(l:bufnr))
    catch
        call lsp_cxx_hl#log('notify_symbols error: ', v:exception, 'at',
                    \ v:throwpoint)
    endtry
endfunction

" Log
function! lsp_cxx_hl#verbose_log(...) abort
    if get(g:, 'lsp_cxx_hl_verbose_log', 0)
        if len(get(g:, 'lsp_cxx_hl_log_file', '')) > 0
            call writefile([strftime('%c') . ': ' . join(a:000, '')],
                        \ g:lsp_cxx_hl_log_file, 'a')
        endif
    endif
endfunction

function! lsp_cxx_hl#log(...) abort
    if len(get(g:, 'lsp_cxx_hl_log_file', '')) > 0
        call writefile([strftime('%c') . ': ' . join(a:000, '')],
                    \ g:lsp_cxx_hl_log_file, 'a')
    endif
endfunction

function! lsp_cxx_hl#profile_begin() abort
    if s:has_reltime
        return reltime()
    else
        return 0
    endif
endfunction

function! lsp_cxx_hl#profile_end(begin, ...) abort
    if s:has_reltime
        let l:name = join(a:000, '')
        call lsp_cxx_hl#log('operation ', l:name, ' took ',
                    \ reltimestr(reltime(a:begin)), 's to complete')
    endif
endfunction

" Section: Helpers

function! s:common_notify_checks(server, buffer, data) abort
    if type(a:buffer) ==# type("")
        let l:bufnr = s:uri2bufnr(a:buffer)
    elseif type(a:buffer) ==# type(0)
        let l:bufnr = a:buffer
    else
        throw 'buffer must be a string or number'
    endif

    if !bufexists(l:bufnr)
        throw 'buffer does not exist!'
    endif

    if type(a:data) !=# type([])
        throw 'symbols must be a list'
    endif

    if a:server !=# 'cquery' && a:server !=# 'ccls'
        throw 'only cquery or ccls is supported'
    endif

    return l:bufnr
endfunction

" Section: Misc Helpers
function! s:uri2bufnr(uri) abort
    " Absolute paths on windows has 3 leading /
    if has('win32') || has('win64')
        let l:regex = '\c^[a-z]\+:///\?'
    else
        let l:regex = '\c^[a-z]\+://'
    endif

    " Remove the leading file:// or whatever protocol is used
    let l:filename = substitute(a:uri, l:regex, '', '')
    let l:bufnr = bufnr(l:filename)

    if l:bufnr == -1
        " Some characters get escaped by ccls into url encoded format.
        " Only try this if received filename doesn't exist.
        let l:bufnr = bufnr(s:unescape_urlencode(l:filename))
    endif

    return l:bufnr
endfunction

" A simple url format decoder
function! s:unescape_urlencode(str) abort
    let l:matches = []
    let l:start = 0

    let l:str = a:str
    while l:start != -1
        let l:match = matchstrpos(l:str, '%[0-9A-Fa-f][0-9A-Fa-f]', l:start)
        let l:start = l:match[2]

        if l:start != -1
            let l:str = l:str[:l:match[1] - 1] . nr2char(str2nr(l:match[0][1:], 16)) .
                        \ l:str[l:match[2]:]
            let l:start = l:match[1] + 1
        endif
    endwhile

    call lsp_cxx_hl#verbose_log('unescape_urlencode unescaped filename: ', l:str)
    return l:str
endfunction
