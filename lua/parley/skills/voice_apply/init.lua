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
    args = {
        { name = "slug", description = "Voice style",
          complete = scan_voice_slugs },
    },
    system_prompt = function(args, file_path, content, skill_md)
        local style_path = vim.fn.expand("~/.personal/" .. args.slug .. "-writing-style.md")
        local f = io.open(style_path, "r")
        if not f then
            error("Voice style file not found: " .. style_path)
        end
        local style = f:read("*a")
        f:close()
        return skill_md .. "\n\n## Voice Style Guide\n\n" .. style
    end,
}
