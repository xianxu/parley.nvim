-- Pure indexed lookahead. A cursor retains one proof for the entire compound
-- query, so resuming a later subquery never forgets its earlier evidence.
local M = {}
local S = require("parley.document.sequence")
local G = require("parley.document.grammar")
local cursors = setmetatable({}, { __mode = "k" })
-- Facts depend on complete lexical descriptors, not payload bytes. These
-- explicit proofs must never be accepted as ordinary text/publication proofs.
local SYNTAX = { kind = "syntax" }

local function copy(value)
    local out = {}
    for key, item in pairs(value) do out[key] = item end
    return out
end

local function selector(kind, width)
    return { kind = kind, width = width }
end

function M.resolve(seq, token_handle, need, opts)
    opts = opts or {}
    local initial = S.stats(seq)
    local node_limit, entry_limit = opts.budget_nodes or 2048, opts.budget_entries or 4096
    local reserve = S.navigation_budget(seq)
    local function work()
        local out = S.stats(seq)
        for key, value in pairs(out) do out[key] = value - (initial[key] or 0) end
        return out
    end
    local function finish(result)
        result.work = work()
        return result
    end
    -- Reserve rank/proof setup plus final certificate before doing any work.
    if node_limit <= reserve.nodes * 3 or entry_limit <= reserve.entries * 3 then
        return finish({ status = "budget", cursor = opts.cursor,
            required = { budget_nodes = reserve.nodes * 3 + 1, budget_entries = reserve.entries * 3 + 1 } })
    end
    local function opaque_boundary(first, last)
        -- Range proofs fail at partial endpoint spans. Demand that unknown
        -- endpoint, never an already-confirmed origin that cannot make progress.
        local a = S.at(seq, first)
        if a and a.opaque and first > a.start_row then return first end
        local z = last > first and S.at(seq, last - 1) or a
        if z and z.opaque and last < z.end_row then return last - 1 end
        error("uncertifiable range has no partial opaque endpoint")
    end
    local state
    if opts.cursor then
        local saved = cursors[opts.cursor]
        if not saved or saved.seq ~= seq or saved.origin ~= token_handle or saved.kind ~= need.kind
            or saved.width ~= need.width or saved.scope_end ~= (need.scope and need.scope["end"]) then
            return finish({ status = "stale" })
        end
        if not S.validate_certificate(seq, saved.proof, SYNTAX) then return finish({ status = "stale" }) end
        state = copy(saved)
    else
        state = { seq = seq, origin = token_handle, kind = need.kind, width = need.width,
            scope_end = need.scope and need.scope["end"] }
    end
    local origin = S.rank(seq, token_handle)
    local boundary = state.scope_end or S.eof(seq)
    local limit = S.rank(seq, boundary)
    if not origin or not limit then return finish({ status = "stale" }) end
    local total = S.size(seq).rows
    local global = need.kind == "header" or need.kind == "footer"
    local first = global and 0 or origin.row
    if origin.row > limit.row then return finish({ status = "stale" }) end
    if not state.proof then
        local proof_last = math.min(total, limit.row + (boundary ~= S.eof(seq) and 1 or 0))
        state.proof = S.range_certificate(seq, first, proof_last, SYNTAX)
        if not state.proof then return finish({ status = "opaque", row = opaque_boundary(first, proof_last) }) end
        state.phase = ({ header = "header_probe", footer = "footer_find", tool_body = "tool_open",
            section_tool_body = "tool_open", ordinary_close = "ordinary", section_ordinary_close = "ordinary",
            reasoning = "reasoning", preface = "preface" })[need.kind]
        assert(state.phase, "unknown indexed fact kind: " .. tostring(need.kind))
        state.cert_origin = global and (S.at(seq, 0) or {}).handle or token_handle
        state.cert_origin = state.cert_origin or S.eof(seq)
    end
    local function pause(required)
        local token = {}
        cursors[token] = state
        return finish({ status = "budget", cursor = token, required = required })
    end
    local function complete(value, last_handle, last_row)
        local range = S.range_certificate(seq, first, math.min(total, last_row + 1), SYNTAX)
        if not range then
            return finish({ status = "opaque", row = opaque_boundary(first, math.min(total, last_row + 1)) })
        end
        return finish({ status = "ready", fact = { value = value,
            certificate = { origin = state.cert_origin, last = last_handle, range = range } } })
    end
    local function negative()
        return complete(false, boundary, limit.row)
    end
    while true do
        local from, to, reverse, selectors
        local phase = state.phase
        if phase == "header_probe" then from, to = 0, math.min(1, total)
        elseif phase == "header_find" then from, to = state.header_from, total; selectors = { selector("divider") }
        elseif phase == "footer_find" then from, to = 0, total; selectors = { selector("footnote") }
        elseif phase == "footer_previous" then
            local footnote = S.rank(seq, state.footnote)
            if not footnote then return finish({ status = "stale" }) end
            from, to, reverse = 0, footnote.row, true
            selectors = { selector("nonblank") }
        elseif phase == "tool_open" or phase == "preface" then
            from, to = math.min(origin.row + 1, limit.row), math.min(origin.row + 2, limit.row)
        elseif phase == "tool_find" then
            local opener = S.rank(seq, state.opener)
            if not opener then return finish({ status = "stale" }) end
            from, to = opener.row + 1, limit.row
            selectors = { selector("bare_close", state.tool_width), selector("structural") }
        elseif phase == "ordinary" then
            from, to = math.min(origin.row + 1, limit.row), limit.row
            selectors = { selector("bare_close", need.width) }
        elseif phase == "reasoning" then
            from, to = math.min(origin.row + 1, limit.row), limit.row
            selectors = { selector("reasoning_boundary") }
        end
        local used = work()
        local remaining_nodes = node_limit - used.nodes_visited - reserve.nodes
        local remaining_entries = entry_limit - used.entries_visited - reserve.entries
        if remaining_nodes <= reserve.nodes or remaining_entries <= reserve.entries then
            return pause({ budget_nodes = used.nodes_visited + reserve.nodes * 2 + 1,
                budget_entries = used.entries_visited + reserve.entries * 2 + 1 })
        end
        local result = S.find(seq, from, to, {
            max_nodes = remaining_nodes, max_entries = remaining_entries,
            cursor = state.query_cursor, reverse = reverse, certificate_kind = "syntax",
            may_match = selectors and function(summary)
                for _, item in ipairs(selectors) do if G.may_contain(summary, item) then return true end end
                return false
            end or nil,
            matches = selectors and function(metadata)
                assert(metadata.token, "confirmed sequence entry requires a lexical token")
                for _, item in ipairs(selectors) do if G.select(metadata.token, item) then return true end end
                return false
            end or nil,
        })
        if result.status == "budget" then state.query_cursor = result.cursor; return pause() end
        if result.status == "stale" then return finish({ status = "stale" }) end
        if result.status == "opaque" then
            return finish({ status = "opaque", row = result.span and result.span.start_row or from })
        end
        state.query_cursor = nil
        local span = result.span
        local token = span and span.metadata and span.metadata.token
        if span and not token then return finish({ status = "opaque", row = span.start_row }) end
        if phase == "header_probe" then
            if not span then return negative() end
            state.header_from = token.divider and 1 or 0
            state.phase = "header_find"
        elseif phase == "header_find" then
            if not span then return negative() end
            return complete({ finish = span.handle }, span.handle, span.start_row)
        elseif phase == "footer_find" then
            if not span then return negative() end
            state.footnote = span.handle
            state.phase = "footer_previous"
        elseif phase == "footer_previous" then
            local footnote = S.rank(seq, state.footnote)
            if not footnote then return finish({ status = "stale" }) end
            return complete({ start = state.footnote,
                content_start = token and token.divider and span.handle or state.footnote },
                state.footnote, footnote.row)
        elseif phase == "tool_open" then
            if not span then return negative() end
            if not token.ordinary_open_width then return complete(false, span.handle, span.start_row) end
            state.opener, state.tool_width = span.handle, token.ordinary_open_width
            state.phase = "tool_find"
        elseif phase == "tool_find" then
            if not span then return negative() end
            return complete(token.bare_close_width == state.tool_width and { close = span.handle } or false,
                span.handle, span.start_row)
        elseif phase == "ordinary" then
            if not span then return negative() end
            return complete(span.handle, span.handle, span.start_row)
        elseif phase == "reasoning" then
            if not span then return negative() end
            return complete(token.kind == "reasoning_end", span.handle, span.start_row)
        elseif phase == "preface" then
            if not span then return negative() end
            return complete(token.kind == "user", span.handle, span.start_row)
        end
    end
end

return M
