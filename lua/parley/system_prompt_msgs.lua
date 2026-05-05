-- parley.system_prompt_msgs — build leading messages that carry the
-- agent's system prompt.
--
-- Returns a list of 0, 1, or 2 messages to be prepended to the
-- conversation. PURE: no I/O, no vim state. The provider feature
-- check is delegated to a callback so tests don't need to load the
-- providers module.
--
-- Two output shapes:
--
--   1. Default (`synthetic_system_prompt` falsy):
--      [{ role = "system", content = <prompt>, cache_control? }]
--
--      The Anthropic adapter extracts role="system" messages into
--      payload.system; OpenAI/Google leave them inline. Existing
--      behavior, byte-identical to pre-#118.
--
--   2. Synthetic (`synthetic_system_prompt = true`):
--      [
--        { role = "user", content = <prompt> + cache_control on the
--          content block when the provider supports it },
--        { role = "assistant", content = <ack text> },
--      ]
--
--      Compatibility shim for providers / models that handle a real
--      `system` field poorly. The synthetic assistant ack ("Got it…")
--      puts the model in a state where it has committed to the rules.
--
-- See workshop/issues/000118-synthetic-system-prompt-via-leading-user-turn.md.

local M = {}

local DEFAULT_ACK = "Got it. I will follow this."

--- Build leading messages for the agent's system prompt.
--- @param agent_info table  { system_prompt, provider, synthetic_system_prompt?, synthetic_system_prompt_ack? }
--- @param has_cache_control fun(provider: string): boolean  feature probe
--- @return table[] messages  0, 1, or 2 entries to prepend to the conversation
function M.build(agent_info, has_cache_control)
    local content = agent_info and agent_info.system_prompt
    if type(content) ~= "string" or not content:match("%S") then
        return {}
    end

    local cache_supported = false
    if agent_info.provider and type(has_cache_control) == "function" then
        cache_supported = has_cache_control(agent_info.provider) and true or false
    end

    if agent_info.synthetic_system_prompt then
        local user_msg
        if cache_supported then
            user_msg = {
                role = "user",
                content = {
                    {
                        type = "text",
                        text = content,
                        cache_control = { type = "ephemeral" },
                    },
                },
            }
        else
            user_msg = { role = "user", content = content }
        end
        local ack = agent_info.synthetic_system_prompt_ack
        if type(ack) ~= "string" or ack == "" then
            ack = DEFAULT_ACK
        end
        return { user_msg, { role = "assistant", content = ack } }
    end

    local sys_msg = { role = "system", content = content }
    if cache_supported then
        sys_msg.cache_control = { type = "ephemeral" }
    end
    return { sys_msg }
end

M.DEFAULT_ACK = DEFAULT_ACK

return M
