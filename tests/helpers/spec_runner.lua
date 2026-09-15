-- Most specs retain Plenary's default deadline. This real 50,010-row native
-- conformance fixture needs extra bootstrap time under parallel CI load.
local M={}
local function absolute(path)
    return vim.fn.resolve(vim.fn.fnamemodify(path,':p'))
end
local extended=absolute('tests/integration/document_fold_batches_spec.lua')
function M.options(path)
    if absolute(path)==extended then return {timeout=180000,sequential=true} end
end
function M.run(path)
    local harness=require('plenary.test_harness')
    local options=M.options(path)
    if options then return harness.test_directory(path,options) end
    return harness.test_file(path)
end
return M
