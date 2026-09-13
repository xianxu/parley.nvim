local assets = require("parley.assets")

local CHAT = "/roots/chats/2026-09-10.14-20-03.112_ui-bug.md"
local TS = "2026-09-10.14-20-03.112"
local FOLDER = "/roots/chats/assets/" .. TS

--- In-memory io_ with injectable failure. `opts.fail[op] = "<err>"` makes
--- that operation report failure (and leave state untouched) until cleared.
local function fake_io(files, dirs, opts)
    files = files or {}
    dirs = dirs or {}
    opts = opts or {}
    local io_ = { files = files, dirs = dirs, removed = {}, clock = 0, fail = opts.fail or {} }
    local function failing(op)
        return io_.fail[op]
    end
    io_.exists = function(p)
        return files[p] ~= nil or dirs[p] == true
    end
    io_.stat = function(p)
        if failing("stat") then
            return nil, io_.fail.stat
        end
        if files[p] == nil then
            return nil, "ENOENT"
        end
        return #files[p]
    end
    io_.mkdir = function(p)
        if failing("mkdir") then
            return false, io_.fail.mkdir
        end
        dirs[p] = true
        return true
    end
    io_.write = function(p, bytes)
        if failing("write") then
            return false, io_.fail.write
        end
        files[p] = bytes
        return true
    end
    io_.read = function(p, max)
        if failing("read") then
            return nil, io_.fail.read
        end
        if files[p] == nil then
            return nil, "ENOENT"
        end
        return files[p]:sub(1, max)
    end
    io_.rename = function(a, b)
        if failing("rename") then
            return nil, io_.fail.rename
        end
        if dirs[a] then
            dirs[a] = nil
            dirs[b] = true
        end
        for p, v in pairs(files) do
            if p:sub(1, #a + 1) == a .. "/" then
                files[b .. p:sub(#a + 1)] = v
                files[p] = nil
            end
        end
        return true
    end
    io_.remove_tree = function(p)
        if failing("remove_tree") then
            return nil, io_.fail.remove_tree
        end
        io_.removed[#io_.removed + 1] = p
        dirs[p] = nil
        for f in pairs(files) do
            if f:sub(1, #p + 1) == p .. "/" then
                files[f] = nil
            end
        end
        return true
    end
    io_.list = function(p)
        local out = {}
        for f in pairs(files) do
            if f:sub(1, #p + 1) == p .. "/" and not f:sub(#p + 2):find("/", 1, true) then
                out[#out + 1] = f:sub(#p + 2)
            end
        end
        table.sort(out)
        return out
    end
    io_.now = function()
        io_.clock = io_.clock + 1
        return "2026-09-12.10-00-00.00" .. io_.clock
    end
    return io_
end

local function seeded(opts)
    return fake_io({ [FOLDER .. "/a.png"] = "A", [FOLDER .. "/b.png"] = "BB" }, { [FOLDER] = true }, opts)
end

local function keys_of(set)
    local out = {}
    for k in pairs(set) do
        out[#out + 1] = k
    end
    table.sort(out)
    return out
end

describe("assets: constants", function()
    it("pins the caps the wires impose", function()
        assert.equals("assets", assets.DIR)
        assert.equals(10 * 1024 * 1024, assets.MAX_BYTES, "Anthropic per-image cap")
        assert.equals(20 * 1024 * 1024, assets.MAX_REQUEST_BYTES, "Gemini inline total")
        assert.equals(20, assets.MAX_REQUEST_IMAGES)
        assert.equals(256, assets.BLOCK_OVERHEAD)
        assert.equals("string", type(assets.OMITTED_NOTE))
    end)
end)

describe("assets: layout", function()
    it("keys a chat by its timestamp, never its slug", function()
        assert.equals(TS, assets.key_for(CHAT))
        assert.equals(TS, assets.key_for("/roots/chats/" .. TS .. ".md"))
        assert.is_nil(assets.key_for("/roots/notes/todo.md"))
        assert.is_nil(assets.key_for(nil))
    end)

    it("folder_for is <dir>/assets/<ts>", function()
        assert.equals(FOLDER, assets.folder_for(CHAT))
        local folder, err = assets.folder_for("/roots/notes/todo.md")
        assert.is_nil(folder)
        assert.matches("not a timestamp%-named chat", err)
        folder, err = assets.folder_for(TS .. ".md")
        assert.is_nil(folder, "a bare basename has no directory to anchor the folder")
        assert.is_string(err)
    end)

    it("folder_in composes the destination form", function()
        assert.equals("/elsewhere/assets/" .. TS, assets.folder_in("/elsewhere", TS))
    end)

    it("relative_path and markdown_link form the one link shape", function()
        local rel = assets.relative_path(TS, "2026-09-10.14-22-31.487.png")
        assert.equals("assets/" .. TS .. "/2026-09-10.14-22-31.487.png", rel)
        assert.equals("![](" .. rel .. ")", assets.markdown_link(rel))
    end)

    it("unique_name suffixes -N while the name is taken", function()
        local taken = { ["s.png"] = true, ["s-2.png"] = true }
        local exists = function(n)
            return taken[n] == true
        end
        assert.equals("s-3.png", assets.unique_name("s", "png", exists))
        assert.equals("t.png", assets.unique_name("t", "png", exists))
    end)

    it("media_type knows the four wire-accepted formats", function()
        assert.equals("image/png", assets.media_type("a.png"))
        assert.equals("image/jpeg", assets.media_type("a.JPG"))
        assert.equals("image/jpeg", assets.media_type("a.jpeg"))
        assert.equals("image/gif", assets.media_type("a.gif"))
        assert.equals("image/webp", assets.media_type("a.webp"))
        assert.is_nil(assets.media_type("a.svg"))
        assert.is_nil(assets.media_type("a"))
    end)

    it("too_big is the one size sentence", function()
        assert.equals(
            (assets.MAX_BYTES + 1) .. " bytes exceeds the " .. assets.MAX_BYTES .. "-byte limit",
            assets.too_big(assets.MAX_BYTES + 1)
        )
    end)
end)

describe("assets: attachment grammar", function()
    local ok_line = "![](assets/" .. TS .. "/2026-09-10.14-22-31.487.png)"

    it("accepts exactly a relative assets link on its own line", function()
        local att = assets.parse_attachment(ok_line)
        assert.same({
            path = "assets/" .. TS .. "/2026-09-10.14-22-31.487.png",
            ts = TS,
            name = "2026-09-10.14-22-31.487.png",
            media_type = "image/png",
        }, att)
        assert.is_not_nil(assets.parse_attachment("  " .. ok_line .. "  "), "blanks either side")
        assert.is_not_nil(assets.parse_attachment("![a screenshot](assets/" .. TS .. "/x.png)"), "alt text")
        assert.equals("image/webp", assets.parse_attachment("![](assets/" .. TS .. "/shot-2.WEBP)").media_type)
    end)

    it("rejects everything that is not the grammar", function()
        local rejected = {
            "![](/abs/assets/" .. TS .. "/x.png)", -- absolute
            "![](assets/../" .. TS .. "/x.png)", -- traversal in ts
            "![](assets/" .. TS .. "/../x.png)", -- traversal in name
            "![](assets/" .. TS .. "/a..b.png)", -- `..` inside the name
            "![](assets/" .. TS .. "/x.svg)", -- unsupported type
            "![](assets/" .. TS .. "/x)", -- no extension
            "![](assets/" .. TS .. "/`id`.png)", -- backtick
            "![](assets/notatimestamp/x.png)", -- ts not a timestamp
            "![](assets/" .. TS .. "_slug/x.png)", -- ts with a slug is not the key
            "![](https://example.com/x.png)", -- URL
            "see ![](assets/" .. TS .. "/x.png) here", -- inline in prose
            "[](assets/" .. TS .. "/x.png)", -- not an image link
            "[x](assets/" .. TS .. "/x.png)", -- a non-image link
            "![](images/" .. TS .. "/x.png)", -- wrong folder
            "![](assets/" .. TS .. "/.hidden.png)", -- dotfile
            "![](assets/" .. TS .. "/a b.png)", -- space in name
            "![](assets/" .. TS .. "/x.png) ![](assets/" .. TS .. "/y.png)", -- two on one line
            "![](assets/" .. TS .. ")", -- no name segment
            "![](assets/" .. TS .. "/sub/x.png)", -- extra segment
            "",
            "just prose",
        }
        for _, line in ipairs(rejected) do
            assert.is_nil(assets.parse_attachment(line), "should reject: " .. line)
        end
        assert.is_nil(assets.parse_attachment(nil))
    end)

    it("attachments_in lists one per matching line, in order", function()
        local text = "look:\n"
            .. ok_line
            .. "\nand\n![](assets/"
            .. TS
            .. "/b.gif)\nprose ![](assets/"
            .. TS
            .. "/c.png) prose"
        local list = assets.attachments_in(text)
        assert.equals(2, #list)
        assert.equals("image/png", list[1].media_type)
        assert.equals("image/gif", list[2].media_type)
        assert.same({}, assets.attachments_in(""))
        assert.same({}, assets.attachments_in(nil))
    end)
end)

describe("assets: encoded_size", function()
    it("is the base64 length of n raw bytes", function()
        assert.equals(0, assets.encoded_size(0))
        assert.equals(4, assets.encoded_size(1))
        assert.equals(4, assets.encoded_size(3))
        assert.equals(8, assets.encoded_size(4))
        for n = 0, 40 do
            assert.equals(#vim.base64.encode(string.rep("x", n)), assets.encoded_size(n), "n=" .. n)
        end
    end)
end)

describe("assets: plan_budget", function()
    local LIMITS = { max_bytes = 100, max_request_bytes = 1000, max_images = 3, block_overhead = 10 }

    -- One OCCURRENCE of an attachment: `id` is "<order>:<n>" (n = position in
    -- that question), the key the plan is keyed by; `path` may repeat.
    local function cand(id, name, size, err)
        return { id = id, order = tonumber(id:match("^(%d+):")), path = "assets/" .. TS .. "/" .. name, size = size, err = err }
    end

    it("includes everything when it all fits and notes nothing", function()
        local plan = assets.plan_budget({ cand("1:1", "a.png", 30), cand("2:1", "b.png", 30) }, 100, LIMITS)
        assert.same({ "1:1", "2:1" }, keys_of(plan.included))
        assert.same({}, plan.notes)
        assert.is_nil(plan.warning)
    end)

    it("takes a newest-first prefix when the request bytes run out", function()
        -- each image costs encoded_size(60) + 10 = 90; text 500; the three
        -- notes that could be emitted are charged too (77 bytes each, 231),
        -- so 731 + 90 + 90 = 911 fits and the third (1001) does not.
        local plan = assets.plan_budget({ cand("1:1", "old.png", 60), cand("2:1", "mid.png", 60), cand("3:1", "new.png", 60) }, 500, LIMITS)
        assert.same({ "2:1", "3:1" }, keys_of(plan.included))
        assert.equals("not sent: request budget", plan.notes["1:1"])
        assert.is_nil(plan.warning)
    end)

    it("is a strict newest-first prefix: a newer image that does not fit closes the request to older ones", function()
        -- 0 text + 3 notes (77, 77, 80 bytes + newlines = 237); new.png costs
        -- encoded_size(60) + 10 = 90 (327); huge.png costs encoded_size(100)
        -- + 10 = 146 — it would fit (473 <= 1000) if it were the only rule,
        -- so shrink the request to make it the first that does not.
        local limits = { max_bytes = 100, max_request_bytes = 400, max_images = 3, block_overhead = 10 }
        local plan = assets.plan_budget({ cand("1:1", "old.png", 1), cand("2:1", "huge.png", 100), cand("3:1", "new.png", 60) }, 0, limits)
        assert.same({ "3:1" }, keys_of(plan.included), "old.png would fit but sits behind huge.png")
        assert.equals("not sent: request budget", plan.notes["2:1"])
        assert.equals("not sent: request budget", plan.notes["1:1"])
    end)

    it("stops at the image count, oldest excluded first", function()
        local cands = {}
        for i = 1, 5 do
            cands[#cands + 1] = cand(i .. ":1", "i" .. i .. ".png", 1)
        end
        local plan = assets.plan_budget(cands, 0, LIMITS)
        assert.same({ "3:1", "4:1", "5:1" }, keys_of(plan.included))
        assert.equals("not sent: request budget", plan.notes["1:1"])
        assert.equals("not sent: request budget", plan.notes["2:1"])
    end)

    it("never counts an oversized or stat-failed candidate as an image", function()
        local plan = assets.plan_budget({
            cand("1:1", "big.png", LIMITS.max_bytes + 1),
            cand("2:1", "gone.png", nil, "ENOENT"),
            cand("3:1", "ok.png", 1),
            cand("4:1", "ok2.png", 1),
            cand("5:1", "ok3.png", 1),
        }, 0, LIMITS)
        assert.same({ "3:1", "4:1", "5:1" }, keys_of(plan.included), "the two non-images do not consume the count of 3")
        assert.equals("not sent: " .. assets.too_big(LIMITS.max_bytes + 1), plan.notes["1:1"])
        assert.equals("could not be read: ENOENT", plan.notes["2:1"])
    end)

    it("text alone over the request limit includes nothing and warns", function()
        local plan = assets.plan_budget({ cand("1:1", "a.png", 1) }, LIMITS.max_request_bytes + 1, LIMITS)
        assert.same({}, plan.included)
        assert.equals("not sent: request budget", plan.notes["1:1"])
        assert.is_string(plan.warning)
        assert.matches("1001", plan.warning)
        assert.matches("1000", plan.warning)
    end)

    -- C1: every OCCURRENCE is budgeted. Twenty-one links to one file are
    -- twenty-one images on the wire, so they are twenty-one candidates.
    it("N references to one path within a question yield exactly the cap, newest last positions kept", function()
        local cands = {}
        for n = 1, 5 do
            cands[#cands + 1] = cand("1:" .. n, "same.png", 1)
        end
        local plan = assets.plan_budget(cands, 0, LIMITS)
        assert.same({ "1:3", "1:4", "1:5" }, keys_of(plan.included))
        assert.equals("not sent: request budget", plan.notes["1:1"])
        assert.equals("not sent: request budget", plan.notes["1:2"])
    end)

    it("N references to one path across questions yield exactly the cap, oldest question first out", function()
        local plan = assets.plan_budget({
            cand("1:1", "same.png", 1),
            cand("1:2", "same.png", 1),
            cand("2:1", "same.png", 1),
            cand("2:2", "same.png", 1),
        }, 0, LIMITS)
        assert.same({ "1:2", "2:1", "2:2" }, keys_of(plan.included))
        assert.equals("not sent: request budget", plan.notes["1:1"])
    end)

    it("repeated references are charged per occurrence against the request bytes", function()
        -- 500 text + 3 notes (78 each = 234) = 734; one 60-byte image is 90:
        -- 824, 914 fit, 1004 does not — the same arithmetic as distinct paths.
        local plan = assets.plan_budget({ cand("1:1", "same.png", 60), cand("1:2", "same.png", 60), cand("1:3", "same.png", 60) }, 500, LIMITS)
        assert.same({ "1:2", "1:3" }, keys_of(plan.included))
        assert.equals("not sent: request budget", plan.notes["1:1"])
    end)

    it("refuses a candidate without an id or with a duplicate id (a caller bug, never a silent merge)", function()
        assert.has_error(function()
            assets.plan_budget({ { order = 1, path = "assets/" .. TS .. "/a.png", size = 1 } }, 0, LIMITS)
        end)
        assert.has_error(function()
            assets.plan_budget({ cand("1:1", "a.png", 1), cand("1:1", "b.png", 1) }, 0, LIMITS)
        end)
    end)

    it("every candidate is either included or noted, and the two never overlap (property)", function()
        -- Park-Miller: 16807 * 2^31 < 2^53, so the product stays exact in a
        -- double (the previous 1103515245 multiplier overflowed and collapsed
        -- the sequence — 199 of 200 trials drew zero candidates).
        local rng = 12345
        local function rand(n)
            rng = (rng * 16807) % 2147483647
            return rng % n
        end
        local dup_trials = 0
        for trial = 1, 200 do
            local cands = {}
            local count = rand(8)
            local seen_paths = {}
            for i = 1, count do
                local kind = rand(4)
                -- a pool of three names, so paths repeat within and across orders
                local name = "c" .. rand(3) .. ".png"
                local order = 1 + rand(3)
                local id = order .. ":" .. i
                if kind == 0 then
                    cands[#cands + 1] = cand(id, name, nil, "EIO")
                elseif kind == 1 then
                    cands[#cands + 1] = cand(id, name, LIMITS.max_bytes + rand(50))
                else
                    cands[#cands + 1] = cand(id, name, rand(LIMITS.max_bytes + 1))
                end
                if seen_paths[name] then
                    dup_trials = dup_trials + 1
                end
                seen_paths[name] = true
            end
            local text = rand(LIMITS.max_request_bytes + 200)
            local plan = assets.plan_budget(cands, text, LIMITS)
            local again = assets.plan_budget(cands, text, LIMITS)
            assert.same(plan, again, "deterministic (trial " .. trial .. ")")

            local included_count, charged = 0, text
            for _, c in ipairs(cands) do
                local inc = plan.included[c.id] == true
                local note = plan.notes[c.id]
                assert.is_true(inc ~= (note ~= nil), ("trial %d: %s must be exactly one of included/noted"):format(trial, c.id))
                if inc then
                    included_count = included_count + 1
                    assert.is_true(c.size ~= nil and c.size <= LIMITS.max_bytes, "only a fitting image is included")
                    charged = charged + assets.encoded_size(c.size) + LIMITS.block_overhead
                else
                    charged = charged + #("[attachment " .. c.path .. " " .. note .. "]\n")
                end
            end
            assert.is_true(included_count <= LIMITS.max_images, "count limit")
            if included_count > 0 then
                assert.is_true(charged <= LIMITS.max_request_bytes, ("trial %d: charged %d over the limit"):format(trial, charged))
            end
            if text > LIMITS.max_request_bytes then
                assert.equals(0, included_count)
                assert.is_string(plan.warning)
            end

            -- newest-first prefix: once a fitting occurrence is excluded, no
            -- OLDER fitting occurrence (lower order, then lower position) is
            -- included.
            local by_age = {}
            for i, c in ipairs(cands) do
                by_age[#by_age + 1] = { c = c, pos = i }
            end
            table.sort(by_age, function(a, b)
                if a.c.order ~= b.c.order then
                    return a.c.order > b.c.order
                end
                return a.pos > b.pos
            end)
            local seen_excluded = false
            for _, e in ipairs(by_age) do
                local c = e.c
                if c.size and c.size <= LIMITS.max_bytes then
                    if plan.included[c.id] then
                        assert.is_false(seen_excluded, ("trial %d: %s included after a newer one was excluded"):format(trial, c.id))
                    else
                        seen_excluded = true
                    end
                end
            end
        end
        assert.is_true(dup_trials > 50, "the generator must exercise duplicate paths")
    end)

    it("defaults its limits to the module constants", function()
        local plan = assets.plan_budget({ cand("1:1", "a.png", 10) }, 0)
        assert.is_true(plan.included["1:1"])
        plan = assets.plan_budget({ cand("1:1", "a.png", assets.MAX_BYTES + 1) }, 0)
        assert.equals("not sent: " .. assets.too_big(assets.MAX_BYTES + 1), plan.notes["1:1"])
    end)
end)

describe("assets: payload_size and has_image", function()
    it("payload_size is the encoded length", function()
        local payload = { model = "m", messages = { { role = "user", content = "hi" } } }
        assert.equals(#vim.json.encode(payload), assets.payload_size(payload))
    end)

    it("has_image finds each wire's shape anywhere in the payload", function()
        local anthropic = { messages = { { role = "user", content = {
            { type = "image", source = { type = "base64", media_type = "image/png", data = "AAAA" } },
            { type = "text", text = "q" },
        } } } }
        local openai = { messages = { { role = "user", content = {
            { type = "image_url", image_url = { url = "data:image/png;base64,AAAA", detail = "auto" } },
        } } } }
        local gemini = { contents = { { role = "user", parts = {
            { inlineData = { mimeType = "image/png", data = "AAAA" } },
            { text = "q" },
        } } } }
        assert.is_true(assets.has_image(anthropic))
        assert.is_true(assets.has_image(openai))
        assert.is_true(assets.has_image(gemini))
    end)

    it("has_image is false for text-only payloads and near-misses", function()
        assert.is_false(assets.has_image({ messages = { { role = "user", content = "hi" } } }))
        assert.is_false(assets.has_image({ messages = { { role = "user", content = {
            { type = "text", text = "image" },
        } } } }))
        assert.is_false(assets.has_image({ messages = { { role = "user", content = {
            { type = "image_url", image_url = { url = "https://example.com/x.png" } },
        } } } }), "a remote image_url carries no bytes")
        assert.is_false(assets.has_image({ contents = { { parts = { { text = "inlineData" } } } } }))
        assert.is_false(assets.has_image({}))
        assert.is_false(assets.has_image("data:image/png;base64,AAAA"))
        assert.is_false(assets.has_image(nil))
    end)
end)

describe("assets: question content", function()
    local A = "assets/" .. TS .. "/a.png"
    local B = "assets/" .. TS .. "/b.gif"
    local PNG = "\137PNG\r\n\26\n" .. "PNGBYTES"
    local GIF = "GIF89a" .. "GIFBYTES"
    -- Attachments carry the occurrence id the builder assigned ("<order>:<n>").
    local atts = {
        { id = "1:1", path = A, media_type = "image/png" },
        { id = "1:2", path = B, media_type = "image/gif" },
    }
    local function no_read()
        error("must not read")
    end
    local function plan_all()
        return { included = { ["1:1"] = true, ["1:2"] = true }, notes = {} }
    end

    it("returns the text unchanged with no attachments", function()
        assert.equals("hi", assets.question_content("hi", {}, plan_all(), no_read))
        assert.equals("hi", assets.question_content("hi", nil, plan_all(), no_read))
    end)

    it("puts images first, base64-encoded, then one text block", function()
        local files = { [A] = PNG, [B] = GIF }
        local content = assets.question_content("what is this?", atts, plan_all(), function(rel)
            return files[rel]
        end)
        assert.equals(3, #content)
        assert.same({ type = "image", source = { type = "base64", media_type = "image/png", data = vim.base64.encode(PNG) } }, content[1])
        assert.same({ type = "image", source = { type = "base64", media_type = "image/gif", data = vim.base64.encode(GIF) } }, content[2])
        assert.same({ type = "text", text = "what is this?" }, content[3])
    end)

    it("prepends the plan's notes and never reads an excluded attachment", function()
        local plan = { included = { ["1:1"] = true }, notes = { ["1:2"] = "not sent: request budget" } }
        local reads = {}
        local content = assets.question_content("q", atts, plan, function(rel)
            reads[#reads + 1] = rel
            return PNG
        end)
        assert.same({ A }, reads)
        assert.equals(2, #content)
        assert.equals("image", content[1].type)
        assert.equals("[attachment " .. B .. " not sent: request budget]\nq", content[2].text)
    end)

    it("is a plain string when nothing is included", function()
        local plan = { included = {}, notes = { ["1:1"] = "could not be read: ENOENT", ["1:2"] = "not sent: request budget" } }
        local content = assets.question_content("q", atts, plan, no_read)
        assert.equals("string", type(content))
        assert.equals("[attachment " .. A .. " could not be read: ENOENT]\n[attachment " .. B .. " not sent: request budget]\nq", content)
    end)

    it("a read that fails after planning becomes a note, never a block", function()
        local content = assets.question_content("q", { atts[1] }, plan_all(), function()
            return nil, "ENOENT"
        end)
        assert.equals("[attachment " .. A .. " could not be read: ENOENT]\nq", content)
    end)

    it("a file that grew past the cap after planning gets the one size sentence", function()
        local big = PNG .. string.rep("x", assets.MAX_BYTES + 1)
        local content = assets.question_content("q", { atts[1] }, plan_all(), function()
            return big
        end)
        assert.equals("[attachment " .. A .. " not sent: " .. assets.too_big(#big) .. "]\nq", content)
    end)

    -- C4: bytes that do not look like the attachment's media type are a note,
    -- never a block — whatever reader the caller injected.
    it("bytes that are not the declared image type become a note, never a block", function()
        for _, bad in ipairs({ "", "hello, world", "\137PN", GIF }) do
            local content = assets.question_content("q", { atts[1] }, plan_all(), function()
                return bad
            end)
            assert.equals("[attachment " .. A .. " not a image/png image]\nq", content, ("%q"):format(bad))
        end
    end)

    it("keeps readable images when a sibling failed", function()
        local content = assets.question_content("q", atts, plan_all(), function(rel)
            if rel == A then
                return PNG
            end
            return nil, "gone"
        end)
        assert.equals(2, #content)
        assert.equals("image", content[1].type)
        assert.equals("[attachment " .. B .. " could not be read: gone]\nq", content[2].text)
    end)

    it("an attachment the plan never saw is noted, not read", function()
        local content = assets.question_content("q", { atts[1] }, { included = {}, notes = {} }, no_read)
        assert.equals("[attachment " .. A .. " not sent: not planned]\nq", content)
        assert.equals("[attachment " .. A .. " not sent: not planned]\nq", assets.question_content("q", { atts[1] }, nil, no_read))
    end)

    it("an attachment without an id is unplanned by definition, not read", function()
        local content = assets.question_content("q", { { path = A, media_type = "image/png" } }, plan_all(), no_read)
        assert.equals("[attachment " .. A .. " not sent: not planned]\nq", content)
    end)

    -- C1 end to end: repeated links to one file, a cap of 3, exactly 3 blocks.
    it("N references to one path emit exactly the planned occurrences, the rest as notes", function()
        local repeated, cands = {}, {}
        for n = 1, 5 do
            repeated[n] = { id = "1:" .. n, path = A, media_type = "image/png" }
            cands[n] = { id = "1:" .. n, order = 1, path = A, size = #PNG }
        end
        local plan = assets.plan_budget(cands, 0, { max_images = 3 })
        local reads = 0
        local content = assets.question_content("q", repeated, plan, function()
            reads = reads + 1
            return PNG
        end)
        assert.equals(4, #content, "3 image blocks + 1 text block")
        assert.equals(3, reads)
        for i = 1, 3 do
            assert.equals("image", content[i].type)
        end
        assert.equals(
            "[attachment " .. A .. " not sent: request budget]\n[attachment " .. A .. " not sent: request budget]\nq",
            content[4].text
        )
    end)

    it("omitted_text appends the note only when an image was attached", function()
        assert.equals("[omitted]", assets.omitted_text("[omitted]", {}))
        assert.equals("[omitted]", assets.omitted_text("[omitted]", nil))
        assert.equals("[omitted]\n" .. assets.OMITTED_NOTE, assets.omitted_text("[omitted]", atts))
    end)
end)

describe("assets: looks_like (C4 — bytes must match the declared type)", function()
    local PNG = "\137PNG\r\n\26\n"
    local JPEG = "\255\216\255\224"
    local GIF87, GIF89 = "GIF87a", "GIF89a"
    local WEBP = "RIFF\0\0\0\0WEBPVP8 "

    it("accepts each wire-accepted format's signature", function()
        assert.is_true(assets.looks_like("image/png", PNG .. "body"))
        assert.is_true(assets.looks_like("image/jpeg", JPEG .. "body"))
        assert.is_true(assets.looks_like("image/gif", GIF87 .. "body"))
        assert.is_true(assets.looks_like("image/gif", GIF89 .. "body"))
        assert.is_true(assets.looks_like("image/webp", WEBP .. "body"))
    end)

    it("rejects empty, text, truncated, mismatched and unknown", function()
        assert.is_false(assets.looks_like("image/png", ""))
        assert.is_false(assets.looks_like("image/png", "hello"))
        assert.is_false(assets.looks_like("image/png", PNG:sub(1, 5)), "truncated header")
        assert.is_false(assets.looks_like("image/jpeg", PNG .. "body"), "png bytes declared jpeg")
        assert.is_false(assets.looks_like("image/gif", "GIF88a"), "not a gif version")
        assert.is_false(assets.looks_like("image/webp", "RIFF\0\0\0\0WAVE"), "RIFF but not WEBP")
        assert.is_false(assets.looks_like("image/webp", "RIFFWEBP"), "WEBP not at offset 8")
        assert.is_false(assets.looks_like("image/svg+xml", "<svg/>"), "unknown media type")
        assert.is_false(assets.looks_like(nil, PNG))
        assert.is_false(assets.looks_like("image/png", nil))
    end)
end)

describe("assets: elide_image_data", function()
    local B64 = vim.base64.encode(string.rep("\1\2\3", 400)) -- 1200 raw bytes

    it("replaces the bytes in all three wire shapes and copies everything else", function()
        local value = {
            anthropic = { { type = "image", source = { type = "base64", media_type = "image/png", data = B64 } } },
            openai = { { type = "image_url", image_url = { url = "data:image/gif;base64," .. B64, detail = "auto" } } },
            gemini = { { inlineData = { mimeType = "image/webp", data = B64 } } },
            text = "unchanged",
            n = 3,
            nested = { deeper = { { type = "text", text = "t" } } },
        }
        local out = assets.elide_image_data(value)
        assert.equals("<image/png, 1200 bytes>", out.anthropic[1].source.data)
        assert.equals("base64", out.anthropic[1].source.type)
        assert.equals("<image/gif, 1200 bytes>", out.openai[1].image_url.url)
        assert.equals("auto", out.openai[1].image_url.detail)
        assert.equals("<image/webp, 1200 bytes>", out.gemini[1].inlineData.data)
        assert.equals("image/webp", out.gemini[1].inlineData.mimeType)
        assert.equals("unchanged", out.text)
        assert.equals(3, out.n)
        assert.same({ deeper = { { type = "text", text = "t" } } }, out.nested)
        assert.is_nil(vim.inspect(out):find(B64:sub(1, 64), 1, true), "no base64 survives vim.inspect")
    end)

    it("does not mutate its input and passes non-tables through", function()
        local value = { { type = "image", source = { type = "base64", media_type = "image/png", data = B64 } } }
        assets.elide_image_data(value)
        assert.equals(B64, value[1].source.data)
        assert.equals("s", assets.elide_image_data("s"))
        assert.is_nil(assets.elide_image_data(nil))
        local remote = { type = "image_url", image_url = { url = "https://x/y.png" } }
        assert.same(remote, assets.elide_image_data(remote), "a remote URL holds no bytes to elide")
    end)
end)

describe("assets: save and read_bounded", function()
    local PNG = "\137PNG\r\n\26\n" .. "PNGBYTES"

    it("creates the folder, mints a unique name, writes, and returns the link", function()
        local io_ = fake_io()
        local rel, abs = assets.save(CHAT, PNG, "png", io_)
        assert.equals("assets/" .. TS .. "/2026-09-12.10-00-00.001.png", rel)
        assert.equals(FOLDER .. "/2026-09-12.10-00-00.001.png", abs)
        assert.is_true(io_.dirs[FOLDER])
        assert.equals(PNG, io_.files[abs])
        assert.equals(PNG, assets.read_bounded(CHAT, rel, io_))
    end)

    it("two saves in the same millisecond do not collide", function()
        local io_ = fake_io()
        io_.now = function()
            return "same"
        end
        local a = assets.save(CHAT, "1", "png", io_)
        local b = assets.save(CHAT, "2", "png", io_)
        assert.equals("assets/" .. TS .. "/same.png", a)
        assert.equals("assets/" .. TS .. "/same-2.png", b)
        assert.equals("1", io_.files[FOLDER .. "/same.png"])
        assert.equals("2", io_.files[FOLDER .. "/same-2.png"])
    end)

    it("refuses a non-chat path and an oversized image before touching disk", function()
        local io_ = fake_io()
        local rel, abs, err = assets.save("/roots/notes/todo.md", "x", "png", io_)
        assert.is_nil(rel)
        assert.is_nil(abs)
        assert.matches("not a timestamp%-named chat", err)
        rel, abs, err = assets.save(CHAT, string.rep("x", assets.MAX_BYTES + 1), "png", io_)
        assert.is_nil(rel)
        assert.is_nil(abs)
        assert.equals(assets.too_big(assets.MAX_BYTES + 1), err)
        assert.same({}, io_.files)
        assert.same({}, io_.dirs, "no folder is created for a refused save")
    end)

    it("save: mkdir failure → error, nothing written", function()
        local io_ = fake_io(nil, nil, { fail = { mkdir = "EACCES" } })
        local rel, abs, err = assets.save(CHAT, "x", "png", io_)
        assert.is_nil(rel)
        assert.is_nil(abs)
        assert.matches("could not create " .. vim.pesc(FOLDER), err)
        assert.matches("EACCES", err)
        assert.same({}, io_.files)
    end)

    it("save: write failure → error, no file left behind", function()
        local io_ = fake_io(nil, nil, { fail = { write = "ENOSPC" } })
        local rel, abs, err = assets.save(CHAT, "x", "png", io_)
        assert.is_nil(rel)
        assert.is_nil(abs)
        assert.matches("could not write", err)
        assert.matches("ENOSPC", err)
        assert.same({}, io_.files, "no partial file")
    end)

    it("read_bounded stats first and refuses an oversized file without reading", function()
        local io_ = fake_io({ [FOLDER .. "/big.png"] = string.rep("x", assets.MAX_BYTES + 1) }, { [FOLDER] = true })
        local reads = 0
        local inner = io_.read
        io_.read = function(...)
            reads = reads + 1
            return inner(...)
        end
        local bytes, err = assets.read_bounded(CHAT, "assets/" .. TS .. "/big.png", io_)
        assert.is_nil(bytes)
        assert.equals(assets.too_big(assets.MAX_BYTES + 1), err)
        assert.equals(0, reads, "an oversized file is never read")
    end)

    it("read_bounded catches a file that grew between stat and read", function()
        local io_ = fake_io({ [FOLDER .. "/g.png"] = string.rep("x", assets.MAX_BYTES + 5) }, { [FOLDER] = true })
        io_.stat = function()
            return 10
        end
        local max_seen
        local inner = io_.read
        io_.read = function(p, max)
            max_seen = max
            return inner(p, max)
        end
        local bytes, err = assets.read_bounded(CHAT, "assets/" .. TS .. "/g.png", io_)
        assert.is_nil(bytes)
        assert.equals(assets.MAX_BYTES + 1, max_seen, "the read is bounded to MAX_BYTES + 1")
        assert.equals(assets.too_big(assets.MAX_BYTES + 1), err)
    end)

    it("read_bounded reports a missing file, a stat failure and a read failure, never raises", function()
        local bytes, err = assets.read_bounded(CHAT, "assets/" .. TS .. "/nope.png", fake_io())
        assert.is_nil(bytes)
        assert.equals("ENOENT", err)
        bytes, err = assets.read_bounded(CHAT, "assets/" .. TS .. "/a.png", seeded({ fail = { stat = "EIO" } }))
        assert.is_nil(bytes)
        assert.equals("EIO", err)
        bytes, err = assets.read_bounded(CHAT, "assets/" .. TS .. "/a.png", seeded({ fail = { read = "EIO" } }))
        assert.is_nil(bytes)
        assert.equals("EIO", err)
    end)

    it("read_bounded refuses bytes that are not the declared image type (C4)", function()
        local cases = {
            { name = "empty.png", bytes = "", err = "not a image/png image" },
            { name = "text.png", bytes = "hello, world\n", err = "not a image/png image" },
            { name = "trunc.png", bytes = "\137PN", err = "not a image/png image" },
            { name = "wrong.jpg", bytes = PNG, err = "not a image/jpeg image" },
            { name = "riff.webp", bytes = "RIFF\0\0\0\0WAVEfmt ", err = "not a image/webp image" },
        }
        for _, c in ipairs(cases) do
            local io_ = fake_io({ [FOLDER .. "/" .. c.name] = c.bytes }, { [FOLDER] = true })
            local bytes, err = assets.read_bounded(CHAT, "assets/" .. TS .. "/" .. c.name, io_)
            assert.is_nil(bytes, c.name)
            assert.equals(c.err, err, c.name)
        end
        local ok_io = fake_io({
            [FOLDER .. "/ok.png"] = PNG,
            [FOLDER .. "/ok.gif"] = "GIF87a!",
            [FOLDER .. "/ok.webp"] = "RIFF\0\0\0\0WEBPVP8 ",
            [FOLDER .. "/ok.jpeg"] = "\255\216\255\224",
        }, { [FOLDER] = true })
        for _, name in ipairs({ "ok.png", "ok.gif", "ok.webp", "ok.jpeg" }) do
            assert.equals(ok_io.files[FOLDER .. "/" .. name], assets.read_bounded(CHAT, "assets/" .. TS .. "/" .. name, ok_io), name)
        end
    end)

    it("read_bounded relays a non-regular file from stat and never reads it (C4)", function()
        local io_ = seeded()
        io_.stat = function(p)
            return nil, "not a regular file: " .. p
        end
        io_.read = function()
            error("must not read")
        end
        local bytes, err = assets.read_bounded(CHAT, "assets/" .. TS .. "/a.png", io_)
        assert.is_nil(bytes)
        assert.equals("not a regular file: " .. FOLDER .. "/a.png", err)
    end)

    it("read_bounded refuses a relative path outside the chat's directory", function()
        local io_ = seeded()
        for _, rel in ipairs({ "/etc/passwd", "../x.png", "assets/../../x.png", "" }) do
            local bytes, err = assets.read_bounded(CHAT, rel, io_)
            assert.is_nil(bytes, rel)
            assert.is_string(err, rel)
        end
        local bytes, err = assets.read_bounded(TS .. ".md", "assets/" .. TS .. "/a.png", io_)
        assert.is_nil(bytes)
        assert.is_string(err, "a chat path without a directory cannot anchor a read")
    end)
end)

describe("assets: move", function()
    it("move_conflict names source and destination, or the clash", function()
        local io_ = seeded()
        local src, dst = assets.move_conflict(CHAT, "/other/root", io_)
        assert.equals(FOLDER, src)
        assert.equals("/other/root/assets/" .. TS, dst)
        io_.dirs["/other/root/assets/" .. TS] = true
        local s, err = assets.move_conflict(CHAT, "/other/root", io_)
        assert.is_nil(s)
        assert.matches("asset folder already exists", err)
        local none, none_err = assets.move_conflict(CHAT, "/other/root", fake_io())
        assert.is_nil(none, "no folder → nothing to move")
        assert.is_nil(none_err)
        none, none_err = assets.move_conflict("/roots/notes/todo.md", "/other/root", io_)
        assert.is_nil(none, "a non-chat path has no folder")
        assert.is_nil(none_err)
    end)

    it("move_with renames the folder next to the moved chat", function()
        local io_ = seeded()
        local ok, err = assets.move_with(CHAT, "/other/root/" .. TS .. "_ui-bug.md", io_)
        assert.is_true(ok, err)
        assert.is_nil(err)
        assert.is_nil(io_.dirs[FOLDER])
        assert.is_true(io_.dirs["/other/root/assets/" .. TS])
        assert.equals("A", io_.files["/other/root/assets/" .. TS .. "/a.png"])
        assert.is_true(io_.dirs["/other/root/assets"], "parent assets/ is created first")
    end)

    it("move_with is a no-op when the chat has no folder", function()
        local io_ = fake_io()
        local ok, err = assets.move_with(CHAT, "/other/root/" .. TS .. ".md", io_)
        assert.is_true(ok)
        assert.is_nil(err)
        assert.same({}, io_.dirs)
    end)

    it("move_with refuses when the destination folder exists, touching nothing", function()
        local io_ = seeded()
        io_.dirs["/other/root/assets/" .. TS] = true
        local ok, err = assets.move_with(CHAT, "/other/root/" .. TS .. ".md", io_)
        assert.is_nil(ok)
        assert.matches("already exists", err)
        assert.is_true(io_.dirs[FOLDER], "source untouched")
        assert.equals("A", io_.files[FOLDER .. "/a.png"])
    end)

    it("move_with: mkdir failure → error, source untouched", function()
        local io_ = seeded({ fail = { mkdir = "EACCES" } })
        local ok, err = assets.move_with(CHAT, "/other/root/" .. TS .. ".md", io_)
        assert.is_nil(ok)
        assert.matches("could not create /other/root/assets", err)
        assert.matches("EACCES", err)
        assert.is_true(io_.dirs[FOLDER])
        assert.equals("A", io_.files[FOLDER .. "/a.png"])
    end)

    it("move_with: rename failure → error naming the source, source untouched", function()
        local io_ = seeded({ fail = { rename = "EXDEV" } })
        local ok, err = assets.move_with(CHAT, "/other/root/" .. TS .. ".md", io_)
        assert.is_nil(ok)
        assert.matches("could not move " .. vim.pesc(FOLDER), err)
        assert.matches("EXDEV", err)
        assert.is_true(io_.dirs[FOLDER])
        assert.equals("A", io_.files[FOLDER .. "/a.png"])
    end)

    it("move_with refuses a destination without a directory", function()
        local ok, err = assets.move_with(CHAT, TS .. ".md", seeded())
        assert.is_nil(ok)
        assert.is_string(err)
    end)
end)

describe("assets: delete", function()
    it("delete_with removes exactly the constructed folder", function()
        local io_ = seeded()
        local ok, err = assets.delete_with(CHAT, io_)
        assert.is_true(ok)
        assert.is_nil(err)
        assert.same({ FOLDER }, io_.removed)
        assert.is_nil(io_.files[FOLDER .. "/a.png"])
    end)

    it("delete_with is true with nothing to do for a non-chat path or a missing folder", function()
        local io_ = seeded()
        assert.is_true(assets.delete_with("/roots/notes/todo.md", io_))
        assert.same({}, io_.removed, "a non-chat path removes nothing")
        assert.is_true(assets.delete_with(CHAT, fake_io()))
    end)

    it("delete_with: removal failure → error, folder kept for the next delete", function()
        local io_ = seeded({ fail = { remove_tree = "EBUSY" } })
        local ok, err = assets.delete_with(CHAT, io_)
        assert.is_nil(ok)
        assert.matches("could not remove " .. vim.pesc(FOLDER), err)
        assert.matches("EBUSY", err)
        assert.is_true(io_.dirs[FOLDER])
        assert.equals("A", io_.files[FOLDER .. "/a.png"])
    end)

    it("removal_note names the folder and its file count, or is empty", function()
        assert.equals(" and assets/" .. TS .. "/ (2 files)", assets.removal_note(CHAT, seeded()))
        local one = fake_io({ [FOLDER .. "/a.png"] = "A" }, { [FOLDER] = true })
        assert.equals(" and assets/" .. TS .. "/ (1 file)", assets.removal_note(CHAT, one))
        assert.equals("", assets.removal_note(CHAT, fake_io()))
        assert.equals("", assets.removal_note("/roots/notes/todo.md", seeded()))
    end)
end)

describe("assets: copy_into", function()
    it("duplicates the folder's files under export_dir/assets/<ts>", function()
        local io_ = seeded()
        local n, errs = assets.copy_into(CHAT, "/export", io_)
        assert.equals(2, n)
        assert.same({}, errs)
        assert.equals("A", io_.files["/export/assets/" .. TS .. "/a.png"])
        assert.equals("BB", io_.files["/export/assets/" .. TS .. "/b.png"])
        assert.equals("A", io_.files[FOLDER .. "/a.png"], "source kept")
        n, errs = assets.copy_into("/roots/chats/2026-01-01.00-00-00.000.md", "/export", io_)
        assert.equals(0, n)
        assert.same({}, errs)
        n, errs = assets.copy_into("/roots/notes/todo.md", "/export", io_)
        assert.equals(0, n)
        assert.same({}, errs)
    end)

    it("mkdir failure → 0 copied, one error, nothing written", function()
        local io_ = seeded({ fail = { mkdir = "EACCES" } })
        local n, errs = assets.copy_into(CHAT, "/export", io_)
        assert.equals(0, n)
        assert.equals(1, #errs)
        assert.matches("EACCES", errs[1])
        assert.is_nil(io_.files["/export/assets/" .. TS .. "/a.png"])
    end)

    it("a failing read or write is an error entry and not counted", function()
        local io_ = seeded()
        local inner = io_.read
        io_.read = function(p, max)
            if p:match("a%.png$") then
                return nil, "EIO"
            end
            return inner(p, max)
        end
        local n, errs = assets.copy_into(CHAT, "/export", io_)
        assert.equals(1, n)
        assert.equals(1, #errs)
        assert.matches("a%.png", errs[1])
        assert.matches("EIO", errs[1])
        assert.equals("BB", io_.files["/export/assets/" .. TS .. "/b.png"])

        io_ = seeded({ fail = { write = "ENOSPC" } })
        n, errs = assets.copy_into(CHAT, "/export", io_)
        assert.equals(0, n)
        assert.equals(2, #errs)
        assert.matches("ENOSPC", errs[1])
    end)

    it("a stat failure on one file is an error entry; the rest still copy", function()
        local io_ = seeded()
        local inner = io_.stat
        io_.stat = function(p)
            if p:match("b%.png$") then
                return nil, "EIO"
            end
            return inner(p)
        end
        local n, errs = assets.copy_into(CHAT, "/export", io_)
        assert.equals(1, n)
        assert.equals(1, #errs)
        assert.matches("b%.png", errs[1])
    end)
end)

describe("assets: default_io", function()
    local root

    before_each(function()
        root = vim.fn.tempname()
        vim.fn.mkdir(root, "p")
    end)

    after_each(function()
        vim.fn.delete(root, "rf")
    end)

    local PNG = "\137PNG\r\n\26\n" .. "PNGBYTES"

    it("round-trips save, read_bounded, move, copy and delete on a real directory", function()
        local chat = root .. "/" .. TS .. ".md"
        local rel, abs, err = assets.save(chat, PNG, "png")
        assert.is_string(rel, err)
        assert.equals(1, vim.fn.filereadable(abs))
        assert.equals(PNG, assets.read_bounded(chat, rel))

        vim.fn.mkdir(root .. "/moved", "p")
        local ok, merr = assets.move_with(chat, root .. "/moved/" .. TS .. ".md")
        assert.is_true(ok, merr)
        assert.equals(0, vim.fn.isdirectory(root .. "/assets/" .. TS))
        assert.equals(1, vim.fn.isdirectory(root .. "/moved/assets/" .. TS))
        local moved = root .. "/moved/" .. TS .. ".md"

        local n, errs = assets.copy_into(moved, root .. "/export")
        assert.equals(1, n, vim.inspect(errs))
        assert.equals(1, vim.fn.filereadable(root .. "/export/assets/" .. TS .. "/" .. rel:match("[^/]+$")))

        assert.equals(" and assets/" .. TS .. "/ (1 file)", assets.removal_note(moved))
        local dok, derr = assets.delete_with(moved)
        assert.is_true(dok, derr)
        assert.equals(0, vim.fn.isdirectory(root .. "/moved/assets/" .. TS))
    end)

    it("stat reports size and read is bounded", function()
        local p = root .. "/f.bin"
        assert.is_true(assets.default_io.write(p, "0123456789"))
        assert.equals(10, assets.default_io.stat(p))
        assert.equals("01234", assets.default_io.read(p, 5))
        assert.equals("0123456789", assets.default_io.read(p, 100))
        local size, err = assets.default_io.stat(root .. "/missing")
        assert.is_nil(size)
        assert.is_string(err)
        local bytes, rerr = assets.default_io.read(root .. "/missing", 5)
        assert.is_nil(bytes)
        assert.is_string(rerr)
        assert.is_true(assets.default_io.write(root .. "/empty", ""))
        assert.equals("", assets.default_io.read(root .. "/empty", 5), "an empty regular file reads as an empty string")
    end)

    it("stat and read report a directory as an error, never as an empty file (C4)", function()
        local d = root .. "/dir.png"
        vim.fn.mkdir(d, "p")
        local size, serr = assets.default_io.stat(d)
        assert.is_nil(size)
        assert.matches("not a regular file", serr)
        local bytes, rerr = assets.default_io.read(d, 5)
        assert.is_nil(bytes, "io.open on a directory succeeds on macOS; read must still fail")
        assert.is_string(rerr)
    end)

    it("read_bounded on real files: a directory, an empty file and a text file are errors; a PNG is bytes (C4)", function()
        local chat = root .. "/" .. TS .. ".md"
        local folder = root .. "/assets/" .. TS
        vim.fn.mkdir(folder .. "/dir.png", "p")
        assert.is_true(assets.default_io.write(folder .. "/empty.png", ""))
        assert.is_true(assets.default_io.write(folder .. "/text.png", "just some text\n"))
        assert.is_true(assets.default_io.write(folder .. "/ok.png", PNG))
        for _, name in ipairs({ "dir.png", "empty.png", "text.png" }) do
            local bytes, err = assets.read_bounded(chat, "assets/" .. TS .. "/" .. name)
            assert.is_nil(bytes, name)
            assert.is_string(err, name)
            assert.is_not.equals("", bytes, name)
        end
        assert.matches("not a regular file", select(2, assets.read_bounded(chat, "assets/" .. TS .. "/dir.png")))
        assert.equals("not a image/png image", select(2, assets.read_bounded(chat, "assets/" .. TS .. "/empty.png")))
        assert.equals("not a image/png image", select(2, assets.read_bounded(chat, "assets/" .. TS .. "/text.png")))
        assert.equals(PNG, assets.read_bounded(chat, "assets/" .. TS .. "/ok.png"))
    end)

    it("write into a missing directory fails and leaves nothing", function()
        local ok, err = assets.default_io.write(root .. "/nope/f.bin", "x")
        assert.is_false(ok)
        assert.is_string(err)
        assert.equals(0, vim.fn.filereadable(root .. "/nope/f.bin"))
    end)

    --- Run `fn` with io.open returning a handle whose write/close are
    --- `overrides` (each gets the real handle first), recording os.remove
    --- calls. Globals are restored whatever happens.
    local function with_faulty_handle(overrides, fn)
        local real_open, real_remove = io.open, os.remove
        local removed = {}
        -- Swapping the two globals is the only seam into default_io.write's
        -- close check; restored below whatever happens.
        io.open = function(p, mode) -- luacheck: ignore 122
            local f, err = real_open(p, mode)
            if not f then
                return nil, err
            end
            return {
                write = function(_, bytes)
                    if overrides.write then
                        return overrides.write(f, bytes)
                    end
                    return f:write(bytes)
                end,
                close = function()
                    if overrides.close then
                        return overrides.close(f)
                    end
                    return f:close()
                end,
            }
        end
        os.remove = function(p) -- luacheck: ignore 122
            removed[#removed + 1] = p
            return real_remove(p)
        end
        local ok, a, b = pcall(fn)
        io.open, os.remove = real_open, real_remove -- luacheck: ignore 122
        assert.is_true(ok, a)
        return a, b, removed
    end

    it("write checks close and removes the partial file", function()
        local p = root .. "/partial.bin"
        local ok, err, removed = with_faulty_handle({
            close = function(f)
                f:close()
                return nil, "EIO on close"
            end,
        }, function()
            return assets.default_io.write(p, "x")
        end)
        assert.is_false(ok)
        assert.matches("EIO on close", err)
        assert.same({ p }, removed)
        assert.equals(0, vim.fn.filereadable(p), "no partial file after a failed close")
    end)

    it("write checks the write itself and removes the partial file", function()
        local p = root .. "/w.bin"
        local ok, err, removed = with_faulty_handle({
            write = function()
                return nil, "ENOSPC"
            end,
        }, function()
            return assets.default_io.write(p, "x")
        end)
        assert.is_false(ok)
        assert.matches("ENOSPC", err)
        assert.same({ p }, removed)
        assert.equals(0, vim.fn.filereadable(p))
    end)

    it("rename and remove_tree report failure with a reason", function()
        local ok, err = assets.default_io.rename(root .. "/missing", root .. "/other")
        assert.is_nil(ok)
        assert.is_string(err)
        vim.fn.mkdir(root .. "/d", "p")
        assets.default_io.write(root .. "/d/f", "x")
        local rok, rerr = assets.default_io.remove_tree(root .. "/d")
        assert.is_true(rok, rerr)
        assert.equals(0, vim.fn.isdirectory(root .. "/d"))
        rok, rerr = assets.default_io.remove_tree(root .. "/absent")
        assert.is_nil(rok)
        assert.is_string(rerr)
    end)

    it("list returns plain files only, sorted; mkdir is idempotent", function()
        assert.is_true(assets.default_io.mkdir(root .. "/l"))
        assert.is_true(assets.default_io.mkdir(root .. "/l"), "an existing directory is not an error")
        assets.default_io.write(root .. "/l/b", "x")
        assets.default_io.write(root .. "/l/a", "x")
        vim.fn.mkdir(root .. "/l/sub", "p")
        assert.same({ "a", "b" }, assets.default_io.list(root .. "/l"))
        assert.same({}, assets.default_io.list(root .. "/absent"))
        assert.is_true(assets.default_io.exists(root .. "/l"))
        assert.is_true(assets.default_io.exists(root .. "/l/a"))
        assert.is_false(assets.default_io.exists(root .. "/absent"))
        assert.is_string(assets.key_for("/x/" .. assets.default_io.now() .. ".md"), "now mints a chat-shaped stamp")
    end)
end)
