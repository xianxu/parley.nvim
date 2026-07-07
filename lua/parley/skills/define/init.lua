-- The `define` skill (#161): define a user-selected term concisely, inline.
--
-- Auto-discovered by the disk provider (no registry edit). Invoked from
-- `define_visual` (lua/parley/init.lua) via skill_invoke with args.phrase and a
-- bounded `opts.document`. There is deliberately NO `force_tool`: an unforced
-- turn (tool_choice = auto) lets the server-side web_search tool run when the
-- global `:ToggleWebSearch` is on. `source(ctx)` owns the whole system prompt
-- (folding in the phrase), so there is no SKILL.md.

local M = {
    name = "define",
    description = "Define a selected term concisely, inline.",
    scope = "global",
    activation = { manual = true },
    tools = { "emit_definition" },
    -- no force_tool (see note above)
}

function M.source(ctx)
    local phrase = ctx and ctx.args and ctx.args.phrase or ""
    return table.concat({
        "You define a single term for a reader of a chat transcript.",
        "The user selected this phrase: «" .. phrase .. "».",
        "Define it concisely (1–3 sentences) AS USED in the document below.",
        "Prefer a plain, jargon-free explanation.",
        "If it is an unfamiliar or fresh proper noun and web search is available,",
        "you may search first. Then ALWAYS call the emit_definition tool exactly",
        "once with {term, definition}. Do not reply in plain prose.",
    }, "\n")
end

return M
