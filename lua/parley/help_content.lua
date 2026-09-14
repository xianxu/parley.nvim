-- Pure discovery of the published documentation and its shared introduction.
local M = {}
function M.parse(readme, atlas)
    if type(readme) ~= 'string' or type(atlas) ~= 'string'
        or #readme > 131072 or #atlas > 131072 then return nil, 'Invalid documentation size' end
    local overview = readme:match('<!%-%- parley:introduction:start %-%->(.-)<!%-%- parley:introduction:end %-%->')
    if not overview or not overview:match('%S') then return nil, 'README introduction is missing' end
    local docs = {overview = overview:match('^%s*(.-)%s*$'), topics = {'README', 'atlas/index'},
        paths = {README = 'README.md', ['atlas/index'] = 'atlas/index.md'}}
    for _, name in ipairs({'welcome', 'basics', 'advanced'}) do
        local topic = 'tutorials/' .. name
        docs.topics[#docs.topics + 1] = topic
        docs.paths[topic] = 'packaging/tutorials/' .. name .. '.md'
    end
    for path in atlas:gmatch('%]%(([%w_/%-]+%.md)%)') do
        local topic = 'atlas/' .. path:sub(1, -4)
        if path:sub(1, 1) ~= '/' and not path:find('//', 1, true) and not docs.paths[topic] then
            if #docs.topics >= 256 then return nil, 'Too many documentation topics' end
            docs.topics[#docs.topics + 1] = topic
            docs.paths[topic] = 'atlas/' .. path
        end
    end
    return docs
end
function M.introduction(overview, mode)
    local current = mode == 'app' and 'standalone Parley app' or 'parley.nvim Neovim plugin'
    return 'Parley product context (installed README):\nCurrent mode: ' .. current
        .. '.\n' .. overview .. '\nFor Parley questions, use parley_help if available to discover '
        .. 'the installed README, tutorials and atlas. Start with tutorials for guided usage and atlas for feature reference. Atlas also describes internals and may label future plans; '
        .. 'do not present planned features as shipped. Prefer atlas/infra/starter for app defaults.'
end
return M
