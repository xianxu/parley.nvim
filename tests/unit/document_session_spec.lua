local model
local function load_model()
    local ok, module = pcall(require, "parley.document_session")
    assert.is_true(ok, tostring(module))
    model = module
end
local null = {}
local function registration(path)
    return { ID = "doc-1", File = path or "/old.md", Owner = "ops:1", RegisteredOwner = "ops:1", RegisteredAt = "now" }
end
local function session()
    return model.new({ path = "/old.md", namespace = "thread", incarnation = 7 })
end
local function outcome(kind, path)
    return { kind = kind, registration = kind == "registered" and registration(path) or nil }
end
local function reply(s, effect, result)
    return s.dispatch({ type = "reply", witness = effect.witness, result = result })
end
local function plain(s)
    reply(s, s.dispatch({ type = "open" })[1], { kind = "absent" })
end
local function attached(s)
    reply(s, s.dispatch({ type = "open" })[1], outcome("registered"))
end

describe("document_session.classify_reply", function()
    before_each(load_model)
    it("proves absence only with explicit lookup null and success", function()
        assert.equals("absent", model.classify_reply("lookup", 0, { Code = "ok", Registration = null }, null).kind)
        for _, op in ipairs({ "lookup", "register", "rename" }) do
            for _, exit in ipairs({ 0, 1 }) do
                for _, envelope in ipairs({ {}, { Code = "ok" }, { Code = "ok", Registration = null }, { Code = "bad", Registration = null } }) do
                    if op ~= "lookup" or exit ~= 0 or envelope.Code ~= "ok" or envelope.Registration ~= null then
                        assert.equals("unavailable", model.classify_reply(op, exit, envelope, null).kind)
                    end
                end
            end
        end
        assert.equals("unavailable", model.classify_reply("lookup", 0, { Code = "ok" }, nil).kind)
    end)
    it("validates every registration field and mutation Changed", function()
        for _, op in ipairs({ "lookup", "register", "rename" }) do
            assert.equals("registered", model.classify_reply(op, 0,
                { Code = "ok", Registration = registration(), Changed = false }, null).kind)
            for _, key in ipairs({ "ID", "File", "Owner", "RegisteredOwner", "RegisteredAt" }) do
                for _, bad in ipairs({ false, 42, {} }) do
                    local reg = registration()
                    reg[key] = bad
                    assert.equals("unavailable", model.classify_reply(op, 0, { Code = "ok", Registration = reg, Changed = true }, null).kind)
                end
                local reg = registration()
                reg[key] = nil
                assert.equals("unavailable", model.classify_reply(op, 0, { Code = "ok", Registration = reg, Changed = true }, null).kind)
            end
            local reg = registration("relative.md")
            assert.equals("unavailable", model.classify_reply(op, 0, { Code = "ok", Registration = reg, Changed = true }, null).kind)
        end
        assert.equals("unavailable", model.classify_reply("register", 0, { Code = "ok", Registration = registration() }, null).kind)
        assert.equals("uncertain", model.classify_reply("rename", 1, { Code = "registry-uncertain", Error = "lost reply" }, null).kind)
        assert.equals("unavailable", model.classify_reply("lookup", 1, { Code = "registry-uncertain" }, null).kind)
    end)
end)

describe("document_session lifecycle", function()
    before_each(load_model)
    it("seeds only a valid canonical cached identity", function()
        local cached = registration()
        local s = model.new({ path = "/old.md", namespace = "thread", incarnation = 7, registration = cached })
        cached.ID = "mutated"
        assert.equals("registered", s.snapshot().phase)
        assert.equals("doc-1", s.snapshot().registration.ID)
        local lookup = s.dispatch({ type = "open" })[1]
        assert.same({}, reply(s, lookup, { kind = "unavailable" }))
        assert.equals("registered", s.snapshot().phase)
        local wrong = model.new({ path = "/wrong.md", namespace = "thread", incarnation = 7, registration = registration() })
        assert.equals("unknown", wrong.snapshot().phase)
        assert.is_nil(wrong.snapshot().registration)
    end)
    it("keeps unavailable admission editable and attaches only confirmed identity", function()
        local s = session()
        local effects = reply(s, s.dispatch({ type = "open" })[1], { kind = "unavailable", error = "offline" })
        assert.equals("unknown", s.snapshot().phase)
        assert.equals("band", effects[1].kind)
        assert.equals("Couch unavailable: agentic state unknown", effects[1].message)
        local attached_effects = reply(s, s.dispatch({ type = "open" })[1], outcome("registered"))
        assert.equals("attach", attached_effects[1].kind)
        assert.equals("registered", s.snapshot().phase)
    end)
    it("saves then registers then attaches and sends once", function()
        local s = session()
        plain(s)
        local save = s.dispatch({ type = "submit", owner = "ops:1" })[1]
        assert.equals("save", save.kind)
        assert.same({}, s.dispatch({ type = "submit", owner = "ops:1" }))
        local register = s.dispatch({ type = "saved", witness = save.witness, ok = true })[1]
        assert.equals("register", register.kind)
        local effects = reply(s, register, outcome("registered"))
        assert.equals("attach", effects[1].kind)
        assert.equals("send", effects[2].kind)
        assert.equals("ops:1", effects[2].owner)
        assert.same({}, reply(s, register, outcome("registered")))
        s.dispatch({ type = "sent", witness = effects[2].witness, ok = false, error = "uncertain" })
        assert.equals("registered", s.snapshot().phase)
        assert.equals("doc-1", s.snapshot().registration.ID)
        assert.same({}, s.dispatch({ type = "sent", witness = effects[2].witness, ok = true }))
    end)
    it("does not register or send on save failure", function()
        local s = session()
        plain(s)
        local save = s.dispatch({ type = "submit", owner = "ops:1" })[1]
        local effects = s.dispatch({ type = "saved", witness = save.witness, ok = false, error = "disk full" })
        assert.equals("notify", effects[1].kind)
        assert.equals("plain", s.snapshot().phase)
    end)
    it("keeps uncertain mutation pending with exact captured identity", function()
        local s = session()
        plain(s)
        local save = s.dispatch({ type = "submit", owner = "ops:1" })[1]
        local reg = s.dispatch({ type = "saved", witness = save.witness, ok = true })[1]
        local effects = reply(s, reg, { kind = "uncertain" })
        assert.equals("pending", s.snapshot().phase)
        assert.equals("reconcile", effects[1].kind)
        assert.equals("register", effects[1].operation)
        assert.same({}, s.dispatch({ type = "submit", owner = "ops:1" }))
    end)
    it("ignores stale reads and never sends after mutation witness invalidation", function()
        for _, change in ipairs({ { type = "changed", path = "/other.md" }, { type = "changed", namespace = "other" }, { type = "changed" }, { type = "detach" } }) do
            local s = session()
            local probe = s.dispatch({ type = "open" })[1]
            s.dispatch(change)
            assert.same({}, reply(s, probe, outcome("registered")))
            s = session()
            plain(s)
            local save = s.dispatch({ type = "submit", owner = "ops:1" })[1]
            local reg = s.dispatch({ type = "saved", witness = save.witness, ok = true })[1]
            s.dispatch(change)
            local effects = reply(s, reg, outcome("registered"))
            for _, effect in ipairs(effects) do
                assert.is_not.equals("send", effect.kind)
                assert.is_not.equals("attach", effect.kind)
                assert.is_not.equals("unlock", effect.kind)
            end
        end
    end)
    it("preserves a stable rename tuple through uncertain outcomes", function()
        local s = session()
        attached(s)
        local move = s.dispatch({ type = "rename", new_path = "/new.md" })[1]
        assert.equals("move", move.kind)
        assert.equals("doc-1", move.registration.ID)
        local metadata = s.dispatch({ type = "moved", witness = move.witness, ok = true })[1]
        assert.equals("rename", metadata.kind)
        assert.equals("/old.md", metadata.old_path)
        assert.equals("/new.md", metadata.new_path)
        reply(s, metadata, { kind = "uncertain" })
        assert.equals("pending", s.snapshot().phase)
        assert.same({}, s.dispatch({ type = "rename", new_path = "/third.md" }))
        local retry = s.dispatch({ type = "retry" })[1]
        assert.equals("rename", retry.kind)
        assert.equals("/old.md", retry.old_path)
        assert.equals("/new.md", retry.new_path)
        local done = reply(s, retry, outcome("registered", "/new.md"))
        assert.equals("finish_move", done[1].kind)
        assert.equals("doc-1", s.snapshot().registration.ID)
        assert.equals("/new.md", s.snapshot().path)
    end)
    it("rejects metadata identity changes and protects private state from effects and snapshots", function()
        local s = session()
        attached(s)
        local snapshot = s.snapshot()
        snapshot.registration.ID = "forged"
        snapshot.path = "/forged"
        local move = s.dispatch({ type = "rename", new_path = "/new.md" })[1]
        move.registration.ID = "forged"
        local rename = s.dispatch({ type = "moved", witness = move.witness, ok = true })[1]
        local wrong = outcome("registered", "/new.md")
        wrong.registration.ID = "wrong"
        local effects = reply(s, rename, wrong)
        assert.equals("pending", s.snapshot().phase)
        assert.equals("reconcile", effects[1].kind)
        assert.equals("doc-1", s.snapshot().registration.ID)
    end)
    it("rejects forged witnesses across bounded completion sequences", function()
        for _, field in ipairs({ "namespace", "path", "incarnation", "generation", "token", "operation" }) do
            local s = session()
            plain(s)
            local save = s.dispatch({ type = "submit", owner = "ops:1" })[1]
            local witness = vim.deepcopy(save.witness)
            witness[field] = "forged"
            assert.same({}, s.dispatch({ type = "saved", witness = witness, ok = true }))
            local reg = s.dispatch({ type = "saved", witness = save.witness, ok = true })[1]
            local sent = reply(s, reg, outcome("registered"))[2]
            s.dispatch({ type = "sent", witness = sent.witness, ok = true })
            assert.same({}, s.dispatch({ type = "saved", witness = save.witness, ok = true }))
        end
    end)
end)
