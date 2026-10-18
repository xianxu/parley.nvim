-- parley.color — PURE color arithmetic on 24-bit RGB integers (#387), the
-- form nvim_get_hl returns for fg/bg.
local M = {}

local function channels(rgb)
    return math.floor(rgb / 65536) % 256, math.floor(rgb / 256) % 256, rgb % 256
end

--- Mix `tint` into `base` by `alpha` (0 = base, 1 = tint), per channel, rounded.
--- @param base integer 0xRRGGBB
--- @param tint integer 0xRRGGBB
--- @param alpha number 0..1
--- @return integer 0xRRGGBB
function M.blend(base, tint, alpha)
    local br, bg, bb = channels(base)
    local tr, tg, tb = channels(tint)
    local function mix(b, t) return math.floor(b + (t - b) * alpha + 0.5) end
    return mix(br, tr) * 65536 + mix(bg, tg) * 256 + mix(bb, tb)
end

return M
