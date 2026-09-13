-- Unit tests for image blocks on the three wire shapes (#231 Task 7)
--
-- One internal image block, three wire shapes — asserted against the payload
-- prepare_payload builds, per wire, from the provider docs read 2026-09-12:
--   anthropic: { type="image", source={ type="base64", media_type, data } } passes through
--   openai:    { type="image_url", image_url={ url="data:<mime>;base64,…", detail="auto" } }
--   googleai:  { inlineData={ mimeType, data } } (camelCase)
-- Text-only shapes are pinned so the change is additive on every wire.
local tmp_dir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-wire-images-" .. os.time()
local parley = require("parley")
parley.setup({ chat_dir = tmp_dir, state_dir = tmp_dir .. "/state", providers = {}, api_keys = {} })
local dispatcher = require("parley.dispatcher")

-- As dispatcher_spec does: a truthy web_search would append server tools to
-- the anthropic/googleai payloads and muddy the pinned shapes. Nothing in
-- this file flips it, so once at file scope is enough.
parley._state.web_search = false

local DATA = vim.base64.encode("PNGBYTES")
local function image_block()
    return { type = "image", source = { type = "base64", media_type = "image/png", data = DATA } }
end
local function image_user(text)
    return {
        role = "user",
        content = {
            image_block(),
            { type = "text", text = text },
        },
    }
end
local function sys(t) return { role = "system", content = t } end
local function user(t) return { role = "user", content = t } end
local function assistant(t) return { role = "assistant", content = t } end

describe("image attachments on the anthropic wire", function()
    it("passes the image block through, images before text, system hoisted", function()
        local payload = dispatcher.prepare_payload(
            { sys("S"), image_user("what?") }, { model = "claude-opus-5" }, "anthropic")
        assert.equals("S", payload.system[1].text)
        assert.equals(1, #payload.messages)
        local m = payload.messages[1]
        assert.equals("user", m.role)
        assert.same(image_block(), m.content[1])
        assert.same({ type = "text", text = "what?" }, m.content[2])
    end)
end)

describe("image attachments on the openai wire", function()
    it("becomes an image_url data URL part followed by a text part", function()
        local payload = dispatcher.prepare_payload(
            { sys("S"), image_user("what?") }, { model = "gpt-4o" }, "openai")
        assert.equals(2, #payload.messages)
        local m = payload.messages[2]
        assert.equals("user", m.role)
        assert.same({
            { type = "image_url", image_url = { url = "data:image/png;base64," .. DATA, detail = "auto" } },
            { type = "text", text = "what?" },
        }, m.content)
    end)

    it("an image with no text is a parts list with no text part", function()
        local msg = { role = "user", content = { image_block() } }
        local payload = dispatcher.prepare_payload({ msg }, { model = "gpt-4o" }, "openai")
        assert.equals(1, #payload.messages[1].content)
        assert.equals("image_url", payload.messages[1].content[1].type)
    end)

    it("a text-only user message stays a plain string (pinned)", function()
        local payload = dispatcher.prepare_payload({ user("hi") }, { model = "gpt-4o" }, "openai")
        assert.equals("hi", payload.messages[1].content)
    end)

    it("text-only blocks still collapse to a plain string (pinned)", function()
        local msg = { role = "user", content = { { type = "text", text = "a" }, { type = "text", text = "b" } } }
        local payload = dispatcher.prepare_payload({ msg }, { model = "gpt-4o" }, "openai")
        assert.equals("a\n\nb", payload.messages[1].content)
    end)

    it("tool_result blocks and an image in one user turn keep their order", function()
        local msg = {
            role = "user",
            content = {
                { type = "tool_result", tool_use_id = "t1", content = "R" },
                image_block(),
                { type = "text", text = "and?" },
            },
        }
        local payload = dispatcher.prepare_payload({ msg }, { model = "gpt-4o" }, "openai")
        assert.equals(2, #payload.messages)
        assert.equals("tool", payload.messages[1].role)
        assert.equals("t1", payload.messages[1].tool_call_id)
        assert.equals("R", payload.messages[1].content)
        assert.equals("user", payload.messages[2].role)
        assert.equals("image_url", payload.messages[2].content[1].type)
        assert.equals("and?", payload.messages[2].content[2].text)
    end)

    it("still warns and drops an unknown block type", function()
        local logger = require("parley.logger")
        local warned = {}
        local orig = logger.warning
        logger.warning = function(m) table.insert(warned, m) end
        local msg = { role = "user", content = { { type = "document" }, { type = "text", text = "t" } } }
        local ok, payload = pcall(dispatcher.prepare_payload, { msg }, { model = "gpt-4o" }, "openai")
        logger.warning = orig
        assert.is_true(ok)
        assert.equals("t", payload.messages[1].content)
        assert.equals(1, #warned)
        assert.truthy(warned[1]:find("document", 1, true))
    end)
end)

describe("image attachments on the googleai wire", function()
    it("becomes an inlineData part, camelCase, before the text part", function()
        local payload = dispatcher.prepare_payload(
            { image_user("what?") }, { model = "gemini-2.5-pro" }, "googleai")
        assert.equals(1, #payload.contents)
        local c = payload.contents[1]
        assert.equals("user", c.role)
        assert.is_nil(c.content)
        assert.same({
            { inlineData = { mimeType = "image/png", data = DATA } },
            { text = "what?" },
        }, c.parts)
    end)

    it("same-role merging appends whole parts lists", function()
        local payload = dispatcher.prepare_payload(
            { sys("S"), image_user("what?") }, { model = "gemini-2.5-pro" }, "googleai")
        -- system → user, merged with the following user message
        assert.equals(1, #payload.contents)
        assert.same({
            { text = "S" },
            { inlineData = { mimeType = "image/png", data = DATA } },
            { text = "what?" },
        }, payload.contents[1].parts)
    end)

    it("warns and drops an unknown block type", function()
        local logger = require("parley.logger")
        local warned = {}
        local orig = logger.warning
        logger.warning = function(m) table.insert(warned, m) end
        local msg = { role = "user", content = { { type = "document" }, { type = "text", text = "t" } } }
        local ok, payload = pcall(dispatcher.prepare_payload, { msg }, { model = "gemini-2.5-pro" }, "googleai")
        logger.warning = orig
        assert.is_true(ok)
        assert.same({ { text = "t" } }, payload.contents[1].parts)
        assert.equals(1, #warned)
        assert.truthy(warned[1]:find("document", 1, true))
    end)

    it("text-only payloads are byte-identical to before (pinned)", function()
        local payload = dispatcher.prepare_payload(
            { sys("S"), user("u"), assistant("a"), user("u2") }, { model = "gemini-2.5-pro" }, "googleai")
        assert.same({
            { role = "user", parts = { { text = "S" }, { text = "u" } } },
            { role = "model", parts = { { text = "a" } } },
            { role = "user", parts = { { text = "u2" } } },
        }, payload.contents)
    end)
end)
