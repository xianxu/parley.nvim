-- Most specs retain Plenary's default deadline. These real 50,000-row
-- conformance corpora need extra bootstrap time under parallel CI load.
local M={}
local function absolute(path)
    return vim.fn.resolve(vim.fn.fnamemodify(path,':p'))
end
local extended={
    [absolute('tests/integration/document_fold_batches_spec.lua')]=true,
    [absolute('tests/unit/document_semantic_spec.lua')]=true,
}
function M.options(path)
    if extended[absolute(path)] then return {timeout=180000,sequential=true} end
end
function M.run(path)
    local harness=require('plenary.test_harness')
    local options=M.options(path)
    if options then return harness.test_directory(path,options) end
    return harness.test_file(path)
end
return M
