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
function M.run(path)
    local harness=require('plenary.test_harness')
    return harness.test_directory(path,vim.tbl_extend('force',{minimal_init=INIT},M.options(path) or {}))
end
return M
