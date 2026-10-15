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

function M.new(context)
    local state = {
        phase = "unknown", path = context.path, namespace = context.namespace,
        incarnation = context.incarnation, generation = 0,
    }
    if valid_registration(context.registration) and context.registration.File == context.path then
        state.registration, state.phase = copy(context.registration), "registered"
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

    local function send()
        state.phase = "busy"
        return issue("send", { owner = state.registration.Owner, registration = state.registration })
    end

    function controller.snapshot()
        return copy(state)
    end

    function controller.dispatch(event)
        if state.phase == "detached" then return {} end
        if event.type == "detach" then
            local effects = state.operation and { { kind = "cancel", witness = copy(state.operation.witness) } } or {}
            state.generation = state.generation + 1
            state.operation, state.phase = nil, "detached"
            return effects
        end
        if event.type == "changed" then
            state.generation = state.generation + 1
            state.path = event.path or state.path
            state.namespace = event.namespace or state.namespace
            local operation = state.operation
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
            state.pending = nil
            local operation = previous.witness.operation
            state.phase = (operation == "rename" or operation == "move") and "moving" or "busy"
            -- Registration confirmation must never automatically resend a message.
            local args = copy(previous.args)
            args.resume_only = true
            return { issue(operation, args, previous.witness) }
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
            state.phase = "busy"
            return { issue("save", { owner = event.owner, previous_phase = state.registration and "registered" or "plain" }) }
        end
        if event.type == "rename" then
            if state.operation or state.pending or not state.registration then return {} end
            if not nonempty(event.new_path) or event.new_path:sub(1, 1) ~= "/" then return notify("Invalid destination") end
            if event.new_path == state.path then return {} end
            state.generation = state.generation + 1
            state.phase = "moving"
            return { issue("move", { old_path = state.path, new_path = event.new_path, registration = state.registration }) }
        end
        if not matching(event.witness) then return {} end
        local operation = state.operation
        local kind = operation.witness.operation
        if not live(operation.witness) then
            if kind == "register" or kind == "rename" or kind == "move" then
                return pending(operation, "Document changed during mutation")
            end
            state.operation = nil
            state.phase = stable_phase()
            return {}
        end
        if event.type == "saved" and kind == "save" then
            state.operation = nil
            if not event.ok then
                state.phase = operation.args.previous_phase
                return notify(event.error)
            end
            if state.registration then return { send() } end
            return { issue("register", { owner = operation.args.owner }) }
        end
        if event.type == "sent" and kind == "send" then
            state.operation, state.phase = nil, "registered"
            return event.ok and {} or notify(event.error)
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
            if state.registration and kind ~= "rename" then valid = valid and result.registration.ID == state.registration.ID end
        end
        if kind == "lookup" then
            state.operation = nil
            if valid then
                state.registration, state.phase = copy(result.registration), "registered"
                return { { kind = "attach", registration = copy(state.registration), witness = copy(operation.witness) } }
            end
            if result.kind == "absent" and not state.registration then
                state.phase = "plain"
                return { { kind = "band", message = "" } }
            end
            state.phase = stable_phase()
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
        if operation.args.resume_only then state.phase = "registered" else effects[2] = send() end
        return effects
    end

    return controller
end

return M
