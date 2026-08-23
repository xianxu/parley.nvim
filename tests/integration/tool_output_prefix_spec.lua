-- #203: the producer half of the parser's safety.
--
-- `fence.scan` refuses to let a tool body span a column-0 structural marker.
-- That is only safe because no tool EMITS one — every tool prefixes its output
-- (read_file `%5d  `, grep/ack `file:line:`, chat_history_search
-- `{label}/path:line:`). Nothing enforced that, so a future tool that returned
-- raw file content would silently re-open the ambiguity #203 closed, and the
-- failure would show up as chats collapsing into one exchange.
--
-- The tool list is DERIVED from the registry, not hand-listed: the first draft
-- of this guard named four of ten and missed `emit_definition`, which is the
-- same defect one level down.
--
-- KNOWN EXCEPTION, stated rather than hidden: grep/ack/ls/find splice raw
-- stderr after a prefixed first line, so a hostile error message can carry a
-- column-0 marker. That degrades to over-forking — visible — which is the
-- degradation this issue's Spec chose over silent swallowing. Only success
-- paths are asserted here.

local tools = require("parley.tools")
local highlight_structure = require("parley.highlight_structure")

local MARKED = table.concat({
    "💬: a question at column zero",
    "🤖: an answer at column zero",
    "📎: read_file id=x",
    "🔧: read_file id=y",
    "📝: a summary",
}, "\n")

describe("tool output never begins a line with a structural marker (#203)", function()
    local dir, file, patterns

    before_each(function()
        -- Without this the registry is empty, tools.get returns nil, and every
        -- case below skips — a guard that passes because it ran nothing. The
        -- first draft of this spec did exactly that: it stayed green with
        -- read_file's prefix deleted.
        tools.register_builtins()
        dir = vim.fn.tempname() .. "-tool-prefix"
        vim.fn.mkdir(dir, "p")
        file = dir .. "/transcript.md"
        vim.fn.writefile(vim.split(MARKED, "\n"), file)
        patterns = highlight_structure.patterns(require("parley.config"))
    end)

    --- Every registered tool, so a new builtin is covered by construction.
    local function registered()
        local names = {}
        for _, n in ipairs(tools.BUILTIN_NAMES) do names[#names + 1] = n end
        for _, n in ipairs(tools.OPTIONAL_NAMES) do names[#names + 1] = n end
        return names
    end

    -- Declared here, assigned below; plenary evaluates it() bodies eagerly, so
    -- any case reading this table must come AFTER the assignment.
    local READ_INPUTS

    local function assert_no_column0_marker(name, content)
        for _, line in ipairs(vim.split(content or "", "\n")) do
            local kind = highlight_structure.classify(line, patterns).kind
            assert.message(("%s emitted a column-0 %s marker: %q\n"
                .. "A tool body may not span one (fence.scan), so this would let a "
                .. "tool result fork a spurious exchange."):format(name, kind, line))
                .is_false(highlight_structure.is_structural_kind(kind))
        end
    end

    it("covers every registered tool, not a hand-picked subset", function()
        assert.is_true(#registered() >= 9,
            "registry shrank — this guard derives its subjects from it")
    end)

    -- Tools that cannot echo file content back, and why. Every registered tool
    -- must appear here or in READ_INPUTS — the assertion below fails otherwise,
    -- so a new builtin is ruled rather than silently uncovered (#203 BR-2). The
    -- previous draft hand-listed five and let the atlas claim it derived from
    -- the registry; that claim is only true with this check.
    local NOT_ECHOING = {
        edit_file = "returns a status message, never file content",
        write_file = "returns a status message",
        propose_edits = "returns a status message",
        emit_definition = "returns the empty string",
        chat_history_search = "rg with --with-filename --line-number, then the "
            .. "path prefix is rewritten to {label}/ — never column 0",
    }

    -- Read-shaped tools are the ones that can echo file content back.
    READ_INPUTS = {
        read_file = function(f) return { file_path = f } end,
        grep = function(f, d) return { pattern = "💬", path = d } end,
        ack = function(f, d) return { pattern = "💬", path = d } end,
        ls = function(f, d) return { path = d } end,
        find = function(f, d) return { path = d } end,
    }

    it("rules on every registered tool, none silently uncovered", function()
        for _, name in ipairs(registered()) do
            assert.message(("%s is registered but neither exercised nor ruled out — "
                .. "add it to READ_INPUTS or NOT_ECHOING with a reason"):format(name))
                .is_true(READ_INPUTS[name] ~= nil or NOT_ECHOING[name] ~= nil)
        end
    end)

    for name, build in pairs(READ_INPUTS) do
        it(name .. " prefixes any marker it echoes", function()
            local def = tools.get(name)
            if not def then
                -- Absent is only acceptable for an OPTIONAL tool; for a builtin
                -- it means the registry moved and this guard stopped running.
                local optional = false
                for _, n in ipairs(tools.OPTIONAL_NAMES) do
                    if n == name then optional = true end
                end
                assert.message(name .. " is not registered — guard would silently skip")
                    .is_true(optional)
                return
            end
            local result = def.handler(build(file, dir))
            -- Error paths splice raw stderr and are a stated exception, but a
            -- silent skip on EVERY input would hide a broken guard, so prove the
            -- success path was actually exercised.
            assert.message(name .. " only produced errors — the guard exercised nothing")
                .is_false(result.is_error)
            assert_no_column0_marker(name, result.content)
        end)
    end
end)
