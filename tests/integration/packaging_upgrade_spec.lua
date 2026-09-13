local root = vim.fn.getcwd()
local uv = vim.uv or vim.loop
local function write(path, lines)
    vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
    vim.fn.writefile(lines, path)
end

describe('disposable guest package upgrade', function()
    local scratch, env
    before_each(function()
        scratch = vim.fn.tempname() .. ' spaced'
        write(scratch .. '/brew/state.json', { vim.json.encode({
            public_linked = true, installed = false, tap = false, commands = {}, versions = {},
        }) })
        write(scratch .. '/brew/public-parley', { '#!/bin/sh',
            'export PARLEY_RUNTIME=' .. vim.fn.shellescape(scratch .. '/public/libexec'),
            'export PARLEY_STARTER=' .. vim.fn.shellescape(scratch .. '/public/share/parley/config/init.lua'),
            'export PARLEY_NVIM=' .. vim.fn.shellescape(vim.v.progpath),
            'exec "$PARLEY_RUNTIME/packaging/parley" "$@"' })
        assert(uv.fs_chmod(scratch .. '/brew/public-parley', 448))
        vim.fn.mkdir(scratch .. '/brew/prefix/bin', 'p')
        assert(uv.fs_symlink(scratch .. '/brew/public-parley', scratch .. '/brew/prefix/bin/parley'))
        vim.fn.mkdir(scratch .. '/bin', 'p')
        assert(uv.fs_symlink(root .. '/tests/fixtures/fake_packaging_upgrade_brew', scratch .. '/bin/brew'))
        for _, path in ipairs({ 'packaging/formula.lua', 'packaging/parley', 'packaging/launcher.lua',
            'lua/parley/deps.lua', 'lua/parley/fs.lua' }) do
            write(scratch .. '/public/libexec/' .. path, vim.fn.readfile(root .. '/' .. path))
        end
        assert(uv.fs_chmod(scratch .. '/public/libexec/packaging/parley', 493))
        write(scratch .. '/public/share/parley/config/init.lua',
            vim.fn.readfile(root .. '/packaging/starter-config/init.lua'))
        write(scratch .. '/config/parley/init.lua', { '-- operator settings' })
        write(scratch .. '/config/nvim/init.lua', { 'error("decoy must never load")' })
        env = { HOME = scratch .. '/home', XDG_CONFIG_HOME = scratch .. '/config',
            XDG_DATA_HOME = scratch .. '/data', XDG_STATE_HOME = scratch .. '/state',
            XDG_CACHE_HOME = scratch .. '/cache', TMPDIR = scratch,
            PATH = scratch .. '/bin:' .. vim.env.PATH, FAKE_UPGRADE_BREW = scratch .. '/brew',
            FAKE_UPGRADE_NVIM = vim.v.progpath }
    end)
    after_each(function() vim.fn.delete(scratch, 'rf') end)
    local function run(extra)
        return vim.system({ 'sh', root .. '/scripts/test-parley-upgrade.sh', scratch .. '/public/libexec', scratch .. '/report' }, {
            clear_env = true, text = true, env = vim.tbl_extend('force', env, extra or {}),
        }):wait(30000)
    end
    local function state()
        return vim.json.decode(table.concat(vim.fn.readfile(scratch .. '/brew/state.json'), '\n'))
    end
    it('upgrades two packages, preserves settings and decoy, then restores public parley', function()
        assert.equals(0, vim.fn.filereadable(scratch .. '/public/libexec/packaging/starter-config/init.lua'))
        local result = run()
        assert.equals(0, result.code, result.stderr)
        local final = state()
        assert.is_true(final.public_linked)
        assert.is_false(final.installed)
        assert.is_false(final.tap)
        assert.same({ 'parley-upgrade-fixture-0.0.1.tar.gz', 'parley-upgrade-fixture-0.0.2.tar.gz' }, final.versions)
        assert.same({ '-- operator settings' }, vim.fn.readfile(scratch .. '/config/parley/init.lua'))
        assert.same({ 'error("decoy must never load")' }, vim.fn.readfile(scratch .. '/config/nvim/init.lua'))
        local report = vim.json.decode(table.concat(vim.fn.readfile(scratch .. '/report/upgrade.json'), '\n'))
        assert.equals('passed', report.status)
        assert.is_true(report.public_restored)
        local starter = table.concat(vim.fn.readfile(scratch .. '/public/share/parley/config/init.lua'), '\n') .. '\n'
        assert.equals(vim.fn.sha256(starter .. '\n-- acceptance fixture B\n'), report.candidate_b_sha256)
        assert.equals(0, vim.fn.filereadable(scratch .. '/public/libexec/packaging/starter-config/init.lua'))
    end)
    it('restores public parley and removes only its fixture on upgrade failure', function()
        local result = run({ FAKE_UPGRADE_FAIL = 'upgrade' })
        assert.is_not.equals(0, result.code)
        assert.is_truthy(result.stderr:find('brew upgrade failed (42)', 1, true))
        local final = state()
        assert.is_true(final.public_linked)
        assert.is_false(final.installed)
        assert.is_false(final.tap)
        assert.equals(0, vim.fn.filereadable(scratch .. '/report/upgrade.json'))
        assert.same({ '-- operator settings' }, vim.fn.readfile(scratch .. '/config/parley/init.lua'))
    end)
    it('refuses to adopt existing fixture work or taps', function()
        write(scratch .. '/report/upgrade-fixture/keep', { 'another run' })
        assert.is_not.equals(0, run().code)
        assert.same({ 'another run' }, vim.fn.readfile(scratch .. '/report/upgrade-fixture/keep'))
        assert.equals(0, #state().commands)
        vim.fn.delete(scratch .. '/report/upgrade-fixture', 'rf')
        write(scratch .. '/brew/tap/keep', { 'another tap' })
        assert.is_not.equals(0, run().code)
        assert.same({ 'another tap' }, vim.fn.readfile(scratch .. '/brew/tap/keep'))
        assert.is_true(state().public_linked)
        assert.equals(0, vim.fn.filereadable(scratch .. '/report/upgrade.json'))
    end)

end)
