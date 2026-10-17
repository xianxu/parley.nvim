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
    it("keeps Couch's refusal code, so a move can name a target-conflict (#359)", function()
        local refused = model.classify_reply("rename", 1, { Code = "target-conflict", Error = "destination registered" }, null)
        assert.same({ kind = "unavailable", code = "target-conflict", error = "destination registered" }, refused)
        assert.is_nil(model.classify_reply("rename", 0, "not a table", null).code)
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
    it("forgets confirmed absence only after the turn engine reconciles and detaches", function()
        local s = session()
        attached(s)
        local lookup = s.dispatch({ type="open" })[1]
        local detach = reply(s, lookup, {kind="absent"})[1]
        assert.equals("detach_turn", detach.kind)
        assert.equals("doc-1", s.snapshot().registration.ID)
        assert.equals("busy", s.snapshot().phase)
        local effects = s.dispatch({type="turn_detached",witness=detach.witness,ok=true})
        assert.equals("plain", s.snapshot().phase)
        assert.is_nil(s.snapshot().registration)
        assert.equals("band", effects[1].kind)
        assert.same({}, s.dispatch({type="turn_detached",witness=detach.witness,ok=true}))
    end)

    it("retains confirmed identity when forgetting cannot reconcile the turn", function()
        local s = session()
        attached(s)
        local lookup = s.dispatch({type="open"})[1]
        local detach = reply(s, lookup, {kind="absent"})[1]
        local effects = s.dispatch({type="turn_detached",witness=detach.witness,ok=false,error="foreign write unkept"})
        assert.equals("registered", s.snapshot().phase)
        assert.equals("doc-1", s.snapshot().registration.ID)
        assert.equals("notify", effects[1].kind)
        assert.equals("foreign write unkept", effects[1].message)
    end)

    it("replaces a confirmed same-path identity only through reconciled detach and attach", function()
        local s = session()
        attached(s)
        local lookup = s.dispatch({type="open"})[1]
        local replacement = outcome("registered")
        replacement.registration.ID = "replacement"
        replacement.registration.Owner = "other:2"
        local detach = reply(s, lookup, replacement)[1]
        assert.equals("detach_turn", detach.kind)
        assert.equals("doc-1", detach.registration.ID)
        assert.equals("replacement", detach.replacement.ID)
        assert.equals("doc-1", s.snapshot().registration.ID)
        detach.replacement.ID = "forged"
        local effects = s.dispatch({type="turn_detached",witness=detach.witness,ok=true})
        assert.equals("registered", s.snapshot().phase)
        assert.equals("replacement", s.snapshot().registration.ID)
        assert.equals("attach", effects[1].kind)
        assert.equals("other:2", effects[1].registration.Owner)
        assert.equals(1, #effects)
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
    it("refreshes a registered owner through lookup before each explicit send", function()
        local s = session()
        attached(s)
        local save = s.dispatch({ type="submit" })[1]
        local lookup = s.dispatch({ type="saved", witness=save.witness, ok=true })[1]
        assert.equals("lookup", lookup.kind)
        assert.is_true(lookup.submit)
        local refreshed = outcome("registered")
        refreshed.registration.Owner = "other:2"
        local effects = reply(s, lookup, refreshed)
        assert.equals("attach", effects[1].kind)
        assert.equals("other:2", effects[1].registration.Owner)
        assert.equals("send", effects[2].kind)
        assert.equals("other:2", effects[2].owner)
        assert.equals("doc-1", s.snapshot().registration.ID)
    end)

    it("retains attached identity without send when submit owner confirmation fails", function()
        local s = session()
        attached(s)
        local save = s.dispatch({ type="submit" })[1]
        local lookup = s.dispatch({ type="saved", witness=save.witness, ok=true })[1]
        local effects = reply(s, lookup, {kind="unavailable",error="offline"})
        assert.equals("registered", s.snapshot().phase)
        assert.equals("ops:1", s.snapshot().registration.Owner)
        assert.equals(1, #effects)
        assert.equals("notify", effects[1].kind)
        assert.equals("offline", effects[1].message)
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
    it("confirms a body-invalidated registration on retry without resending", function()
        local s = session()
        plain(s)
        local save = s.dispatch({ type = "submit", owner = "ops:1" })[1]
        local register = s.dispatch({ type = "saved", witness = save.witness, ok = true })[1]
        s.dispatch({ type = "changed" })
        reply(s, register, outcome("registered"))
        assert.equals("pending", s.snapshot().phase)
        local retry = s.dispatch({ type = "retry" })[1]
        assert.equals("register", retry.kind)
        assert.is_true(retry.resume_only)
        assert.equals(register.witness.path, retry.witness.path)
        assert.equals(register.owner, retry.owner)
        assert.equals(s.snapshot().generation, retry.witness.generation)
        local effects = reply(s, retry, outcome("registered"))
        assert.equals("registered", s.snapshot().phase)
        assert.equals("attach", effects[1].kind)
        assert.equals(1, #effects)
        assert.same({}, reply(s, retry, outcome("registered")))
    end)

    -- #357: the operator's press on a pending registration confirms it and asks
    -- the shell for a fresh submit (current bytes); it never sends the stale ones.
    local function pending_register(s)
        plain(s)
        local save = s.dispatch({ type = "submit", owner = "ops:1" })[1]
        local register = s.dispatch({ type = "saved", witness = save.witness, ok = true, hash = "h1" })[1]
        reply(s, register, { kind = "unavailable", error = "Couch registry deadline exceeded" })
        assert.equals("pending", s.snapshot().phase)
    end
    it("a pressed retry of a pending registration confirms it, then asks for a fresh submit (#357)", function()
        local s = session()
        pending_register(s)
        local retry = s.dispatch({ type = "retry", submit = true })[1]
        assert.equals("register", retry.kind)
        assert.is_true(retry.resume_only)
        local effects = reply(s, retry, outcome("registered"))
        assert.same({ "attach", "resubmit" }, { effects[1].kind, effects[2] and effects[2].kind })
        assert.equals("registered", s.snapshot().phase)
        for _, effect in ipairs(effects) do assert.is_not.equals("send", effect.kind) end
    end)
    it("an unpressed retry, or one that fails again, asks for no submit (#357)", function()
        local s = session()
        pending_register(s)
        local effects = reply(s, s.dispatch({ type = "retry" })[1], outcome("registered"))
        assert.equals(1, #effects)
        s = session()
        pending_register(s)
        local again = reply(s, s.dispatch({ type = "retry", submit = true })[1], { kind = "unavailable", error = "slow" })
        assert.equals("pending", s.snapshot().phase)
        assert.same({ "reconcile" }, { again[1].kind })
        assert.is_nil(again[2])
    end)
    it("a pressed retry of a pending rename only confirms it (#357)", function()
        local s = session()
        attached(s)
        local move = s.dispatch({ type = "rename", new_path = "/new.md" })[1]
        local metadata = s.dispatch({ type = "moved", witness = move.witness, ok = true })[1]
        reply(s, metadata, { kind = "uncertain" })
        local retry = s.dispatch({ type = "retry", submit = true })[1]
        assert.is_nil(retry.resubmit)
        local done = reply(s, retry, outcome("registered", "/new.md"))
        assert.same({ "finish_move" }, { done[1].kind })
        assert.is_nil(done[2])
    end)

    it("does not reauthorize a pending registration in another path or namespace", function()
        for _, change in ipairs({ { type="changed", path="/other.md" }, { type="changed", namespace="another" } }) do
            local s = session()
            plain(s)
            local save = s.dispatch({ type="submit", owner="ops:1" })[1]
            local register = s.dispatch({ type="saved", witness=save.witness, ok=true })[1]
            s.dispatch(change)
            reply(s, register, outcome("registered"))
            local effects = s.dispatch({ type="retry" })
            for _, effect in ipairs(effects) do
                assert.is_not.equals("attach", effect.kind)
                assert.is_not.equals("send", effect.kind)
                assert.is_not.equals("register", effect.kind)
            end
            assert.equals("pending", s.snapshot().phase)
            assert.is_nil(s.snapshot().registration)
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

-- Receipt decisions use injected clocks and captured post-save hashes only.
describe("document_session successful-submit receipt", function()
    before_each(load_model)
    local function find(effects, kind)
        for _, effect in ipairs(effects) do if effect.kind == kind then return effect end end
    end
    local function attempt(s, hash, pressed, confirmed, reg)
        local save=s.dispatch({type="submit",owner="ops:1",now_ms=pressed})[1]
        local lookup=s.dispatch({type="saved",witness=save.witness,ok=true,hash=hash})[1]
        local result={kind="registered",registration=reg or registration()}
        return s.dispatch({type="reply",witness=lookup.witness,result=result,now_ms=confirmed or pressed})
    end
    local function sent(s, effect, ok, time)
        return s.dispatch({type="sent",witness=effect.witness,ok=ok,now_ms=20,display_time=time or "12:34",error=not ok and "delivery uncertain" or nil})
    end
    local function delivered(hash)
        local s=session()
        attached(s)
        local effect=find(attempt(s,hash or "hash-A",0,10),"send")
        sent(s,effect,true)
        return s
    end

    it("records only confirmed captured bytes and emits the submitted owner/time feedback", function()
        local s=session()
        attached(s)
        local send=find(attempt(s,"hash-A",0,10),"send")
        assert.equals("hash-A",send.hash)
        assert.is_false(send.resent)
        assert.is_nil(s.snapshot().receipt)
        local effects=sent(s,send,true)
        assert.same({namespace="thread",id="doc-1",owner="ops:1",hash="hash-A",display_time="12:34"},s.snapshot().receipt)
        local feedback=find(effects,"feedback")
        assert.equals("submitted",feedback.intent)
        assert.equals("submitted to ops:1 · 12:34",feedback.message)
    end)

    it("suppresses an unchanged first idle press after save and owner confirmation", function()
        local s=delivered()
        local effects=attempt(s,"hash-A",100,120)
        assert.is_nil(find(effects,"send"))
        assert.equals("registered",s.snapshot().phase)
        assert.is_nil(s.snapshot().operation)
        local feedback=find(effects,"feedback")
        assert.equals("unchanged",feedback.intent)
        assert.equals("nothing to submit: no changes since 12:34",feedback.message)
    end)

    it("captures an explicit second press at the inclusive two-second boundary before slow lookup", function()
        local s=delivered()
        attempt(s,"hash-A",100,120)
        local send=find(attempt(s,"hash-A",2120,9000),"send")
        assert.is_not_nil(send)
        assert.is_true(send.resent)
        local feedback=find(sent(s,send,true,"12:35"),"feedback")
        assert.equals("resent",feedback.intent)
        assert.equals("resent to ops:1 · 12:35",feedback.message)
        assert.equals("12:35",s.snapshot().receipt.display_time)
    end)

    it("requires a new confirmation when the window expired", function()
        local s=delivered()
        attempt(s,"hash-A",100,120)
        local effects=attempt(s,"hash-A",2121,2140)
        assert.is_nil(find(effects,"send"))
        assert.equals("unchanged",find(effects,"feedback").intent)
        assert.is_true(find(attempt(s,"hash-A",2200,2210),"send").resent)
    end)

    it("sends changed bytes normally and does not advance the receipt after failed or uncertain send", function()
        local s=delivered()
        local original=s.snapshot().receipt
        local send=find(attempt(s,"hash-B",100,120),"send")
        assert.is_false(send.resent)
        assert.equals("hash-B",send.hash)
        sent(s,send,false)
        assert.same(original,s.snapshot().receipt)
        send=find(attempt(s,"hash-B",200,220),"send")
        assert.is_false(send.resent)
        assert.equals("hash-B",send.hash)
    end)

    it("does not count busy lookup, save or send presses as resend confirmation", function()
        local s=delivered()
        local save=s.dispatch({type="submit",now_ms=100})[1]
        assert.same({},s.dispatch({type="submit",now_ms=101}))
        local lookup=s.dispatch({type="saved",witness=save.witness,ok=true,hash="hash-A"})[1]
        assert.same({},s.dispatch({type="submit",now_ms=102}))
        local effects=s.dispatch({type="reply",witness=lookup.witness,result=outcome("registered"),now_ms=120})
        assert.is_nil(find(effects,"send"))
        local resend=find(attempt(s,"hash-A",130,140),"send")
        assert.is_true(resend.resent)
        assert.same({},s.dispatch({type="submit",now_ms=150}))
        sent(s,resend,true)
        assert.is_nil(find(attempt(s,"hash-A",160,170),"send"))
    end)

    it("invalidates confirmation on edits even when content returns to the same hash", function()
        local s=delivered()
        attempt(s,"hash-A",100,120)
        s.dispatch({type="changed"})
        local effects=attempt(s,"hash-A",130,140)
        assert.is_nil(find(effects,"send"))
        assert.equals("unchanged",find(effects,"feedback").intent)
    end)

    it("invalidates confirmation without cancelling an admission lookup or its receipt", function()
        local s=delivered()
        attempt(s,"hash-A",100,120)
        local lookup=s.dispatch({type="open"})[1]
        assert.same({},s.dispatch({type="invalidate_confirmation"}))
        assert.equals(lookup.witness.token,s.snapshot().operation.witness.token)
        reply(s,lookup,outcome("registered"))
        local effects=attempt(s,"hash-A",130,140)
        assert.is_nil(find(effects,"send"))
        assert.equals("unchanged",find(effects,"feedback").intent)
        assert.equals("hash-A",s.snapshot().receipt.hash)
    end)

    it("revokes captured resend authorization on reload without cancelling owner confirmation", function()
        local s=delivered()
        attempt(s,"hash-A",100,120)
        local save=s.dispatch({type="submit",now_ms=130})[1]
        local lookup=s.dispatch({type="saved",witness=save.witness,ok=true,hash="hash-A"})[1]
        s.dispatch({type="invalidate_confirmation"})
        assert.equals(lookup.witness.token,s.snapshot().operation.witness.token)
        local effects=s.dispatch({type="reply",witness=lookup.witness,result=outcome("registered"),now_ms=140})
        assert.is_nil(find(effects,"send"))
        assert.equals("unchanged",find(effects,"feedback").intent)
    end)

    it("does not suppress or label a confirmed different effective owner as resent", function()
        local s=delivered()
        attempt(s,"hash-A",100,120)
        local reg=registration()
        reg.Owner="other:2"
        local send=find(attempt(s,"hash-A",130,140,reg),"send")
        assert.equals("other:2",send.owner)
        assert.is_false(send.resent)
    end)

    it("does not reuse confirmation or receipt across a confirmed replacement registry ID", function()
        local s=delivered()
        attempt(s,"hash-A",100,120)
        local reg=registration()
        reg.ID="replacement"
        local detach=find(attempt(s,"hash-A",130,140,reg),"detach_turn")
        local effects=s.dispatch({type="turn_detached",witness=detach.witness,ok=true,now_ms=150})
        local send=find(effects,"send")
        assert.is_false(send.resent)
        assert.equals("hash-A",send.hash)
        assert.is_nil(s.snapshot().receipt)
    end)

    it("records the issued hash after an intervening edit without stale success feedback or a second operation", function()
        local s=delivered()
        local send=find(attempt(s,"hash-B",100,120),"send")
        s.dispatch({type="changed"})
        assert.equals("send",s.snapshot().operation.witness.operation)
        assert.same({},s.dispatch({type="submit",now_ms=130}))
        local effects=sent(s,send,true,"12:36")
        assert.equals("hash-B",s.snapshot().receipt.hash)
        assert.is_nil(find(effects,"feedback"))
        assert.equals("registered",s.snapshot().phase)
        local next_send=find(attempt(s,"hash-C",140,150),"send")
        assert.is_false(next_send.resent)
        assert.same({},sent(s,send,true,"wrong"))
        assert.equals(next_send.witness.token,s.snapshot().operation.witness.token)
    end)

    it("keeps a failed issued-send error visible after body edits without advancing the receipt", function()
        local s=delivered()
        local receipt=s.snapshot().receipt
        local send=find(attempt(s,"hash-B",100,120),"send")
        s.dispatch({type="changed"})
        local effects=sent(s,send,false)
        assert.same(receipt,s.snapshot().receipt)
        assert.equals("registered",s.snapshot().phase)
        local error=find(effects,"notify")
        assert.is_not_nil(error)
        assert.equals("delivery uncertain",error.message)
        assert.is_nil(find(effects,"feedback"))
    end)

    it("does not adopt old send receipts after namespace, path or incarnation death", function()
        for _, change in ipairs({{type="changed",namespace="other"},{type="changed",path="/other.md"},{type="detach"}}) do
            local s=delivered()
            local send=find(attempt(s,"hash-B",100,120),"send")
            s.dispatch(change)
            local effects=sent(s,send,true)
            assert.is_nil(s.snapshot().receipt)
            assert.is_nil(find(effects,"feedback"))
        end
    end)

    it("preserves a receipt through same-ID native rename but never carries its armed confirmation", function()
        local s=delivered()
        attempt(s,"hash-A",100,120)
        local move=s.dispatch({type="rename",new_path="/new.md"})[1]
        local metadata=s.dispatch({type="moved",witness=move.witness,ok=true})[1]
        reply(s,metadata,outcome("registered","/new.md"))
        local reg=registration("/new.md")
        local effects=attempt(s,"hash-A",130,140,reg)
        assert.is_nil(find(effects,"send"))
        assert.equals("unchanged",find(effects,"feedback").intent)
    end)

    it("accepts only a detached receipt seed matching namespace stable ID and effective owner", function()
        local receipt=delivered().snapshot().receipt
        local seeded=model.new({path="/new.md",namespace="thread",incarnation=8,registration=registration("/new.md"),receipt=receipt})
        receipt.hash="forged"
        local effects=attempt(seeded,"hash-A",130,140,registration("/new.md"))
        assert.is_nil(find(effects,"send"))
        assert.equals("unchanged",find(effects,"feedback").intent)
        for _, field in ipairs({"namespace","id","owner"}) do
            local invalid=seeded.snapshot().receipt
            invalid[field]="other"
            local isolated=model.new({path="/new.md",namespace="thread",incarnation=8,registration=registration("/new.md"),receipt=invalid})
            assert.is_nil(isolated.snapshot().receipt)
        end
        local reopened=model.new({path="/old.md",namespace="thread",incarnation=9,registration=registration()})
        assert.is_nil(reopened.snapshot().receipt)
    end)
end)

-- #378: a side doc inherits its parent's effective owner, but only when Couch
-- confirms the child is absent and the parent still holds that registration.
describe("document_session inherit", function()
    before_each(load_model)
    local parent = { path = "/p.md", id = "parent-1", owner = "ops:0" }
    local function parent_registration(over)
        return vim.tbl_extend("force", { ID = "parent-1", File = "/p.md", Owner = "ops:0",
            RegisteredOwner = "ops:0", RegisteredAt = "now" }, over or {})
    end
    local function child_registration(owner)
        return { ID = "child-1", File = "/old.md", Owner = owner, RegisteredOwner = owner, RegisteredAt = "now" }
    end
    local function kinds(effects)
        return vim.tbl_map(function(e) return e.kind end, effects)
    end
    -- Drive an inherit on a plain child up to the parent confirmation.
    local function to_confirm(s)
        local lookup = s.dispatch({ type = "inherit", parent = parent })[1]
        assert.equals("lookup", lookup.kind)
        local confirm = reply(s, lookup, { kind = "absent" })[1]
        assert.equals("confirm_parent", confirm.kind)
        assert.same(parent, confirm.parent)
        return confirm
    end

    it("registers an absent side child to the confirmed parent owner, sending nothing", function()
        local s = session(); plain(s)
        local register = reply(s, to_confirm(s), { kind = "registered", registration = parent_registration() })[1]
        assert.equals("register", register.kind)
        assert.equals("ops:0", register.owner)
        assert.is_true(register.resume_only)
        local done = reply(s, register, { kind = "registered", registration = child_registration("ops:0"), changed = true })
        assert.same({ "attach" }, kinds(done))
        assert.equals("ops:0", s.snapshot().registration.Owner)
        assert.equals("registered", s.snapshot().phase)
    end)

    it("keeps an existing child registration", function()
        local s = session(); attached(s)
        assert.same({}, s.dispatch({ type = "inherit", parent = parent }))
        assert.equals("ops:1", s.snapshot().registration.Owner)
        -- and a hint that meets a registered answer adopts it, never registers
        local fresh = session()
        local lookup = fresh.dispatch({ type = "open" })[1]
        assert.same({}, fresh.dispatch({ type = "inherit", parent = parent }))
        assert.same({ "attach" }, kinds(reply(fresh, lookup, outcome("registered"))))
        assert.equals("ops:1", fresh.snapshot().registration.Owner)
    end)

    it("applies a hint that arrives while the attach lookup is out", function()
        local s = session()
        local lookup = s.dispatch({ type = "open" })[1]
        assert.same({}, s.dispatch({ type = "inherit", parent = parent }))
        assert.same({ "confirm_parent" }, kinds(reply(s, lookup, { kind = "absent" })))
    end)

    it("refuses a stale or unconfirmed parent, then a later navigation succeeds", function()
        for _, answer in ipairs({
            { kind = "registered", registration = parent_registration({ ID = "other" }) },
            { kind = "registered", registration = parent_registration({ Owner = "ops:9" }) },
            { kind = "registered", registration = parent_registration({ File = "/elsewhere.md" }) },
            { kind = "absent" },
            { kind = "unavailable", error = "down" },
        }) do
            local s = session(); plain(s)
            local effects = reply(s, to_confirm(s), answer)
            assert.same({ { kind = "band", message = model.NOT_INHERITED } }, effects)
            assert.equals("plain", s.snapshot().phase)
            assert.is_nil(s.snapshot().registration)
            local register = reply(s, to_confirm(s), { kind = "registered", registration = parent_registration() })[1]
            assert.equals("register", register.kind)
        end
    end)

    it("drops the hint when the child lookup cannot answer", function()
        local s = session(); plain(s)
        local lookup = s.dispatch({ type = "inherit", parent = parent })[1]
        assert.same({ "band" }, kinds(reply(s, lookup, { kind = "unavailable", error = "down" })))
        -- the background retry re-opens without the hint: no confirmation, no register
        local again = s.dispatch({ type = "open" })[1]
        assert.same({ { kind = "band", message = "" } }, reply(s, again, { kind = "absent" }))
    end)

    it("adopts whoever registered the child first when the register is refused", function()
        local s = session(); plain(s)
        local register = reply(s, to_confirm(s), { kind = "registered", registration = parent_registration() })[1]
        local lookup = reply(s, register, { kind = "unavailable", code = "owner-conflict", error = "different fallback owner" })[1]
        assert.equals("lookup", lookup.kind)
        assert.same({ "attach" }, kinds(reply(s, lookup, { kind = "registered", registration = child_registration("ops:7") })))
        assert.equals("ops:7", s.snapshot().registration.Owner)
    end)

    -- The hub's guard (#378): a press queued while the owner is unknown is
    -- settled exactly once, by every way the operation holding it can end. It
    -- flushes into a registration, or into the plain-doc submit when no
    -- inheritance was involved; any other inheritance ending drops it. A new
    -- ending added later lands in this walk or leaks visibly.
    it("settles a queued press exactly once on every ending", function()
        local absent, down = { kind = "absent" }, { kind = "unavailable", error = "down" }
        local parent_ok = { kind = "registered", registration = parent_registration() }
        local function child_ok(owner) return { kind = "registered", registration = child_registration(owner) } end
        local function op(s) return s.snapshot().operation end
        local function answer(s, result) return reply(s, { witness = op(s).witness }, result) end
        -- Each start reaches an operation that holds the press.
        local starts = {
            attach = function(s) s.dispatch({ type = "open" }) end,
            inherit = function(s) plain(s); s.dispatch({ type = "inherit", parent = parent }) end,
            stashed = function(s) s.dispatch({ type = "open" }); s.dispatch({ type = "inherit", parent = parent }) end,
            confirm = function(s) plain(s); to_confirm(s) end,
            register = function(s) plain(s); answer(s, to_confirm(s) and parent_ok) end,
            relookup = function(s)
                plain(s); answer(s, to_confirm(s) and parent_ok)
                answer(s, { kind = "unavailable", code = "owner-conflict" })
            end,
        }
        local endings = {
            { "attach", "registered", function(s) answer(s, outcome("registered")) end, "flush_queued" },
            { "attach", "absent", function(s) answer(s, absent) end, "flush_queued" },
            { "attach", "unavailable", function(s) answer(s, down) end, "flush_queued" },
            { "attach", "changed", function(s) s.dispatch({ type = "changed" }) end, "flush_queued" },
            { "attach", "detach", function(s) s.dispatch({ type = "detach" }) end, "drop_queued" },
            { "inherit", "child registered", function(s) answer(s, child_ok("ops:7")) end, "flush_queued" },
            { "inherit", "unavailable", function(s) answer(s, down) end, "drop_queued" },
            { "inherit", "changed", function(s) s.dispatch({ type = "changed" }) end, "drop_queued" },
            { "inherit", "detach", function(s) s.dispatch({ type = "detach" }) end, "drop_queued" },
            { "stashed", "refused parent", function(s) answer(s, absent); answer(s, absent) end, "drop_queued" },
            { "stashed", "inherited", function(s)
                answer(s, absent); answer(s, parent_ok); answer(s, child_ok("ops:0"))
            end, "flush_queued" },
            { "confirm", "stale parent", function(s) answer(s, { kind = "registered",
                registration = parent_registration({ Owner = "ops:9" }) }) end, "drop_queued" },
            { "confirm", "parent absent", function(s) answer(s, absent) end, "drop_queued" },
            { "confirm", "parent unavailable", function(s) answer(s, down) end, "drop_queued" },
            { "confirm", "changed", function(s) s.dispatch({ type = "changed" }) end, "drop_queued" },
            { "confirm", "detach", function(s) s.dispatch({ type = "detach" }) end, "drop_queued" },
            { "register", "inherited", function(s) answer(s, child_ok("ops:0")) end, "flush_queued" },
            { "register", "uncertain", function(s) answer(s, { kind = "uncertain", error = "lost" }) end, "drop_queued" },
            -- A mutation that outlives a change goes pending: the next press is
            -- the explicit retry, so the held one drops.
            { "register", "changed, then answered", function(s)
                s.dispatch({ type = "changed" }); answer(s, child_ok("ops:0"))
            end, "drop_queued" },
            { "relookup", "adopted", function(s) answer(s, child_ok("ops:7")) end, "flush_queued" },
            { "relookup", "absent", function(s) answer(s, absent) end, "drop_queued" },
            { "relookup", "unavailable", function(s) answer(s, down) end, "drop_queued" },
        }
        for _, case in ipairs(endings) do
            local start, name, finish, expected = case[1], case[2], case[3], case[4]
            local label = start .. " → " .. name
            local s = session()
            starts[start](s)
            assert.is_not_nil(op(s), label .. ": the start left nothing in flight")
            local decisions = {}
            local dispatch = s.dispatch
            s.dispatch = function(event)
                local effects = dispatch(event)
                for _, e in ipairs(effects) do
                    if e.kind == "flush_queued" or e.kind == "drop_queued" then decisions[#decisions + 1] = e.kind end
                end
                return effects
            end
            s.dispatch({ type = "queue_submit" })
            assert.truthy(s.snapshot().queued, label .. ": the press was not held")
            -- A reply with a stale witness ends nothing and decides nothing.
            reply(s, { witness = { token = -1 } }, absent)
            assert.same({}, decisions, label .. ": a stale reply settled the press")
            finish(s)
            assert.same({ expected }, decisions, label)
            assert.is_nil(s.snapshot().queued, label .. ": the press is still held")
            -- and nothing after the ending settles it a second time
            s.dispatch({ type = "open" })
            s.dispatch({ type = "changed" })
            assert.same({ expected }, decisions, label .. ": settled twice")
        end
    end)

    it("ignores a malformed hint and a detached document", function()
        local s = session(); plain(s)
        assert.same({}, s.dispatch({ type = "inherit", parent = { path = "/p.md", id = "", owner = "ops:0" } }))
        s.dispatch({ type = "detach" })
        assert.same({}, s.dispatch({ type = "inherit", parent = parent }))
    end)
end)
