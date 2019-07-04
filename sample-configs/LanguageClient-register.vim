" Configuration of LanguageClient-neovim to use cquery and ccls with


" ccls
" also see https://github.com/autozimu/LanguageClient-neovim/wiki/ccls
let s:ccls_settings = {
         \ 'highlight': { 'lsRanges' : v:true },
         \ }

let s:ccls_command = ['ccls', '-init=' . json_encode(s:ccls_settings)]

let g:LanguageClient_serverCommands = {
      \ 'c': s:ccls_command,
      \ 'cpp': s:ccls_command,
      \ 'objc': s:ccls_command,
      \ }

" cquery
" also see https://github.com/autozimu/LanguageClient-neovim/wiki/cquery
let s:cquery_settings = {
         \ 'cacheDirectory': '/var/cquery/',
         \ 'emitInactiveRegions': v:true,
         \ 'highlight': { 'enabled' : v:true },
         \ }

let s:cquery_command = ['cquery', '-init=' . json_encode(s:cquery_settings)]

let g:LanguageClient_serverCommands = {
      \ 'c': s:cquery_command,
      \ 'cpp': s:cquery_command,
      \ 'objc': s:cquery_command,
      \ }
