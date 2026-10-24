local function api()
    local ok, module = pcall(require, 'parley.skills.review.local_proposal')
    assert.is_true(ok, 'local proposal guard must exist')
    return module
end

local question = { line = 0, col = 0, raw = '🤖[why?]', ready = true }
local command = { line = 1, col = 0, raw = '🤖[tighten this]', ready = true }
local original = question.raw .. '\n' .. command.raw
local function classifications()
    return {
        { line = question.line, col = question.col, raw = question.raw, kind = 'question' },
        { line = command.line, col = command.col, raw = command.raw, kind = 'command' },
    }
end
local function context()
    return { markers = { question, command }, protected = {} }
end
local edit = { old_string = command.raw, new_string = 'Tight text.', explain = 'tightened' }

describe('local review proposal guard', function()
    it('applies commands while preserving declared questions', function()
        local err, summary = api().validate(original, {edit}, {review_asks = classifications()}, context())
        assert.is_nil(err)
        assert.equals(1, summary.deferred)
        assert.equals(question.raw .. '\nTight text.', summary.content)
        assert.is_false(summary.noop)
    end)

    it('completes a question-only proposal without a write', function()
        local err, summary = api().validate(question.raw, {}, {review_asks = { classifications()[1] }},
            { markers = {question}, protected = {} })
        assert.is_nil(err)
        assert.is_true(summary.noop)
        assert.equals(question.raw, summary.content)
        assert.equals(1, summary.deferred)
    end)

    it('requires exhaustive exact classification identities', function()
        local variants = {
            {}, { review_asks = {} }, { review_asks = {classifications()[1]} },
            { review_asks = {classifications()[1], classifications()[1]} },
        }
        for _, input in ipairs(variants) do
            assert.is_string(api().validate(original, {edit}, input, context()))
        end
        for _, field in ipairs({'line', 'col', 'raw', 'kind'}) do
            local asks = classifications()
            asks[2][field] = field == 'raw' and 'different' or field == 'kind' and 'unsure' or 99
            assert.is_string(api().validate(original, {edit}, {review_asks = asks}, context()))
        end
    end)

    it('refuses replacing a question even with an unchanged copy elsewhere', function()
        local edits = {{old_string=original, new_string='Answer here.\n'..question.raw, explain='wrong'}}
        assert.is_string(api().validate(original, edits, {review_asks=classifications()}, context()))
    end)

    it('rejects malformed, sparse and overlapping edit batches', function()
        local batches = {
            {{old_string='',new_string='x',explain='x'}},
            {{old_string=command.raw,new_string=false,explain='x'}},
            {[2]=edit}, {edit, edit}, {edit, 'bad'},
        }
        for _, edits in ipairs(batches) do
            assert.is_string(api().validate(original, edits, {review_asks=classifications()}, context()))
        end
        local asks=classifications(); asks.extra=asks[1]
        assert.is_string(api().validate(original,{edit},{review_asks=asks},context()))
    end)

    it('rejects editing protected metadata and commandless work', function()
        local c=context(); c.protected={{first=#question.raw+2,last=#original}}
        assert.is_string(api().validate(original,{edit},{review_asks=classifications()},c))
        assert.is_string(api().validate(question.raw,{{old_string=question.raw,new_string='new',explain='x'}},
            {review_asks={classifications()[1]}},{markers={question},protected={}}))
    end)

    it('distinguishes duplicate raw markers by source position', function()
        local text=question.raw..'\n'..question.raw
        local second={line=1,col=0,raw=question.raw,ready=true}
        local asks={classifications()[1],{line=1,col=0,raw=question.raw,kind='question'}}
        local err, summary=api().validate(text,{}, {review_asks=asks}, {markers={question,second},protected={}})
        assert.is_nil(err)
        assert.equals(2,summary.deferred)
    end)
end)
