-- `emit_definition` — output-only structured tool for the inline term-definition
-- feature (#161). The model calls it exactly once to return a concise
-- {term, definition}; there are NO side effects — define's on_done reads the
-- tool-call args (result.calls[1].input) and renders them as an inline
-- diagnostic. `self_paginates = true` marks it non-pageable (types.is_pageable),
-- so the dispatcher does not inject offset/limit pager params (it isn't a reader
-- and has nothing to page).

return {
    name = "emit_definition",
    self_paginates = true,
    description = "Return a concise definition of the selected term as used in "
        .. "the provided context. Call this exactly once with your answer.",
    input_schema = {
        type = "object",
        properties = {
            term = { type = "string", description = "The term being defined." },
            definition = {
                type = "string",
                description = "A concise 1–3 sentence definition of the term, in context.",
            },
        },
        required = { "term", "definition" },
    },
    handler = function(_input)
        -- No-op: the value lives in the tool-call args, consumed by define's
        -- on_done. Return an empty ToolResult (dispatcher stamps id/name).
        return { content = "", name = "emit_definition" }
    end,
}
