-- parley.discovery.base — the parley-shipped base registry.
--
-- The universal types any repo has (pensive, prose, continuation) plus the
-- parley-native ones the #116 source-map audit flagged as NOT datatype docs
-- (chat, note, vision, issue, plan — homed by parley's own conventions, with
-- discriminators other than `type:` frontmatter). This is the "parley ships
-- the base, the repo declares the delta" half made concrete.
--
-- `build(config)` is a PURE FUNCTION of config — it reads the LIVE config
-- passed by the caller, never a load-time snapshot of defaults, so user
-- overrides of chat_dir/notes_dir reach the descriptors. Dir-backed `locate`
-- globs are derived from config keys (ARCH-DRY) rather than hardcoded literals,
-- so the registry tracks parley's own repo-mode conventions (repo_mode.md).
-- Globs are repo-RELATIVE; the RegistryBuilder (init.lua) prefixes repo_root +
-- super-repo members. Absolute global globs (chat/note's chat_dir/notes_dir)
-- pass through unchanged there.
--
-- `plan` has no config key (parley does not auto-create workshop/plans/), so
-- its glob is the literal `workshop/plans/*.md`.

local M = {}

--- The base descriptor list, computed from the given (live) config.
--- @param config table parley config (must carry the dir keys below)
--- @return table list of base TypeDescriptors
function M.build(config)
    return {
    -- chat — parley-native; header carries `file:`/`topic:`, no `type:`.
    -- Homed in the repo chat dir (primary) and the demoted global chat_dir.
    {
        name = "chat",
        label = "Chat",
        scope = "base",
        locate = { config.repo_chat_dir .. "/*.md", config.chat_dir .. "/*.md" },
        matcher = { kind = "frontmatter_present", field = "file" },
        blurb = "a parley chat session",
    },
    -- note — parley-native; no fixed frontmatter discriminator, the locate
    -- glob alone homes it (repo note dir + demoted global notes_dir).
    {
        name = "note",
        label = "Note",
        scope = "base",
        locate = { config.repo_note_dir .. "/*.md", config.notes_dir .. "/*.md" },
        matcher = { kind = "any" },
        blurb = "a freeform note",
    },
    -- vision — yaml tracker entries; the glob (and extension) discriminates.
    {
        name = "vision",
        label = "Vision",
        scope = "base",
        locate = { config.vision_dir .. "/*.yaml" },
        matcher = { kind = "any" },
        blurb = "a vision-tracker node",
    },
    -- issue — sdlc-owned; NNNNNN-slug filename convention (shared with plan,
    -- so the locate glob, not the basename, separates the two).
    {
        name = "issue",
        label = "Issue",
        scope = "base",
        locate = { config.issues_dir .. "/*.md" },
        matcher = { kind = "filename", pattern = "^%d%d%d%d%d%d%-" },
        blurb = "an sdlc work item (NNNNNN-slug)",
    },
    -- plan — durable design doc; same NNNNNN-slug convention as issue, but
    -- homed in workshop/plans/ (no config key — parley does not create it).
    {
        name = "plan",
        label = "Plan",
        scope = "base",
        locate = { "workshop/plans/*.md" },
        matcher = { kind = "any" },
        blurb = "a durable implementation plan",
    },
    -- pensive — universal; per-topic thinking note, `type: pensive`.
    {
        name = "pensive",
        label = "Pensive",
        scope = "base",
        locate = { "**/*.md" },
        matcher = { kind = "frontmatter", field = "type", value = "pensive" },
        blurb = "a per-topic thinking note",
    },
    -- prose — universal; long-form writing, `type: prose`.
    {
        name = "prose",
        label = "Prose",
        scope = "base",
        locate = { "**/*.md" },
        matcher = { kind = "frontmatter", field = "type", value = "prose" },
        blurb = "long-form prose",
    },
    -- continuation — universal; session hand-off doc, `type: continuation`.
    {
        name = "continuation",
        label = "Continuation",
        scope = "base",
        locate = { "**/*.md" },
        matcher = { kind = "frontmatter", field = "type", value = "continuation" },
        blurb = "a session hand-off doc",
    },
    }
end

return M
