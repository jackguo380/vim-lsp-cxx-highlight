# vim-lsp-cxx-highlight

vim-lsp-cxx-highlight is a vim plugin that provides C/C++/ObjC semantic highlighting
using the language server protocol.

## Introduction

**Motivation**

So why another semantic highlighting plugin when 
[color_coded](https://github.com/jeaye/color_coded) and
[chromatica](https://github.com/arakashic/chromatica.nvim) exist? 

The idea for this plugin came from seeing [vscode-cquery](https://github.com/cquery-project/vscode-cquery)
and seeing how cquery/ccls can provide semantic highlighting data.

Some advantages of this plugin would be:
- Reuse cquery/ccls highlight data, no need to re-analyze the source file wasting CPU cycles.
- No external dependencies (other than the language server) such as python or vim compiled with `+lua`.
- cquery/ccls sanitizes libclang's AST data leading to more consistent highlighting.

## Requirements

The plugin requires `vim` or `neovim`. For `vim` `+timers` and `+byte_offset` are
recommended but not required.

Additionally a compatible language server and language server client is required.

The following language servers and protocol extensions are supported:

- **[cquery](https://www.github.com/cquery-project/cquery)**

 - `$cquery/publishSemanticHighlighting` - semantic highlighting
 - `$cquery/setInactiveRegions` - preprocessor skipped regions

- **[ccls](https://www.github.com/MaskRay/ccls)**
 
 - `$ccls/publishSemanticHighlight` - semantic highlighting
 - `$ccls/publishSkippedRegions` - preprocessor skipped regions

The following language server clients are supported:

- **[vim-lsp](https://www.github.com/prabirshrestha/vim-lsp)**
- (PRs would be appreciated!)

## Install

Using [vim-plug](https://www.github.com/junegunn/vim-plug)

```vim
Plug 'prabirshrestha/vim-lsp'
Plug 'jackguo380/vim-lsp-cxx-highlight'
```

For `cquery` the following initializationOptions are needed:
```json
{
    "highlight": { "enabled" : true },
    "emitInactiveRegions" : true
}
```

For `ccls` if your `vim` does _not_ have `+byte_offset` this initializationOption is needed:
```json
{
    "highlight": { "lsRanges" : true }
}
```

For a sample vim-lsp configuration see [this](sample-vimrcs/vim-lsp-register.vimrc)

## Configuration

The plugin should work without any additional configuration. But if you don't like
the default settings here are some settings.

### Settings

