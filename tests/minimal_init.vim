" Minimal Neovim init for headless test runs.
" Usage: nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedDirectory tests/ {sequential=true}"
" Loaded by the parent AND by every spec child (tests/helpers/spec_runner.lua).

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
" Since #261 M5 every spec child loads this init (tests/helpers/spec_runner.lua
" passes it to plenary), so what is set here — `g:` included — reaches specs.
" Before that, children started without it and only the environment carried over;
" code that must know it is under the harness still reads $PARLEY_TEST_MODE
" (#227), which works either way. A spec that needs a different value for
" `g:parley_test_mode` sets it itself (file_tracker_spec, sidecars.lua).
let $PARLEY_TEST_MODE = '1'
" #237: cliproxy's release lookups go to github.com by default. Point them at a
" dead local port so a spec that forgets cliproxy._set_releases_url fails fast
" instead of reaching the network; plenary's child nvims inherit this.
let $PARLEY_CLIPROXY_RELEASES_URL = 'http://127.0.0.1:9/router-for-me/CLIProxyAPI/releases'

" Harness-only guards (#261 M5 review BR-71). Production code carries neither.
"
" 1. Request bodies get a directory per process. Sharing one under the XDG cache
"    let a parallel spec prune or rename another's body, and a body that was not
"    written aborts the query before curl (#261 M1).
" 2. A refusal that reaches a user without words is a defect. `refusal.describe`
"    is pure and says how it resolved; the wrapper below watches for `unkeyed`
"    and fails the spec file through `cquit`, which no pcall seam can swallow.
lua << EOF
local tmp = (vim.env.TMPDIR or "/tmp"):gsub("/$", "")
vim.env.PARLEY_QUERY_DIR = tmp .. "/parley-query-" .. vim.fn.getpid()
vim.fn.mkdir(vim.env.PARLEY_QUERY_DIR, "p")
-- The removal lives beside the creation: `make test` cleans its env, but
-- test-spec, test-changed and a direct PlenaryBustedFile run do not, and one
-- directory per spec process would simply accumulate (#261 M5 review round 4).
local function drop_query_dir()
    pcall(vim.fn.delete, vim.env.PARLEY_QUERY_DIR, "rf")
end
vim.api.nvim_create_autocmd("VimLeavePre", { callback = drop_query_dir })

-- Every harness Neovim — the `make` parent and every plenary spec child — loads
-- this file, so one call here covers both (#220). It exits with os.exit, which
-- skips VimLeavePre, so the query dir's removal is handed to it as well: one
-- definition, two triggers.
require("tests.helpers.exit_with_parent").install(nil, drop_query_dir)

-- A spec that exercises a wordless token on purpose names it in
-- g:parley_expected_unkeyed, at file scope: nothing to restore, and the
-- exemption is visible where the case lives.
local refusal = require("parley.refusal")
local describe, wordless = refusal.describe, {}
refusal.describe = function(kind, outcome, failure, detail)
    local message, resolution = describe(kind, outcome, failure, detail)
    if resolution == "unkeyed" then
        local token = tostring(failure or outcome)
        if not vim.tbl_contains(vim.g.parley_expected_unkeyed or {}, token) then wordless[token] = true end
    end
    return message, resolution
end
vim.api.nvim_create_autocmd("VimLeavePre", { callback = function()
    local tokens = {}
    for token in pairs(wordless) do tokens[#tokens + 1] = token end
    if #tokens == 0 then return end
    table.sort(tokens)
    io.stderr:write("\nrefusal: these reached a user with no words: " .. table.concat(tokens, ", ")
        .. "\nadd a row to TOKENS or INTERNAL in lua/parley/refusal.lua\n")
    vim.cmd("cquit 1")
end })
EOF

" Preserve ordinary per-file deadlines; the scoped runner extends only the
" real 50k-row conformance corpora, including mapped make runs.
command! -nargs=1 -complete=file PlenaryBustedFile
      \ lua require('tests.helpers.spec_runner').run([[<args>]])
