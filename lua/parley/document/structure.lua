-- Incremental metadata publication. Neovim text remains outside this module.
local sequence = require("parley.document.sequence")
local grammar = require("parley.document.grammar")
local projection = require("parley.document.projection")
local M = {}
local documents = setmetatable({}, { __mode = "k" })
local jobs = setmetatable({}, { __mode = "k" })

local function state(document)
    return assert(documents[document], "invalid document structure")
end

local function new_sequence(spans)
    return sequence.new(spans, {
        empty_summary = grammar.empty_summary(),
        projection_summary = projection.summary,
        combine_projection = projection.combine,
        empty_projection = projection.empty(),
        channel_names = grammar.CHANNELS,
        channels = function(metadata)
            return metadata and metadata.token and grammar.channels(metadata.token) or {}
        end,
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

function M.stats(document, reset)
    return sequence.stats(state(document).index, reset)
end

local function frontier(current)
    return current.semantic and require("parley.document.semantic").confirmed_frontier(current.semantic)
        or sequence.size(current.index).rows
end
local function visible(current,row,opts,certainty)
    if row and row.metadata and current.semantic then
        row.metadata.confirmed = row.end_row <= (certainty or frontier(current)) and row.metadata.confirmed == true
        if not row.metadata.confirmed then
            if opts and opts.presentation and row.metadata.semantic then
                local sem=row.metadata.semantic
                row.metadata.presentation={footer=sem.footer,draft=sem.draft,draft_end=sem.draft_end,
                    draft_start=sem.draft_start}
            end
            row.metadata.semantic = nil
            if not (opts and opts.presentation) then row.metadata.render_before = nil end
        end
    end
    return row
end
function M.query(document, first, last, opts)
    local current = state(document)
    local rows = sequence.query(current.index, first, last, opts)
    local certainty=frontier(current)
    for _,row in ipairs(rows) do visible(current,row,opts,certainty) end
    return rows
end
function M.at(document,row,opts)
    local current=state(document)
    return visible(current,sequence.at(current.index,row),opts)
end
function M.lookup(document,handle,opts)
    local current=state(document)
    local rank=sequence.rank(current.index,handle)
    if not rank or rank.rows==0 then return nil end
    return visible(current,sequence.at(current.index,rank.row),opts)
end
local function unknown(current)
    return {status="opaque",row=frontier(current),work={nodes_visited=0,entries_visited=0}}
end
function M.exchange(document,row,opts)
    local current=state(document)
    if row>=frontier(current) then return unknown(current) end
    local result=projection.exchange(current.index,row,opts)
    if result.status=="ready" and (result.last>frontier(current) or result.last==frontier(current)
        and result.last<sequence.size(current.index).rows) then
        local refused=unknown(current);refused.work=result.work;return refused
    end
    return result
end
function M.folds(document,first,last,opts)
    local current=state(document)
    if last>frontier(current) then return unknown(current) end
    return projection.folds(current.index,first,last,opts)
end
function M.outline(document,first,last,opts)
    local current=state(document)
    if first>=frontier(current) then return unknown(current) end
    local result=projection.find(current.index,first,math.min(last,frontier(current)),
        opts and opts.is_chat and "outline_chat" or "outline",opts)
    if result.status=="not_found" and last>frontier(current) then
        local refused=unknown(current);refused.work=result.work;return refused
    end
    return result
end
function M.validate_projection(document,certificate)
    local current=state(document)
    local valid,bounds=projection.validate(current.index,certificate)
    if not valid then return false,bounds end
    if bounds.last_row>frontier(current) then return false,"unconfirmed projection" end
    return true,bounds
end

-- Prove byte authority against a confirmed semantic marker and its next
-- owning boundary. Later dirty regions do not block an already confirmed one.
function M.authority_range(document,entity,first_byte,last_byte,opts)
    local current=state(document)
    opts=opts or {}
    local initial=sequence.stats(current.index)
    local function finish(result)
        local measured=sequence.stats(current.index)
        for key,value in pairs(measured) do measured[key]=value-(initial[key] or 0) end
        result.work=measured
        return result
    end
    local nodes,entries=opts.budget_nodes or opts.nodes or 4096,opts.budget_entries or opts.entries or 8192
    local reserve=sequence.navigation_budget(current.index)
    if nodes<=reserve.nodes*3 or entries<=reserve.entries*3 then return finish({status="budget"}) end
    if type(first_byte)~="number" or type(last_byte)~="number" or first_byte<0 or last_byte<first_byte
        or last_byte==math.huge or first_byte%1~=0 or last_byte%1~=0 then return finish({status="refused"}) end
    local marker=M.lookup(document,entity)
    if not marker then return finish({status="stale"}) end
    local sem=marker.metadata and marker.metadata.semantic
    if not sem then return finish({status="opaque",row=marker.start_row}) end
    if not sem.answer_start and not sem.exchange_start then return finish({status="refused"}) end
    local used=sequence.stats(current.index)
    local remaining={budget_nodes=nodes-(used.nodes_visited-initial.nodes_visited)-reserve.nodes,
        budget_entries=entries-(used.entries_visited-initial.entries_visited)-reserve.entries}
    local limit=frontier(current)
    local found=projection.find(current.index,marker.start_row+1,limit,
        sem.answer_start and "answer_end" or "exchange",remaining)
    if found.status~="found" and found.status~="not_found" then return finish(found) end
    if not found.span and limit<sequence.size(current.index).rows then return finish({status="opaque",row=limit}) end
    local last=found.span and found.span.start_row or limit
    local upper=found.span and found.span.start_byte or sequence.size(current.index).bytes
    if first_byte<marker.start_byte or last_byte>upper then return finish({status="refused"}) end
    local certificate=sequence.range_certificate(current.index,marker.start_row,
        found.span and last+1 or last,{kind="projection"})
    if not certificate then return finish({status="opaque",row=last}) end
    return finish({status="ready",entity=entity,first_byte=first_byte,last_byte=last_byte,
        region_first_byte=marker.start_byte,region_last_byte=upper,certificate=certificate})
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

function M.replace_fragment(document, first, last, spans, budget)
    local current = state(document)
    local semantic = require("parley.document.semantic")
    current.semantic = current.semantic or semantic.new(current.index)
    local initial = sequence.stats(current.index)
    local evidence = semantic.before_fragment(current.semantic, first, last, spans, budget)
    sequence.splice(current.index, first, last, spans)
    local added = 0
    for _, span in ipairs(spans) do added = added + span.rows end
    local result = semantic.after_fragment(current.semantic, evidence, first, first + added)
    result.reused_suffix = result.status == "reused"
    result.work = result.work or {}
    for key, value in pairs(sequence.stats(current.index)) do result.work[key] = value - (initial[key] or 0) end
    return result
end

function M.reload(document, spans)
    local current = state(document)
    current.index = new_sequence(spans)
    current.epoch = current.epoch + 1
    current.lexer, current.semantic, current.read_pending = nil, nil, nil
end

-- A job proves only local text identity. It cannot authorize semantic state;
-- only the semantic worker validates context and publishes derived metadata.
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
    if #spans > 256 then return { status = "invalid_extent" } end
    for _, span in ipairs(spans) do
        if span.opaque or span.rows ~= 1 or type(span.metadata) ~= "table"
            or type(span.metadata.token) ~= "table" then
            return { status = "invalid_metadata" }
        end
        for key in pairs(span.metadata) do
            if key ~= "token" then return { status = "invalid_metadata" } end
        end
    end
    local existing = sequence.query(current.index, extent.first_row, extent.last_row, { limit = 257 })
    local equivalent = #existing == #spans
    for i, span in ipairs(spans) do
        local old = existing[i]
        if not old or old.opaque or old.rows ~= 1 or old.bytes ~= span.bytes
            or not old.metadata or not old.metadata.token
            or not grammar.same_token(old.metadata.token, span.metadata.token) then
            equivalent = false
            break
        end
    end
    -- Equivalent lexical results leave current semantic metadata and row
    -- identities intact, including newer context settled while this job ran.
    -- Changed lexical results use the normal semantic invalidation path.
    if not equivalent then
        M.splice(document, extent.first_row, extent.last_row, spans)
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
