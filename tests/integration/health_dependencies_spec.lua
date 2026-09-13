local uv = vim.uv or vim.loop
local parley = require('parley')
local cliproxy = require('parley.cliproxy')
local health = require('parley.health')

describe('dependency health', function()
    local root, saved, reports
    local function executable(name)
        local path = root .. '/path/' .. name
        vim.fn.mkdir(vim.fs.dirname(path), 'p')
        vim.fn.writefile({'#!/bin/sh', 'exit 99'}, path)
        uv.fs_chmod(path, 493)
    end
    local function report(fragment)
        for _, row in ipairs(reports) do
            if row.message:find(fragment, 1, true) then return row end
        end
        error('missing diagnostic: ' .. fragment .. '\n' .. vim.inspect(reports))
    end
    before_each(function()
        root = vim.fn.tempname()
        saved = {path=vim.env.PATH, config=parley.config, setup=parley._setup_called,
            health=vim.health, system=vim.system, uname=uv.os_uname,
            fn_system=vim.fn.system, fn_systemlist=vim.fn.systemlist, jobstart=vim.fn.jobstart}
        reports = {}
        vim.health = {}
        for _, level in ipairs({'start', 'ok', 'warn', 'error', 'info'}) do
            vim.health[level] = function(message) reports[#reports+1] = {level=level, message=message} end
        end
        local function forbidden() error('health must not spawn processes') end
        vim.system, vim.fn.system, vim.fn.systemlist, vim.fn.jobstart = forbidden, forbidden, forbidden, forbidden
        vim.env.PATH = root .. '/path'
        uv.os_uname = function() return {sysname='Linux'} end
        parley.config, parley._setup_called = nil, false
        cliproxy._set_data_dir(root .. '/managed')
    end)
    after_each(function()
        vim.env.PATH, parley.config, parley._setup_called = saved.path, saved.config, saved.setup
        vim.health, vim.system, uv.os_uname = saved.health, saved.system, saved.uname
        vim.fn.system, vim.fn.systemlist, vim.fn.jobstart = saved.fn_system, saved.fn_systemlist, saved.jobstart
        cliproxy._set_data_dir(nil)
        vim.fn.delete(root, 'rf')
    end)
    it('reports every dependency without setup, writes or subprocesses', function()
        health.check()
        assert.equals('error', report('setup() has not been called').level)
        for _, entry in ipairs(require('parley.deps').entries) do
            local row = report(entry.id .. ' [')
            assert.is_truthy(row.message:find(entry.tier, 1, true))
            assert.is_truthy(row.message:find(entry.feature, 1, true))
        end
        assert.equals('error', report('curl [').level)
        assert.equals('warn', report('ripgrep [').level)
        assert.equals('info', report('osascript [').level)
        assert.equals('info', report('sips [').level)
        assert.is_truthy(report('cliproxyapi [').message:find(':ParleyProxy update', 1, true))
        assert.is_nil(uv.fs_stat(root))
    end)
    it('refreshes detection and provides advice only for the actual manager', function()
        executable('apt')
        health.check()
        assert.is_truthy(report('ripgrep [').message:find('apt install ripgrep', 1, true))
        executable('rg')
        executable('curl')
        reports = {}
        health.check()
        assert.equals('ok', report('ripgrep [').level)
        assert.equals('ok', report('curl [').level)
        assert.is_nil(uv.fs_stat(root .. '/managed'))
        uv.os_uname = function() return {sysname='FreeBSD'} end
        reports = {}
        health.check()
        for _, row in ipairs(reports) do
            assert.is_nil(row.message:find('apt install', 1, true))
            assert.is_nil(row.message:find('brew install', 1, true))
        end
    end)
    it('shows the selected managed source and recorded version', function()
        vim.fn.mkdir(root .. '/managed/bin', 'p')
        local bin = root .. '/managed/bin/cli-proxy-api'
        vim.fn.writefile({'#!/bin/sh', 'exit 99'}, bin)
        uv.fs_chmod(bin, 493)
        vim.fn.writefile({'9.9.9'}, bin .. '.version')
        health.check()
        local row = report('cliproxyapi [')
        assert.equals('ok', row.level)
        assert.is_truthy(row.message:find('source: managed', 1, true))
        assert.is_truthy(row.message:find('version: 9.9.9', 1, true))
    end)
end)
