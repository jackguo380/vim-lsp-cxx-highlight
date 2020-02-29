" ccls
lua <<EOF
require'nvim_lsp'.ccls.setup{
  init_options = {
    highlight = {
      lsRanges = true;
    }
  }
}
EOF

" cquery is not supported in nvim-lsp
