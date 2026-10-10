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
    it("leaves single-line text alone", function()
        assert.equals("plain", codec.encode("plain"))
        assert.equals("plain", codec.decode("plain"))
    end)
end)
