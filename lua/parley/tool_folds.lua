-- Chat buffer folding for parley.
--
-- Uses a pure exchange-model projection to compute fold regions. Thinking,
-- summary, tool-use, and tool-result blocks fold; questions, ordinary answer
-- text, and agent headers do not.
--
-- foldmethod=manual — folds are created explicitly from model positions.
-- No foldexpr evaluation, no backward scanning.

local M = {}
local projection = require("parley.fold_projection")
local initialized = {}

local function valid_target(buf, win)
    return vim.api.nvim_buf_is_valid(buf)
        and vim.api.nvim_win_is_valid(win)
        and vim.api.nvim_win_get_buf(win) == buf
end

local function notify(event)
    if M._observer then M._observer(event) end
end

--- Report a refused reconcile. The observer seam carries the detail for tests;
--- production gets one debug line, because an exchange that silently stops
--- folding is indistinguishable from one that has nothing to fold.
local function report_drift(buf, win, exchange_index, failed_index, which, ranges, do_log)
    notify({
        phase = "drift", win = win, exchange_index = exchange_index, ranges = {},
        failed_index = failed_index, which = which,
        failed_range = failed_index and ranges and ranges[failed_index] or nil,
    })
    if not do_log then return end
    local range = failed_index and ranges and ranges[failed_index]
    require("parley.logger").debug(string.format(
        "tool_folds: refused fold reconcile for buf %d exchange %d — %s drift%s",
        buf, exchange_index, which or "model",
        range and string.format(" at rows %d..%d (%s)", range.start_0, range.end_0, range.kind) or ""))
end

--- Delete every fold overlapping rows [first_0, last_0].
---
--- Parley owns every fold within an exchange span (#200): the projection is a
--- desired state, and a fold the projection no longer wants must not survive.
--- Deleting only at projected start rows — the previous behavior — left a
--- drifted fold in place forever, since nothing else ever removes one.
--- Folds outside every exchange span are untouched.
local function clear_folds_in_span(buf, win, first_0, last_0)
    if not valid_target(buf, win) then return end
    if first_0 == nil or last_0 == nil or last_0 < first_0 then return end
    vim.api.nvim_win_call(win, function()
        local cursor = vim.api.nvim_win_get_cursor(win)
        local line_count = vim.api.nvim_buf_line_count(buf)
        local last_row = math.min(last_0 + 1, line_count)
        local first_row = math.max(first_0 + 1, 1)
        if first_row > last_row then return end
        -- Walk fold-to-fold, not row-to-row, in ONE Lua→VimL crossing.
        -- chat_respond wraps every streamed chunk in with_exchange_update, so
        -- this is a per-chunk cost and it must not scale with exchange length:
        -- probing every row costs O(span) (3.7ms from Lua, 1.2ms natively, on a
        -- 600-row exchange), while `zj` jumps straight to the next fold start,
        -- making it O(number of folds present). zD deletes nested folds at the
        -- cursor too. If zj cannot move there is no further fold below, so stop.
        -- s:guard bounds the loop absolutely: `zD` refuses under a non-manual
        -- 'foldmethod' (E350), which would otherwise leave foldlevel unchanged
        -- and spin here forever. Bounding by the span means the worst case
        -- degrades to the row-walk cost rather than hanging the editor.
        vim.api.nvim_exec2(string.format([[
            execute %d
            let s:guard = 0
            let s:limit = %d
            while line('.') <= %d && s:guard < s:limit
              let s:guard += 1
              if foldlevel(line('.')) > 0
                silent! normal! zD
                if foldlevel(line('.')) > 0
                  break
                endif
              else
                let s:before = line('.')
                silent! normal! zj
                if line('.') == s:before
                  break
                endif
              endif
            endwhile
        ]], first_row, (last_row - first_row + 2) * 2, last_row), {})
        vim.api.nvim_win_set_cursor(win, {
            math.min(cursor[1], vim.api.nvim_buf_line_count(buf)), cursor[2],
        })
    end)
end

--- 0-indexed [first, last] buffer rows an exchange occupies, or nil when it has
--- no visible block.
local function exchange_span(model, exchange_index)
    if not model or not model.exchanges[exchange_index] then return nil end
    local last_0 = model:last_nonempty_block_end(exchange_index)
    if not last_0 then return nil end
    return model:exchange_start(exchange_index), last_0
end

--- Read every buffer row the ranges cover, keyed by 0-based row. Rows past the
--- end of the buffer are simply absent; verify_anchors treats a missing row as
--- drift.
local function covered_lines(buf, ranges)
    local out = {}
    local line_count = vim.api.nvim_buf_line_count(buf)
    for _, range in ipairs(ranges) do
        local last = math.min(range.end_0, line_count - 1)
        if range.start_0 <= last then
            local chunk = vim.api.nvim_buf_get_lines(buf, range.start_0, last + 1, false)
            for offset, line in ipairs(chunk) do
                out[range.start_0 + offset - 1] = line
            end
        end
    end
    return out
end

--- Read rows [first_0, last_0], keyed by 0-based row; absent past end-of-buffer.
local function span_lines(buf, first_0, last_0)
    local out = {}
    if first_0 == nil or last_0 == nil then return out end
    local last = math.min(last_0, vim.api.nvim_buf_line_count(buf) - 1)
    if first_0 > last then return out end
    local chunk = vim.api.nvim_buf_get_lines(buf, first_0, last + 1, false)
    for offset, line in ipairs(chunk) do out[first_0 + offset - 1] = line end
    return out
end

--- True when the model still describes the buffer, for BOTH halves of the
--- reconcile: the ranges it will create and the span it will clear. Returns the
--- failing range index when range verification is what failed, so the caller
--- can say which block drifted rather than only that something did.
--- @return boolean ok, integer|nil failed_range_index, string|nil which
local function model_fits(buf, ranges, first_0, last_0, patterns, exchange_index)
    -- A missing row is drift, which verify_anchors already reports, so the
    -- fits-in-buffer rule is not restated here.
    local ok, failed = projection.verify_anchors(ranges, covered_lines(buf, ranges), patterns)
    if not ok then return false, failed, "ranges" end
    if not projection.verify_span(first_0, last_0, span_lines(buf, first_0, last_0),
        patterns, exchange_index > 1) then
        return false, nil, "span"
    end
    return true
end

local function default_model_provider(buf)
    local chat_parser = require("parley.chat_parser")
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local header_end = chat_parser.find_header_end(lines)
    if not header_end then return nil end
    local parsed = chat_parser.parse_chat(lines, header_end, require("parley.config"))
    return require("parley.exchange_model").from_parsed_chat(parsed)
end

-- The drift re-derive parses the WHOLE buffer, and reconcile runs once per
-- exchange (apply_folds/hydrate_window) and once per streamed chunk. Measured
-- 1356 ms per refused reconcile on a 4805-line chat, so re-parsing per call is
-- not affordable. Keyed on changedtick: identical buffer content yields an
-- identical parse, so reusing it within a tick is exact, not an approximation.
-- Unlike a fold-state memo this cannot go stale silently — any edit moves the
-- tick.
local rederived = setmetatable({}, { __mode = "k" })

-- Minimum gap between re-parses once one has failed to resolve the drift. The
-- changedtick key alone only collapses the same-tick fan-out (reconcile runs
-- per exchange); on the streaming path every chunk is a NEW tick, so persistent
-- drift would re-parse per chunk — 81.8 ms/call on a 4325-line chat. Drift is
-- exceptional and does not clear by itself, so retrying every chunk buys
-- nothing; retrying a few times a second recovers promptly once the buffer is
-- parseable again.
local REDERIVE_RETRY_MS = 250

local function rederive_model(buf)
    local tick = vim.api.nvim_buf_get_var(buf, "changedtick")
    local hit = rederived[buf]
    if hit and hit.tick == tick then return hit.model, hit.logged end
    if hit and hit.model == nil and hit.failed_at
        and (vim.loop.now() - hit.failed_at) < REDERIVE_RETRY_MS then
        -- A recent re-parse of this buffer already failed to help; the content
        -- has changed, but not in a way worth paying a full parse for yet.
        return nil, hit.logged
    end
    local ok, model = pcall(M._model_provider or default_model_provider, buf)
    model = ok and model or nil
    rederived[buf] = {
        tick = tick,
        model = model,
        logged = hit and hit.logged or false,
        failed_at = model == nil and vim.loop.now() or nil,
    }
    return model, rederived[buf].logged
end

--- The re-derived model did not resolve the drift, so start the retry clock
--- even though the parse itself succeeded.
local function mark_rederive_unhelpful(buf)
    local hit = rederived[buf]
    if hit and not hit.failed_at then hit.failed_at = vim.loop.now() end
end

local function mark_drift_logged(buf)
    if rederived[buf] then rederived[buf].logged = true end
end

--- Reconcile exchange K's folds to the projection's desired state.
---
--- The projection is a desired state, not an append list: the exchange's span is
--- cleared before the desired folds are created, so a fold the projection no
--- longer wants cannot survive. Before anything is applied, every range is
--- checked against the buffer — it must fit, must anchor on its own marker, and
--- must not cover a question. A model that has drifted from the buffer (any
--- mutation not wrapped in with_exchange_update) would otherwise anchor a fold
--- on a 💬: line and leave it there for the rest of the session (#200). On drift
--- the model is re-derived from the buffer once; if that still does not verify,
--- no fold is created rather than a wrong one.
function M.reconcile_exchange(buf, win, model, exchange_index)
    if not valid_target(buf, win) or not model.exchanges[exchange_index] then return false end
    local patterns = require("parley.highlight_structure").patterns(require("parley.config"))
    local ranges = projection.desired_folds(model, exchange_index)
    local first_0, last_0 = exchange_span(model, exchange_index)

    local fits, failed_index, which = model_fits(buf, ranges, first_0, last_0, patterns, exchange_index)
    if not fits then
        local fresh, already_logged = rederive_model(buf)
        local fresh_ranges, fresh_first, fresh_last
        if fresh and fresh.exchanges[exchange_index] then
            fresh_ranges = projection.desired_folds(fresh, exchange_index)
            fresh_first, fresh_last = exchange_span(fresh, exchange_index)
            fits = model_fits(buf, fresh_ranges, fresh_first, fresh_last, patterns, exchange_index)
        else
            fits = false
        end
        if not fits then
            -- Refuse rather than fold wrongly — but do not swallow the
            -- diagnosis with it. A silently unfolded exchange is the same
            -- shape of invisible failure that let #200 persist unnoticed.
            -- Logged once per buffer state: reconcile runs per exchange and
            -- per streamed chunk, so a persistent drift would otherwise flood.
            report_drift(buf, win, exchange_index, failed_index, which, ranges,
                not already_logged)
            mark_drift_logged(buf)
            mark_rederive_unhelpful(buf)
            return false
        end
        ranges, first_0, last_0 = fresh_ranges, fresh_first, fresh_last
    end

    clear_folds_in_span(buf, win, first_0, last_0)
    vim.api.nvim_win_call(win, function()
        vim.api.nvim_set_option_value("foldminlines", 0, { win = win })
        for _, range in ipairs(ranges) do
            vim.cmd(string.format("%d,%dfold", range.start_0 + 1, range.end_0 + 1))
        end
    end)
    notify({ phase = "reconcile", win = win, exchange_index = exchange_index, ranges = ranges })
    return true
end

function M.prepare_exchange_update(buf, model, exchange_index)
    if not vim.api.nvim_buf_is_valid(buf) or not model.exchanges[exchange_index] then return {} end
    local ranges = projection.desired_folds(model, exchange_index)
    local first_0, last_0 = exchange_span(model, exchange_index)
    local patterns = require("parley.highlight_structure").patterns(require("parley.config"))
    -- Same destructive operation as reconcile, so the same guard: a stale span
    -- here would clear a neighbouring exchange's folds before the mutation even
    -- runs, and finalize would not recreate them (#200 C1).
    if not projection.verify_span(first_0, last_0, span_lines(buf, first_0, last_0),
        patterns, exchange_index > 1) then
        first_0, last_0 = nil, nil
    end
    local windows = vim.fn.win_findbuf(buf) or {}
    for _, win in ipairs(windows) do
        if valid_target(buf, win) then
            clear_folds_in_span(buf, win, first_0, last_0)
            notify({ phase = "prepare", win = win, exchange_index = exchange_index, ranges = ranges })
        end
    end
    return windows
end

function M.finalize_exchange_update(buf, windows, model, exchange_index)
    for _, win in ipairs(windows or {}) do
        M.reconcile_exchange(buf, win, model, exchange_index)
    end
end

function M.with_exchange_update(buf, model, exchange_index, mutate)
    local windows = M.prepare_exchange_update(buf, model, exchange_index)
    local result
    local ok, err = xpcall(function() result = mutate() end, debug.traceback)
    local final_model = model
    if not ok then
        local recovered, parsed = pcall(M._model_provider or default_model_provider, buf)
        final_model = recovered and parsed or nil
    end
    if ok then
        M.finalize_exchange_update(buf, windows, final_model, exchange_index)
    else
        if final_model then
            for _, win in ipairs(windows) do
                pcall(M.reconcile_exchange, buf, win, final_model, exchange_index)
            end
        end
        error(err, 0)
    end
    return result
end

--- Compute and apply folds from the exchange model.
--- @param buf integer
function M.apply_folds(buf, win, model_provider)
    if not vim.api.nvim_buf_is_valid(buf) then return false end
    local model = (model_provider or M._model_provider or default_model_provider)(buf)
    if not model then return false end
    local windows = win and { win } or vim.fn.win_findbuf(buf)
    for k in ipairs(model.exchanges) do
        for _, target_win in ipairs(windows) do
            M.reconcile_exchange(buf, target_win, model, k)
        end
    end
    return true
end

function M.hydrate_window(buf, win, model_provider)
    if not valid_target(buf, win) then return false end
    initialized[buf] = initialized[buf] or {}
    if initialized[buf][win] then return false end
    vim.api.nvim_set_option_value("foldmethod", "manual", { win = win })
    vim.api.nvim_set_option_value("foldtext", "v:lua.require('parley.tool_folds').foldtext()", { win = win })
    vim.api.nvim_set_option_value("foldcolumn", "1", { win = win })
    vim.api.nvim_set_option_value("foldminlines", 0, { win = win })
    local provider = model_provider or M._model_provider or default_model_provider
    local model = provider(buf)
    if not model then return false end
    vim.api.nvim_win_call(win, function()
        vim.cmd("normal! zE")
    end)
    for exchange_index in ipairs(model.exchanges) do
        M.reconcile_exchange(buf, win, model, exchange_index)
    end
    initialized[buf][win] = true
    return true
end

--- Custom fold text.
function M.foldtext()
    local start_line = vim.fn.getline(vim.v.foldstart)
    local line_count = vim.v.foldend - vim.v.foldstart + 1

    if start_line:match("^🔧:") then
        local name = start_line:match("^🔧:%s*(%S+)") or "tool"
        return string.format("🔧 %s (%d lines) ", name, line_count)
    elseif start_line:match("^📎:") then
        local name = start_line:match("^📎:%s*(%S+)") or "result"
        local is_error = start_line:match("error=true") and " error" or ""
        return string.format("📎 %s%s (%d lines) ", name, is_error, line_count)
    elseif start_line:match("^🧠:") then
        return "🧠 thinking (" .. line_count .. " lines) "
    elseif start_line:match("^📝:") then
        return "📝 summary (" .. line_count .. " lines) "
    else
        local preview = start_line:sub(1, 60)
        if #start_line > 60 then preview = preview .. "..." end
        return preview .. " (" .. line_count .. " lines) "
    end
end

--- Set up folding on a chat buffer.
function M.setup(buf)
    local group = vim.api.nvim_create_augroup("ParleyToolFolds" .. buf, { clear = true })
    vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
        group = group,
        callback = function(args)
            if args.buf ~= buf then return end
            local target = vim.api.nvim_get_current_win()
            vim.schedule(function() M.hydrate_window(buf, target) end)
        end,
    })
    vim.api.nvim_create_autocmd("WinClosed", {
        group = group,
        callback = function(args)
            local closed = tonumber(args.match)
            if initialized[buf] then initialized[buf][closed] = nil end
        end,
    })
    vim.api.nvim_create_autocmd({ "BufUnload", "BufDelete" }, {
        group = group, buffer = buf,
        callback = function() initialized[buf] = nil end,
    })
    local win = vim.api.nvim_get_current_win()
    vim.schedule(function()
        M.hydrate_window(buf, win)
    end)
end

return M
