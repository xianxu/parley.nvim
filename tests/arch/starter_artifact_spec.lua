describe('portable starter artifact', function()
    local scanner = vim.fn.getcwd() .. '/scripts/check-starter.py'
    it('accepts the shipped artifact and rejects planted personal markers', function()
        local actual = vim.system({ 'python3', scanner }, { text = true }):wait()
        assert.equals(0, actual.code, actual.stderr)
        local fixture = vim.fn.tempname()
        for _, marker in ipairs({ '/Users/person/private', 'Mobile Documents', '~/blogs',
            'OPENAI_API_KEY', 'require("core.options")', 'person@example.com',
            '~/notes', '~/workspace/ariadne', 'require("ariadne")', 'require[[ariadne]]' }) do
            vim.fn.writefile({ marker }, fixture)
            local result = vim.system({ 'python3', scanner, fixture }, { text = true }):wait()
            assert.equals(1, result.code, marker)
        end
        vim.fn.delete(fixture)
    end)
end)
