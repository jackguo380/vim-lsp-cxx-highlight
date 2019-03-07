" Default syntax
" Customizing:
" to change the highlighting of a group add this to your vimrc.
"
" E.g. Change Preprocessor skipped regions to red bold text
" hi LspCxxHlSkippedRegion cterm=Red guifg=#FF0000 cterm=bold gui=bold
"
" E.g. Change Variables to be highlighted as Identifiers
" hi link LspCxxHlSymVariable Identifier


" Preprocessor Skipped Regions:
"
" This is used for false branches of #if or other preprocessor conditions
hi default link LspCxxHlSkippedRegion Comment

" This is the first and last line of the preprocessor regions
" in most cases this contains the #if/#else/#endif statements
" so it is better to let syntax do the highlighting.
hi default link LspCxxHlSkippedRegionBeginEnd Normal


" Syntax Highlighting:
"
" Highlight Resolution Rules:
" The way cquery and ccls provide highlighting can result in a huge number
" of highlight groups if we mapped every single one out.
"
" To avoid that here are rules on what highlight group gets used.
"
" Format:
" LspCxxHlSym[<ParentKind>]<Kind>[<StorageClass>]
" 
" ParentKind   - the enclosing symbol kind
" Kind         - the symbol kind
" StorageClass - any storage specifiers
"                (None, Extern, Static, PrivateExtern, Auto, Register)
"
" About Kind and ParentKind
" Kind and ParentKind are the same as the language server specification 
" for SymbolKind. E.g. File, Constructor, Enum, etc...
" See https://microsoft.github.io/language-server-protocol/specification#textDocument_documentSymbol
" 
" cquery and ccls also add custom values:
" TypeAlias - custom types from typedef
" Parameter - function parameter
" StaticMethod - static methods
" Macro - macros and function like macros
"
" Examples
"
" LspCxxHlSymClassMethod - a method in a class
" LspCxxHlSymStructMethod - a method in a struct
" LspCxxHlSymVariableStatic - a static variable
"
" Resolution Rules:
" The highlight groups will be tried in this order:
" 1. Full match: 
"    LspCxxHlSym<ParentKind><Kind><StorageClass>
"
" 2. Full match minus StorageClass
"    LspCxxHlSym<ParentKind><Kind>
" 
" 3. Partial match
"    LspCxxHlSym<Kind><StorageClass>
"
" 4. Partial match minus Storage Class
"    LspCxxHlSym<Kind>
"
" The first one to match will be used

" Custom Highlight Groups
hi default LspCxxHlGroupEnumConstant ctermfg=Magenta guifg=#AD7FA8 cterm=none gui=none
hi default LspCxxHlGroupNamespace ctermfg=Yellow guifg=#BBBB00 cterm=none gui=none
hi default LspCxxHlGroupMemberVariable ctermfg=White guifg=White

hi default link LspCxxHlSymUnknown Normal

" Type
hi default link LspCxxHlSymClass Type
hi default link LspCxxHlSymStruct Type
hi default link LspCxxHlSymEnum Type
hi default link LspCxxHlSymTypeAlias Type
hi default link LspCxxHlSymTypeParameter Type

" Function
hi default link LspCxxHlSymFunction Function
hi default link LspCxxHlSymMethod Function
hi default link LspCxxHlSymStaticMethod Function
hi default link LspCxxHlSymConstructor Function

" EnumConstant
hi default link LspCxxHlSymEnumMember LspCxxHlGroupEnumConstant

" Preprocessor
hi default link LspCxxHlSymMacro Macro

" Namespace
hi default link LspCxxHlSymNamespace LspCxxHlGroupNamespace

" Variables
hi default link LspCxxHlSymVariable Normal
hi default link LspCxxHlSymParameter Normal
hi default link LspCxxHlSymField LspCxxHlGroupMemberVariable
