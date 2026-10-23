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
    it('resolves generated processing components independently and preserves their effective values after fill', function()
        local settings = module()
        local choices = { false, '', 'Use canonical # text: exactly.' }
        for _, canonical_mode in ipairs({ false, 'proof' }) do
            for _, canonical_text in ipairs(choices) do
                for _, legacy in ipairs({ '[copy-edit] Fix punctuation.', 'Free legacy # text' }) do
                    local document = { '---', 'process-instruction: ' .. vim.json.encode(legacy) }
                    if canonical_mode then document[#document + 1] = 'processing-mode: ' .. canonical_mode end
                    if canonical_text then document[#document + 1] = 'processing-instruction: ' .. vim.json.encode(canonical_text) end
                    document[#document + 1], document[#document + 2] = '---', '# Body'
                    local before = vim.deepcopy(document)
                    local resolved = assert(settings.resolve(document, catalog))
                    local expected_mode = canonical_mode and 'proofreading'
                        or (legacy:sub(1, 1) == '[' and 'copy-editing' or 'free-form')
                    local expected_text = canonical_text ~= false and canonical_text
                        or (legacy:sub(1, 1) == '[' and 'Fix punctuation.' or legacy)
                    assert.equals(expected_mode, resolved.modes[1].name)
                    assert.equals(expected_text, resolved.instruction)
                    local filled = assert(settings.fill(document, catalog))
                    assert.same(before, document)
                    for row = 1, #before - 2 do assert.equals(before[row], filled.lines[row]) end
                    local after = assert(settings.resolve(filled.lines, catalog))
                    assert.equals(expected_mode, after.modes[1].name)
                    assert.equals(expected_text, after.instruction)
                    assert.is_false(assert(settings.fill(filled.lines, catalog)).changed)
                end
            end
        end
    end)

    it('resolves exact names before prefixes and refuses generated unknown or ambiguous selectors', function()
        local settings = module()
        local modes = vim.deepcopy(catalog)
        modes[#modes + 1] = { name = 'copy-edit', scope = 'whole-doc', frontier = 'off' }
        local selectors = { { 'copy-edit', 'copy-edit' }, { 'proof', 'proofreading' },
            { 'copy-', false, 'ambiguous' }, { 'f', false, 'ambiguous' },
            { 'absent-mode', false, 'not a stock prompt' }, { '', false, 'not a stock prompt' } }
        for _, selector in ipairs(selectors) do
            for _, key in ipairs({ 'processing-mode', 'process-instruction' }) do
                local value = key == 'process-instruction' and ('[' .. selector[1] .. '] Carry intent.') or selector[1]
                local document = { '---', key .. ': ' .. vim.json.encode(value), '---', '# Body' }
                local captured = vim.deepcopy(document)
                local resolved, err = settings.resolve(document, modes)
                if selector[2] then
                    assert.equals(selector[2], assert(resolved, err).modes[1].name)
                    assert.is_not_nil(settings.fill(document, modes))
                else
                    assert.is_nil(resolved, key .. ': ' .. selector[1])
                    assert.truthy(err:find(selector[3], 1, true))
                    assert.is_nil(settings.fill(document, modes))
                end
                assert.same(captured, document)
            end
        end
    end)

    it('preserves scalar styles and comments while decoding their effective values', function()
        local settings = module()
        local values = { { '"Keep # hash: and \\"quote\\"" # trailing', 'Keep # hash: and "quote"' },
            { "'Don''t lose # hash: text' # trailing", "Don't lose # hash: text" },
            { 'Keep hash#inside # trailing', 'Keep hash#inside' },
            { '"\\u03bb and \\nnext" # trailing', 'λ and \nnext' } }
        for _, value in ipairs(values) do
            local document = { '---', "presentation-mode: 'direct' # keep", 'processing-mode: "copy-edit" # keep',
                'processing-instruction: ' .. value[1], '---', '# Body' }
            local filled = assert(settings.fill(document, catalog))
            for row = 1, 4 do assert.equals(document[row], filled.lines[row]) end
            local resolved = assert(settings.resolve(filled.lines, catalog))
            assert.equals('direct', resolved.presentation)
            assert.equals('copy-editing', resolved.modes[1].name)
            assert.equals(value[2], resolved.instruction)
        end
    end)

    it('refuses each relevant duplicate including quoted and differently cased keys', function()
        local settings = module()
        local fields = { { 'collaboration-mode', 'discussion' }, { 'presentation-mode', 'highlight' },
            { 'presentation', 'direct' }, { 'processing-mode', 'free-form' },
            { 'processing-instruction', 'Keep intent' }, { 'process-instruction', 'Keep intent' } }
        for _, field in ipairs(fields) do
            for _, duplicate in ipairs({ field[1], '"' .. field[1] .. '"', field[1]:upper() }) do
                local document = { '---', field[1] .. ': ' .. field[2], duplicate .. ': ' .. field[2], '---', '# Body' }
                local captured = vim.deepcopy(document)
                local filled, err = settings.fill(document, catalog)
                assert.is_nil(filled, field[1] .. ' duplicate')
                assert.truthy(err:find('duplicate ' .. field[1], 1, true))
                assert.same(captured, document)
            end
        end
    end)

    it('refuses generated malformed root metadata without producing a patch', function()
        local settings = module()
        local roots = { { '- processing-mode: free-form' }, { '<<: *defaults' },
            { '? processing-mode', ': free-form' }, { '"unclosed: value' },
            { 'future: [', 'processing-mode: free-form' }, { 'future: scalar', '  processing-mode: free-form' },
            { '\tprocessing-mode: free-form' }, { 'future: {a: ]}' } }
        for index, root in ipairs(roots) do
            local document = { '---' }
            vim.list_extend(document, root)
            vim.list_extend(document, { '---', '# Body' })
            local captured = vim.deepcopy(document)
            local filled, err = settings.fill(document, catalog)
            assert.is_nil(filled, 'malformed root ' .. index)
            assert.is_string(err)
            assert.same(captured, document)
        end
    end)

    it('keeps all legacy modes readable in order but refuses every multi-mode fill unchanged', function()
        local settings = module()
        for _, pair in ipairs({ { 'proof', 'copy-edit' }, { 'free-form', 'developmental' }, { 'proof', 'proof' } }) do
            for _, canonical in ipairs({ false, 'processing-mode: fact-check', 'processing-instruction: Canonical intent' }) do
                local document = { '---', 'process-instruction: "[' .. pair[1] .. '][' .. pair[2] .. '] Legacy intent"' }
                if canonical then document[#document + 1] = canonical end
                vim.list_extend(document, { '---', '# Body' })
                local captured = vim.deepcopy(document)
                local resolved = assert(settings.resolve(document, catalog))
                if canonical == 'processing-mode: fact-check' then
                    assert.equals(1, #resolved.modes)
                    assert.equals('fact-check', resolved.modes[1].name)
                else
                    assert.equals(2, #resolved.modes)
                    local expected = { proof = 'proofreading', ['copy-edit'] = 'copy-editing' }
                    for i, name in ipairs(pair) do assert.equals(expected[name] or name, resolved.modes[i].name) end
                end
                assert.equals(canonical == 'processing-instruction: Canonical intent' and 'Canonical intent' or 'Legacy intent', resolved.instruction)
                assert.truthy(table.concat(resolved.warnings, '\n'):find('all briefs remain readable', 1, true))
                local filled, err = settings.fill(document, catalog)
                assert.is_nil(filled)
                assert.truthy(err:find('one processing-mode', 1, true))
                assert.same(captured, document)
            end
        end
    end)

    it('uses the same case-insensitive field presence for collaboration reading and filling', function()
        local settings = module()
        for _, key in ipairs({ 'collaboration-mode', 'COLLABORATION-MODE', 'Collaboration-Mode', '"COLLABORATION-MODE"' }) do
            for _, value in ipairs({ 'chat', '{default: chat}' }) do
                local document = { '---', key .. ': ' .. value, '---', '# Body' }
                local resolved = assert(settings.resolve(document, catalog))
                assert.equals('chat', resolved.collaboration.mode_by_row[4], key .. ': ' .. value)
                local filled = assert(settings.fill(document, catalog))
                assert.equals(document[2], filled.lines[2])
                local after = assert(settings.resolve(filled.lines, catalog))
                assert.equals('chat', after.collaboration.mode_by_row[#filled.lines])
            end
        end
    end)

    it('bounds the complete input and projected header while allowing a large body', function()
        local settings = module()
        local fixed = { '---', 'collaboration-mode: discussion', 'presentation-mode: highlight',
            'processing-mode: free-form' }
        local function header_with_bytes(size)
            local doc, used = vim.deepcopy(fixed), 4
            for i = 2, #doc do used = used + #doc[i] + 1 end
            doc[#doc + 1] = '# ' .. string.rep('x', size - used - 7)
            doc[#doc + 1] = '---'
            return doc
        end
        assert.is_not_nil(settings.fill(header_with_bytes(1024 * 1024), catalog))
        local too_large = header_with_bytes(1024 * 1024 + 1)
        local result, err = settings.fill(too_large, catalog)
        assert.is_true(result == nil, "over-budget input must refuse")
        assert.truthy(err:find('1 MiB', 1, true))
        local full = vim.deepcopy(fixed)
        while #full < 8191 do full[#full + 1] = '# comment' end
        full[#full + 1] = '---'
        assert.is_not_nil(settings.fill(full, catalog))
        table.insert(full, 2, '# over')
        assert.is_nil(settings.fill(full, catalog))
        local needs_keys = { '---' }
        while #needs_keys < 8191 do needs_keys[#needs_keys + 1] = '# comment' end
        needs_keys[#needs_keys + 1] = '---'
        assert.is_nil(settings.fill(needs_keys, catalog), 'projection may not create an unreadable header')
        assert.is_not_nil(settings.fill({ '# Body', string.rep('x', 1024 * 1024 + 1) }, catalog))
    end)

    it('keeps counted VM work linear at N and 2N for header plus body growth', function()
        local settings = module()
        local function work(n)
            local document = { '---' }
            for i = 1, n do document[#document + 1] = 'unknown-' .. i .. ': retained' end
            document[#document + 1] = '---'
            for i = 1, n do document[#document + 1] = 'body ' .. i end
            local ticks = 0
            jit.off()
            debug.sethook(function() ticks = ticks + 1 end, '', 100)
            local ok, result = pcall(settings.fill, document, catalog)
            debug.sethook()
            jit.on()
            assert.is_true(ok, tostring(result))
            assert.is_not_nil(result)
            return ticks
        end
        local n, doubled = work(128), work(256)
        assert.is_true(doubled <= n * 2.3, ('counted work %d -> %d'):format(n, doubled))
    end)

end)
