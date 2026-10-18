-- Edit round (#383): shows the agent's last write of a document, the round
-- Couch keeps (pair#661), the way the document's `presentation:` asks. Under
-- highlight (the default) each changed span is highlighted with its reason;
-- under direct nothing is drawn; under propose the markers are already in the
-- text. The round clears on the operator's next confirmed submit.
--
-- The shell around the pure presentation module: one bounded Couch request
-- per refresh, and a generation per buffer, the single guard that drops a
-- reply a later refresh or clear has overtaken.
local presentation = require("parley.presentation")
local skill_render = require("parley.skill_render")

local M = {}

-- buf -> the latest request's generation; a reply from an older one is stale.
local generation = {}
-- buf -> the on_lines attachment's token; a stale token detaches itself.
local attached = {}
-- buf -> true while a re-derive is scheduled: keystrokes coalesce into one.
local pending = {}
-- buf -> the result_hash of the last round whose cap was announced.
local announced = {}

-- Counts for specs: re-derives run, one per scheduled batch of keystrokes.
M.stats = { rederives = 0 }

-- Couch's whole-file hash, hex of sha256's first 8 bytes, over the buffer as
-- a file: lines joined by newlines plus the final one.
local function file_hash(lines)
    return vim.fn.sha256(table.concat(lines, "\n") .. "\n"):sub(1, 16)
end

local function lines_of(buf)
    return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

-- Keep the round's diagnostics on their marks while the operator edits: marks
-- move with the text, diagnostics do not. Per keystroke this only sets a flag;
-- the re-derive is O(spans) and runs once per scheduled batch.
local function follow_edits(buf)
    if attached[buf] then return end
    local token = {}
    attached[buf] = token
    vim.api.nvim_buf_attach(buf, false, {
        on_lines = function()
            if attached[buf] ~= token then return true end
            if pending[buf] then return end
            pending[buf] = true
            vim.schedule(function()
                pending[buf] = nil
                if attached[buf] ~= token then return end
                M.stats.rederives = M.stats.rederives + 1
                skill_render.rederive_round(buf)
            end)
        end,
        on_detach = function()
            if attached[buf] == token then attached[buf] = nil end
        end,
    })
end

local function draw(buf, round)
    local lines = lines_of(buf)
    if presentation.value(lines) ~= "highlight" then
        skill_render.clear_round(buf)
        return
    end
    skill_render.publish_round(buf, presentation.decorations(round, lines, file_hash(lines)))
    follow_edits(buf)
    local count = type(round.spans) == "table" and #round.spans or 0
    if count > presentation.MAX_SPANS and announced[buf] ~= round.result_hash then
        announced[buf] = round.result_hash
        vim.notify(("parley: showing %d of %d agent changes"):format(presentation.MAX_SPANS, count),
            vim.log.levels.WARN)
    end
end

--- Fetch the document's round from Couch and draw it, replacing what was
--- drawn. Called after a reload and on attach. Decorations are computed from
--- the buffer at reply time, so an edit made while the request ran is
--- handled by re-anchoring.
--- @param buf number
function M.refresh(buf)
    if not vim.api.nvim_buf_is_valid(buf) then return end
    if presentation.value(lines_of(buf)) ~= "highlight" then
        M.clear(buf)
        return
    end
    local name = vim.api.nvim_buf_get_name(buf)
    if name == "" then return end
    local path = vim.fn.fnamemodify(name, ":p")
    path = (vim.uv or vim.loop).fs_realpath(path) or path
    generation[buf] = (generation[buf] or 0) + 1
    local mine = generation[buf]
    require("parley.document_registry").request("round", { path }, { path = path, generation = mine },
        function(result)
            if generation[buf] ~= mine or not vim.api.nvim_buf_is_valid(buf) then return end
            if result.kind == "round" and not result.cleared then
                draw(buf, result.round)
                return
            end
            if result.kind == "unavailable" then
                require("parley").logger.debug("edit_round: no round for " .. path .. ": " .. tostring(result.error))
            end
            skill_render.clear_round(buf)
        end)
end

--- Clear the round, dropping any reply still in flight. Called on a
--- confirmed submit: the operator has answered the round.
--- @param buf number
function M.clear(buf)
    generation[buf] = (generation[buf] or 0) + 1
    attached[buf] = nil
    skill_render.clear_round(buf)
end

--- Forget the buffer entirely (BufUnload): nothing of it outlives the buffer.
--- @param buf number
function M.forget(buf)
    M.clear(buf)
    generation[buf], pending[buf], announced[buf] = nil, nil, nil
end

return M
