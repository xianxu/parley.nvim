local structure = require("parley.document.structure")

local function span(text)
    local grammar = require("parley.document.grammar")
    local lexer = grammar.lex_start(require("parley.highlight_structure").patterns({}))
    local _, token = grammar.lex_step(lexer, text, true)
    return { rows = 1, bytes = #text + 1, metadata = { token = token } }
end

local function document()
    return structure.new({ span("first"), span("middle"), span("last") })
end

describe("incremental structure publication", function()
    it("preserves row identity when publishing equivalent lexical metadata", function()
        local doc = document()
        local before = structure.query(doc, 0, 2)
        local job = structure.capture(doc, 0, 2)
        local first = span("first")
        assert.equals("published", structure.publish(doc, job, { first, span("middle") }).status)
        local after = structure.query(doc, 0, 2)
        assert.equals(before[1].handle, after[1].handle)
        assert.equals(before[2].handle, after[2].handle)
        assert.same(first.metadata.token, after[1].metadata.token)
    end)

    it("publishes a locally valid repair after an unrelated edit", function()
        local doc = document()
        local job = structure.capture(doc, 0, 1)
        structure.splice(doc, 2, 3, { span("changed elsewhere") })
        local result = structure.publish(doc, job, { span("first") })
        assert.equals("published", result.status)
        assert.equals(#"changed elsewhere" + 1, structure.query(doc, 2, 3)[1].bytes)
    end)

    it("rejects stale repair despite replacement having identical size", function()
        local doc = document()
        local job = structure.capture(doc, 0, 1)
        structure.splice(doc, 0, 1, { span("other") })
        local result = structure.publish(doc, job, { span("first") })
        assert.equals("stale", result.status)
        assert.same(span("other").metadata.token, structure.query(doc, 0, 1)[1].metadata.token)
    end)

    it("cannot reuse a consumed repair authority", function()
        local doc = document()
        local job = structure.capture(doc, 1, 2)
        assert.equals("published", structure.publish(doc, job, { span("middle") }).status)
        assert.equals("stale", structure.publish(doc, job, { span("middle") }).status)
    end)

    it("does not accept a repair from another document or reload epoch", function()
        local doc, other = document(), document()
        local job = structure.capture(doc, 1, 2)
        assert.equals("stale", structure.publish(other, job, { span("middle") }).status)
        structure.reload(doc, { span("reloaded") })
        assert.equals("stale", structure.publish(doc, job, { span("middle") }).status)
    end)

    it("publishes only metadata with the captured row and byte extent", function()
        local doc = document()
        local job = structure.capture(doc, 0, 1)
        assert.equals("invalid_extent", structure.publish(doc, job, { span("much longer") }).status)
        assert.equals(#"first" + 1, structure.query(doc, 0, 1)[1].bytes)
    end)

    it("keeps unread bulk text opaque without per-row allocation", function()
        local doc = structure.new({ { rows = 1000000, bytes = 2000000, opaque = true } })
        local result = structure.query(doc, 200, 201)
        assert.equals(1, #result)
        assert.is_true(result[1].opaque)
        assert.equals(1000000, structure.size(doc).rows)
        assert.is_nil(result[1].metadata)
    end)
end)

local function settle(doc, lines, budget)
    assert.equals("function", type(structure.repair_step))
    local input
    for _ = 1, 10000 do
        local result = structure.repair_step(doc, input, budget)
        input = nil
        if result.status == "idle" then return end
        if result.status == "read" then
            local request = result.request
            local line = assert(lines[request.row + 1])
            local bytes = line:sub(request.col + 1, request.col + request.max_bytes)
            local start_byte = 0
            for i = 1, request.row do start_byte = start_byte + #lines[i] + 1 end
            input = { request_id = request.request_id, bytes = bytes,
                eol = request.col + #bytes == #line, start_byte = start_byte }
        end
        if result.work then
            assert.is_true((result.work.bytes_scanned or 0) <= (budget.bytes or 65536))
            assert.is_true((result.work.rows_processed or 0) <= (budget.rows or 256))
        end
    end
    error("repair failed to settle")
end

local function opaque_document(lines)
    local bytes = 0
    for _, line in ipairs(lines) do bytes = bytes + #line + 1 end
    return structure.new({ { rows = #lines, bytes = bytes, opaque = true } },
        require("parley.highlight_structure").patterns({}))
end

describe("document repair orchestration", function()
    it("rejects old semantic publication after a disjoint context change", function()
        local lines = { "💬: q", "one", "two", "three", "four" }
        local doc = opaque_document(lines)
        settle(doc, lines, { rows = 256 })
        local captured = structure.query(doc, 3, 4)[1]
        local job = structure.capture(doc, 3, 4)
        lines[1] = "🤖: a"
        structure.splice(doc, 0, 1, { span(lines[1]) })
        settle(doc, lines, { rows = 256 })
        assert.equals("answer", structure.query(doc, 3, 4)[1].metadata.semantic.role)
        assert.equals("invalid_metadata", structure.publish(doc, job, {
            { rows = 1, bytes = captured.bytes, metadata = captured.metadata },
        }).status)
        for _, key in ipairs({ "confirmed", "before", "after", "semantic", "render_before",
            "answer_header", "section", "section_before", "section_after" }) do
            local candidate = span(lines[4])
            candidate.metadata[key] = true
            assert.equals("invalid_metadata", structure.publish(doc, job, { candidate }).status)
        end
        assert.equals("published", structure.publish(doc, job, { span(lines[4]) }).status)
        local current = structure.query(doc, 3, 4)[1]
        assert.equals(captured.handle, current.handle)
        assert.equals("answer", current.metadata.semantic.role)
        assert.is_true(current.metadata.confirmed)
    end)

    it("invalidates semantics when a lexical publication changes classification", function()
        local lines = { "💬: q", "one", "two" }
        local doc = opaque_document(lines)
        settle(doc, lines, { rows = 256 })
        local job = structure.capture(doc, 0, 1)
        -- A corrected classification for the same certified bytes cannot carry
        -- any old derived state into the repair worker.
        local candidate = span("🤖: a")
        assert.equals("published", structure.publish(doc, job, { candidate }).status)
        assert.is_nil(structure.query(doc, 2, 3)[1].metadata.semantic)
        settle(doc, lines, { rows = 256 })
        assert.equals("answer", structure.query(doc, 2, 3)[1].metadata.semantic.role)
    end)

    it("settles opaque text into confirmed exchanges through bounded reads", function()
        local lines = { "💬: question", "🤖: answer", "body", "💬: next", "draft" }
        local doc = opaque_document(lines)
        settle(doc, lines, { bytes = 4, rows = 2 })
        local rows = structure.query(doc, 0, #lines)
        assert.equals(#lines, #rows)
        assert.is_true(rows[1].metadata.semantic.exchange_start)
        assert.is_true(rows[2].metadata.semantic.answer_start)
        assert.equals("answer", rows[3].metadata.semantic.role)
        assert.is_true(rows[4].metadata.semantic.exchange_start)
        assert.equals("question", rows[5].metadata.semantic.role)
    end)

    it("reconciles partial exchange deletion without manufacturing deleted identities", function()
        local lines = { "💬: first", "🤖: answer", "body", "💬: second", "🤖: result" }
        local doc = opaque_document(lines)
        settle(doc, lines, { bytes = 32, rows = 2 })
        local old = structure.query(doc, 3, 4)[1].handle
        structure.splice(doc, 1, 4, { { rows = 1, bytes = 5, opaque = true } })
        lines = { "💬: first", "join", "🤖: result" }
        settle(doc, lines, { bytes = 32, rows = 2 })
        local rows = structure.query(doc, 0, 3)
        assert.equals("question", rows[2].metadata.semantic.role)
        assert.is_true(rows[3].metadata.semantic.answer_start)
        for _, row in ipairs(rows) do assert.is_not.equals(old, row.handle) end
    end)
end)

describe("settled document compatibility", function()
    it("matches independent exchange and section oracles on malformed dialect fixtures", function()
        local parser = require("parley.chat_parser")
        for _, case in ipairs(require("tests.fixtures.document_edits")) do
            local doc = opaque_document(case.lines)
            settle(doc, case.lines, { bytes = 7, rows = 2 })
            local rows = structure.query(doc, 0, #case.lines)
            local starts, answers = {}, {}
            for i, row in ipairs(rows) do
                assert.is_true(row.metadata.confirmed, case.name .. " row " .. i)
                if row.metadata.semantic.exchange_start then starts[#starts + 1] = i end
                if row.metadata.semantic.answer_start then answers[#answers + 1] = i end
            end
            assert.same(case.exchange_rows, starts, case.name)
            assert.same(case.answer_rows, answers, case.name)
            local parsed = parser.parse_chat(case.lines, 0, {})
            for _, exchange in ipairs(parsed.exchanges) do
                for _, section in ipairs(exchange.answer and exchange.answer.semantic_sections or {}) do
                    for i = section.line_start, section.line_end do
                        if not rows[i].metadata.token.blank then
                            assert.equals(section.kind, rows[i].metadata.semantic.section_kind,
                                case.name .. " row " .. i)
                        end
                    end
                end
            end
        end
    end)
end)

describe("arbitrary incremental transcript edits", function()
    it("settles seeded range edits to the full parser's exchange boundaries", function()
        local lines = { "💬: first", "🤖: answer", "plain", "💬: next", "draft" }
        local doc = opaque_document(lines)
        local seed = 254
        local function random(n) seed = seed * 16807 % 2147483647; return seed % n end
        local atoms = { "plain", "", "💬: next", "📎: result", "```", "```lua", "🧠: think",
            "🧠:[END]", "🔒: note", "@@tag@@", "📝: sum" }
        local parser = require("parley.chat_parser")
        for iteration = 1, 100 do
            settle(doc, lines, { bytes = 9, rows = 3 })
            local parsed = parser.parse_chat(lines, 0, {})
            local expected, actual = {}, {}
            for _, exchange in ipairs(parsed.exchanges) do expected[#expected + 1] = exchange.question.line_start end
            for i, row in ipairs(structure.query(doc, 0, #lines)) do
                if row.metadata.semantic.exchange_start then actual[#actual + 1] = i end
            end
            assert.same(expected, actual, "iteration " .. iteration)
            local first = 1 + random(#lines)
            local count = math.min(random(4), #lines - first)
            local added, spans = {}, {}
            for i = 1, random(4) do
                added[i] = atoms[random(#atoms) + 1]
                spans[i] = { rows = 1, bytes = #added[i] + 1, opaque = true }
            end
            structure.splice(doc, first, first + count, spans)
            for _ = 1, count do table.remove(lines, first + 1) end
            for i = #added, 1, -1 do table.insert(lines, first + 1, added[i]) end
        end
    end)
end)

local function classified(line)
    local grammar = require("parley.document.grammar")
    local _, token = grammar.lex_step(grammar.lex_start(), line, true, { bytes = #line })
    return token
end

describe("ordinary body edit repair", function()
    it("keeps confirmed syntax and invalidates old text publication without a suffix scan", function()
        local lines = { "💬: question", "🤖: answer", "body", "💬: next", "draft" }
        local doc = opaque_document(lines)
        settle(doc, lines, { bytes = 32, rows = 2 })
        local before = structure.query(doc, 0, 5)
        local old_text = structure.capture(doc, 4, 5)
        assert.equals("function", type(structure.replace_row))
        local changed = "draft with more text"
        local result = structure.replace_row(doc, 4, classified(changed), #changed + 1)
        assert.is_true(result.same_syntax_proven)
        local repair = structure.repair_step(doc, nil, { bytes = 32, rows = 2 })
        assert.equals("idle", repair.status)
        assert.equals(0, repair.work.rows_processed)
        local after = structure.query(doc, 0, 5)
        for i = 1, 5 do
            assert.equals(before[i].handle, after[i].handle)
            assert.is_true(after[i].metadata.confirmed)
        end
        assert.equals("stale", structure.publish(doc, old_text, { span("draft") }).status)
    end)

    it("invalidates dependent semantics when a same-row edit introduces syntax", function()
        local lines = { "💬: question", "🤖: answer", "body", "tail" }
        local doc = opaque_document(lines)
        settle(doc, lines, { bytes = 32, rows = 2 })
        assert.equals("function", type(structure.replace_row))
        local changed = "💬: next"
        local result = structure.replace_row(doc, 2, classified(changed), #changed + 1)
        assert.is_false(result.same_syntax_proven)
        lines[3] = changed
        assert.is_nil(structure.query(doc, 3, 4)[1].metadata.semantic)
        settle(doc, lines, { bytes = 32, rows = 2 })
        assert.equals("question", structure.query(doc, 3, 4)[1].metadata.semantic.role)
    end)
end)

describe("bounded classified fragment replacement", function()
    it("reuses confirmed suffix after Enter and join while retiring old text evidence", function()
        local lines = { "💬: q", "🤖: a", "first second", "tail", "💬: next", "draft" }
        local doc = opaque_document(lines)
        settle(doc, lines, { bytes = 32, rows = 2 })
        assert.equals("function", type(structure.replace_fragment))
        local suffix = structure.query(doc, 3, 6)
        local old_text = structure.capture(doc, 2, 3)
        local result = structure.replace_fragment(doc, 2, 3, {
            { rows = 1, bytes = 6, metadata = { token = classified("first") } },
            { rows = 1, bytes = 7, metadata = { token = classified("second") } },
        }, { rows = 4, bytes = 64 })
        assert.is_true(result.reused_suffix)
        assert.equals("idle", structure.repair_step(doc).status)
        local after = structure.query(doc, 4, 7)
        for i = 1, 3 do
            assert.equals(suffix[i].handle, after[i].handle)
            assert.is_true(after[i].metadata.confirmed)
        end
        assert.equals("stale", structure.publish(doc, old_text, { span("first second") }).status)
        result = structure.replace_fragment(doc, 2, 4, {
            { rows = 1, bytes = 13, metadata = { token = classified("first second") } },
        }, { rows = 4, bytes = 64 })
        assert.is_true(result.reused_suffix)
        assert.equals(suffix[1].handle, structure.query(doc, 3, 4)[1].handle)
    end)

    it("does not reuse a suffix when an inserted blank ends implicit reasoning", function()
        local lines = { "💬: q", "🤖: a", "🧠: thought", "continued", "tail" }
        local doc = opaque_document(lines)
        settle(doc, lines, { bytes = 32, rows = 2 })
        assert.equals("function", type(structure.replace_fragment))
        local result = structure.replace_fragment(doc, 3, 3, {
            { rows = 1, bytes = 1, metadata = { token = classified("") } },
        }, { rows = 4, bytes = 64 })
        assert.is_false(result.reused_suffix)
        table.insert(lines, 4, "")
        settle(doc, lines, { bytes = 32, rows = 2 })
        assert.equals("text", structure.query(doc, 4, 5)[1].metadata.semantic.section_kind)
    end)
end)

describe("repair read lifetime", function()
    it("rejects a pending byte response after reload and repairs the new epoch", function()
        local lines = { "💬: first", "body" }
        local doc = opaque_document(lines)
        local request
        for _ = 1, 100 do
            local result = structure.repair_step(doc, nil, { bytes = 4, rows = 1 })
            if result.status == "read" then request = result.request; break end
        end
        assert.is_table(request)
        local changed = { "💬: other", "tail" }
        local bytes = #changed[1] + #changed[2] + 2
        structure.reload(doc, { { rows = 2, bytes = bytes, opaque = true } })
        local result = structure.repair_step(doc, { request_id = request.request_id,
            bytes = lines[1]:sub(1, 4), eol = false, start_byte = 0 }, { bytes = 4, rows = 1 })
        assert.equals("stale", result.status)
        settle(doc, changed, { bytes = 4, rows = 1 })
        assert.is_true(structure.query(doc, 0, 1)[1].metadata.semantic.exchange_start)
    end)
end)

describe("viewport query work", function()
    it("checks certainty once for a visible range without resolving each row again", function()
        local lines = { "💬: question" }
        for i = 2, 300 do lines[i] = "body" end
        local doc = opaque_document(lines)
        settle(doc, lines, { bytes = 64, rows = 8 })
        assert.equals("function", type(structure.stats))
        structure.stats(doc, true)
        local rows = structure.query(doc, 128, 160)
        local work = structure.stats(doc)
        assert.equals(32, #rows)
        for _, row in ipairs(rows) do assert.is_true(row.metadata.confirmed) end
        -- Materialized leaves may contain one row: allow their binary traversal
        -- plus boundary paths, but no second per-row rank/metadata lookup.
        assert.is_true(work.nodes_visited <= 2 * #rows + 32, "viewport query visited " .. work.nodes_visited .. " nodes")
    end)
end)

describe('shared live projection queries', function()
    it('resolves containing spans and stable handles with bounded navigation', function()
        local doc = structure.new({{rows=50000,bytes=100000,opaque=true}})
        structure.stats(doc,true)
        local row=structure.at(doc,25000)
        assert.equals(0,row.start_row); assert.equals(50000,row.end_row)
        assert.equals(row.handle,structure.lookup(doc,row.handle).handle)
        assert.is_true(structure.stats(doc).nodes_visited<32)
        structure.splice(doc,0,50000,{span('replacement')})
        assert.is_nil(structure.lookup(doc,row.handle))
    end)
    it('exposes confirmed projections and gates stale semantics while preserving presentation', function()
        local lines={'💬: q','🤖: a','📝: summary','body','💬: next'}
        local doc=opaque_document(lines)
        settle(doc,lines,{bytes=32,rows=2})
        local row=structure.at(doc,3)
        assert.is_true(row.metadata.confirmed)
        assert.equals('ready',structure.exchange(doc,3).status)
        assert.equals(1,#structure.folds(doc,0,4).ranges)
        assert.equals(0,structure.outline(doc,0,5,{is_chat=true}).span.start_row)
        local proof=structure.folds(doc,2,4).certificate
        structure.replace_row(doc,0,classified('body'),5)
        assert.is_false(structure.validate_projection(doc,proof))
        assert.is_nil(structure.lookup(doc,row.handle).metadata.semantic)
        assert.is_nil(structure.lookup(doc,row.handle).metadata.render_before)
        assert.is_table(structure.lookup(doc,row.handle,{presentation=true}).metadata.render_before)
        assert.is_table(structure.lookup(doc,row.handle,{presentation=true}).metadata.presentation)
        assert.equals('opaque',structure.folds(doc,0,4).status)
    end)
end)

describe('scoped marker authority',function()
    it('proves an answer range and excludes later answers within its exchange',function()
        local lines={'💬: q','🤖: a','body','🤖: another','other','💬: later','tail'}
        local doc=opaque_document(lines)
        settle(doc,lines,{bytes=32,rows=2})
        local marker=structure.at(doc,1)
        local body=structure.at(doc,2)
        local result=structure.authority_range(doc,marker.handle,body.start_byte,body.end_byte)
        assert.equals('ready',result.status)
        assert.is_true(structure.validate_projection(doc,result.certificate))
        local another=structure.at(doc,4)
        assert.equals('refused',structure.authority_range(doc,marker.handle,another.start_byte,another.end_byte).status)
        structure.replace_row(doc,6,classified('💬: changed'),#'💬: changed'+1)
        assert.equals('opaque',structure.authority_range(doc,marker.handle,body.start_byte,body.end_byte).status)
        for _=1,30 do
            structure.repair_step(doc,nil,{rows=1})
            result=structure.authority_range(doc,marker.handle,body.start_byte,body.end_byte)
            if result.status=='ready' then break end
        end
        assert.equals('ready',result.status)
        assert.is_false(structure.at(doc,6).metadata.confirmed)
        assert.equals('budget',structure.authority_range(doc,marker.handle,body.start_byte,body.end_byte,
            {budget_nodes=1,budget_entries=1}).status)
    end)
end)
