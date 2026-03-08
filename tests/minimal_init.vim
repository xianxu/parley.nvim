" Minimal Neovim init for headless test runs.
" Usage: nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedDirectory tests/ {sequential=true}"

set nocompatible

" Add parley.nvim root to runtimepath so require("parley") resolves
set rtp+=.

" Add plenary (installed via lazy.nvim)
if exists('$NVIM_TEST_PLENARY') && !empty($NVIM_TEST_PLENARY)
  execute 'set rtp+=' . fnameescape($NVIM_TEST_PLENARY)
else
  set rtp+=~/.local/share/nvim/lazy/plenary.nvim
endif

" Load plenary plugin so PlenaryBusted* commands are registered
runtime plugin/plenary.vim

" Hermetic test runtime: avoid swap/temp writes outside workspace
set noswapfile
set directory=.test-tmp//
let g:parley_test_mode = v:true
