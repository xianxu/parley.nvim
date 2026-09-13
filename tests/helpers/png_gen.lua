-- tests/helpers/png_gen.lua
--
-- A structurally valid PNG of any size without zlib: stored (uncompressed)
-- deflate blocks with a real Adler-32 and per-chunk CRC-32, so both
-- `assets.looks_like` and the real `sips` accept it. Truecolour, 8-bit,
-- every pixel `rgb` (default a flat grey). PURE.
local M = {}

local CRC = {}
for i = 0, 255 do
    local c = i
    for _ = 1, 8 do
        c = (c % 2 == 1) and bit.bxor(bit.rshift(c, 1), 0xEDB88320) or bit.rshift(c, 1)
    end
    CRC[i] = c
end
local function crc32(s)
    local c = 0xFFFFFFFF
    for i = 1, #s do
        c = bit.bxor(CRC[bit.band(bit.bxor(c, s:byte(i)), 0xFF)], bit.rshift(c, 8))
    end
    return bit.band(bit.bnot(c), 0xFFFFFFFF)
end
local function adler32(s)
    local a, b = 1, 0
    for i = 1, #s do
        a = (a + s:byte(i)) % 65521
        b = (b + a) % 65521
    end
    return b * 65536 + a
end
local function u32be(n)
    return string.char(bit.band(bit.rshift(n, 24), 0xFF), bit.band(bit.rshift(n, 16), 0xFF), bit.band(bit.rshift(n, 8), 0xFF), bit.band(n, 0xFF))
end
local function chunk(kind, data)
    return u32be(#data) .. kind .. data .. u32be(crc32(kind .. data))
end
-- zlib stream of stored blocks (BFINAL on the last, ≤ 65535 bytes each).
local function stored_zlib(raw)
    local parts = { "\120\1" }
    local pos, n = 1, #raw
    repeat
        local len = math.min(65535, n - pos + 1)
        local final = (pos + len > n) and 1 or 0
        parts[#parts + 1] = string.char(final, len % 256, math.floor(len / 256), 255 - len % 256, 255 - math.floor(len / 256))
        parts[#parts + 1] = raw:sub(pos, pos + len - 1)
        pos = pos + len
    until pos > n
    parts[#parts + 1] = u32be(adler32(raw))
    return table.concat(parts)
end

--- @param width integer
--- @param height integer
--- @param rgb string|nil  three bytes; default "\128\128\128"
--- @return string png
function M.png_bytes(width, height, rgb)
    local row = "\0" .. string.rep(rgb or "\128\128\128", width)
    local raw = string.rep(row, height)
    local ihdr = u32be(width) .. u32be(height) .. string.char(8, 2, 0, 0, 0)
    return "\137PNG\r\n\26\n" .. chunk("IHDR", ihdr) .. chunk("IDAT", stored_zlib(raw)) .. chunk("IEND", "")
end

return M
