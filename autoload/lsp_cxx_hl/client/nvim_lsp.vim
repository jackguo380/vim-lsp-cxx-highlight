" Neovim LSP

function! lsp_cxx_hl#client#nvim_lsp#init() abort
    if has('nvim')
        call s:doinit()

        augroup lsp_cxx_hl_nvim_lsp_init
            autocmd! 
            autocmd VimEnter *  call s:doinit()
        augroup END
    else
        throw 'Not Neovim'
    endif
endfunction

function! s:doinit() abort
lua <<EOF
handlers = vim.lsp.handlers

--[ backwards compatibility with neovim<0.5 --]
if (handlers == nil)
then
  handlers = vim.lsp.callbacks
end

local version = vim.version()
if (version.major >= 0 and version.minor >= 5 and version.patch > 0)
then

handlers['$cquery/publishSemanticHighlighting'] = function(err, result, ctx)
    vim.api.nvim_call_function('lsp_cxx_hl#client#nvim_lsp#cquery_hl', {result})
end

handlers['$cquery/setInactiveRegions'] = function(err, result, ctx)
    vim.api.nvim_call_function('lsp_cxx_hl#client#nvim_lsp#cquery_regions', {result})
end

handlers['$ccls/publishSemanticHighlight'] = function(err, result, ctx)
    vim.api.nvim_call_function('lsp_cxx_hl#client#nvim_lsp#ccls_hl', {result})
end

handlers['$ccls/publishSkippedRanges'] = function(err, result, ctx)
    vim.api.nvim_call_function('lsp_cxx_hl#client#nvim_lsp#ccls_regions', {result})
end

else

handlers['$cquery/publishSemanticHighlighting'] = function(err, method, params, client_id)
    vim.api.nvim_call_function('lsp_cxx_hl#client#nvim_lsp#cquery_hl', {params})
end

handlers['$cquery/setInactiveRegions'] = function(err, method, params, client_id)
    vim.api.nvim_call_function('lsp_cxx_hl#client#nvim_lsp#cquery_regions', {params})
end

handlers['$ccls/publishSemanticHighlight'] = function(err, method, params, client_id)
    vim.api.nvim_call_function('lsp_cxx_hl#client#nvim_lsp#ccls_hl', {params})
end

handlers['$ccls/publishSkippedRanges'] = function(err, method, params, client_id)
    vim.api.nvim_call_function('lsp_cxx_hl#client#nvim_lsp#ccls_regions', {params})
end

end
EOF
endfunction


function! lsp_cxx_hl#client#nvim_lsp#cquery_hl(params) abort
    "call lsp_cxx_hl#log('cquery hl:', a:params)

    call lsp_cxx_hl#notify_symbols('cquery', a:params['uri'],
                \ a:params['symbols'])
endfunction

function! lsp_cxx_hl#client#nvim_lsp#cquery_regions(params) abort
    "call lsp_cxx_hl#log('cquery regions:', a:params)

    call lsp_cxx_hl#notify_skipped('cquery', a:params['uri'],
                \ a:params['inactiveRegions'])
endfunction

function! lsp_cxx_hl#client#nvim_lsp#ccls_hl(params) abort
    "call lsp_cxx_hl#log('ccls hl:', a:params)

    call lsp_cxx_hl#notify_symbols('ccls', a:params['uri'],
                \ a:params['symbols'])
endfunction

function! lsp_cxx_hl#client#nvim_lsp#ccls_regions(params) abort
    "call lsp_cxx_hl#log('ccls regions:', a:params)

    call lsp_cxx_hl#notify_skipped('ccls', a:params['uri'],
                \ a:params['skippedRanges'])
endfunction
