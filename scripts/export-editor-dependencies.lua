-- Standalone export: never resolve the manifest through user runtime paths.
-- luacheck: globals vim
local source = debug.getinfo(1, 'S').source:sub(2)
local root = assert(source:match('^(.*)/scripts/export%-editor%-dependencies%.lua$'))
local manifest = dofile(root .. '/lua/parley/editor_dependencies.lua')
local profile, platform = arg[1] or 'app', arg[2]
if not platform or platform == 'auto' then
    platform = dofile(root .. '/lua/parley/editor_bundle.lua').platform()
end
io.stdout:write(vim.json.encode(manifest.export(profile, platform)), '\n')
