---
name: Bug report
about: File a Bug
title: ''
labels: ''
assignees: ''

---

**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:

**Expected behavior**
A clear and concise description of what you expected to happen.

**Screenshots**
If applicable, add screenshots to help explain your problem.

**Configuration (Fill this out):**
 - Vim or Neovim + Version
 - Which Lsp Client is being used and Lsp Client Version
 - Parts of your `vimrc` or `init.vim` that you think are relevant to vim-lsp-cxx-highlight

**Log File:**
Enable logging by adding these lines:
```vim
let g:lsp_cxx_hl_log_file = '/tmp/lsp-cxx-hl.log'
let g:lsp_cxx_hl_verbose_log = 1
```
Then post the contents of the log file:

```vim
<Log File Contents>
```

**Additional context**
Add any other context about the problem here.
