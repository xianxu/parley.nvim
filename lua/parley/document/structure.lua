-- Incremental metadata publication. Neovim text remains outside this module.
local sequence = require("parley.document.sequence")
local grammar = require("parley.document.grammar")
local M = {}
local documents = setmetatable({}, { __mode = "k" })
local jobs = setmetatable({}, { __mode = "k" })

local function state(document)
    return assert(documents[document], "invalid document structure")
end

local function new_sequence(spans)
    return sequence.new(spans, {
        empty_summary = grammar.empty_summary(),
        summarize = function(metadata)
            return metadata and metadata.token and grammar.summary(metadata.token) or grammar.empty_summary()
        end,
        combine = grammar.combine,
    })
end

function M.new(spans, patterns)
    local document = {}
    documents[document] = { index = new_sequence(spans), epoch = 1, patterns = patterns }
    return document
end

function M.size(document)
    return sequence.size(state(document).index)
end

function M.query(document, first, last, opts)
    local current = state(document)
    local rows = sequence.query(current.index, first, last, opts)
    if current.semantic then
        local semantic = require("parley.document.semantic")
        for _, row in ipairs(rows) do
            if row.metadata then
                row.metadata.confirmed = semantic.is_confirmed(current.semantic, row.handle)
                if not row.metadata.confirmed then
                    row.metadata.semantic, row.metadata.render_before = nil, nil
                end
            end
        end
    end
    return rows
end

function M.splice(document, first, last, spans, opts)
    local current = state(document)
    local evidence
    if current.semantic then
        evidence = require("parley.document.semantic").before_splice(current.semantic, first, last)
    end
    sequence.splice(current.index, first, last, spans, opts)
    if current.semantic then
        local added = 0
        for _, span in ipairs(spans) do added = added + span.rows end
        require("parley.document.semantic").after_splice(current.semantic, evidence, first, first + added)
    end
end

-- Observe a classified single-row text replacement. Callers must obtain token
-- through the bounded lexer; unread/structural range edits use splice instead.
function M.replace_row(document, row, token, bytes)
    local current = state(document)
    local old = sequence.at(current.index, row)
    assert(old and not old.opaque and old.rows == 1 and old.metadata and old.metadata.token,
        "single-row replacement requires confirmed lexical metadata")
    local equivalent = grammar.same_token(old.metadata.token, token)
    local semantic = current.semantic and require("parley.document.semantic")
    local evidence = semantic and not equivalent
        and semantic.before_splice(current.semantic, row, row + 1) or nil
    local metadata = old.metadata
    metadata.token = token
    local ok, result = sequence.update_text(current.index, old.handle, { bytes = bytes, metadata = metadata })
    assert(ok, result)
    assert(result.same_syntax_proven == equivalent, "lexical equivalence disagrees with indexed proof")
    if evidence then semantic.after_splice(current.semantic, evidence, row, row + 1) end
    return result
end

function M.reload(document, spans)
    local current = state(document)
    current.index = new_sequence(spans)
    current.epoch = current.epoch + 1
    current.lexer, current.semantic, current.read_pending = nil, nil, nil
end

-- A job holds a local certificate, not a document-wide changedtick or old tree.
function M.capture(document, first, last)
    local current = state(document)
    local certificate, reason = sequence.range_certificate(current.index, first, last)
    if not certificate then return nil, reason end
    local extent = assert(sequence.summary(current.index, first, last))
    local job = {}
    jobs[job] = {
        document = document, epoch = current.epoch, certificate = certificate,
        rows = extent.rows, bytes = extent.bytes,
    }
    return job
end

function M.publish(document, job, spans)
    local current, captured = state(document), jobs[job]
    if not captured or captured.document ~= document or captured.epoch ~= current.epoch then
        return { status = "stale" }
    end
    local valid, extent = sequence.validate_certificate(current.index, captured.certificate)
    if not valid then jobs[job] = nil; return { status = "stale" } end
    local rows, bytes = 0, 0
    for _, span in ipairs(spans) do
        rows, bytes = rows + span.rows, bytes + span.bytes
    end
    if rows ~= captured.rows or bytes ~= captured.bytes then
        return { status = "invalid_extent" }
    end
    local existing = sequence.query(current.index, extent.first_row, extent.last_row, { limit = 257 })
    local updates = {}
    local compatible = #existing == #spans and #spans <= 256
    for i, span in ipairs(spans) do
        local old = existing[i]
        if not old or old.opaque or span.opaque or old.rows ~= span.rows or old.bytes ~= span.bytes then
            compatible = false
            break
        end
        updates[i] = { handle = old.handle, metadata = span.metadata }
    end
    if compatible then
        assert(sequence.update_many(current.index, updates))
    else
        sequence.splice(current.index, extent.first_row, extent.last_row, spans)
    end
    jobs[job] = nil
    return { status = "published", first_row = extent.first_row, last_row = extent.last_row }
end

-- One call performs one semantic slice or one bounded lexical read transition.
-- The caller owns reading text and scheduling the next turn.
function M.repair_step(document, input, budget)
    local current = state(document)
    local lexer = require("parley.document.lexer")
    local semantic = require("parley.document.semantic")
    budget = budget or {}
    local before = sequence.stats(current.index)
    local function finish(result, earlier)
        local work = result.work or {}
        for key, value in pairs(earlier or {}) do work[key] = (work[key] or 0) + value end
        for key, value in pairs(sequence.stats(current.index)) do work[key] = value - (before[key] or 0) end
        work.rows_processed = (work.rows_processed or 0) + (work.rows_materialized or 0)
        result.work = work
        return result
    end
    current.lexer = current.lexer or lexer.new(current.index, current.patterns)
    current.semantic = current.semantic or semantic.new(current.index)
    if input or current.read_pending then
        local result = lexer.step(current.lexer, input, budget)
        current.read_pending = result.status == "read"
        return finish(result)
    end
    local result = semantic.step(current.semantic, budget)
    if result.status == "opaque" then
        lexer.demand(current.lexer, result.row)
        local read = lexer.step(current.lexer, nil, budget)
        read.deltas = result.deltas
        current.read_pending = read.status == "read"
        return finish(read, result.work)
    end
    return finish(result)
end

return M
