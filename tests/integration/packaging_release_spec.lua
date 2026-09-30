local repo = vim.fn.getcwd()
local scratch
local function run(argv, cwd)
    local result = vim.system(argv, { cwd = cwd or scratch, text = true }):wait()
    assert.are.equal(0, result.code, result.stderr)
    return vim.trim(result.stdout)
end
local function write(path, lines)
    vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
    vim.fn.writefile(lines, path)
end
local function release(publish)
    local argv = { 'sh', repo .. '/scripts/release-parley.sh', 'v2.3.0', scratch .. '/tap' }
    if publish then argv[#argv + 1] = '--publish' end
    return vim.system(argv, { cwd = scratch .. '/source', text = true, env = {
        GIT_CONFIG_GLOBAL = scratch .. '/gitconfig', GIT_CONFIG_NOSYSTEM = '1',
        PACKAGING_ARCHIVES = scratch .. '/archives',
        PACKAGING_VERIFY_LOG = scratch .. '/verification.log', PACKAGING_VERIFY_FAIL = scratch .. '/reject-verification', PATH = scratch .. '/bin:' .. vim.env.PATH,
    } }):wait()
end
describe('immutable Homebrew release workflow', function()
    before_each(function()
        scratch = vim.fn.tempname()
        vim.fn.mkdir(scratch, 'p')
        write(scratch .. '/gitconfig', { '[user]', 'name = Test', 'email = test@example.invalid',
            '[url "' .. scratch .. '/source.git"]', 'insteadOf = https://github.com/xianxu/parley.nvim.git',
            '[url "' .. scratch .. '/tap.git"]', 'insteadOf = https://github.com/xianxu/homebrew-parley.git' })
        for _, name in ipairs({ 'source', 'tap' }) do
            run({ 'git', 'init', '--bare', scratch .. '/' .. name .. '.git' })
            run({ 'git', 'clone', scratch .. '/' .. name .. '.git', scratch .. '/' .. name })
            run({ 'git', 'config', 'user.name', 'Test' }, scratch .. '/' .. name)
            run({ 'git', 'config', 'user.email', 'test@example.invalid' }, scratch .. '/' .. name)
            write(scratch .. '/' .. name .. '/README', { 'fixture' })
        end
        for _, path in ipairs({ 'packaging/formula.lua', 'packaging/render-formula.lua', 'packaging/starter-config/init.lua', 'lua/parley/deps.lua' }) do
            write(scratch .. '/source/' .. path, vim.fn.readfile(repo .. '/' .. path))
        end
        write(scratch .. '/source/lua/parley/editor_dependencies.lua', {
            "local M = {}",
            "function M.plugins() return {{ name = 'archive-editor', repo = 'fixture/editor', commit = string.rep('a', 40), url = 'https://example.invalid/archive-editor.tar.gz', sha256 = string.rep('b', 64), scope = 'app' }} end",
            "function M.artifact(platform) local member = 'preview-' .. platform; return { platform = platform, version = 'v1', url = 'https://example.invalid/' .. member .. '.tar.gz', sha256 = string.rep('c', 64), binary_sha256 = string.rep('d', 64), member = member, output = 'plugins/markdown-preview.nvim/app/bin/' .. member } end",
            "return M",
        })
        write(scratch .. '/source/scripts/editor-dependencies.py', { '# fixture assembler; offline conformance is substituted below' })
        write(scratch .. '/source/scripts/export-editor-dependencies.lua', { '-- fixture exporter' })
        -- Stateful conformance boundary: records the actual extracted tree's
        -- manifest, and can fail on initial publication or on a retry.
        write(scratch .. '/source/scripts/check-editor-bundle.sh', {
            '#!/bin/sh', 'set -eu',
            'cat lua/parley/editor_dependencies.lua >> "$PACKAGING_VERIFY_LOG"',
            '[ ! -f "$PACKAGING_VERIFY_FAIL" ] || { echo "fixture offline conformance failed" >&2; exit 27; }',
        })
        write(scratch .. '/source/packaging/parley', { '#!/bin/sh', 'exit 0' })
        write(scratch .. '/source/packaging/launcher.lua', { '-- fixture profile publisher' })
        -- An archive-only registry default proves rendering does not use the checkout registry.
        local deps = vim.fn.readfile(scratch .. '/source/lua/parley/deps.lua')
        deps = vim.split(table.concat(deps, '\n'):gsub('brew = "ripgrep"', 'brew = "archive-ripgrep"'), '\n')
        write(scratch .. '/source/lua/parley/deps.lua', deps)
        for _, name in ipairs({ 'source', 'tap' }) do
            local cwd = scratch .. '/' .. name
            run({ 'git', 'add', '.' }, cwd)
            run({ 'git', 'commit', '-m', 'fixture' }, cwd)
            run({ 'git', 'push', 'origin', 'HEAD' }, cwd)
            run({ 'git', 'remote', 'set-url', 'origin', 'https://github.com/xianxu/' .. (name == 'source' and 'parley.nvim' or 'homebrew-parley') .. '.git' }, cwd)
        end
        run({ 'git', 'tag', 'v2.3.0' }, scratch .. '/source')
        run({ 'git', 'push', scratch .. '/source.git', 'v2.3.0' }, scratch .. '/source')
        vim.fn.mkdir(scratch .. '/archives', 'p')
        run({ 'git', 'archive', '--format=tar.gz', '--prefix=release/', '--output=' .. scratch .. '/archives/v2.3.0.tar.gz', 'v2.3.0' }, scratch .. '/source')
        vim.fn.mkdir(scratch .. '/bin', 'p')
        assert(vim.uv.fs_symlink(repo .. '/tests/fixtures/fake_packaging_curl', scratch .. '/bin/curl'))
    end)
    after_each(function() vim.fn.delete(scratch, 'rf') end)
    it('renders through the shared entry from another working directory and rejects invalid metadata', function()
        local output = scratch .. '/entry.rb'
        local function entry(tag)
            return vim.system({ vim.v.progpath, '-n', '--headless', '--noplugin', '-u', 'NONE', '-i', 'NONE',
                '-l', repo .. '/packaging/render-formula.lua' }, { cwd = scratch, text = true, env = {
                    PARLEY_RELEASE_TAG = tag, PARLEY_RELEASE_SHA256 = string.rep('a', 64),
                    PARLEY_RELEASE_OUTPUT = output,
                } }):wait(10000)
        end
        local result = entry('v2.3.0')
        assert.are.equal(0, result.code, result.stderr)
        assert.are.equal(dofile(repo .. '/packaging/formula.lua').render_formula({
            tag = 'v2.3.0', sha256 = string.rep('a', 64),
        }), table.concat(vim.fn.readfile(output, 'b'), '\n'))
        vim.fn.delete(output)
        result = entry('main')
        assert.is_true(result.code ~= 0)
        assert.are.equal(0, vim.fn.filereadable(output))
    end)
    it('selects exactly the host artifact and rejects unsupported Linux ARM before staging', function()
        if vim.fn.executable('ruby') ~= 1 then return end
        local formula_path, evaluator = scratch .. '/platform.rb', scratch .. '/evaluate.rb'
        write(formula_path, vim.split(dofile(repo .. '/packaging/formula.lua').render_formula({
            tag = 'v2.3.0', sha256 = string.rep('a', 64),
        }), '\n'))
        write(evaluator, vim.split([[
require 'json'
module OS
  def self.mac?; ENV.fetch('PLATFORM').start_with?('macos'); end
  def self.linux?; !mac?; end
end
module Hardware
  module CPU
    def self.arm?; ENV.fetch('PLATFORM').end_with?('arm64'); end
    def self.intel?; !arm?; end
  end
end
class Resource
  attr_reader :values
  def initialize; @values = {}; end
  def url(value); @values[:url] = value; end
  def sha256(value); @values[:sha256] = value; end
end
class Formula
  def self.method_missing(*args); end
  def self.on_macos(&block); class_eval(&block) if OS.mac?; end
  def self.on_linux(&block); class_eval(&block) if OS.linux?; end
  def self.on_arm(&block); class_eval(&block) if Hardware::CPU.arm?; end
  def self.on_intel(&block); class_eval(&block) if Hardware::CPU.intel?; end
  def self.resource(name, &block)
    value = Resource.new
    value.instance_eval(&block)
    (@resources ||= {})[name] = value.values
  end
  def self.resources; @resources; end
  def self.test; end
  def odie(message); raise message; end
end
load ARGV.fetch(0)
result = { resources: Parley.resources }
if ENV.fetch('PLATFORM') == 'linux-arm64'
  begin
    Parley.new.install
  rescue => error
    result[:error] = error.message
  end
end
puts JSON.generate(result)
]], '\n'))
        local editor = dofile(repo .. '/lua/parley/editor_dependencies.lua')
        for _, platform in ipairs({ 'macos-arm64', 'macos', 'linux', 'linux-arm64' }) do
            local result = vim.system({ 'ruby', evaluator, formula_path }, { text = true, env = { PLATFORM = platform } }):wait()
            assert.equals(0, result.code, result.stderr)
            local actual = vim.json.decode(result.stdout)
            local expected = {}
            for _, plugin in ipairs(editor.plugins('app')) do
                expected['editor-' .. plugin.name] = { url = plugin.url, sha256 = plugin.sha256 }
            end
            if platform == 'linux-arm64' then
                assert.is_truthy(actual.error:find('unsupported editor bundle platform', 1, true))
            else
                local artifact = editor.artifact(platform)
                expected['editor-markdown-preview-binary'] = { url = artifact.url, sha256 = artifact.sha256 }
            end
            assert.same(expected, actual.resources)
        end
    end)
    it('generates from the tagged archive without committing by default', function()
        local before = run({ 'git', 'rev-parse', 'HEAD' }, scratch .. '/tap')
        local result = release()
        assert.are.equal(0, result.code, result.stderr)
        local formula = table.concat(vim.fn.readfile(scratch .. '/tap/Formula/parley.rb'), '\n')
        if vim.fn.executable('ruby') == 1 then
            run({ 'ruby', '-c', scratch .. '/tap/Formula/parley.rb' })
        end
        assert.is_truthy(formula:find('depends_on "archive-ripgrep"', 1, true))
        assert.are.equal(before, run({ 'git', 'rev-parse', 'HEAD' }, scratch .. '/tap'))
        local digest = run({ 'shasum', '-a', '256', scratch .. '/archives/v2.3.0.tar.gz' }):match('^%w+')
        assert.is_truthy(formula:find('sha256 "' .. digest .. '"', 1, true))
        assert.are.equal(0, release().code)
        assert.are.equal(0, release(true).code)
    end)
    it('verifies the tagged dependency tree and leaves local and remote tap untouched on failure', function()
        -- The caller checkout must not supply either the manifest or runner.
        write(scratch .. '/source/lua/parley/editor_dependencies.lua', { "error('caller manifest must not load')" })
        write(scratch .. '/source/scripts/check-editor-bundle.sh', { '#!/bin/sh', 'exit 99' })
        local before = run({ 'git', 'rev-parse', 'HEAD' }, scratch .. '/tap')
        write(scratch .. '/reject-verification', { 'fail first check' })
        local result = release(true)
        assert.is_true(result.code ~= 0)
        assert.is_truthy(result.stderr:find('fixture offline conformance failed', 1, true))
        assert.are.equal('', run({ 'git', 'status', '--porcelain' }, scratch .. '/tap'))
        assert.are.equal(before, run({ 'git', 'rev-parse', 'HEAD' }, scratch .. '/tap'))
        assert.are.equal(before, run({ 'git', '--git-dir=' .. scratch .. '/tap.git', 'rev-parse', 'HEAD' }))
        local log = table.concat(vim.fn.readfile(scratch .. '/verification.log'), '\n')
        assert.is_truthy(log:find('archive-editor', 1, true))
        assert.is_falsy(log:find('caller manifest', 1, true))
        vim.fn.delete(scratch .. '/reject-verification')
        result = release(true)
        assert.are.equal(0, result.code, result.stderr)
        local published = run({ 'git', 'rev-parse', 'HEAD' }, scratch .. '/tap')
        local formula = table.concat(vim.fn.readfile(scratch .. '/tap/Formula/parley.rb'), '\n')
        assert.is_truthy(formula:find('editor-archive-editor', 1, true))
        write(scratch .. '/reject-verification', { 'reject retry' })
        assert.is_true(release(true).code ~= 0)
        assert.are.equal(published, run({ 'git', 'rev-parse', 'HEAD' }, scratch .. '/tap'))
        assert.are.equal(published, run({ 'git', '--git-dir=' .. scratch .. '/tap.git', 'rev-parse', 'HEAD' }))
        assert.are.equal('', run({ 'git', 'status', '--porcelain' }, scratch .. '/tap'))
    end)
    it('publishes only formula and retries identical publication', function()
        local result = release(true)
        assert.are.equal(0, result.code, result.stderr)
        local head = run({ 'git', 'rev-parse', 'HEAD' }, scratch .. '/tap')
        assert.are.equal('Formula/parley.rb', run({ 'git', 'diff-tree', '--no-commit-id', '--name-only', '-r', 'HEAD' }, scratch .. '/tap'))
        result = release(true)
        assert.are.equal(0, result.code, result.stderr)
        assert.are.equal(head, run({ 'git', 'rev-parse', 'HEAD' }, scratch .. '/tap'))
    end)
    it('retries a committed release after an interrupted push', function()
        local hook = scratch .. '/tap.git/hooks/pre-receive'
        write(hook, { '#!/bin/sh', 'exit 1' })
        vim.fn.setfperm(hook, 'rwx------')
        local result = release(true)
        assert.is_true(result.code ~= 0)
        local head = run({ 'git', 'rev-parse', 'HEAD' }, scratch .. '/tap')
        vim.fn.delete(hook)
        result = release(true)
        assert.are.equal(0, result.code, result.stderr)
        assert.are.equal(head, run({ 'git', 'rev-parse', 'HEAD' }, scratch .. '/tap'))
        assert.are.equal(head, run({ 'git', '--git-dir=' .. scratch .. '/tap.git', 'rev-parse', 'HEAD' }))
    end)
    it('fails without mutating the tap when download or archive contents fail', function()
        vim.fn.delete(scratch .. '/archives/v2.3.0.tar.gz')
        assert.is_true(release().code ~= 0)
        assert.are.equal('', run({ 'git', 'status', '--porcelain' }, scratch .. '/tap'))
        run({ 'git', 'archive', '--format=tar.gz', '--prefix=release/', '--output=' .. scratch .. '/archives/v2.3.0.tar.gz', 'v2.3.0', 'README' }, scratch .. '/source')
        local result = release()
        assert.is_true(result.code ~= 0)
        assert.is_truthy(result.stderr:find('tagged archive lacks packaging/formula.lua', 1, true))
        assert.are.equal('', run({ 'git', 'status', '--porcelain' }, scratch .. '/tap'))
    end)
    it('preserves a dirty formula and refuses symlink destinations', function()
        write(scratch .. '/tap/Formula/parley.rb', { 'human edits' })
        assert.is_true(release(true).code ~= 0)
        assert.are.same({ 'human edits' }, vim.fn.readfile(scratch .. '/tap/Formula/parley.rb'))
        vim.fn.delete(scratch .. '/tap/Formula', 'rf')
        vim.fn.mkdir(scratch .. '/outside', 'p')
        assert(vim.uv.fs_symlink(scratch .. '/outside', scratch .. '/tap/Formula'))
        assert.is_true(release().code ~= 0)
        assert.are.equal(0, vim.fn.filereadable(scratch .. '/outside/parley.rb'))
    end)
    it('refuses dirty or wrong tap and moved local tags', function()
        write(scratch .. '/tap/unrelated', { 'dirty' })
        assert.is_true(release().code ~= 0)
        vim.fn.delete(scratch .. '/tap/unrelated')
        run({ 'git', 'remote', 'set-url', 'origin', 'https://github.com/other/homebrew-parley.git' }, scratch .. '/tap')
        assert.is_true(release().code ~= 0)
        run({ 'git', 'remote', 'set-url', 'origin', 'https://github.com/xianxu/homebrew-parley.git' }, scratch .. '/tap')
        write(scratch .. '/source/changed', { 'new' })
        run({ 'git', 'add', '.' }, scratch .. '/source')
        run({ 'git', 'commit', '-m', 'changed' }, scratch .. '/source')
        run({ 'git', 'tag', '-f', 'v2.3.0' }, scratch .. '/source')
        assert.is_true(release().code ~= 0)
    end)
end)
