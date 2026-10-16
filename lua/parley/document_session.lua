-- Pure document admission/submission lifecycle. The shell executes effects and
-- returns their witnesses unchanged; no editor state or IO is read here.
local M = {}

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
    local unavailable = { kind = "unavailable", error = error_text or "Invalid registry response" }
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

    local function issue(operation, args, captured)
        serial = serial + 1
        local witness = copy(captured or {
            path = state.path, namespace = state.namespace,
            incarnation = state.incarnation, generation = state.generation,
        })
        witness.token, witness.operation = serial, operation
        state.operation = { witness = witness, args = copy(args or {}) }
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

    local function pending(operation, message)
        state.pending = copy(operation)
        state.operation = nil
        state.phase = "pending"
        local effect = copy(operation.args)
        effect.kind, effect.operation = "reconcile", operation.witness.operation
        effect.witness, effect.error = copy(operation.witness), message
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

    function controller.dispatch(event)
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
            local witness = copy(previous.witness)
            witness.generation = state.generation
            return { issue(operation, args, witness) }
        end
        if event.type == "open" then
            if state.operation or state.pending then return {} end
            state.phase = "probing"
            return { issue("lookup") }
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
        if event.type ~= "reply" or (kind ~= "lookup" and kind ~= "register" and kind ~= "rename") then return {} end
        local result = event.result or { kind = "unavailable" }
        local valid = result.kind == "registered" and valid_registration(result.registration)
        if valid then
            local expected_path = kind == "rename" and operation.args.new_path or operation.witness.path
            valid = result.registration.File == expected_path
            if kind == "rename" then valid = valid and result.registration.ID == operation.args.registration.ID end
            if state.registration and kind == "register" then valid = valid and result.registration.ID == state.registration.ID end
        end
        if kind == "lookup" then
            state.operation = nil
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
                state.phase = "plain"
                return { { kind = "band", message = "" } }
            end
            state.phase = stable_phase()
            if operation.args.submit then return notify(result.error or "Registered owner could not be confirmed") end
            return state.registration and {} or { { kind = "band", message = "Couch unavailable: agentic state unknown" } }
        end
        if not valid then return pending(operation, result.error) end
        state.operation, state.pending = nil, nil
        state.registration = copy(result.registration)
        if kind == "rename" then
            state.path, state.phase = result.registration.File, "registered"
            return { { kind = "finish_move", old_path = operation.args.old_path, new_path = operation.args.new_path,
                registration = copy(state.registration), witness = copy(operation.witness) } }
        end
        local effects = { { kind = "attach", registration = copy(state.registration), witness = copy(operation.witness) } }
        if operation.args.resume_only then state.phase = "registered" else effects[2] = send(operation.args, event.now_ms) end
        return effects
    end

    return controller
end

return M
