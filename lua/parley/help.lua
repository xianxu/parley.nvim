-- Only the installed README and atlas-linked Markdown are exposed to models.
local content = require('parley.help_content')
local uv = vim.uv or vim.loop
local source = debug.getinfo(1, 'S').source:sub(2)
local root = source:match('^(.*)/lua/parley/help%.lua$')
root = root and uv.fs_realpath(root)
local function read_file(path)
    local expected = root and root .. '/' .. path
    -- Reject redirected documentation, including symlinked parent directories.
    if not expected or uv.fs_realpath(expected) ~= expected then
        return nil, 'Bundled documentation is missing or redirected'
    end
    local stat = uv.fs_stat(expected)
    if not stat or stat.type ~= 'file' or stat.size > 131072 then
        return nil, 'Invalid bundled documentation file'
    end
    local file = io.open(expected, 'rb')
    if not file then return nil, 'Bundled documentation is unreadable' end
    local text = file:read(131073) or ''
    file:close()
    if #text > 131072 then return nil, 'Bundled documentation exceeds size limit' end
    return text
end
local readme, problem = read_file('README.md')
local atlas, atlas_error = read_file('atlas/index.md')
local docs
if readme and atlas then docs, problem = content.parse(readme, atlas)
else problem = problem or atlas_error end
local M = {}
function M.read(topic)
    if not docs then return nil, problem end
    if topic == nil or topic == '' then return table.concat(docs.topics, '\n') end
    if type(topic) ~= 'string' or not docs.paths[topic] then
        return nil, 'Unknown help topic; call parley_help without a topic to list topics'
    end
    return read_file(docs.paths[topic])
end
function M.context(mode)
    return docs and content.introduction(docs.overview, mode) or ''
end
return M
