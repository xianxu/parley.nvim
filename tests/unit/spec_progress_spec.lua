local available, Progress = pcall(require, "tests.helpers.spec_progress")

describe("completed-case framing", function()
    local reader, output, frames
    before_each(function()
        output, frames = {}, {}
    end)
    local function start()
        assert.is_true(available, "completed-case frame decoder is missing")
        assert.is_function(Progress.new)
        reader = Progress.new("owned-token", function(text) output[#output + 1] = text end,
            function(sequence) frames[#frames + 1] = sequence end)
    end

    it("reassembles split frames and preserves the original surrounding output", function()
        start()
        reader.feed("Success || case\nowned-to")
        reader.feed("ken 1\nowned-token 2\nnext")
        reader.finish()
        assert.same({ 1, 2 }, frames)
        assert.equals("Success || case\nnext", table.concat(output))
    end)

    it("does not treat arbitrary, foreign, malformed or unterminated output as progress", function()
        start()
        local text = "Success || user output\nother-token 1\nowned-token 0\nowned-token 1junk\nowned-token 1"
        reader.feed(text)
        reader.finish()
        assert.same({}, frames)
        assert.equals(text, table.concat(output))
    end)

    it("streams an oversized line without retaining it or admitting a suffix as a frame", function()
        start()
        local text = string.rep("x", 100000)
        reader.feed(text)
        assert.equals(text, table.concat(output))
        reader.feed("owned-token 1\nowned-token 2\n")
        reader.finish()
        assert.same({ 2 }, frames)
        assert.equals(text .. "owned-token 1\n", table.concat(output))
    end)
end)
