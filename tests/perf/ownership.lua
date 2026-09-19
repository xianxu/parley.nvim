-- Real editor/handler interleaving. Provider delivery is controlled here;
-- this is not a tool-runner concurrency benchmark.
local M = {}
local typing = require("tests.perf.chat_typing")
local reader = require("parley.line_reader")

local function fixture(n)
    local lines = { "# topic: ownership perf", "- file: perf.md", "---", "" }
    while #lines + 10 <= n do
        vim.list_extend(lines, { "💬: historical question", "", "🤖: [PerfFixture]", "",
            "🧠: historical thought", "detail", "", "historical answer" })
    end
    while #lines < n - 2 do lines[#lines + 1] = "historical padding" end
    lines[#lines + 1], lines[#lines + 2] = "", "💬: stream here"
    return lines, #lines
end

local function feed(keys)
    vim.api.nvim_input(keys)
end

function M.measure(n, done)
    local scenario = typing.open_fixture(n, fixture)
    local buf = scenario.buf
    local token, group, qid, session, call, original_query
    local parley = require("parley")
    local finished = false
    local function finish(sample, err)
        if finished then return end
        finished = true
        if token then reader.clear_observer(buf, token) end
        if group then vim.api.nvim_del_augroup_by_id(group) end
        -- The benchmark stops the response the way a user does, so the stop is
        -- silent and the probe's report stays clean (#261 M5).
        if session then
            require("parley.response_session").cancel(session, require("parley.refusal").USER_STOP)
        end
        -- The fake's completion is positive evidence that no delivery remains;
        -- cancellation alone does not resolve a transport operation.
        if call then call:finish() end
        if original_query then parley.dispatcher.query = original_query end
        if session then
            for _ = 1, 100 do
                require("parley.response_session").step(session)
                local snapshot = require("parley.response_session").snapshot(session)
                if snapshot.status == "terminal" or snapshot.status == "cancelled" then break end
            end
            local status = require("parley.response_session").snapshot(session).status
            if status ~= "terminal" and status ~= "cancelled" then
                sample, err = nil, "fake completion left response unresolved: " .. status
            end
        end
        vim.cmd("stopinsert")
        scenario:close()
        done(sample, err)
    end
    local deadline
    local function guarded(fn)
        local ok, err = xpcall(fn, debug.traceback)
        if not ok then finish(nil, err) end
    end
    local function poll(predicate, label, fn)
        if finished then return end
        guarded(function()
            if predicate() then return fn() end
            if vim.uv.hrtime() >= deadline then
                return finish(nil, "ownership timeout: " .. (type(label)=="function" and label() or label))
            end
            vim.defer_fn(function() poll(predicate, label, fn) end, 1)
        end)
    end
    guarded(function()
        -- Query the already confirmed shared index; no second live layout model.
        local Document = require("parley.document")
        local folds = require("parley.tool_folds")
        folds.apply_folds(buf, vim.api.nvim_get_current_win())
        assert(folds.flush(buf,math.max(10000,n)) == "idle", "initial fold projection did not settle")
        local thinking_row
        for _, row in ipairs(Document.query(scenario.document, math.max(0, n - 32), n)) do
            local semantic = row.metadata and row.metadata.semantic
            if semantic and semantic.section_kind == "thinking" and semantic.section_start then
                thinking_row = row.start_row
            end
        end
        assert(thinking_row, "fixture has no historical thinking block")
        assert(vim.fn.foldlevel(thinking_row + 1) > 0, "fixture has no native thinking fold")
        local counter = typing.new_counter()
        token = reader.set_observer(buf, function(e) counter:observe(e) end)
        local started = vim.uv.hrtime()
        reader.with_phase(buf, "fold_maintenance", function()
            vim.api.nvim_buf_set_lines(buf, thinking_row + 1, thinking_row + 2, false, { "edited detail" })
        end)
        local sample = {
            fold_elapsed_ms = (vim.uv.hrtime() - started) / 1000000,
            fold_work = counter:snapshot(),
            fold_preserved = vim.fn.foldlevel(thinking_row + 1) > 0,
        }
        reader.clear_observer(buf, token)
        token = nil
        assert(sample.fold_preserved, "body update did not retain the existing native fold")
        original_query = parley.dispatcher.query
        local handler
        qid = "ownership-perf-" .. buf
        parley.dispatcher.query = function(target, _, _, write, on_exit, _, _, on_abort, _, on_error, opts)
            assert(not call, "benchmark unexpectedly started a second provider attempt")
            call = {running = true}
            function call:finish(failure)
                if not self.running then return end
                self.running = false
                parley.tasker.reject_query(qid)
                if failure then on_error(qid, failure) else on_exit(qid) end
            end
            if opts.alive and not opts.alive() then
                call.running = false
                on_abort("benchmark request cancelled before launch")
                return
            end
            parley.tasker.set_query(qid, { response = "", raw_response = "", buf = target })
            handler = function(id, bytes)
                if not call.running or opts.alive and not opts.alive() then return false end
                local query = parley.tasker.get_query(id)
                query.response = query.response .. bytes
                return write(id, bytes)
            end
        end
        vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(buf), 0 })
        local ok, result, reason = pcall(parley.chat_respond, { range = 0 }, nil, true)
        assert(ok, result)
        assert(result, reason or "production response was not admitted")
        session = result
        local function text()
            -- Fixed-size completion probes; never scan the transcript to time it.
            local count = vim.api.nvim_buf_line_count(buf)
            return table.concat(vim.api.nvim_buf_get_lines(buf, math.max(0, count - 12), count, false), "\n")
        end
        -- Fixture parsing, native fold hydration and response setup are outside
        -- the keyboard sample and must not consume its completion deadline.
        deadline = vim.uv.hrtime() + 5000000000
        poll(function() return handler ~= nil end, "response preparation", function()
            sample.deliveries = 1
            assert(handler(qid, "🧠: stream first\n") ~= false, "first delivery refused")
            poll(function()
                local generation = require("parley.response_session").snapshot(session).generation
                return text():find("🧠: stream first", 1, true) and generation
                    and generation.committed_bytes == #"🧠: stream first\n"
            end, function() return "first stream receipt "
                .. vim.inspect(require("parley.response_session").snapshot(session)) end, function()
                assert(Document.drain(scenario.document, math.max(10000, n * 8)).status == "idle",
                    "first delivery structure did not settle")
                assert(folds.flush(buf, math.max(10000, n)) == "idle", "first delivery folds did not settle")
                -- Cross a native timer turn after setup publication, then flush its
                -- queued escape before entering the measured keyboard path.
                vim.defer_fn(function() guarded(function()
                    -- Flush setup's queued escape before entering the timed keyboard path.
                    vim.api.nvim_feedkeys("", "x", false)
                    counter:reset()
                    token = reader.set_observer(buf, function(e) counter:observe(e) end)
                    sample.text_changed_i = 0
                    group = vim.api.nvim_create_augroup("ParleyOwnershipPerf" .. buf, { clear = true })
                    vim.api.nvim_create_autocmd("TextChangedI", { group = group, buffer = buf,
                        callback = function() sample.text_changed_i = sample.text_changed_i + 1 end })
                    started = vim.uv.hrtime()
                    deadline = started + 5000000000
                    feed("Go<CR>💬: human typed ahead")
                    poll(function() return text():find("💬: human typed ahead", 1, true)
                        and sample.text_changed_i > 0 end, function() return "human typed ahead mode="
                            ..vim.api.nvim_get_mode().mode.." events="..sample.text_changed_i.." tail="..text() end, function()
                        sample.insert_mode = vim.api.nvim_get_mode().mode:sub(1, 1) == "i"
                        sample.deliveries = sample.deliveries + 1
                        assert(handler(qid, "stream second") ~= false, "second delivery refused: "
                            .. vim.inspect(require("parley.response_session").snapshot(session)))
                        poll(function() return text():find("stream second", 1, true) end, "second stream delivery", function()
                            sample.stream_elapsed_ms = (vim.uv.hrtime() - started) / 1000000
                            sample.stream_work = counter:snapshot()
                            -- Verification reads occur after the measured observer window.
                            reader.clear_observer(buf, token)
                            token = nil
                            local result = text()
                            local human = result:find("💬: human typed ahead", 1, true)
                            local streamed = result:find("stream second", 1, true)
                            sample.human_preserved = human ~= nil
                            sample.stream_before_human = human ~= nil and streamed < human
                            assert(sample.human_preserved and sample.stream_before_human and sample.insert_mode,
                                "stream did not preserve the human typed-ahead suffix")
                            finish(sample)
                        end)
                    end)
                end) end, 1)
            end)
        end)
    end)
end

function M.add_baselines(report, n, warmups, iterations, done)
    local index = 0
    local fold_times, fold_work, stream_times, stream_work = {}, {}, {}, {}
    local function next_sample()
        M.measure(n, function(sample, err)
            if not sample then return done(err) end
            index = index + 1
            local measured = typing.measured_index(index, warmups)
            if measured then
                fold_times[measured], fold_work[measured] = sample.fold_elapsed_ms, sample.fold_work
                stream_times[measured], stream_work[measured] = sample.stream_elapsed_ms, sample.stream_work
            end
            if index < warmups + iterations then return vim.schedule(next_sample) end
            typing.add_result(report, "fold_maintenance", "isolated", n, fold_times, typing.max_work(fold_work))
            typing.add_result(report, "stream_human_interleave", "inclusive", n,
                stream_times, typing.max_work(stream_work))
            done()
        end)
    end
    next_sample()
end

function M.run_probe(n, output)
    M.measure(n, function(sample, err)
        if not sample then print(err); vim.cmd("cquit 1"); return end
        typing.write_report(output, vim.json.encode(sample))
        vim.cmd("qa!")
    end)
end

return M
