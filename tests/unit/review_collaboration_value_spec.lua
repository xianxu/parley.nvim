local parser = require("parley.skills.review.collaboration_value")
local function read(body)
    local lines = { "---", "title: Example" }
    for line in (body .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
    lines[#lines + 1] = "---"
    lines[#lines + 1] = "# Body"
    return parser.parse(lines)
end
local function bad(body)
    local value, err = read(body)
    assert.is_nil(value)
    assert.is_truthy(err)
end

describe("collaboration-mode value", function()
    it("reads legacy chat despite literal quotes in unrelated plain root values", function()
        for _, text in ipairs({ [[Keep commas, "please]], [[Keep ["asides] intact]], [[Keep -"voice intact]],
            [[Keep commas, 'please]], [[Keep commas, "please # trailing comment]] }) do
            for _, key in ipairs({ "process-instruction", "processing-instruction", "notes" }) do
                for _, declaration in ipairs({ "collaboration-mode: chat", "collaboration-mode: {chat: [Notes]}",
                    "collaboration-mode:\n  chat:\n    - Notes" }) do
                    for _, first in ipairs({ true, false }) do
                        local unrelated = key .. ": " .. text
                        local value, err = read(first and (unrelated .. "\n" .. declaration)
                            or (declaration .. "\n" .. unrelated))
                        assert.is_nil(err)
                        assert.same(declaration == "collaboration-mode: chat" and "chat" or { chat = { "Notes" } }, value)
                    end
                end
            end
        end
    end)
    it("leaves absent fields absent", function()
        local value, err = parser.parse({ "# Document", "collaboration-mode: chat" })
        assert.is_nil(value)
        assert.is_nil(err)
        value, err = read("other: value")
        assert.is_nil(value)
        assert.is_nil(err)
    end)
    it("reads plain and quoted scalar defaults with comments", function()
        assert.equals("collaboration", read("collaboration-mode: collaboration # note"))
        assert.equals("chat", read([[collaboration-mode: 'chat' # note]]))
    end)
    it("reads block maps and both forms of heading lists", function()
        assert.same({ default = "discussion", chat = { "Instructions", "What's next" }, collaboration = { "Notes" } }, read([=[collaboration-mode:
  default: discussion
  chat:
    - Instructions
    - 'What''s next' # comment
  collaboration: [Notes]
other: ignored]=]))
    end)
    it("reads multiline flow maps with quoted punctuation and escaped names", function()
        assert.same({ default = "discussion", chat = { 'A, B: # notes', 'Say "yes"', "Next\nline" } }, read([=[collaboration-mode: {
  default: discussion, # note
  chat: ["A, B: # notes", "Say \"yes\"", "Next\nline"],
}]=]))
    end)
    it("keeps punctuation in block sequence names and decodes Unicode escapes", function()
        assert.same({ chat = { "One, two", "A [bracket]", "café", "Operator's notes" } }, read([=[collaboration-mode:
  chat:
    - One, two
    - A [bracket]
    - "caf\u00e9"
    - Operator's notes]=]))
    end)
    it("reads empty maps and lists and quoted map keys", function()
        assert.same({}, read("collaboration-mode: {}"))
        assert.same({ chat = {} }, read([[collaboration-mode: {"chat": []}]]))
    end)
    it("passes unknown mode names through for semantic validation", function()
        assert.equals("unknown", read("collaboration-mode: unknown"))
        assert.same({ unknown = { "Notes" } }, read("collaboration-mode: {unknown: [Notes]}"))
    end)
    it("recognizes separated and quoted field keys without silently defaulting", function()
        assert.equals("chat", read("collaboration-mode : chat"))
        assert.equals("chat", read([['collaboration-mode': chat]]))
        bad("collaboration-mode : chat\nother: value\ncollaboration-mode: discussion")
    end)
    it("rejects duplicate fields and mapping keys", function()
        bad("collaboration-mode: chat\ncollaboration-mode: discussion")
        bad("collaboration-mode: {chat: [One], chat: [Two]}")
        bad("collaboration-mode:\n  chat: [One]\n  chat: [Two]")
    end)
    it("rejects missing delimiters and trailing scalar content", function()
        bad("collaboration-mode: {chat: [One]")
        bad('collaboration-mode: "chat" trailing')
        bad('collaboration-mode: {chat: ["unclosed]}')
        bad("collaboration-mode: {chat: [One] garbage}")
    end)
    it("rejects unsupported YAML and wrong value shapes visibly", function()
        for _, value in ipairs({ "", "null", "true", "42", "&anchor chat", "*alias", "!tag chat", "|", ">", "[chat]", "{default: [chat]}", "{chat: discussion}", "{chat: [true]}", "{chat: [{nested: value}]}" }) do
            bad("collaboration-mode: " .. value)
        end
        bad("collaboration-mode:\n  chat:\n    nested: value")
        bad("collaboration-mode: chat\n  ignored: discussion")
    end)
    it("rejects unsupported quoted escapes and inconsistent indentation", function()
        bad([[collaboration-mode: "ch\qat"]])
        bad("collaboration-mode:\n  chat: [One]\n   collaboration: [Two]")
        bad("collaboration-mode:\n\tchat: [One]")
    end)
end)

describe("collaboration declaration recognition", function()
    local function document(body)
        local lines = { "---" }
        for line in (body .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
        lines[#lines + 1] = "---"
        return parser.parse(lines)
    end
    it("decodes the same field under uniform root indentation and quoted escapes", function()
        for _, body in ipairs({
            "  collaboration-mode: chat",
            "  title: Example\n  collaboration-mode:\n    default: chat",
            [['collaboration-mode': chat]],
            [["collaboration\u002dmode": chat]],
            [[  "collaboration\x2dmode": chat]],
        }) do
            local value, err = document(body)
            assert.is_nil(err)
            assert.same(body:find("default:", 1, true) and { default = "chat" } or "chat", value)
        end
    end)
    it("rejects duplicate declarations after dedenting and decoding keys", function()
        for _, body in ipairs({
            [[  collaboration-mode: chat
  "collaboration\u002dmode": discussion]],
            [["collaboration-mode": chat
metadata:
  nested: yes
'collaboration-mode': discussion]],
        }) do
            local value, err = document(body)
            assert.is_nil(value)
            assert.is_truthy(err)
        end
    end)
    it("refuses unsupported root shapes rather than defaulting", function()
        for _, body in ipairs({
            "{collaboration-mode: chat}",
            "{\n  collaboration-mode: chat\n}",
            "- collaboration-mode: chat",
            "? collaboration-mode\n: chat",
            "? [collaboration-mode]\n: chat",
            "!mapping {collaboration-mode: chat}",
            "&root\ncollaboration-mode: chat",
            "*root",
            "defaults: &defaults {collaboration-mode: chat}\n<<: *defaults",
            [['<<': {collaboration-mode: chat}]],
            [["\u003c\u003c": {collaboration-mode: chat}]],
            "!field collaboration-mode: chat",
            "*field: chat",
            "&field collaboration-mode: chat",
            "collaboration-mode", "[collaboration-mode, chat]",
            [["collaboration\qmode": chat]],
            "  title: Example\ncollaboration-mode: chat",
            "title: Example\n  collaboration-mode: chat",
        }) do
            local value, err = document(body)
            assert.is_nil(value)
            assert.is_truthy(err)
        end
    end)
    it("refuses every unclosed leading frontmatter representation", function()
        for _, body in ipairs({
            "", "title: Example", "  collaboration-mode: chat",
            [["collaboration\u002dmode": chat]], "{collaboration-mode: chat}",
            "metadata:\n  collaboration-mode: chat",
        }) do
            local lines = { "---" }
            for line in (body .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
            local value, err = parser.parse(lines)
            assert.is_nil(value)
            assert.is_truthy(err)
        end
    end)
    it("defaults only for recognizable root mappings without the field", function()
        for _, body in ipairs({
            "", "# comment", "title: Example",
            "  title: Example\n  metadata:\n    collaboration-mode: chat",
            "metadata:\n  collaboration-mode: chat\nowner: ops:0",
            [["title\u002dtext": Example]],
            "notes: |\n  collaboration-mode: chat",
            "notes: |\n  \"unclosed quote is literal text\n  collaboration-mode: chat",
        }) do
            local value, err = document(body)
            assert.is_nil(value)
            assert.is_nil(err)
        end
    end)
end)

-- Count copied bytes rather than timing the editor: the bound is independent
-- of machine load, and catches both growing prefixes and repeated tail copies.
local function copied_bytes(body)
    local original, bytes = string.sub, 0
    -- luacheck: push ignore 122 (bounded instrumentation, restored after pcall)
    string.sub = function(s, first, last)
        local result = original(s, first, last)
        bytes = bytes + #result
        return result
    end
    local ok, value, err = pcall(read, body)
    string.sub = original
    -- luacheck: pop
    assert.is_truthy(ok)
    assert.is_nil(err)
    return bytes, value
end

describe("collaboration frontmatter scan work", function()
    it("bounds VM work for punctuation in long plain root values", function()
        local function work(size)
            local running = jit.status()
            jit.off()
            jit.flush()
            local count = 0
            debug.sethook(function() count = count + 1 end, "", 1)
            local ok, value, err = pcall(read, 'process-instruction: Keep ' .. string.rep('a, ', size)
                .. '"please\ncollaboration-mode: chat')
            debug.sethook()
            if running then jit.on() end
            assert.is_true(ok)
            assert.is_nil(err)
            assert.equals("chat", value)
            return count
        end
        local small, large = work(2048), work(4096)
        assert.is_true(large < small * 2.3, ("VM work grew from %d to %d"):format(small, large))
    end)
    it("handles large whitespace runs and multiline collections without editor stalls", function()
        local start = os.clock()
        local value, err = read("notes: a" .. string.rep(" ", 20000) .. "z")
        assert.is_nil(value)
        assert.is_nil(err)
        local rows = { "collaboration-mode:", "  chat: [" }
        for _ = 1, 4000 do rows[#rows + 1] = '    "A",' end
        rows[#rows + 1] = '    "Z"]'
        value, err = read(table.concat(rows, "\n"))
        assert.is_nil(err)
        assert.equals(4001, #value.chat)
        -- CPU time excludes queue waits; 1 s leaves two orders of magnitude
        -- over normal execution while detecting seconds of pattern backtracking.
        assert.is_truthy(os.clock() - start < 1)
    end)
    it("bounds copied bytes for long unrelated metadata", function()
        for _, size in ipairs({ 5000, 10000, 20000 }) do
            local body = "notes: " .. string.rep("a", size)
            local bytes = copied_bytes(body)
            assert.is_truthy(bytes < #body * 40)
        end
    end)
    it("bounds copied bytes across many quoted flow values", function()
        for _, count in ipairs({ 100, 200, 400 }) do
            local body = 'collaboration-mode: {chat: [' .. string.rep('"A", ', count) .. '"Z"]}'
            local bytes, value = copied_bytes(body)
            assert.equals(count + 1, #value.chat)
            assert.is_truthy(bytes < #body * 40)
        end
    end)
end)
