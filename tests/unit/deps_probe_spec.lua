local cliproxy = require('parley.cliproxy')
local parley = require('parley')
local uv = vim.uv or vim.loop

describe('read-only dependency observations', function()
    local root, saved_path, saved_config, saved_system
    local function executable(path)
        vim.fn.mkdir(vim.fs.dirname(path), 'p')
        vim.fn.writefile({'#!/bin/sh', 'exit 99'}, path)
        assert.is_truthy(uv.fs_chmod(path, 493))
    end
    before_each(function()
        root = vim.fn.tempname()
        saved_path, saved_config, saved_system = vim.env.PATH, parley.config, vim.system
        vim.env.PATH = root .. '/path'
        parley.config = {cliproxy = {}}
        cliproxy._set_data_dir(root .. '/managed')
        vim.system = function() error('observation must not run a process') end
    end)
    after_each(function()
        vim.env.PATH, parley.config, vim.system = saved_path, saved_config, saved_system
        cliproxy._set_data_dir(nil)
        vim.fn.delete(root, 'rf')
    end)
    it('does not create a directory when reading absent managed state', function()
        assert.is_nil(cliproxy.managed_binary())
        assert.is_nil(cliproxy.installed_version())
        local path, source = cliproxy.discover_binary()
        assert.is_nil(path)
        assert.equals('none', source)
        assert.is_nil(uv.fs_stat(root))
    end)
    it('observes installation and removal without executing the binary', function()
        local probe = require('parley.deps_probe')
        local entry = require('parley.deps').get('ripgrep')
        local host = {sysname='Linux', manager='apt'}
        assert.is_false(probe.observe(entry, host).present)
        executable(root .. '/path/rg')
        local observed = probe.observe(entry, host)
        assert.is_true(observed.present)
        assert.equals('PATH', observed.source)
        vim.fn.delete(root .. '/path/rg')
        assert.is_false(probe.observe(entry, host).present)
        assert.is_false(probe.observe(require('parley.deps').get('sips'), host).applicable)
    end)
    it('attributes version only to the selected managed binary', function()
        local probe = require('parley.deps_probe')
        local entry = require('parley.deps').get('cliproxyapi')
        local host = {sysname='Darwin', manager='brew'}
        executable(root .. '/path/cliproxyapi')
        executable(root .. '/managed/bin/cli-proxy-api')
        vim.fn.writefile({'9.9.9'}, root .. '/managed/bin/cli-proxy-api.version')
        executable(root .. '/custom')
        parley.config.cliproxy.binary_path = root .. '/custom'
        local selected = probe.observe(entry, host)
        assert.equals('binary_path', selected.source)
        assert.is_nil(selected.version)
        parley.config.cliproxy.binary_path = nil
        selected = probe.observe(entry, host)
        assert.equals('managed', selected.source)
        assert.equals('9.9.9', selected.version)
        vim.fn.writefile({'untrusted record'}, root .. '/managed/bin/cli-proxy-api.version')
        assert.is_nil(probe.observe(entry, host).version)
        vim.fn.writefile({'9.9.9'}, root .. '/managed/bin/cli-proxy-api.version')
        vim.fn.delete(root .. '/managed/bin/cli-proxy-api')
        selected = probe.observe(entry, host)
        assert.equals('PATH', selected.source)
        assert.is_nil(selected.version)
    end)
    it('detects a package manager locally without invoking it', function()
        local probe = require('parley.deps_probe')
        local uname = uv.os_uname
        local ok, err = pcall(function()
            uv.os_uname = function() return {sysname='Linux'} end
            assert.is_nil(probe.host().manager)
            executable(root .. '/path/apt')
            assert.equals('apt', probe.host().manager)
            uv.os_uname = function() return {sysname='Darwin'} end
            assert.is_nil(probe.host().manager)
            executable(root .. '/path/brew')
            assert.equals('brew', probe.host().manager)
            uv.os_uname = function() return {sysname='FreeBSD'} end
            assert.is_nil(probe.host().manager)
        end)
        uv.os_uname = uname
        assert.is_true(ok, err)
    end)
end)
