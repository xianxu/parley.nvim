-- Admission history has one owner. The editor supplies observations and runs
-- returned effects; no observation or failed IO can retire an outstanding turn.
local M = {}
local outcomes = { acquired = true, unavailable = true, refused = true, freshened = true,
    released = true, release_failed = true }

function M.new()
    local phase, history, baseline, content = 'idle', false, nil, nil
    local proof, token, message, operation, serial
    serial = 0

    local function outstanding()
        return history and (baseline == nil or content ~= baseline)
    end

    local function effect(kind, fields)
        serial = serial + 1
        operation = { kind = kind, witness = serial }
        local result = { kind = kind, witness = serial, token = token, proof = proof }
        for key, value in pairs(fields or {}) do result[key] = value end
        return result
    end

    local function matches(event, kind)
        return operation and operation.kind == kind and operation.witness == event.witness
    end

    local function snapshot()
        return { phase = phase, history = history, baseline = baseline, content = content,
            owned_lock = proof, acquire_token = token,
            admission = phase == 'unconfirmed' and 'unavailable' or phase == 'refused' and 'refused' or nil,
            admission_message = message, unconfirmed_edit = outstanding() }
    end

    local function dispatch(event)
        local kind = event.type
        local accepted
        if outcomes[kind] then accepted = false end
        if kind == 'observe' then
            content = event.content
        elseif kind == 'acquire' then
            -- The first pre-edit baseline survives all later retries, including
            -- clean saves made while ownership was unavailable or refused.
            content = event.content
            local can_freshen = event.clean == true and (not history or not outstanding())
            if not history then baseline, history = event.baseline, true end
            token = token or event.token
            phase, message = 'acquiring', nil
            local result = effect('acquire')
            operation.can_freshen = can_freshen
            operation.content = content
            return result
        elseif kind == 'acquired' and matches(event, 'acquire') then
            accepted = true
            local can_freshen = operation.can_freshen and operation.content == content
            proof, message = event.proof, nil
            operation = nil
            if can_freshen then
                phase = 'freshening'
                return effect('freshen'), nil, true
            end
            phase = 'held'
        elseif (kind == 'unavailable' and matches(event, 'acquire'))
            or (kind == 'refused' and (matches(event, 'acquire') or matches(event, 'freshen'))) then
            accepted = true
            phase = kind == 'unavailable' and 'unconfirmed' or 'refused'
            message, operation = event.message, nil
        elseif kind == 'freshened' and matches(event, 'freshen') then
            accepted = true
            operation = nil
            if event.clean == true then
                baseline, content, phase, message = event.content, event.content, 'held', nil
            else
                phase, message = 'refused', event.message
            end
        elseif kind == 'release' and history then
            return effect('release')
        elseif kind == 'released' and matches(event, 'release') then
            accepted = true
            phase, history, baseline, proof, token, message, operation = 'idle', false, nil, nil, nil, nil, nil
        elseif kind == 'release_failed' and matches(event, 'release') then
            accepted = true
            operation = nil
        elseif kind == 'observed' then
            -- Discovery may supply a tokenless legacy turn's missing preimage,
            -- never reconstruct a registered turn's deliberately unknown one.
            if not history then
                baseline, history = event.baseline, true
            elseif baseline == nil and token == nil then
                baseline = event.baseline
            end
            content = event.content
        elseif kind == 'legacy_adopt' then
            if history and token ~= nil then
                return nil, 'conflicting operator history'
            end
            if not history then baseline, history = event.baseline, true end
            content, proof, phase, message, operation = event.content, event.proof, 'held', nil, nil
        elseif kind == 'restore' then
            if history and (baseline ~= event.baseline or proof ~= event.proof or token ~= event.token) then
                return nil, 'conflicting operator history'
            end
            baseline, proof, token, history = event.baseline, event.proof, event.token, true
            phase, message, operation = 'held', nil, nil
        elseif kind == 'rebase' and history and baseline ~= nil and baseline == event.before then
            baseline = event.after
        end
        return nil, nil, accepted
    end

    return { dispatch = dispatch, snapshot = snapshot }
end

return M
