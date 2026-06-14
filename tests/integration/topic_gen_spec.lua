-- generate_topic must NOT carry the persona system prompt into the topic
-- request — the default system prompt mandates a `🧠:` thinking block, which an
-- obedient model emits and which then lands as the "topic".

local tmp_dir = (os.getenv("TMPDIR") or "/tmp") .. "/parley-topic-gen-" .. os.time()
vim.fn.mkdir(tmp_dir, "p")

local parley = require("parley")
parley.setup({ chat_dir = tmp_dir, state_dir = tmp_dir .. "/state", providers = {}, api_keys = {} })
local chat_respond = require("parley.chat_respond")

describe("_conversation_after_lead (drops system-prompt + ancestors)", function()
    it("drops a synthetic system prompt (lead=2) — the user-turn + ack form", function()
        local msgs = {
            { role = "user", content = "SYSTEM with 🧠 mandate" }, -- synthetic sysprompt
            { role = "assistant", content = "Got it." }, -- ack
            { role = "user", content = "what is lua?" },
            { role = "assistant", content = "Lua is a language." },
        }
        assert.same({
            { role = "user", content = "what is lua?" },
            { role = "assistant", content = "Lua is a language." },
        }, chat_respond._conversation_after_lead(msgs, 2))
    end)

    it("drops a default system prompt (lead=1)", function()
        local msgs = { { role = "system", content = "sys" }, { role = "user", content = "q" } }
        assert.same({ { role = "user", content = "q" } }, chat_respond._conversation_after_lead(msgs, 1))
    end)

    it("drops system + ancestor messages (lead = sys + ancestors)", function()
        local msgs = {
            { role = "system", content = "sys" },
            { role = "user", content = "anc-q" },
            { role = "assistant", content = "anc-a" },
            { role = "user", content = "cur-q" },
        }
        assert.same({ { role = "user", content = "cur-q" } }, chat_respond._conversation_after_lead(msgs, 3))
    end)
end)

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
