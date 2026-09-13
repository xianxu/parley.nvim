local root = vim.fn.getcwd()
local script = root .. '/scripts/check-fresh-clone.sh'

local function run(args)
    local scratch = vim.fn.tempname() .. '-archive-check'
    vim.fn.mkdir(scratch, 'p')
    local command = { 'sh', script }
    vim.list_extend(command, args)
    local result = vim.system(command, { text = true, env = { TMPDIR = scratch } }):wait(120000)
    local leftovers = vim.fn.glob(scratch .. '/parley-fresh-clone.*', false, true)
    vim.fn.delete(scratch, 'rf')
    assert.equals(0, #leftovers, 'script must clean scratch on success and failure')
    return result
end

describe('standalone tracked archive', function()
    it('loads and creates chats with intact and unavailable optional vocabulary', function()
        local result = run({ '--runtime', '--worktree' })
        assert.equals(0, result.code, (result.stdout or '') .. (result.stderr or ''))
        for _, variant in ipairs({ 'intact', 'missing', 'corrupt', 'malformed' }) do
            assert.is_truthy(result.stdout:find('PASS ' .. variant, 1, true), result.stdout)
        end
    end)

    it('rejects an escaping archive symlink before loading plugin code', function()
        local dir = vim.fn.tempname() .. '-escaping archive'
        vim.fn.mkdir(dir, 'p')
        assert((vim.uv or vim.loop).fs_symlink('../outside', dir .. '/escape'))
        local result = run({ '--guard', dir })
        vim.fn.delete(dir, 'rf')
        assert.is_not.equals(0, result.code)
        assert.is_truthy((result.stderr .. result.stdout):find('escaping symlink', 1, true))
    end)

    it('accepts a self-contained archive symlink', function()
        local dir = vim.fn.tempname() .. '-internal archive'
        vim.fn.mkdir(dir, 'p')
        vim.fn.writefile({ 'local file' }, dir .. '/target')
        assert((vim.uv or vim.loop).fs_symlink('target', dir .. '/local-link'))
        local result = run({ '--guard', dir })
        vim.fn.delete(dir, 'rf')
        assert.equals(0, result.code, result.stderr .. result.stdout)
    end)
end)
