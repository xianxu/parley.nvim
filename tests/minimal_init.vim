" Minimal Neovim init for headless test runs.
" Usage: nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedDirectory tests/ {sequential=true}"

set nocompatible

" Add parley.nvim root to runtimepath so require("parley") resolves
set rtp+=.

" Add plenary (installed via lazy.nvim)
set rtp+=~/.local/share/nvim/lazy/plenary.nvim

" Load plenary plugin so PlenaryBusted* commands are registered
runtime plugin/plenary.vim
