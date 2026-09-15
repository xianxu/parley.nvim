local definition = {
    name = 'parley_help',
    kind = 'read',
    description = 'Read the installed Parley README, tutorials and atlas. Omit topic to list topics, '
        .. 'Then supply an exact topic ID, such as tutorials/welcome or atlas/infra/starter, to read it. Covers app/plugin usage, accounts, '
        .. 'shortcuts, attachments and configuration. No access to personal files.',
    input_schema = {
        type = 'object',
        properties = {topic = {type = 'string', description = 'Topic ID from the topic list; omit to list topics.'}},
    },
    handler = function(input)
        input = input or {}
        for key in pairs(input) do
            if key ~= 'topic' and key ~= 'offset' and key ~= 'limit' then
                return {content = 'Only a help topic is accepted, not a file path', is_error = true}
            end
        end
        local text, err = require('parley.help').read(input.topic)
        -- Documentation can quote chat delimiters. Indent read output so it
        -- cannot become a new exchange when rendered in a transcript.
        if text and input.topic and input.topic ~= '' then text = '    ' .. text:gsub('\n', '\n    ') end
        return {content = text or err, is_error = text == nil}
    end,
}

return require("parley.tools.async_builtin").bind(definition)
