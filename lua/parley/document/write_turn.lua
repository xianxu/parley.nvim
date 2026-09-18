-- Pure write-turn decision (#266 M1).
--
-- One generation may mutate a document at a time. Eligibility order is admission
-- order, which `state.lua`'s monotone integer `id()` already encodes, so no
-- separate sequence number is needed and ordinary `<` is the correct comparison.
--
-- An eligible incumbent keeps the turn: re-requesting cannot preempt, and a
-- release hands over by offering `current=nil`.

local M = {}

--- Decide which generation holds the write turn.
--- @param generations table  map of integer id -> {eligible=boolean}
--- @param current integer|nil  the currently held id, if any
--- @return integer|nil  the holder, or nil when nothing is eligible
function M.holder(generations, current)
    if current then
        local held = generations[current]
        if held and held.eligible then return current end
    end
    local best
    for id, record in pairs(generations) do
        if record.eligible and (not best or id < best) then best = id end
    end
    return best
end

return M
