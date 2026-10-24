local function reason(failure)
    return require('parley.skill_failure').reason(failure)
end

describe('safe skill failure reason (#441)', function()
    it('replays the sanitized upstream rejection without its envelope', function()
        local capture = vim.json.decode(table.concat(vim.fn.readfile('tests/fixtures/review_tool_choice_rejection.json'), '\n'))
        assert.equals('HTTP 400: tool_choice: type "tool" and "any" are not supported for this model.', reason(capture.response))
    end)
    it('selects only the error message, never headers, request or stderr', function()
        local failure = {http_status=503, body=vim.json.encode({error={message='Service unavailable'},
            request={text='PRIVATE DOCUMENT'}, api_key='SECRET'}), stderr='Bearer SECRET', headers='SECRET'}
        assert.equals('HTTP 503: Service unavailable', reason(failure))
    end)
    it('bounds and sanitizes a structured reason', function()
        local output = reason({http_status=400,body=vim.json.encode({error={message=
            'Bad token sk-secret123; Bearer credential; https://private.invalid/path?key=secret\n' .. string.rep('x',1000)}})})
        assert.is_true(#output <= 240)
        for _, secret in ipairs({'sk-secret123','credential','private.invalid','\n'}) do
            assert.is_nil(output:find(secret,1,true))
        end
    end)
    it('redacts quoted document echoes and keeps bounded UTF-8 intact',function()
        local output=reason({http_status=400,body=vim.json.encode({error={message='Invalid value "PRIVATE TEXT"'}})})
        assert.equals('HTTP 400: Invalid value [redacted]',output)
        output=reason({http_status=500,body=vim.json.encode({error={message=string.rep('界',200)}})})
        assert.is_true(#output<=240)
        assert.equals(output,vim.fn.iconv(output,'utf-8','utf-8'))
    end)

    it('does not treat malformed, partial or plain bodies as a safe diagnosis', function()
        for _, body in ipairs({'PRIVATE DOCUMENT', '{"error":', '{"request":"PRIVATE"}', '{"error":{"message":null}}'}) do
            assert.equals('HTTP 500: provider request failed', reason({http_status=500,body=body}))
        end
        assert.equals('provider transport failed', reason({exit='killed: deadline',body='PRIVATE',stderr='SECRET'}))
    end)
end)
