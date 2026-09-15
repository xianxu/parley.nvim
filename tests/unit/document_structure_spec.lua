local structure = require("parley.document.structure")

local function span(text)
    return { rows = 1, bytes = #text + 1, metadata = { text_id = text } }
end

local function document()
    return structure.new({ span("first"), span("middle"), span("last") })
end

describe("incremental structure publication", function()
    it("preserves confirmed row identity when publishing metadata", function()
        local doc = document()
        local before = structure.query(doc, 0, 2)
        local job = structure.capture(doc, 0, 2)
        local first = span("first")
        first.metadata.confirmed = true
        assert.equals("published", structure.publish(doc, job, { first, span("middle") }).status)
        local after = structure.query(doc, 0, 2)
        assert.equals(before[1].handle, after[1].handle)
        assert.equals(before[2].handle, after[2].handle)
        assert.is_true(after[1].metadata.confirmed)
    end)

    it("publishes a locally valid repair after an unrelated edit", function()
        local doc = document()
        local job = structure.capture(doc, 0, 1)
        structure.splice(doc, 2, 3, { span("changed elsewhere") })
        local result = structure.publish(doc, job, { span("first") })
        assert.equals("published", result.status)
        assert.equals("changed elsewhere", structure.query(doc, 2, 3)[1].metadata.text_id)
    end)

    it("rejects stale repair despite replacement having identical size", function()
        local doc = document()
        local job = structure.capture(doc, 0, 1)
        structure.splice(doc, 0, 1, { span("other") })
        local result = structure.publish(doc, job, { span("first") })
        assert.equals("stale", result.status)
        assert.equals("other", structure.query(doc, 0, 1)[1].metadata.text_id)
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
        assert.equals("first", structure.query(doc, 0, 1)[1].metadata.text_id)
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
