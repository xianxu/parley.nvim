-- Direct pure-core work measurements. Fixtures and index construction are
-- outside the timed window; this does not claim live-editor migration results.
local M = {}
local S = require("parley.document.sequence")
local G = require("parley.document.grammar")
local D = require("parley.document.dependencies")
local F = require("parley.document.facts")
local L = require("parley.document.lexer")
local Semantic = require("parley.document.semantic")
local harness = require("tests.perf.harness")
local typing = require("tests.perf.chat_typing")
local PHASES = { "typed_row", "sequence_splice", "bulk_paste_delete", "dependency_eof", "fact_footer", "long_line", "fragment_enter_join" }

local function value(line)
    local _, token = G.lex_step(G.lex_start(), line, true, { bytes = #line })
    return { rows = 1, bytes = #line + 1, metadata = { token = token } }
end

local function work(stats, extra)
    local out = {}
    for _, field in ipairs(harness.WORK_FIELDS) do out[field] = 0 end
    out.index_nodes_visited = stats.nodes_visited
    out.index_entries_visited = stats.entries_visited
    out.metadata_values_copied = stats.metadata_values_copied
    out.summary_values_copied = stats.summary_values_copied + (stats.channel_values_copied or 0)
    out.structure_entries_copied = stats.entries_copied
    for key, amount in pairs(extra or {}) do out[key] = out[key] + amount end
    return out
end

function M.measure(n, phase)
    assert(n >= 4, "document benchmark requires at least four rows")
    local values, blank = {}, value(" ")
    for i = 1, n do values[i] = blank end
    local middle, long_bytes = math.floor(n / 2), n * 16
    if phase == "fact_footer" then
        values[1], values[2], values[n] = value("body"), value("---"), value("[^1]: note")
    elseif phase == "fragment_enter_join" then
        for i = 1, n do values[i] = value(i == 1 and "💬: question" or "body") end
    elseif phase == "long_line" then
        values[middle + 1] = { rows = 1, bytes = long_bytes + 1, opaque = true }
    end
    local seq = S.new(values, { channel_names = G.CHANNELS, channels = function(metadata) return G.channels(metadata and metadata.token) end, summarize = function(metadata)
        return metadata and metadata.token and G.summary(metadata.token) or G.empty_summary()
    end, combine = G.combine, empty_summary = G.empty_summary() })
    local spans = S.query(seq, 0, n)
    local dependency, syntax_proof, text_proof, typed_metadata
    if phase == "typed_row" then
        syntax_proof = S.range_certificate(seq, 0, n, { kind = "syntax" })
        text_proof = S.range_certificate(seq, 0, n)
        -- Classification is a separate bounded lexer workload. This measures
        -- the index update once exact descriptor equality has been established.
        typed_metadata = value("  ").metadata
    end
    if phase == "dependency_eof" then
        dependency = D.new({ rank = function(handle)
            local position = S.rank(seq, handle)
            return position and position.row
        end })
        for _, span in ipairs(spans) do assert(dependency:add(span.handle, S.eof(seq)).status == "ok") end
    end
    local semantic, suffix, enter_values, join_values
    if phase == "fragment_enter_join" then
        semantic = Semantic.new(seq)
        local settled = false
        -- Bootstrap is finite and outside the timed update window. Each slice
        -- has explicit row/navigation budgets, including global fact discovery.
        for _ = 1, n do
            local result = Semantic.step(semantic, { rows = 256, nodes = 32768, entries = 32768 })
            assert(result.work.rows_processed <= 256)
            assert(result.work.nodes_visited <= 32768 and result.work.entries_visited <= 32768)
            assert(result.status ~= "opaque", "confirmed fixture demanded lexical materialization")
            if result.status == "idle" then settled = true; break end
        end
        assert(settled, "semantic benchmark fixture did not settle")
        suffix = S.at(seq, middle + 1)
        enter_values, join_values = { value("body first"), value("body second") }, { value("joined body") }
    end
    S.stats(seq, true)
    local started = vim.uv.hrtime()
    local extra, verify = {}, function() end
    if phase == "typed_row" then
        local accepted, evidence = S.update_text(seq, spans[middle + 1].handle,
            { bytes = 3, metadata = typed_metadata })
        local valid = S.validate_certificate(seq, syntax_proof, { kind = "syntax" })
        verify = function()
            assert(accepted and evidence.same_syntax_proven and valid)
            assert(not S.validate_certificate(seq, text_proof))
            assert(S.size(seq).rows == n and S.size(seq).bytes == n * 2 + 1)
        end
    elseif phase == "fragment_enter_join" then
        local snapshots, statuses = {}, {}
        extra.dependency_nodes_visited, extra.structure_rows_processed = 0, 0
        for i, edit in ipairs({ { last = middle + 1, values = enter_values },
            { last = middle + 2, values = join_values } }) do
            local evidence = Semantic.before_fragment(semantic, middle, edit.last, edit.values,
                { rows = 256, bytes = 65536, nodes = 65536, entries = 65536 })
            S.splice(seq, middle, edit.last, edit.values)
            local result = Semantic.after_fragment(semantic, evidence, middle, middle + #edit.values)
            statuses[i] = { result.status, Semantic.step(semantic).status }
            snapshots[i] = S.at(seq, middle + #edit.values)
            -- Seq.stats already includes navigation from semantic preparation,
            -- splice, projection, and these bounded checks. Add only counters
            -- owned by the semantic/dependency layer; never add result node work.
            extra.dependency_nodes_visited = extra.dependency_nodes_visited
                + evidence.work.dependency_nodes_visited + result.work.dependency_nodes_visited
            extra.structure_rows_processed = extra.structure_rows_processed + result.work.rows_processed
        end
        verify = function()
            for i = 1, 2 do
                assert(statuses[i][1] == "reused" and statuses[i][2] == "idle")
                assert(snapshots[i].handle == suffix.handle)
                assert(vim.deep_equal(snapshots[i].metadata, suffix.metadata))
            end
            assert(S.size(seq).rows == n)
        end
    elseif phase == "sequence_splice" then
        S.splice(seq, middle, middle, { value("") })
        S.splice(seq, middle, middle + 1, {})
        verify = function()
            assert(S.size(seq).rows == n)
            assert(S.rank(seq, spans[n].handle).row == n - 1)
        end
    elseif phase == "bulk_paste_delete" then
        -- Both a million-row paste and its removal remain one opaque span.
        S.splice(seq, middle, middle, { { rows = 1000000, bytes = 8000000, opaque = true } })
        S.splice(seq, middle, middle + 1000000, {})
        verify = function()
            assert(S.size(seq).rows == n)
            assert(S.rank(seq, spans[n].handle).row == n - 1)
        end
    elseif phase == "dependency_eof" then
        local hit = dependency:restart_origin(n, n, { budget = 128 })
        local removed = dependency:remove_from(spans[middle + 1].handle, { budget = 512 })
        extra.dependency_nodes_visited = hit.work.dependency_nodes_visited + removed.work.dependency_nodes_visited
        verify = function()
            assert(hit.status == "ok" and hit.origin == spans[1].handle)
            assert(removed.status == "ok" and removed.removed == n - middle)
        end
    elseif phase == "fact_footer" then
        local result, slices, opts = nil, 0, { budget_nodes = 512, budget_entries = 1700 }
        repeat
            result = F.resolve(seq, spans[1].handle, { kind = "footer" }, opts)
            assert(result.work.nodes_visited <= opts.budget_nodes and result.work.entries_visited <= opts.budget_entries)
            opts.cursor = result.cursor
            slices = slices + 1
            assert(slices < 20, "footer summary search did not converge")
        until result.status ~= "budget"
        verify = function()
            assert(result.status == "ready")
            assert(result.fact.value.start == spans[n].handle and result.fact.value.content_start == spans[2].handle)
        end
    elseif phase == "long_line" then
        local worker = L.new(seq)
        L.demand(worker, middle)
        local result = L.step(worker, nil, { bytes = 4096, rows = 1 })
        extra.line_read_calls, extra.lines_requested, extra.bytes_read = 0, 0, 0
        while result.status == "read" do
            local request = result.request
            local bytes = math.min(request.max_bytes, long_bytes - request.col)
            extra.line_read_calls = extra.line_read_calls + 1
            extra.lines_requested = extra.lines_requested + 1
            extra.bytes_read = extra.bytes_read + bytes
            result = L.step(worker, { request_id = request.request_id, bytes = string.rep("x", bytes),
                eol = request.col + bytes == long_bytes, start_byte = middle * 2, separator_bytes = 1 },
                { bytes = 4096, rows = 1 })
            assert(result.work.bytes_scanned <= 4096 and result.work.rows_materialized <= 1)
            assert(L.retained_bytes(worker) < 256, "long-line lexer retained the payload")
        end
        extra.structure_rows_processed = result.work.rows_materialized
        verify = function()
            assert(result.published and result.published.row == middle)
            assert(S.at(seq, middle).metadata.token.kind == "text")
            assert(S.size(seq).rows == n and extra.bytes_read == long_bytes)
        end
    else
        error("unknown document benchmark phase: " .. tostring(phase))
    end
    local elapsed = (vim.uv.hrtime() - started) / 1000000
    local measured = work(S.stats(seq), extra)
    verify()
    return elapsed, measured
end

function M.run(opts)
    opts = opts or {}
    local iterations, warmups = opts.iterations or 3, opts.warmups or 1
    local report = harness.new_report(opts.environment or { suite = "document_core", nvim = vim.version().major
        .. "." .. vim.version().minor .. "." .. vim.version().patch })
    for _, n in ipairs(opts.sizes or { 100, 1000, 10000, 50000 }) do
        for _, phase in ipairs(PHASES) do
            for _ = 1, warmups do M.measure(n, phase) end
            local times, samples = {}, {}
            for i = 1, iterations do times[i], samples[i] = M.measure(n, phase) end
            local summary = harness.summarize(times)
            harness.add_scenario(report, { name = "parley_document_core", phase = phase,
                attribution = "isolated", line_count = n, iteration_count = iterations,
                elapsed_ms = { samples = times, median = summary.median, p95 = summary.p95 },
                work = typing.max_work(samples) })
        end
    end
    if opts.output then typing.write_report(opts.output, harness.encode(report)) end
    return report
end

return M
