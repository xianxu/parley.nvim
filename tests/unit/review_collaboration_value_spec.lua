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
