-- Pure public reason: every displayed character comes from a fixed diagnostic
-- or a validated HTTP integer. Provider prose, stderr and request data stay private.
local M = {}
local tool_choice_rejection = 'tool_choice: type "tool" and "any" are not supported for this model.'
local safe_messages = {
    [tool_choice_rejection] = tool_choice_rejection,
    ['Service unavailable'] = 'Service unavailable',
}
local safe_types = {
    invalid_request_error = 'invalid request', authentication_error = 'authentication failed',
    permission_error = 'permission denied', rate_limit_error = 'rate limit exceeded',
    overloaded_error = 'provider overloaded', api_error = 'provider error',
}
local safe_statuses = {
    [400] = 'invalid request', [401] = 'authentication failed', [403] = 'permission denied',
    [404] = 'resource unavailable', [429] = 'rate limit exceeded', [503] = 'service unavailable',
}
function M.reason(failure)
    failure = type(failure) == 'table' and failure or {}
    local status = failure.http_status
    local valid_status = type(status) == 'number' and status >= 100 and status <= 599 and status % 1 == 0
    local prefix = valid_status and ('HTTP ' .. tostring(status) .. ': ') or ''
    if failure.exit then return prefix .. 'provider transport failed' end
    local fallback = (valid_status and safe_statuses[status]) or 'provider request failed'
    local body = failure.body
    if type(body) == 'string' and #body <= 16384 then
        local ok, decoded = pcall(vim.json.decode, body)
        local err = ok and type(decoded) == 'table' and decoded.error
        if type(err) == 'table' then
            -- Exact equality, never a prefix, substring, normalization or echo.
            return prefix .. (safe_messages[err.message] or safe_types[err.type] or fallback)
        end
    end
    return prefix .. fallback
end
return M
