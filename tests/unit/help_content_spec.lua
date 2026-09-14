describe('bundled help content', function()
    local intro = '<!-- parley:introduction:start -->Parley is a chat app.<!-- parley:introduction:end -->'
    it('discovers only local atlas Markdown links and shares the README introduction', function()
        local help = require('parley.help_content')
        local docs = assert(help.parse(intro, '[Chat](chat/format.md) [duplicate](chat/format.md) '
            .. '[escape](../secret.md) [absolute](/etc/secret.md) [remote](https://example.com/a.md)'))
        assert.same({'README', 'atlas/index', 'tutorials/welcome', 'tutorials/basics', 'tutorials/advanced', 'atlas/chat/format'}, docs.topics)
        assert.equals('atlas/chat/format.md', docs.paths['atlas/chat/format'])
        assert.truthy(help.introduction(docs.overview, 'app'):find('standalone', 1, true))
        assert.truthy(help.introduction(docs.overview, 'plugin'):find('Neovim plugin', 1, true))
        assert.truthy(help.introduction(docs.overview, 'app'):find('Parley is a chat app.', 1, true))
    end)
    it('exposes only the three canonical tutorials and keeps the topic ceiling', function()
        local help = require('parley.help_content')
        local docs = assert(help.parse(intro, ''))
        for _, name in ipairs({'welcome', 'basics', 'advanced'}) do
            assert.equals('packaging/tutorials/' .. name .. '.md', docs.paths['tutorials/' .. name])
        end
        assert.is_nil(docs.paths['workshop/parley/welcome'])
        local links = {}
        for i = 1, 251 do links[#links + 1] = '[Page](page' .. i .. '.md)' end
        assert.equals(256, #assert(help.parse(intro, table.concat(links))).topics)
        links[#links + 1] = '[Extra](extra.md)'
        assert.is_nil(help.parse(intro, table.concat(links)))
    end)
    it('rejects missing introduction and oversized source', function()
        local help = require('parley.help_content')
        assert.is_nil(help.parse('no introduction', ''))
        assert.is_nil(help.parse(intro .. string.rep('x', 131073), ''))
        assert.is_nil(help.parse(intro, string.rep('x', 131073)))
    end)
end)
