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

" Hermetic test runtime: keep every scratch write out of the repo tree. The
" suite traverses the repo (find/grep/ack tool specs) while eight parallel jobs
" run, so a swap file landing in-tree can vanish mid-traversal (#202). $TMPDIR
" is the harness scratch root, which Makefile.parley places outside $(CURDIR).
set noswapfile
execute 'set directory=' . fnameescape(empty($TMPDIR) ? '/tmp' : $TMPDIR) . '//'
let g:parley_test_mode = v:true
