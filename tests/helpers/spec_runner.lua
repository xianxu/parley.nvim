-- Most specs retain Plenary's default deadline. These real 50,000-row
-- conformance corpora need extra bootstrap time under parallel CI load.
local M={}
local function absolute(path)
    return vim.fn.resolve(vim.fn.fnamemodify(path,':p'))
end
local extended={
    [absolute('tests/integration/document_fold_batches_spec.lua')]=true,
    [absolute('tests/unit/document_semantic_spec.lua')]=true,
    [absolute('tests/integration/document_fold_retirement_spec.lua')]=true,
    [absolute('tests/integration/document_fold_uncertainty_retirement_spec.lua')]=true,
}
function M.options(path)
    if extended[absolute(path)] then return {timeout=180000,sequential=true} end
end
-- Every child loads tests/minimal_init.vim, so the harness-only guards there
-- (a per-process query dir, the wordless-refusal watch) cover every spec rather
-- than the ones that remember to ask (#261 M5 review BR-71).
local INIT='tests/minimal_init.vim'
-- A deadline is a hang check, sized for a quiet machine. Other sessions' suites
-- share this one (#294 run 3: load average 72-105 on 12 cores), and there a
-- quiet-machine deadline kills specs that are only waiting their turn for a
-- CPU. So it stretches by how oversubscribed the machine is when the spec
-- starts, and stops stretching at LOAD_CAP so a real hang still ends.
local DEFAULT_TIMEOUT=50000 -- plenary.test_harness's own default
local LOAD_CAP=4
function M.load_factor(load1,ncpu)
    return math.min(LOAD_CAP,math.max(1,load1/math.max(1,ncpu)))
end
-- Plenary kills a child at its deadline without a word, so a deadline kill read
-- as a failure with no assertion output (#294). The parent waits in vim.wait,
-- where timers run; one at the deadline names the cause.
function M.run(path)
    local harness=require('plenary.test_harness')
    if vim.env.PARLEY_TEST_JITSTAT=='1' then require('tests.helpers.jit_watch').silence() end
    local opts=vim.tbl_extend('force',{minimal_init=INIT,timeout=DEFAULT_TIMEOUT},M.options(path) or {})
    local base,load1,ncpu=opts.timeout,vim.uv.loadavg(),vim.uv.available_parallelism()
    local factor=M.load_factor(load1,ncpu)
    opts.timeout=math.floor(base*factor)
    vim.defer_fn(function()
        io.stdout:write(('DEADLINE: %s still running at its %ds deadline (%ds x%.1f for load %.0f on %d CPUs); killed\n')
            :format(path,opts.timeout/1000,base/1000,factor,load1,ncpu))
    end,opts.timeout)
    return harness.test_directory(path,opts)
end
return M
