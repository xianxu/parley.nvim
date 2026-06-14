-- generate_topic must NOT carry the persona system prompt into the topic
-- request — the default system prompt mandates a `🧠:` thinking block, which an
-- obedient model emits and which then lands as the "topic".

local tmp_dir = (os.getenv("TMPDIR") or "/tmp") .. "/parley-topic-gen-" .. os.time()
vim.fn.mkdir(tmp_dir, "p")

local parley = require("parley")
parley.setup({ chat_dir = tmp_dir, state_dir = tmp_dir .. "/state", providers = {}, api_keys = {} })
local chat_respond = require("parley.chat_respond")

describe("generate_topic", function()
    it("drops the system prompt and uses the minimal topic prompt", function()
        local captured
        local saved = parley.dispatcher.query
        parley.dispatcher.query = function(_buf, _provider, payload)
            captured = payload
        end

        chat_respond.generate_topic({
            { role = "system", content = "...always begin with a 🧠: thinking block..." },
            { role = "user", content = "what is lua?" },
            { role = "assistant", content = "🧠: reasoning here\n\nLua is a scripting language." },
        }, "openai", { model = "gpt-x" }, function() end)

        parley.dispatcher.query = saved

        assert.is_truthy(captured) -- the query was issued
        -- NO system message reaches the topic-gen request
        for _, m in ipairs(captured.messages) do
            assert.not_equals("system", m.role)
        end
        -- the minimal topic prompt is the final (user) message
        local last = captured.messages[#captured.messages]
        assert.equals("user", last.role)
        assert.equals(parley.config.chat_topic_gen_prompt, last.content)
        assert.is_truthy(last.content:lower():find("topic"))
        -- and it carries no 🧠: thinking mandate
        assert.is_nil(last.content:find("🧠"))
    end)
end)
