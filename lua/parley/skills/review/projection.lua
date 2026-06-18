-- parley.skills.review.projection — decoration coherence across undo/redo (#133 M5).
--
-- nvim's undo reverts TEXT only; review decorations are drawn once per round and
-- otherwise ride/persist, so after an undo the style goes stale. This records the
-- decoration set per *content-state* (keyed by a content hash) and, on any text
-- change, PROJECTS the right style onto the current state:
--   - content matches a recorded state (an undo/redo landing) → re-render it;
--   - novel forward state (a manual edit, behavior B) → the live decorations keep
--     riding, and we snapshot them under the new state so a later undo restores them.
-- The decide rule is PURE (`M.decide`); the watcher / hashing / snapshot-apply are
-- the thin IO seam, reusing skill_render to draw (ARCH-DRY / ARCH-PURE).

local M = {}

local skill_render = require("parley.skill_render")

-- Per-buffer: { records = { [hash] = snapshot }, watching = bool }.
local _state = {}
-- Buffers whose own round-apply is in flight — the round's `:edit!` must not be
-- mistaken for a user edit by the watcher.
local _applying = {}

-- Cap the per-buffer record set so a long edit session can't grow it without
-- bound (M5 review). FIFO eviction of the oldest states; a round's base/post are
-- recorded most recently, so the cap only ever drops far-back history (undoing
-- past it just re-captures the riding decorations — graceful).
local MAX_RECORDS = 200

local function bufstate(buf)
    _state[buf] = _state[buf] or { records = {}, order = {} }
    return _state[buf]
end

-- Insert/replace a record, maintaining FIFO order + the cap.
local function put(s, h, snap)
    if s.records[h] == nil then
        table.insert(s.order, h)
        if #s.order > MAX_RECORDS then
            local oldest = table.remove(s.order, 1)
            s.records[oldest] = nil
        end
    end
    s.records[h] = snap
end

local function content(buf)
    return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end

local function hash(buf)
    return vim.fn.sha256(content(buf))
end

--- PURE: given the records map and the current content hash, what should happen?
--- "restore" — we've recorded this exact state before (undo/redo) → redraw it.
--- "capture" — a novel forward state → snapshot the live (ridden) decorations.
--- @param records table  { [hash] = snapshot }
--- @param h string       current content hash
--- @return string  "restore" | "capture"
function M.decide(records, h)
    return records[h] ~= nil and "restore" or "capture"
end

--- Mark a buffer's own round-apply as in flight (suppresses the watcher).
function M.set_applying(buf, v)
    _applying[buf] = v or nil
end

--- Record the CURRENT decorations under the current content hash (round end).
function M.record(buf)
    put(bufstate(buf), hash(buf), skill_render.snapshot(buf))
end

--- Record an explicit EMPTY decoration set for the given content (the pre-round
--- base) — so undoing back across the round clears the (now-stale) style.
function M.record_empty_for(buf, base_content)
    put(bufstate(buf), vim.fn.sha256(base_content or ""), { hl_lines = {}, diags = {} })
end

--- Project the recorded style onto the current content state (the watcher body;
--- also called directly by tests). Undo/redo → re-render the matching record;
--- a novel forward state → snapshot the live (ridden) decorations.
function M.project(buf)
    if _applying[buf] or not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    local s = bufstate(buf)
    local h = hash(buf)
    if M.decide(s.records, h) == "restore" then
        skill_render.apply_snapshot(buf, s.records[h]) -- undo/redo → re-render the record
    else
        put(s, h, skill_render.snapshot(buf)) -- novel forward state (B) → snapshot riding decos
    end
end

--- Attach the TextChanged watcher once per buffer (lazy — only after a round, so
--- it never costs a hash on buffers that never ran a review).
function M.ensure_watch(buf)
    local s = bufstate(buf)
    if s.watching then
        return
    end
    s.watching = true
    -- TextChanged covers normal-mode edits + undo/redo (the cases we must
    -- re-project); InsertLeave covers a finished insert. We deliberately do NOT
    -- watch TextChangedI — that fires per insert-keystroke and would sha256 the
    -- whole buffer on every keypress (M5 review). #133
    s.autocmd = vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
        buffer = buf,
        callback = function() M.project(buf) end,
    })
end

--- Forget a buffer's projection state (tests / buffer teardown) — also removes
--- the watcher autocmd so a surviving buffer doesn't double-attach next round.
function M.reset(buf)
    local s = _state[buf]
    if s and s.autocmd then
        pcall(vim.api.nvim_del_autocmd, s.autocmd)
    end
    _state[buf] = nil
    _applying[buf] = nil
end

return M
