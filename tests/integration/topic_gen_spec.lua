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

    it("falls back through real dispatcher teardown on drained transport failure", function()
        local tasker = require("parley.tasker")
        local vault = require("parley.vault")
        vault.resolve_secret("openai", "test-secret", function() end)
        parley.dispatcher.providers.openai = parley.dispatcher.providers.openai or {}
        parley.dispatcher.providers.openai.endpoint = "http://unused.test"

        local original_run = tasker.run
        tasker.run = function(_buf, _cmd, args, terminal, out_reader)
            local write_out
            for i, arg in ipairs(args) do
                if arg == "--write-out" then write_out = args[i + 1] end
            end
            local sentinel = write_out:match("%%{stderr}(.-)%%{http_code}")
            out_reader(nil, nil)
            terminal(7, 0, "", sentinel .. "000\n", nil)
        end

        local result
        chat_respond.generate_topic({ { role = "user", content = "hello" } },
            "openai", { model = "gpt-x" }, function(topic, reason)
                result = { topic = topic, reason = reason }
            end)
        assert.is_true(vim.wait(500, function() return result ~= nil end, 10))
        tasker.run = original_run

        assert.is_nil(result.topic)
        assert.equals("empty", result.reason)
    end)
end)

describe("ChatPrune topic generation failure", function()
    local saved_generate_topic

    local function write_parent(name)
        local path = tmp_dir .. "/" .. name
        vim.fn.writefile({
            "---",
            "topic: parent topic",
            "file: " .. name,
            "---",
            "",
            "💬: keep this exchange",
            "",
            "🤖: kept answer",
            "",
            "💬: prune this exchange",
            "",
            "🤖: pruned answer",
            "",
        }, path)
        vim.cmd("edit! " .. vim.fn.fnameescape(path))
        vim.api.nvim_win_set_cursor(0, { 10, 0 })
        return path
    end

    before_each(function()
        saved_generate_topic = chat_respond.generate_topic
    end)

    after_each(function()
        chat_respond.generate_topic = saved_generate_topic
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            local name = vim.api.nvim_buf_get_name(buf)
            if name:find(tmp_dir, 1, true) then
                pcall(vim.api.nvim_buf_delete, buf, { force = true })
            end
        end
        for _, path in ipairs(vim.fn.glob(tmp_dir .. "/*.md", false, true)) do
            vim.fn.delete(path)
        end
    end)

    for _, reason in ipairs({ "abort", "empty" }) do
        it("keeps the pruned chat unchanged when topic generation returns " .. reason, function()
            local parent = write_parent("2026-07-12-12000" .. (#reason) .. "-parent-" .. reason .. ".md")
            chat_respond.generate_topic = function(_messages, _provider, _model, callback)
                callback(nil, reason)
            end

            local ok, err = pcall(parley.cmd.ChatPrune)

            assert.is_true(ok, tostring(err))
            local parent_content = table.concat(vim.fn.readfile(parent), "\n")
            assert.is_truthy(parent_content:find("🌿:", 1, true))
            assert.is_falsy(parent_content:find("🌿:.-: nil"))
            local children = vim.fn.glob(tmp_dir .. "/*.md", false, true)
            assert.equals(2, #children)
            local child = children[1] == parent and children[2] or children[1]
            assert.is_truthy(table.concat(vim.fn.readfile(child), "\n"):find("topic: ?", 1, true))
        end)
    end
end)
