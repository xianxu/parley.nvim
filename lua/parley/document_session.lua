-- Pure document admission/submission lifecycle. The shell executes effects and
-- returns their witnesses unchanged; no editor state or IO is read here.
local M = {}

--- A typed S1 document is editable but unprotected until registration confirms.
function M.unprotected_view(snapshot, typed)
    if typed ~= true or snapshot.registration ~= nil then return nil end
    return { label = "not protected · Alt+Return registers", hl = "WarningMsg" }
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

local function nonempty(value)
    return type(value) == "string" and value:find("%S") ~= nil
end

local function valid_registration(reg)
    return type(reg) == "table" and nonempty(reg.ID) and nonempty(reg.File)
        and reg.File:sub(1, 1) == "/" and nonempty(reg.Owner)
        and nonempty(reg.RegisteredOwner) and type(reg.RegisteredAt) == "string"
end

-- JSON null must remain an explicit sentinel at the transport boundary.
function M.classify_reply(operation, exit_code, decoded, null_sentinel)
    local mutation = operation == "register" or operation == "rename"
    local error_text = type(decoded) == "table" and type(decoded.Error) == "string" and decoded.Error or nil
    -- The refusal's code travels with it: a move names a target-conflict (#359).
    local code = type(decoded) == "table" and type(decoded.Code) == "string" and decoded.Code ~= "ok" and decoded.Code or nil
    local unavailable = { kind = "unavailable", code = code, error = error_text or "Invalid registry response" }
    if operation ~= "lookup" and not mutation then return unavailable end
    if type(decoded) ~= "table" then return unavailable end
    if mutation and decoded.Code == "registry-uncertain" then
        return { kind = "uncertain", error = error_text }
    end
    if exit_code ~= 0 or decoded.Code ~= "ok" then return unavailable end
    if operation == "lookup" and null_sentinel ~= nil and decoded.Registration == null_sentinel then
        return { kind = "absent" }
    end
    if not valid_registration(decoded.Registration) then return unavailable end
    if mutation and type(decoded.Changed) ~= "boolean" then return unavailable end
    return { kind = "registered", registration = copy(decoded.Registration), changed = decoded.Changed }
end

-- #378: the band a side doc shows when it could not take its parent's owner.
-- The retry comes first: a side doc of a hub-owned parent usually wants the hub.
-- Short enough for an 80-column band, which cuts longer text at its end.
M.NOT_INHERITED = "not inherited · reopen from parent to retry, or Alt+Return here"

local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function M.new(context)
    local state = {
        phase = "unknown", path = context.path, namespace = context.namespace,
        incarnation = context.incarnation, generation = 0,
    }
    if valid_registration(context.registration) and context.registration.File == context.path then
        state.registration, state.phase = copy(context.registration), "registered"
    end
    local seeded = context.receipt
    if type(seeded) == "table" and state.registration and seeded.namespace == state.namespace
        and seeded.id == state.registration.ID and seeded.owner == state.registration.Owner
        and nonempty(seeded.hash) and nonempty(seeded.display_time) then
        state.receipt = copy(seeded)
    end
    local serial = 0
    local controller = {}

    local function stable_phase()
        return state.registration and "registered" or "unknown"
    end

    -- inheritance (#380): the stage this operation is a step of, held on the
    -- operation record itself, never in the effect, so it lives and dies with
    -- the operation: copied into state.pending, carried by retry, gone when
    -- the operation ends.
    local function issue(operation, args, captured, inheritance)
        serial = serial + 1
        local witness = copy(captured or {
            path = state.path, namespace = state.namespace,
            incarnation = state.incarnation, generation = state.generation,
        })
        witness.token, witness.operation = serial, operation
        state.operation = { witness = witness, args = copy(args or {}), inheritance = copy(inheritance) }
        local effect = copy(args or {})
        effect.kind, effect.witness = operation, copy(witness)
        return effect
    end

    local function matching(witness)
        local current = state.operation and state.operation.witness
        if type(witness) ~= "table" or not current then return false end
        for _, field in ipairs({ "path", "namespace", "incarnation", "generation", "token", "operation" }) do
            if witness[field] ~= current[field] then return false end
        end
        return true
    end

    local function live(witness)
        return witness.path == state.path and witness.namespace == state.namespace
            and witness.incarnation == state.incarnation and witness.generation == state.generation
    end

    -- code: Couch's refusal code, when it gave one (a move names a
    -- target-conflict, #359).
    local function pending(operation, message, code)
        state.pending = copy(operation)
        state.operation = nil
        state.phase = "pending"
        local effect = copy(operation.args)
        effect.kind, effect.operation = "reconcile", operation.witness.operation
        effect.witness, effect.error, effect.code = copy(operation.witness), message, code
        return { effect }
    end

    local function notify(message)
        return { { kind = "notify", message = message or "Document operation failed" } }
    end

    local function matches_receipt(receipt, hash)
        return receipt and state.registration and nonempty(hash)
            and receipt.namespace == state.namespace and receipt.id == state.registration.ID
            and receipt.owner == state.registration.Owner and receipt.hash == hash
    end

    local function feedback(intent, message)
        return { kind = "feedback", intent = intent, message = message }
    end

    -- A confirmation authorizes one explicit press, not a callback that happens
    -- to arrive quickly. Its captured receipt is rechecked against saved bytes
    -- and the effective owner after registry confirmation.
    local function send(candidate, now)
        candidate = candidate or {}
        local resent = false
        if matches_receipt(state.receipt, candidate.hash) then
            local authorization = candidate.authorization
            resent = matches_receipt(authorization, candidate.hash)
                and authorization.display_time == state.receipt.display_time or false
            if not resent then
                state.phase = "registered"
                if finite(now) then
                    state.confirmation = { receipt = copy(state.receipt), armed_at = now, expires_at = now + 2000 }
                end
                return feedback("unchanged", "nothing to submit: no changes since " .. state.receipt.display_time)
            end
        end
        state.confirmation = nil
        state.phase = "busy"
        return issue("send", { owner = state.registration.Owner, registration = state.registration,
            hash = candidate.hash, resent = resent })
    end

    function controller.snapshot()
        return copy(state)
    end

    local step

    -- #380: a side doc's inheritance (#378) is one tagged stage on the
    -- operation that is its current step (see issue), so its lifetime is that
    -- operation's: it survives pending and retry, and a cancel, refusal or
    -- reply that ends the operation ends it too. Each step names the next:
    --   hinted      a hint that met the attach lookup in flight
    --   looking     the inherit lookup, from plain or unknown
    --   confirming  confirm_parent: the parent re-read from Couch
    --   registering the register to the parent's owner
    --   relooking   the lookup after that register was refused or lost
    local STAGES = { hinted = true, looking = true, confirming = true, registering = true, relooking = true }
    local function inherit_as(stage, parent)
        assert(STAGES[stage], "unknown inheritance stage " .. tostring(stage))
        return { stage = stage, parent = copy(parent) }
    end
    local function stage_of(operation)
        return operation and operation.inheritance and operation.inheritance.stage or nil
    end

    -- An operation that may hold an Alt+Return pressed before the document's
    -- owner is known: the attach lookup, and every step of an inheritance.
    local function admits(operation)
        if not operation then return false end
        local kind = operation.witness.operation
        return (kind == "lookup" and not operation.args.submit) or kind == "confirm_parent"
            or (kind == "register" and stage_of(operation) == "registering")
    end
    local function inheriting()
        return stage_of(state.operation) ~= nil
    end

    -- #378: the model owns the queued press. Every dispatch settles it here, so
    -- once the operation holding it ends, by any event, exactly one of
    -- flush_queued or drop_queued is emitted. It flushes into a registration, or
    -- into the plain-doc submit when no inheritance was involved; an inheritance
    -- that ends any other way (refused, unavailable, cancelled, pending,
    -- detached) drops it, so it is never re-aimed at the pane's actor.
    function controller.dispatch(event)
        if event.type == "queue_submit" then
            if not state.queued and not state.registration and admits(state.operation) then
                state.queued = { inheriting = inheriting() }
            end
            return {}
        end
        local effects = step(event)
        local queued = state.queued
        if not queued then return effects end
        if admits(state.operation) then
            queued.inheriting = queued.inheriting or inheriting()
            return effects
        end
        state.queued = nil
        local release = (state.phase == "registered" and state.registration ~= nil)
            or (not queued.inheriting and (state.phase == "plain" or state.phase == "unknown"))
        effects[#effects + 1] = { kind = release and "flush_queued" or "drop_queued" }
        return effects
    end

    step = function(event)
        if state.phase == "detached" then return {} end
        if event.type == "invalidate_confirmation" then
            state.confirmation = nil
            if state.operation then state.operation.args.authorization = nil end
            return {}
        end
        if event.type == "detach" then
            local effects = state.operation and { { kind = "cancel", witness = copy(state.operation.witness) } } or {}
            state.generation = state.generation + 1
            state.operation, state.phase, state.receipt, state.confirmation = nil, "detached", nil, nil
            return effects
        end
        if event.type == "changed" then
            local changed_context = (event.path ~= nil and event.path ~= state.path)
                or (event.namespace ~= nil and event.namespace ~= state.namespace)
            state.confirmation = nil
            if changed_context then state.receipt = nil end
            state.generation = state.generation + 1
            state.path = event.path or state.path
            state.namespace = event.namespace or state.namespace
            local operation = state.operation
            if operation and operation.witness.operation == "send" and not changed_context then
                -- The external delivery is already issued. Keep one token until
                -- completion so its captured bytes can become knowledge, without
                -- permitting a second send or stale success feedback.
                return {}
            end
            if operation and (operation.witness.operation == "register" or operation.witness.operation == "rename"
                or operation.witness.operation == "move") then
                -- A mutation may already have happened. Consume its outcome before
                -- permitting anything else; it cannot authorize a stale send.
                return {}
            end
            state.operation = nil
            state.phase = state.pending and "pending" or stable_phase()
            return operation and { { kind = "cancel", witness = copy(operation.witness) } } or {}
        end
        if event.type == "retry" then
            if state.operation or not state.pending then return {} end
            local previous = state.pending
            local captured = previous.witness
            if captured.path ~= state.path or captured.namespace ~= state.namespace
                or captured.incarnation ~= state.incarnation then
                return pending(previous, "Pending mutation belongs to a different document context")
            end
            state.pending = nil
            local operation = previous.witness.operation
            state.phase = (operation == "rename" or operation == "move") and "moving" or "busy"
            -- Registration confirmation must never automatically resend a message.
            local args = copy(previous.args)
            args.resume_only = true
            -- The operator pressed Alt+Return again (#357): once a pending
            -- registration is confirmed, submit afresh, saving the current bytes.
            -- The confirmation itself still sends nothing stale.
            args.resubmit = (event.submit and operation == "register") or nil
            local witness = copy(previous.witness)
            witness.generation = state.generation
            return { issue(operation, args, witness, previous.inheritance) }
        end
        if event.type == "open" then
            if state.operation or state.pending then return {} end
            state.phase = "probing"
            return { issue("lookup") }
        end
        if event.type == "inherit" then
            -- #378: a side doc opened from a registered parent takes the parent's
            -- effective owner once Couch confirms both halves: the child is
            -- absent, and the parent still holds this registration. A registered
            -- or pending child keeps what it has; nothing is sent.
            local parent = event.parent
            if state.registration or state.pending or stage_of(state.operation) or type(parent) ~= "table"
                or not nonempty(parent.path) or not nonempty(parent.id) or not nonempty(parent.owner) then return {} end
            if state.operation then
                -- The attach lookup is still out: its absence will do.
                if state.operation.witness.operation == "lookup" and not state.operation.args.submit then
                    state.operation.inheritance = inherit_as("hinted", parent)
                end
                return {}
            end
            state.phase = "probing"
            return { issue("lookup", nil, nil, inherit_as("looking", parent)) }
        end
        if event.type == "submit" then
            if state.operation or state.pending then return {} end
            if not nonempty(state.path) or state.path:sub(1, 1) ~= "/" then return notify("Save the document first") end
            if not state.registration and not nonempty(event.owner) then return notify("Document owner unavailable") end
            local confirmation = state.confirmation
            local authorization
            if confirmation and finite(event.now_ms) and event.now_ms >= confirmation.armed_at
                and event.now_ms <= confirmation.expires_at then authorization = copy(confirmation.receipt) end
            state.confirmation = nil
            state.phase = "busy"
            return { issue("save", { owner = event.owner, previous_phase = state.registration and "registered" or "plain",
                authorization = authorization }) }
        end
        if event.type == "rename" then
            if state.operation or state.pending or not state.registration then return {} end
            if not nonempty(event.new_path) or event.new_path:sub(1, 1) ~= "/" then return notify("Invalid destination") end
            if event.new_path == state.path then return {} end
            state.confirmation = nil
            state.generation = state.generation + 1
            state.phase = "moving"
            return { issue("move", { old_path = state.path, new_path = event.new_path, registration = state.registration }) }
        end
        if not matching(event.witness) then return {} end
        local operation = state.operation
        local inheritance = operation.inheritance
        local kind = operation.witness.operation
        if event.type == "sent" and kind == "send" then
            local current = live(operation.witness)
            state.operation, state.phase = nil, "registered"
            -- Body edits do not retract a real delivery; context changes do not
            -- import an old pane's receipt into a different document identity.
            local identity = operation.args.registration
            local same_identity = state.registration and identity
                and identity.ID == state.registration.ID and identity.Owner == state.registration.Owner
                and operation.witness.namespace == state.namespace and operation.witness.path == state.path
                and operation.witness.incarnation == state.incarnation
            if not same_identity then return {} end
            if event.ok and nonempty(operation.args.hash) and nonempty(event.display_time) then
                state.receipt = { namespace = state.namespace, id = identity.ID, owner = identity.Owner,
                    hash = operation.args.hash, display_time = event.display_time }
            end
            if not event.ok then return notify(event.error) end
            if not current then return {} end
            if not nonempty(event.display_time) then return {} end
            local intent = operation.args.resent and "resent" or "submitted"
            return { feedback(intent, intent .. " to " .. identity.Owner .. " · " .. event.display_time) }
        end
        if not live(operation.witness) then
            if kind == "register" or kind == "rename" or kind == "move" then
                return pending(operation, "Document changed during mutation")
            end
            state.operation = nil
            state.phase = stable_phase()
            return {}
        end
        if event.type == "turn_detached" and kind == "detach_turn" then
            state.operation = nil
            if not event.ok then
                state.phase = stable_phase()
                return notify(event.error)
            end
            state.registration = copy(operation.args.replacement)
            state.receipt, state.confirmation = nil, nil
            if state.registration then
                state.phase = "registered"
                local effects = { { kind = "attach", registration = copy(state.registration), witness = copy(operation.witness) } }
                if operation.args.submit then effects[2] = send(operation.args, event.now_ms) end
                return effects
            end
            state.phase = "plain"
            return { { kind = "band", message = "" } }
        end
        if event.type == "saved" and kind == "save" then
            state.operation = nil
            if not event.ok then
                state.phase = operation.args.previous_phase
                return notify(event.error)
            end
            local candidate = { hash = nonempty(event.hash) and event.hash or nil, authorization = operation.args.authorization }
            if state.registration then
                candidate.submit = true
                return { issue("lookup", candidate) }
            end
            candidate.owner = operation.args.owner
            return { issue("register", candidate) }
        end
        if event.type == "moved" and kind == "move" then
            if not event.ok then return pending(operation, event.error) end
            state.operation = nil
            return { issue("rename", operation.args) }
        end
        if event.type ~= "reply" or (kind ~= "lookup" and kind ~= "register" and kind ~= "rename"
            and kind ~= "confirm_parent") then return {} end
        local result = event.result or { kind = "unavailable" }
        if kind == "confirm_parent" then
            state.operation = nil
            local parent, reg = inheritance.parent, result.registration
            if result.kind == "registered" and valid_registration(reg) and reg.File == parent.path
                and reg.ID == parent.id and reg.Owner == parent.owner then
                state.phase = "busy"
                return { issue("register", { owner = parent.owner, resume_only = true }, nil,
                    inherit_as("registering", parent)) }
            end
            state.phase = "plain"
            return { { kind = "band", message = M.NOT_INHERITED } }
        end
        local valid = result.kind == "registered" and valid_registration(result.registration)
        if valid then
            local expected_path = kind == "rename" and operation.args.new_path or operation.witness.path
            valid = result.registration.File == expected_path
            if kind == "rename" then valid = valid and result.registration.ID == operation.args.registration.ID end
            if state.registration and kind == "register" then valid = valid and result.registration.ID == state.registration.ID end
        end
        if kind == "lookup" then
            state.operation = nil
            local stage = inheritance and inheritance.stage
            if state.registration and (result.kind == "absent"
                or (valid and result.registration.ID ~= state.registration.ID)) then
                state.phase = "busy"
                return { issue("detach_turn", { registration = state.registration,
                    replacement = valid and result.registration or nil, submit = operation.args.submit,
                    hash = operation.args.hash, authorization = operation.args.authorization }) }
            end
            if valid then
                state.registration, state.phase = copy(result.registration), "registered"
                local effects = { { kind = "attach", registration = copy(state.registration), witness = copy(operation.witness) } }
                if operation.args.submit then effects[2] = send(operation.args, event.now_ms) end
                return effects
            end
            if result.kind == "absent" and not state.registration then
                if stage == "hinted" or stage == "looking" then
                    state.phase = "probing"
                    return { issue("confirm_parent", { parent = copy(inheritance.parent) }, nil,
                        inherit_as("confirming", inheritance.parent)) }
                end
                state.phase = "plain"
                if stage == "relooking" then return { { kind = "band", message = M.NOT_INHERITED } } end
                return { { kind = "band", message = "" } }
            end
            state.phase = stable_phase()
            if operation.args.submit then return notify(result.error or "Registered owner could not be confirmed") end
            return state.registration and {} or { { kind = "band", message = "Couch unavailable: agentic state unknown" } }
        end
        if not valid and inheritance and inheritance.stage == "registering" and result.kind == "unavailable" then
            -- Refused or lost (another owner registered it first, or the deadline
            -- passed): a fresh lookup says what is there, and that is adopted.
            state.operation, state.phase = nil, "probing"
            return { issue("lookup", nil, nil, inherit_as("relooking", inheritance.parent)) }
        end
        if not valid then return pending(operation, result.error, result.code) end
        state.operation, state.pending = nil, nil
        state.registration = copy(result.registration)
        if kind == "rename" then
            state.path, state.phase = result.registration.File, "registered"
            return { { kind = "finish_move", old_path = operation.args.old_path, new_path = operation.args.new_path,
                registration = copy(state.registration), witness = copy(operation.witness) } }
        end
        local effects = { { kind = "attach", registration = copy(state.registration), witness = copy(operation.witness) } }
        if operation.args.resume_only then
            state.phase = "registered"
            if operation.args.resubmit then effects[2] = { kind = "resubmit", witness = copy(operation.witness) } end
        else effects[2] = send(operation.args, event.now_ms) end
        return effects
    end

    return controller
end

return M
