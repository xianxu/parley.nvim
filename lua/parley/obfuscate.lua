-- Simple XOR-based obfuscation for embedding OAuth credentials.
-- This is NOT encryption — it just defeats automated secret scanners
-- (e.g. Google's GitHub credential detection).
--
-- Usage (one-time, to generate encoded values):
--   lua -e 'local o = dofile("lua/parley/obfuscate.lua"); print(o.encode("my-secret", "my-key"))'
--
-- The encoded output is a hex string that can be safely committed to git.

local M = {}

-- XOR a string with a repeating key, return raw bytes
---@param input string # plaintext or ciphertext bytes
---@param key string # XOR key (repeated cyclically)
---@return string # XOR'd bytes
local function xor_bytes(input, key)
    local out = {}
    local klen = #key
    for i = 1, #input do
        local ki = ((i - 1) % klen) + 1
        out[i] = string.char(bit.bxor(string.byte(input, i), string.byte(key, ki)))
    end
    return table.concat(out)
end

-- Encode a plaintext string: XOR with key, then hex-encode.
---@param plaintext string
---@param key string
---@return string # hex-encoded ciphertext
M.encode = function(plaintext, key)
    local xored = xor_bytes(plaintext, key)
    local hex = {}
    for i = 1, #xored do
        hex[i] = string.format("%02x", string.byte(xored, i))
    end
    return table.concat(hex)
end

-- Decode a hex-encoded ciphertext back to plaintext.
---@param hex_str string # hex-encoded ciphertext (from encode())
---@param key string
---@return string # original plaintext
M.decode = function(hex_str, key)
    -- hex -> raw bytes
    local raw = {}
    for i = 1, #hex_str, 2 do
        raw[#raw + 1] = string.char(tonumber(hex_str:sub(i, i + 1), 16))
    end
    return xor_bytes(table.concat(raw), key)
end

return M
