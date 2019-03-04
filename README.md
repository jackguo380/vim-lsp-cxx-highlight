# vim-lsp-cxx-highlight

vim-lsp-cxx-highlight is a vim plugin that provides C/C++/ObjC semantic highlighting
using the language server protocol.

Currently the plugin supports the following language server extensions:

**[cquery](www.github.com/cquery-project/cquery)**

- `$cquery/publishSemanticHighlighting` - semantic highlighting
- `$cquery/setInactiveRegions` - preprocessor skipped regions

**[ccls](www.github.com/MaskRay/ccls)**
 
- `$ccls/publishSemanticHighlight` - semantic highlighting
- `$ccls/publishSkippedRegions` - preprocessor skipped regions

Note that this plugin on its own does nothing, a language server client is required.

Currently this plugin only supports:

**[vim-lsp](www.github.com/prabirshrestha/vim-lsp)**


## Install

[vim-plug](www.github.com/junegunn/vim-plug)

```vim
Plug 'prabirshrestha/vim-lsp'
Plug 'jackguo380/vim-lsp-cxx-highlight'
```
