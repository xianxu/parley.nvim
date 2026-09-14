-- Shipped learning material must remain retrievable and executable as examples.
describe('published documentation (#206)', function()
    local help = require('parley.help')
    local function atlas_files()
        -- A developer checkout may contain ignored maintainer overlays that do
        -- not ship. An extracted release has no Git metadata or such overlays.
        local files = vim.fn.systemlist({'git', 'ls-files', '--cached', '--others', '--exclude-standard', 'atlas'})
        if vim.v.shell_error ~= 0 then return vim.fn.glob('atlas/**/*.md', false, true) end
        return vim.tbl_filter(function(path) return path:match('%.md$') ~= nil end, files)
    end

    it('keeps every atlas page and tutorial reachable from the help catalog', function()
        local topics = assert(help.read())
        for _, path in ipairs(atlas_files()) do
            local topic = path:sub(1, -4)
            assert.truthy(('\n' .. topics .. '\n'):find('\n' .. topic .. '\n', 1, true), path)
            assert.is_string(help.read(topic))
        end
        for _, name in ipairs({'welcome', 'basics', 'advanced'}) do
            local text = assert(help.read('tutorials/' .. name))
            assert.equals(table.concat(vim.fn.readfile('packaging/tutorials/' .. name .. '.md'), '\n') .. '\n', text)
        end
    end)

    it('keeps relative links in published prose pointed at existing files', function()
        local files = atlas_files()
        vim.list_extend(files, vim.fn.glob('packaging/tutorials/*.md', false, true))
        files[#files + 1] = 'README.md'
        local missing = {}
        for _, path in ipairs(files) do
            local fenced = false
            for _, line in ipairs(vim.fn.readfile(path)) do
                if line:match('^%s*```') or line:match('^%s*~~~') then
                    fenced = not fenced
                elseif not fenced then
                    -- Inline code and fenced examples are not navigation links.
                    line = line:gsub('`[^`]+`', '')
                    for target in line:gmatch('%]%(([^%s%)]+)%)') do
                        if not target:match('^[%a][%w+%.%-]*:') and target:sub(1, 1) ~= '#' then
                            local file = target:match('^[^#]+')
                            if file and not vim.uv.fs_stat(vim.fn.fnamemodify(path, ':h') .. '/' .. file) then
                                missing[#missing + 1] = path .. ' -> ' .. target
                            end
                        end
                    end
                end
            end
        end
        assert.same({}, missing)
    end)

    it('the Basics outline exercise selects a real chat outline marker', function()
        local parley = require('parley')
        local cfg = require('parley.config')
        local path = vim.fn.getcwd() .. '/packaging/tutorials/basics.md'
        local items = require('parley.outline')._build_tree_outline_items(path, cfg, {})
        local found
        for _, item in ipairs(items) do
            if item.type == 'annotation' and item.display:find('Try it', 1, true) then found = item end
        end
        assert.is_not_nil(found, 'the tutorial exercise must be selectable in a chat outline')
        local lines = vim.fn.readfile(path)
        assert.equals('@@Try it@@', lines[found.value.lnum])
        assert.is_not_nil(parley.config)
    end)

    it('the tag example parses as documented without implying YAML list support', function()
        local text = assert(help.read('atlas/chat/format'))
        local example = assert(text:match('\n(tags: [^\n]+)\n'), 'missing copyable tag example')
        local parser = require('parley.chat_parser')
        local lines = {'---', 'topic: Example', 'file: welcome.md', example, '---'}
        assert.same({'tutorial', 'getting-started'}, parser.parse_header_metadata(lines, 5).tags)
    end)
end)
