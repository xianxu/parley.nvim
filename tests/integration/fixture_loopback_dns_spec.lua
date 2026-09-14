local repository = vim.fn.getcwd()
describe('loopback HTTP fixtures without reverse DNS', function()
    local root, process
    before_each(function()
        root = vim.fn.tempname()
        vim.fn.mkdir(root, 'p')
    end)
    after_each(function()
        if process then process:kill(15); process:wait(2000); process = nil end
        vim.fn.delete(root, 'rf')
    end)
    for _, mode in ipairs({'fail', 'hang'}) do
        for _, fixture in ipairs({'fake_github_releases', 'fake_cliproxy', 'fake_sse_server'}) do
            it(fixture .. ' serves HTTP while reverse DNS would ' .. mode, function()
                local args = {'python3', repository .. '/tests/fixtures/run_without_dns.py',
                    root .. '/ready', mode, repository .. '/tests/fixtures/' .. fixture}
                if fixture == 'fake_github_releases' then
                    vim.list_extend(args, {'--port', '0', '--root', root})
                elseif fixture == 'fake_sse_server' then
                    vim.list_extend(args, {'unauthorized', root .. '/sse-ready'})
                else
                    vim.list_extend(args, {'--port', '0'})
                end
                process = vim.system(args, {text = true})
                assert.is_true(vim.wait(3000, function()
                    return vim.fn.filereadable(root .. '/ready') == 1
                end, 10), 'fixture exceeded its 3-second readiness deadline')
                local port = assert(tonumber(vim.fn.readfile(root .. '/ready')[1]))
                local route = fixture == 'fake_github_releases' and '/router-for-me/CLIProxyAPI/releases/tag/v1'
                    or '/v1/models'
                local request = {'curl', '--noproxy', '*', '--silent', '--show-error', '--max-time', '2'}
                if fixture == 'fake_sse_server' then vim.list_extend(request, {'-X', 'POST'}) end
                request[#request + 1] = 'http://127.0.0.1:' .. port .. route
                local result = vim.system(request, {text = true}):wait(2500)
                assert.equals(0, result.code, result.stderr)
                assert.is_true(#result.stdout > 0, 'fixture returned no HTTP body')
                if fixture == 'fake_cliproxy' then
                    assert.equals('list', vim.json.decode(result.stdout).object)
                elseif fixture == 'fake_sse_server' then
                    assert.equals('fixture unauthorized', vim.json.decode(result.stdout).error)
                else
                    assert.equals('<html>release</html>', result.stdout)
                end
            end)
        end
    end
end)
