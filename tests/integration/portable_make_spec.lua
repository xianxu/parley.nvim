describe('portable test dependency configuration', function()
    it('shows product test commands without a maintainer overlay', function()
        local result = vim.system({'make','--no-print-directory','WF_WORKFLOW=','help'}, {text=true}):wait()
        assert.equals(0,result.code,result.stdout..result.stderr)
        for _, command in ipairs({'make test ', 'make check-fresh-clone', 'make check-vocabulary'}) do
            assert.is_truthy(result.stdout:find(command,1,true),result.stdout)
        end
    end)
    it('rejects a missing Plenary dependency with actionable advice', function()
        local result = vim.system({'make','--no-print-directory','-f','Makefile.parley',
            'check-test-deps','PLENARY='..vim.fn.tempname()}, {text=true}):wait()
        assert.is_not.equals(0,result.code)
        assert.matches('PLENARY',result.stdout..result.stderr)
        assert.matches('plenary.nvim',result.stdout..result.stderr)
    end)
    it('accepts an explicit dependency outside the default profile', function()
        local dependency = assert(vim.env.NVIM_TEST_PLENARY)
        local result = vim.system({'make','--no-print-directory','-f','Makefile.parley',
            'check-test-deps','PLENARY='..dependency}, {text=true}):wait()
        assert.equals(0,result.code,result.stdout..result.stderr)
        local dry = vim.system({'make','--no-print-directory','-n','-f','Makefile.parley',
            'test-unit','PLENARY='..dependency}, {text=true}):wait()
        assert.equals(0,dry.code,dry.stdout..dry.stderr)
        assert.is_not_nil(dry.stdout:find('NVIM_TEST_PLENARY="'..dependency..'"',1,true))
    end)
end)
