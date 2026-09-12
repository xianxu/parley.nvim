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

" Hermetic test runtime: keep every scratch write out of the repo tree — see
" atlas/infra/test_harness.md for why (#202). $TMPDIR is the harness scratch
" root, which Makefile.parley places outside $(CURDIR).
set noswapfile
execute 'set directory=' . fnameescape(empty($TMPDIR) ? '/tmp' : $TMPDIR) . '//'
let g:parley_test_mode = v:true
" PlenaryBustedFile runs each spec in a child nvim started WITHOUT this init,
" so g: variables set here never reach a spec; the environment does. Code that
" must know it is under the harness reads $PARLEY_TEST_MODE (#227).
let $PARLEY_TEST_MODE = '1'
" #237: cliproxy's release lookups go to github.com by default. Point them at a
" dead local port so a spec that forgets cliproxy._set_releases_url fails fast
" instead of reaching the network; plenary's child nvims inherit this.
let $PARLEY_CLIPROXY_RELEASES_URL = 'http://127.0.0.1:9/router-for-me/CLIProxyAPI/releases'
