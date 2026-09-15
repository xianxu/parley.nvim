local S = require("parley.document.sequence")
local G = require("parley.document.grammar")
local F

local function fixture(lines, opaque)
    local values = {}
    for i, line in ipairs(lines) do
        local _, token = G.lex_step(G.lex_start(), line, true, { bytes = #line })
        values[i] = { rows = 1, bytes = #line + 1, metadata = { token = token }, opaque = i == opaque }
    end
    local seq = S.new(values, { channel_names = G.CHANNELS, channels = function(meta) return G.channels(meta and meta.token) end, summarize = function(meta) return G.summary(meta.token) end,
        combine = G.combine, empty_summary = G.empty_summary() })
    local handles = {}
    for i, span in ipairs(S.query(seq, 0, #lines)) do handles[i] = span.handle end
    return seq, handles
end

local function ready(seq, handle, need, opts)
    local result = F.resolve(seq, handle, need, opts)
    assert.equals("ready", result.status)
    assert.is_true(F.validate(seq, result.fact.certificate))
    return result.fact
end

describe("indexed grammar facts", function()
    before_each(function()
        local loaded, module = pcall(require, "parley.document.facts")
        assert.is_true(loaded, tostring(module))
        F = module
    end)

    it("preserves split body rows outside footer trigger components", function()
        local seq, h = fixture({ "topic", "---", "body", "more", "---", "", "[^1]: note" })
        local header = ready(seq, h[1], { kind = "header" })
        local footer = ready(seq, h[1], { kind = "footer" })
        local _, token = G.lex_step(G.lex_start(), "new body", true, { bytes = 8 })
        S.splice(seq, 3, 3, { { rows = 1, bytes = 9, metadata = { token = token } } })
        assert.is_true(F.validate(seq, header.certificate))
        assert.is_true(F.validate(seq, footer.certificate))
        assert.equals(2, #F.dependencies(footer.certificate))
        assert.equals(h[5], footer.certificate.parts[2].first)
        local D = require("parley.document.dependencies")
        local index = D.new({ rank = function(handle)
            local rank = S.rank(seq, handle)
            return rank and rank.row
        end })
        for _, fact in ipairs({ header, footer }) do
            for _, part in ipairs(F.dependencies(fact.certificate)) do
                assert.equals("ok", index:add(part.origin, part.last,
                    { first = part.first, channels = part.channels }).status)
            end
        end
        assert.is_nil(index:restart_origin(3, 3, { channels = { row = true, nonblank = true } }).origin)
        assert.equals(S.bof(seq), index:restart_origin(5, 5, { channels = { divider = true } }).origin)
    end)

    it("invalidates local adjacency when a blank row is inserted", function()
        local seq, h = fixture({ "@@tag@@", "💬: next", "🔧: read", "```lua", "body", "```" })
        local preface = ready(seq, h[1], { kind = "preface" })
        local tool = ready(seq, h[3], { kind = "tool_body" })
        local _, token = G.lex_step(G.lex_start(), "", true, { bytes = 0 })
        S.splice(seq, 3, 3, { { rows = 1, bytes = 1, metadata = { token = token } } })
        assert.is_false(F.validate(seq, tool.certificate))
        assert.is_true(F.validate(seq, preface.certificate))
        S.splice(seq, 1, 1, { { rows = 1, bytes = 1, metadata = { token = token } } })
        assert.is_false(F.validate(seq, preface.certificate))
    end)

    it("preserves closer proofs across irrelevant Enter and rejects equal-count replacements", function()
        for _, closer in ipairs({ "```", "body" }) do
            local seq, h = fixture({ "```lua", "body", closer })
            local fact = ready(seq, h[1], { kind = "ordinary_close", width = 3 })
            local _, body = G.lex_step(G.lex_start(), "more", true, { bytes = 4 })
            S.splice(seq, 1, 1, { { rows = 1, bytes = 5, metadata = { token = body } } })
            assert.is_true(F.validate(seq, fact.certificate))
            local _, close = G.lex_step(G.lex_start(), "```", true, { bytes = 3 })
            S.splice(seq, 2, 3, { { rows = 1, bytes = 4, metadata = { token = close } } })
            assert.is_false(F.validate(seq, fact.certificate))
        end
        local seq, h = fixture({ "```lua", "````", "```" })
        local fact = ready(seq, h[1], { kind = "ordinary_close", width = 3 })
        local metadata = S.at(seq, 1).metadata
        metadata.token.bare_close_width = 3
        S.update(seq, h[2], metadata)
        assert.is_false(F.validate(seq, fact.certificate))
    end)

    it("matches header and footer source oracles", function()
        for _, lines in ipairs({
            { "# topic: x", "---", "body", "---", "", "[^1]: note" },
            { "---", "topic: x", "---", "body", "[^1]: note" },
            { "---", "unclosed" }, { "ordinary", "body" },
        }) do
            local seq, h = fixture(lines)
            local expected = require("parley.chat_parser").find_header_end(lines)
            local header = ready(seq, h[1], { kind = "header" }).value
            assert.equals(expected and h[expected] or false, header and header.finish or false)
            local content = require("parley.define").managed_footnote_content_start(lines)
            local footer = ready(seq, h[1], { kind = "footer" }).value
            assert.equals(content and h[content] or false, footer and footer.content_start or false)
        end
    end)

    it("distinguishes exact ordinary closers from tool structural barriers", function()
        local seq, h = fixture({ "🔧: read", "```lua", "body", "💬: barrier", "````", "```" })
        assert.is_false(ready(seq, h[1], { kind = "tool_body" }).value)
        assert.equals(h[6], ready(seq, h[2], { kind = "ordinary_close", width = 3 }).value)
        local fact = ready(seq, h[2], { kind = "section_ordinary_close", width = 3,
            scope = { ["end"] = h[4] } })
        assert.is_false(fact.value)
        assert.equals(h[4], fact.certificate.last)
        local complete, handles = fixture({ "📎: result", "````", "```", "````" })
        assert.equals(handles[4], ready(complete, handles[1], { kind = "tool_body" }).value.close)
    end)

    it("proves reasoning and adjacent preface decisions explicitly", function()
        local seq, h = fixture({ "🧠: thought", "", "🧠:[END]", "@@tag@@", "💬: next" })
        assert.is_true(ready(seq, h[1], { kind = "reasoning" }).value)
        assert.is_true(ready(seq, h[4], { kind = "preface" }).value)
        assert.is_false(ready(seq, h[1], { kind = "preface" }).value)
        assert.is_false(ready(seq, h[1], { kind = "reasoning", scope = { ["end"] = h[3] } }).value)
        local missing, handles = fixture({ "```lua", "body" })
        local fact = ready(missing, handles[1], { kind = "ordinary_close", width = 3 })
        assert.is_false(fact.value)
        assert.equals(S.eof(missing), fact.certificate.last)
    end)

    it("demands opaque rows instead of returning a negative fact", function()
        local seq, h = fixture({ "```lua", "unknown", "```" }, 2)
        local result = F.resolve(seq, h[1], { kind = "ordinary_close", width = 3 })
        assert.equals("opaque", result.status)
        assert.equals(1, result.row)
        assert.is_nil(result.fact)
    end)

    it("rejects changes to earlier evidence when resuming a compound tool query", function()
        local lines = { "🔧: read", "`````lua" }
        for i = 3, 6000 do lines[i] = i % 2 == 0 and "````" or "``````" end
        local seq, h = fixture(lines)
        local opts = { budget_nodes = 512, budget_entries = 1700 }
        local result = F.resolve(seq, h[1], { kind = "tool_body" }, opts)
        assert.equals("budget", result.status)
        assert.is_not_nil(result.cursor)
        -- The active close search starts AFTER the opener. Its own rangeproof
        -- cannot establish that the earlier immediate-opener decision survived.
        local metadata = S.at(seq, 1).metadata
        metadata.token.ordinary_open_width = 9
        S.update(seq, h[2], metadata)
        opts.cursor = result.cursor
        assert.equals("stale", F.resolve(seq, h[1], { kind = "tool_body" }, opts).status)
    end)

    it("continues after a disjoint prefix edit using current handle coordinates", function()
        local lines = {}
        for i = 1, 10 do lines[i] = "prefix" end
        lines[11] = "`````lua"
        for i = 12, 6000 do lines[i] = i % 2 == 0 and "````" or "``````" end
        local seq, h = fixture(lines)
        local opts = { budget_nodes = 512, budget_entries = 1700 }
        local result = F.resolve(seq, h[11], { kind = "ordinary_close", width = 5 }, opts)
        assert.equals("budget", result.status)
        S.splice(seq, 1, 1, { { rows = 2, bytes = 2, opaque = true } })
        local slices = 0
        repeat
            opts.cursor = result.cursor
            result = F.resolve(seq, h[11], { kind = "ordinary_close", width = 5 }, opts)
            slices = slices + 1
            assert.is_true(slices < 100)
            assert.is_true(result.work.nodes_visited <= opts.budget_nodes)
            assert.is_true(result.work.entries_visited <= opts.budget_entries)
        until result.status ~= "budget"
        assert.equals("ready", result.status)
        assert.is_false(result.fact.value)
        assert.equals(h[11], result.fact.certificate.origin)
        assert.is_true(F.validate(seq, result.fact.certificate))
    end)

    it("finishes a false-positive summary search within each slice budget", function()
        local lines = { "`````lua" }
        for i = 2, 6000 do lines[i] = i % 2 == 0 and "````" or "``````" end
        local seq, h = fixture(lines)
        local opts = { budget_nodes = 512, budget_entries = 1700 }
        local slices, result = 0
        repeat
            result = F.resolve(seq, h[1], { kind = "ordinary_close", width = 5 }, opts)
            assert.is_true(result.work.nodes_visited <= opts.budget_nodes)
            assert.is_true(result.work.entries_visited <= opts.budget_entries)
            slices = slices + 1
            assert.is_true(slices < 100)
            opts.cursor = result.cursor
        until result.status ~= "budget"
        assert.equals("ready", result.status)
        assert.is_false(result.fact.value)
        assert.is_true(slices > 1)
    end)
    it("narrows ready proofs and does not demand opaque text beyond the witness", function()
        local seq, h = fixture({ "```lua", "body", "```", "plain", "unread" }, 5)
        local fact = ready(seq, h[1], { kind = "ordinary_close", width = 3 })
        assert.equals(h[3], fact.value)
        local metadata = S.at(seq, 3).metadata
        metadata.token.divider = true
        -- The unchanged adjacent handle is enough to preserve a closed search;
        -- changing text after its closer does not invalidate its interior proof.
        S.update(seq, h[4], metadata)
        assert.is_true(F.validate(seq, fact.certificate))
        S.splice(seq, 1, 2, { { rows = 1, bytes = 4, opaque = true } })
        assert.is_false(F.validate(seq, fact.certificate))
    end)

    it("uses summaries for a fifty-thousand-row footer across a blank gap", function()
        local lines = { "body", "---" }
        for i = 3, 49999 do lines[i] = "" end
        lines[50000] = "[^1]: note"
        local seq, h = fixture(lines)
        local opts = { budget_nodes = 512, budget_entries = 1700 }
        local result, slices, entries = nil, 0, 0
        repeat
            result = F.resolve(seq, h[1], { kind = "footer" }, opts)
            entries = entries + result.work.entries_visited
            assert.is_true(result.work.nodes_visited <= opts.budget_nodes)
            assert.is_true(result.work.entries_visited <= opts.budget_entries)
            opts.cursor = result.cursor
            slices = slices + 1
            assert.is_true(slices < 10)
        until result.status ~= "budget"
        assert.equals("ready", result.status)
        assert.equals(h[50000], result.fact.value.start)
        assert.equals(h[2], result.fact.value.content_start)
        assert.is_true(entries < 6000, "footer query scanned the document instead of summaries")
    end)

    it("demands the opaque proof boundary instead of an already-known origin", function()
        local seq, h = fixture({ "```lua" })
        S.splice(seq, 1, 1, { { rows = 5, bytes = 10, opaque = true } })
        local boundary = S.at(seq, 1).handle
        local result = F.resolve(seq, h[1], { kind = "section_ordinary_close", width = 3,
            scope = { ["end"] = boundary } })
        assert.equals("opaque", result.status)
        assert.equals(1, result.row)
        assert.is_true(S.at(seq, result.row).opaque)
        assert.is_nil(result.fact)
        local _, token = G.lex_step(G.lex_start(), "x", true, { bytes = 1 })
        S.splice(seq, 1, 2, { { rows = 1, bytes = 2, metadata = { token = token } } },
            { start_byte = 7, end_byte = 9 })
        boundary = S.at(seq, 1).handle
        result = F.resolve(seq, h[1], { kind = "section_ordinary_close", width = 3,
            scope = { ["end"] = boundary } })
        assert.equals("ready", result.status)
        assert.is_false(result.fact.value)
    end)

    it("keeps fact certificates through derived projection but not lexical updates", function()
        local seq, h = fixture({ "```lua", "body", "```" })
        local fact = ready(seq, h[1], { kind = "ordinary_close", width = 3 })
        local metadata = S.at(seq, 1).metadata
        metadata.semantic = { role = "answer" }
        assert.is_true(S.project_many(seq, { { handle = h[2], metadata = metadata } }))
        assert.is_true(F.validate(seq, fact.certificate))
        metadata.token.bare_close_width = 3
        assert.is_false(S.project_many(seq, { { handle = h[2], metadata = metadata } }))
        assert.is_true(F.validate(seq, fact.certificate))
        assert.is_true(S.update(seq, h[2], metadata))
        assert.is_false(F.validate(seq, fact.certificate))
    end)

    it("demands row zero for initially opaque global facts", function()
        local seq = S.new({ { rows = 50000, bytes = 100000, opaque = true } })
        local origin = S.at(seq, 0).handle
        for _, kind in ipairs({ "header", "footer" }) do
            local result = F.resolve(seq, origin, { kind = kind })
            assert.equals("opaque", result.status)
            assert.equals(0, result.row)
            assert.is_nil(result.fact)
        end
    end)

    it("issues explicit selective proofs that reject relevant lexical changes", function()
        local seq, h = fixture({ "```lua", "body", "```" })
        local fact = ready(seq, h[1], { kind = "ordinary_close", width = 3 })
        local text_proof = S.range_certificate(seq, 0, 3)
        assert.is_false(S.validate_certificate(seq, fact.certificate.range))
        local metadata = S.at(seq, 1).metadata
        metadata.token.bytes = 40
        local accepted, proof = S.update_text(seq, h[2], { bytes = 41, metadata = metadata })
        assert.is_true(accepted)
        assert.is_true(proof.same_syntax_proven)
        assert.is_true(F.validate(seq, fact.certificate))
        assert.is_false(S.validate_certificate(seq, text_proof))
        metadata.token.bare_close_width = 3
        accepted, proof = S.update_text(seq, h[2], { bytes = 41, metadata = metadata })
        assert.is_true(accepted)
        assert.is_false(proof.same_syntax_proven)
        assert.is_false(F.validate(seq, fact.certificate))
    end)

    it("keeps both compound and subquery proofs across token-equivalent payload edits", function()
        local lines = { "`````lua" }
        for i = 2, 6000 do lines[i] = i % 2 == 0 and "````" or "``````" end
        local seq, h = fixture(lines)
        local opts = { budget_nodes = 512, budget_entries = 1700 }
        local result = F.resolve(seq, h[1], { kind = "ordinary_close", width = 5 }, opts)
        assert.equals("budget", result.status)
        local metadata = S.at(seq, 1).metadata
        metadata.token.bytes = 40 -- trailing spaces preserve the same bare closer
        assert.is_true(S.update_text(seq, h[2], { bytes = 41, metadata = metadata }))
        local slices = 0
        repeat
            opts.cursor = result.cursor
            result = F.resolve(seq, h[1], { kind = "ordinary_close", width = 5 }, opts)
            slices = slices + 1
            assert.is_true(slices < 100)
        until result.status ~= "budget"
        assert.equals("ready", result.status)
        assert.is_false(result.fact.value)
    end)

end)
