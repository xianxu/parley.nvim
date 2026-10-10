-- Unit tests for lua/parley/comment/codec.lua (#312): the <br> newline escape
-- that keeps every 🤖 marker on one line.
local codec = require("parley.comment.codec")

describe("comment.codec", function()
    it("encodes newlines as <br>", function()
        assert.equals("a<br>b<br>c", codec.encode("a\nb\r\nc"))
    end)
    it("decodes <br> to newlines", function()
        assert.equals("a\nb", codec.decode("a<br>b"))
    end)
    it("round-trips", function()
        local s = "line one\nline two\n\nend"
        assert.equals(s, codec.decode(codec.encode(s)))
    end)
    it("a literal <br> (table cell) is escaped, not turned into a newline", function()
        assert.equals("a | b\\<br>c | d", codec.encode("a | b<br>c | d"))
        assert.equals("a | b<br>c | d", codec.decode("a | b\\<br>c | d"))
        local s = "row one<br>cell\nnext line"
        assert.equals(s, codec.decode(codec.encode(s)))
    end)
    it("a backslash before an escape round-trips (odd run = literal <br>, even = newline)", function()
        assert.equals("a\\\\<br>b", codec.encode("a\\\nb"))
        assert.equals("a\\\nb", codec.decode("a\\\\<br>b"))
        assert.equals("a\\<br>", codec.decode("a\\\\\\<br>"))
        assert.equals("C:\\dir\\x", codec.encode("C:\\dir\\x"))
    end)
    -- Property: decode(encode(s)) == s over text drawn from the codec's own
    -- delimiters (backslashes, <br>, newlines) — the escape must be injective.
    it("round-trips text built from its own delimiters", function()
        math.randomseed(312)
        local atoms = { "\\", "<br>", "\n", "\r\n", "x", "\\<br>", "<", "br>" }
        for _ = 1, 1000 do
            local parts = {}
            for i = 1, math.random(0, 6) do parts[i] = atoms[math.random(#atoms)] end
            local s = table.concat(parts):gsub("\r\n", "\n")
            assert.equals(s, codec.decode(codec.encode(s)), vim.inspect(s))
        end
    end)
    it("leaves single-line text alone", function()
        assert.equals("plain", codec.encode("plain"))
        assert.equals("plain", codec.decode("plain"))
    end)
end)
