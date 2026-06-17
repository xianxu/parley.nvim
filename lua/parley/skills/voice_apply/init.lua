-- voice-apply skill — Rewrite document to match a personal writing voice.
--
-- Reads a style guide from ~/.personal/<slug>-writing-style.md and uses it
-- to rewrite the current buffer's content in that voice.

local function scan_voice_slugs()
    local dir = vim.fn.expand("~/.personal")
    local slugs = {}
    local handle = vim.loop.fs_scandir(dir)
    if not handle then return slugs end
    while true do
        local name = vim.loop.fs_scandir_next(handle)
        if not name then break end
        local slug = name:match("^(.+)-writing%-style%.md$")
        if slug then table.insert(slugs, slug) end
    end
    table.sort(slugs)
    return slugs
end

return {
    name = "voice-apply",
    description = "Rewrite to match a personal writing voice",

    -- Declarative manifest fields (#128). Runs through the skill_invoke driver
    -- (M4); a `propose_edits` tool exchange on the artifact buffer.
    scope = "global",
    activation = { manual = true },
    tools = { "read_file" },
    elevated = { "propose_edits" },
    force_tool = "propose_edits",

    args = {
        { name = "slug", description = "Voice style",
          complete = scan_voice_slugs },
    },

    -- DYNAMIC body: SKILL.md (injected by the disk provider as ctx.skill_md) ⊕
    -- the per-slug style guide. The driver calls source(ctx) with
    -- ctx = { args = {...}, repo_root, skill_md }.
    source = function(ctx)
        local slug = (ctx.args or {}).slug
        local style_path = vim.fn.expand("~/.personal/" .. tostring(slug) .. "-writing-style.md")
        local f = io.open(style_path, "r")
        if not f then
            error("Voice style file not found: " .. style_path)
        end
        local style = f:read("*a")
        f:close()
        return (ctx.skill_md or "") .. "\n\n## Voice Style Guide\n\n" .. style
    end,
}
