-- Grant-geometry assertions shared by the document specs.
local M = {}

--- Live (non-revoked) grants are well-formed closed ranges and pairwise
--- disjoint (#266 M4). `reclaim_tail` narrows onto a grant's tail without
--- scanning for another owner there, because this holds after every transition.
---@param grants table<any, table> a snapshot's `grants`
---@return table[] live the live grants, for callers that pick one
function M.assert_disjoint(grants)
    local live = {}
    for _, g in pairs(grants) do
        if g.status ~= 'revoked' then
            assert(g.first <= g.last, ('grant %s is inverted: %d..%d'):format(g.id, g.first, g.last))
            for _, o in ipairs(live) do
                assert(g.last < o.first or o.last < g.first,
                    ('live grants %s %d..%d and %s %d..%d overlap'):format(g.id, g.first, g.last, o.id, o.first, o.last))
            end
            live[#live + 1] = g
        end
    end
    table.sort(live, function(a, b) return a.id < b.id end)
    return live
end

return M
