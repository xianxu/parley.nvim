local catalog = {
    { name = 'developmental', scope = 'whole-doc', frontier = 'off' },
    { name = 'line-editing', scope = 'whole-doc', frontier = 'off' },
    { name = 'copy-editing', scope = 'whole-doc', frontier = 'off' },
    { name = 'proofreading', scope = 'whole-doc', frontier = 'off' },
    { name = 'fact-check', scope = 'whole-doc', frontier = 'off' },
    { name = 'free-form', scope = 'markers-only', frontier = 'on' },
}

local function module()
    local ok, value = pcall(require, 'parley.editorial_frontmatter')
    assert.is_true(ok, 'the approved editorial resolver/filler is not implemented')
    return value
end

local function bytes(path)
    local handle = assert(io.open(path, 'rb'))
    local value = handle:read('*a'); assert(handle:close()); return value
end

local function lines(value)
    assert.equals('\n', value:sub(-1))
    return vim.split(value:sub(1, -2), '\n', { plain = true })
end

describe('editorial front matter', function()
    it('fills the pinned producer reference cases exactly and refuses the multi-mode case unchanged', function()
        local settings = module()
        local root = 'tests/fixtures/editorial_fill/'
        local provenance = vim.json.decode(bytes(root .. 'provenance.json'))
        local cases = {}
        for _, entry in ipairs(provenance.files) do
            local content = bytes(root .. entry.path)
            assert.equals(entry.bytes, #content)
            assert.equals(entry.sha256, vim.fn.sha256(content))
            cases[assert(entry.path:match('^([^/]+)/'))] = true
        end
        local count = 0
        for name in pairs(cases) do
            count = count + 1
            local before = lines(bytes(root .. name .. '/before/note.md'))
            local captured = vim.deepcopy(before)
            local result, err = settings.fill(before, catalog)
            if name == 'editorial-fill-multimode' then
                assert.is_nil(result)
                assert.truthy(err:find('one processing-mode', 1, true))
                assert.equals(bytes(root .. name .. '/before/note.md'), bytes(root .. name .. '/after/note.md'))
            else
                assert.is_nil(err)
                assert.equals(bytes(root .. name .. '/after/note.md'), table.concat(result.lines, '\n') .. '\n', name)
                local again = assert(settings.fill(result.lines, catalog))
                assert.is_false(again.changed, name)
                assert.same(result.lines, again.lines, name)
            end
            assert.same(captured, before, 'fill must never mutate its input')
        end
        assert.equals(8, count)
    end)

    it('selects presentation by canonical presence rather than scalar truthiness', function()
        local settings = module()
        for _, legacy in ipairs({ 'direct', 'highlight', 'propose' }) do
            for _, canonical in ipairs({ '', 'typo', 'direct', 'highlight', 'propose' }) do
                local document = { '---', 'presentation: ' .. legacy, 'presentation-mode: ' .. canonical, '---', '# Body' }
                local result = assert(settings.resolve(document, catalog))
                local expected = (canonical == '' or canonical == 'typo') and 'highlight' or canonical
                assert.equals(expected, result.presentation)
                if canonical == 'typo' then
                    assert.truthy(table.concat(result.warnings, '\n'):find('typo', 1, true))
                end
                local filled = assert(settings.fill(document, catalog))
                assert.equals(document[3], filled.lines[3])
                assert.equals(expected, assert(settings.resolve(filled.lines, catalog)).presentation)
            end
        end
    end)

    it('preserves generated unknown nested metadata and body literals without mistaking them for root keys', function()
        local settings = module()
        local atoms = { 'presentation-mode: direct', 'processing-mode: typo', 'collaboration-mode: chat', 'x: [1, 2]', '"quoted" # literal' }
        for _, atom in ipairs(atoms) do
            local document = { '---', 'future:', '  nested: ' .. vim.inspect(atom), 'literal: |', '  ' .. atom,
                'review-mode: operator-private', '---', '# Body', atom }
            local captured = vim.deepcopy(document)
            local filled = assert(settings.fill(document, catalog))
            assert.same(captured, document)
            for row = 1, 6 do assert.equals(document[row], filled.lines[row]) end
            assert.equals('collaboration-mode: discussion', filled.lines[7])
            assert.equals('presentation-mode: highlight', filled.lines[8])
            assert.equals('processing-mode: free-form', filled.lines[9])
            assert.same({ '---', '# Body', atom }, { filled.lines[10], filled.lines[11], filled.lines[12] })
        end
    end)

    it('refuses ambiguous relevant fields before any partial insertion', function()
        local settings = module()
        local headers = {
            { '---', 'processing-mode: free-form', 'processing-mode: proofreading', '---', '# Body' },
            { '---', 'title: unclosed' },
            { '---', '{processing-mode: free-form}', '---', '# Body' },
            { '---', 'processing-mode: [free-form]', '---', '# Body' },
            { '---', 'processing-mode: absent-mode', '---', '# Body' },
        }
        for _, document in ipairs(headers) do
            local captured = vim.deepcopy(document)
            local result, err = settings.fill(document, catalog)
            assert.is_nil(result, vim.inspect(document))
            assert.is_string(err)
            assert.same(captured, document)
        end
    end)
end)
