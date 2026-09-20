-- End-to-end OpenAI tool loop against a process-level fake (#198 M2).
--
-- The unit specs pin each wire function in isolation. This one proves the
-- pieces compose: a real curl request to a real HTTP server, a real SSE
-- stream, the real decoder, the real tool dispatcher executing a real file
-- read, and the real 🔧:/📎: buffer writes — with nothing stubbed on the
-- parley side.
--
-- ARCH-MOCK: the fake is stateful. It decides which round it is in by
-- inspecting the REQUEST (a body carrying a role:"tool" message is by
-- definition the second leg), so the two-round loop is modelled rather than
-- counted. A function-call mock cannot catch the interaction bugs this can —
-- notably the class the plan gate caught, where messages reached the wire
-- untranslated.

local uv = vim.uv or vim.loop
local FAKE = vim.fn.getcwd() .. "/tests/fixtures/fake_cliproxy"

local dispatcher = require("parley.dispatcher")
local ready_port = require("tests.helpers.ready_port")
local Session = require("parley.response_session")
local D = require("parley.document")
local Layout = require("parley.response_layout")
local Preparation = require("parley.response_preparation")
local registry = require("parley.tools")
local vault = require("parley.vault")
local parley = require("parley")

local fixture_process = require("tests.helpers.fixture_process")
local mark

local function start_fake(port, response_mode, env)
    -- The seam MERGES env into the parent's rather than replacing it, so this no
    -- longer has to re-add PATH by hand (#220).
    local handle, _, err, pid = fixture_process.spawn(FAKE,
        { "--port", tostring(port), "--response-mode", response_mode }, env)
    assert(handle, "spawn fake: " .. tostring(err))
    -- wait for the listener
    local up = false
    vim.wait(5000, function()
        local c = uv.new_tcp()
        c:connect("127.0.0.1", port, function(err)
            up = err == nil
            c:close()
        end)
        vim.wait(50, function() return false end)
        return up
    end, 50)
    assert(up, "fake did not come up on port " .. port)
    return pid
end

describe("openai tool loop against a stateful fake (#198)", function()
    local port, tmpdir, file_a, file_b
    local saved_endpoint, saved_manage, buf, doc, session

    before_each(function()
        mark = fixture_process.mark()
        buf,doc,session=nil,nil,nil
        registry.register_builtins()
        parley._state = parley._state or {}
        parley._state.web_search = false

        tmpdir = vim.fn.tempname()
        vim.fn.mkdir(tmpdir, "p")
        file_a = tmpdir .. "/alpha.txt"
        file_b = tmpdir .. "/beta.txt"
        vim.fn.writefile({ "ALPHA-CONTENT" }, file_a)
        vim.fn.writefile({ "BETA-CONTENT" }, file_b)

        port = ready_port.free_port()
        saved_endpoint = dispatcher.providers.cliproxyapi
            and dispatcher.providers.cliproxyapi.endpoint
        dispatcher.providers.cliproxyapi = dispatcher.providers.cliproxyapi or {}
        dispatcher.providers.cliproxyapi.endpoint =
            "http://127.0.0.1:" .. port .. "/v1/chat/completions"
        -- Do not let the managed-proxy hook try to start a real binary.
        local cliproxy = require("parley.cliproxy")
        saved_manage = cliproxy.is_managed
        cliproxy.is_managed = function() return false end

        vault.add_secret("cliproxyapi", "testkey")
    end)

    after_each(function()
        if session then Session.cancel(session)end
        if doc then D.detach(doc)end
        if buf and vim.api.nvim_buf_is_valid(buf)then vim.api.nvim_buf_delete(buf,{force=true})end
        fixture_process.reap({ since = mark, signal = "sigterm" })
        if saved_endpoint then
            dispatcher.providers.cliproxyapi.endpoint = saved_endpoint
        end
        require("parley.cliproxy").is_managed = saved_manage
        registry.register_builtins()
    end)

    -- The session drives both HTTP legs. The server chooses its answer from
    -- translated role:tool messages, so a lost tool result cannot pass by count.
    local function run_session(mode)
        start_fake(port, mode, {
            PARLEY_FAKE_TOOL_PATH_A = file_a, PARLEY_FAKE_TOOL_PATH_B = file_b,
        })
        buf=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{"💬: read files","🤖: old","text"})
        doc=D.attach(buf)
        local plan=Preparation.plan(Layout.prepare({lines={"🤖: old","text"},first_row=1,first_byte=1,
            header_lines={"🤖: fixture"}},{chat_branch_prefix="🌿:",chat_local_prefix="🔒:"}))
        local model={model="gpt-5.6-sol"}
        local messages={{role="user",content="read files"}}
        local initial={provider="cliproxyapi",model=model,buf=buf,messages=messages,
            payload=dispatcher.prepare_payload(messages,model,"cliproxyapi",{"read_file"})}
        local continuations,results={},{}
        session=assert(Session.start(doc,{operation="respond",schedule=true,input={},preparation=plan,
            question={first={row=0,col=0},last={row=0,col=#"💬: read files"}},
            output={first={row=0,col=#"💬: read files"},last={row=2,col=4}}},{
            buf=buf,pending=false,allowed_tools={"read_file"},root_policy={write_root=tmpdir,read_roots={tmpdir}},
            prepare_input=function(_,cb)cb.prepared(initial);cb.resolved()end,
            build_input=function(previous,next_messages)
                previous.messages=next_messages
                previous.payload=dispatcher.prepare_payload(next_messages,model,"cliproxyapi",{"read_file"})
                continuations[#continuations+1]=vim.deepcopy(previous.payload)
                return previous
            end,
            on_result=function(_,query,calls)
                results[#results+1]={response=query.response,calls=vim.deepcopy(calls)}
            end,
        }))
        assert.is_true(vim.wait(15000,function()return Session.snapshot(session).status=="terminal"end,5),
            vim.inspect(Session.snapshot(session)))
        assert.equals("success",Session.snapshot(session).generation.outcome)
        return table.concat(vim.api.nvim_buf_get_lines(buf,0,-1,false),"\n"),continuations,results
    end

    it("composes real HTTP tool results into the next translated request and final answer",function()
        local text,continuations,results=run_session("tool_call")
        assert.equals(2,#results);assert.equals(1,#results[1].calls);assert.equals(0,#results[2].calls)
        assert.matches("🔧: read_file id=call_fake_a",text)
        assert.matches("📎: read_file id=call_fake_a",text)
        assert.matches("ALPHA%-CONTENT",text)
        assert.matches("the tool result was received",text)
        assert.equals(1,#continuations)
        assert.equals("tool",continuations[1].messages[#continuations[1].messages].role)
    end)

    it("the request body carries translated messages, not content blocks", function()
        local payload = dispatcher.prepare_payload({
            { role = "user", content = "read alpha" },
            { role = "assistant", content = {
                { type = "tool_use", id = "call_fake_a", name = "read_file",
                  input = { path = file_a } },
            } },
            { role = "user", content = {
                { type = "tool_result", tool_use_id = "call_fake_a", content = "ALPHA-CONTENT" },
            } },
        }, { model = "gpt-5.6-sol" }, "cliproxyapi", { "read_file" })

        local roles = {}
        for _, m in ipairs(payload.messages) do table.insert(roles, m.role) end
        assert.same({ "user", "assistant", "tool" }, roles)
        assert.equals("function", payload.tools[1].type)
    end)

    it("preserves declaration order for multiple real tools through the HTTP continuation",function()
        local text,continuations,results=run_session("tool_call_parallel")
        assert.equals(2,#results[1].calls);assert.equals(1,#continuations)
        assert.matches("ALPHA%-CONTENT",text);assert.matches("BETA%-CONTENT",text)
        assert.matches("the tool result was received",text)
        local messages=continuations[1].messages
        assert.equals("call_fake_a",messages[#messages-1].tool_call_id)
        assert.equals("call_fake_b",messages[#messages].tool_call_id)
        local a=text:find("📎: read_file id=call_fake_a",1,true)
        local b=text:find("📎: read_file id=call_fake_b",1,true)
        assert.is_true(a<b)
    end)
end)
