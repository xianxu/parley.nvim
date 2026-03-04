-- Unit tests for XOR obfuscation helper

local obf = require("parley.obfuscate")

describe("obfuscate: encode/decode", function()
    it("roundtrips a simple string", function()
        local key = "test-key"
        local plain = "hello-world"
        local enc = obf.encode(plain, key)
        assert.are.equal(plain, obf.decode(enc, key))
    end)

    it("roundtrips an empty string", function()
        assert.are.equal("", obf.decode(obf.encode("", "key"), "key"))
        assert.are.equal("", obf.decode("", "key"))
    end)

    it("produces hex output", function()
        local enc = obf.encode("abc", "x")
        assert.is_true(enc:match("^[0-9a-f]+$") ~= nil)
        assert.are.equal(6, #enc) -- 3 bytes -> 6 hex chars
    end)

    it("different keys produce different encodings", function()
        local plain = "my-secret"
        local enc1 = obf.encode(plain, "key1")
        local enc2 = obf.encode(plain, "key2")
        assert.are_not.equal(enc1, enc2)
    end)

    it("handles long strings with short key", function()
        local key = "k"
        local plain = "a-much-longer-string-that-exceeds-key-length"
        assert.are.equal(plain, obf.decode(obf.encode(plain, key), key))
    end)

    it("handles realistic OAuth client ID", function()
        local key = "parley-gdrive"
        local client_id = "123456789-abcdefg.apps.googleusercontent.com"
        local enc = obf.encode(client_id, key)
        assert.are.equal(client_id, obf.decode(enc, key))
    end)
end)
