local arch = require("tests.arch.arch_helper")

local function source(path) return table.concat(vim.fn.readfile(path), "\n") end

local function bypasses(text)
    -- Raw history fields on an attachment, or on a copied snapshot, cannot be
    -- a second authority. Detect parallel assignments as well as simple ones.
    for statement in text:gmatch("[^\n]+") do
        statement = statement:gsub("[~=<>]=", " comparison ")
        local lhs = statement:match("^(.-)=[^=]") or ""
        for _, field in ipairs({ "baseline", "owned_lock", "acquire_token", "admission", "admission_message", "unconfirmed_edit" }) do
            if lhs:match("s%." .. field .. "%f[^%w_]")
                or lhs:match("admission%s*%([^)]*%)%." .. field .. "%f[^%w_]") then return true end
        end
    end
    local first = assert(text:find("dispatch_admission = function(", 1, true))
    local last = assert(text:find("\n-- Whole minutes", first, true))
    local outside = text:sub(1, first - 1) .. text:sub(last)
    return outside:find("%.operator_admission%.dispatch%s*%(") ~= nil
end

-- Keep checks within the relevant function/prefix, rather than matching a
-- gate elsewhere in the file. Native specs own runtime admission ordering.
local function compact(text)
    local lines={}
    for line in text:gmatch("[^\n]+") do
        if not line:match("^%s*%-%-") then lines[#lines+1]=line end
    end
    return table.concat(lines,"\n"):gsub("%s+", ""):gsub("'", '\"')
end

local function between(text, first, last)
    local start=text:find(first,1,true)
    if not start then return nil end
    local finish=text:find(last,start+#first,true)
    return finish and text:sub(start,finish-1) or nil
end

local function gates_tokenless_write(text)
    local prefix=between(compact(text),"localfunctionwrite_lock(","io.open(")
    return prefix~=nil and prefix:find(
        'ifrequire("parley.agentic_document").owns_admission(buffer_id(buf))thenreturnfalseend',1,true)~=nil
end

local function gates_legacy_attach(text)
    local prefix=between(compact(text),"M.attach=function(","ifstate[buf]then")
    if not prefix then return false end
    local gate=prefix:find('ifnotidentityandrequire("parley.agentic_document").owns_admission(buf)then',1,true)
    if not gate then return false end
    local branch=prefix:sub(gate)
    return branch:sub(-9)=="returnend" or branch:sub(-14)=="returnfalseend"
end

local function s1_before_fallback(text)
    local body=between(compact(text),"M.setup_markdown_keymaps=function(","M.setup_buf_handler=function(")
    if not body then return false end
    local _, count=body:gsub("session_sync%.attach%(","")
    return count==1 and body:find(
        'ifnotrequire("parley.agentic_document").attach(buf)thensession_sync.attach(buf)end',1,true)~=nil
end

local function removed_admission_surface(text)
    local code=compact(text)
    return code:find("legacy_release",1,true)~=nil
        or code:find("M.pending_lookup",1,true)~=nil
        or code:find('M["pending_lookup"]',1,true)~=nil
end

describe("arch: one operator admission history owner (#408)", function()
    it("detects raw history writes and transitions outside the dispatcher", function()
        local shell = "dispatch_admission = function()\nend\n-- Whole minutes\n"
        assert.is_false(bypasses(shell))
        for _, mutation in ipairs({ "s.baseline = nil", "s.owned_lock, s.baseline = nil, nil",
            "admission(s).acquire_token = nil", "s.operator_admission.dispatch({})" }) do
            assert.is_true(bypasses(shell .. mutation), mutation)
        end
    end)

    it("keeps history transitions in the dispatcher and the model independent of IO", function()
        assert.is_false(bypasses(source("lua/parley/session_sync.lua")))
        local model = source("lua/parley/operator_admission.lua")
        assert.is_nil(model:match("vim%."))
        assert.is_nil(model:match("require%s*%(%s*['\"]parley%."))
        for _, path in ipairs(arch.worktree_files({ "lua/**/*.lua" })) do
            if path ~= "lua/parley/session_sync.lua" then
                assert.is_nil(source(path):match("require%s*%(%s*['\"]parley%.operator_admission['\"]"), path)
            end
        end
    end)
end)


describe("arch: S1 retires new tokenless admission (#410)",function()
    it("detects writer guards removed, inverted or placed after the write",function()
        local gate='if require("parley.agentic_document").owns_admission(buffer_id(buf)) then return false end\n'
        local head='local function write_lock(buf,holder,baseline)\n'
        local write='local stream=io.open(path,"w")\nend'
        assert.is_true(gates_tokenless_write(head..gate..write))
        for _,mutation in ipairs({head..write..gate,
            head..gate:gsub("then return false end","then end")..write,
            head..gate:gsub("if require","if not require")..write,
            gate..head..write}) do
            assert.is_false(gates_tokenless_write(mutation),mutation)
        end
    end)

    it("detects missing no-identity attachment gating before controller reuse",function()
        local head='M.attach = function(buf,identity)\n'
        local gate='if not identity and require("parley.agentic_document").owns_admission(buf) then return end\n'
        local reuse='if state[buf] then return end\nend'
        assert.is_true(gates_legacy_attach(head..gate..reuse))
        for _,mutation in ipairs({head..reuse..gate,
            head..gate:gsub("not identity","identity")..reuse,
            head..gate:gsub("then return end","then end")..reuse,
            gate..head..reuse}) do
            assert.is_false(gates_legacy_attach(mutation),mutation)
        end
    end)

    it("detects unconditional or reordered legacy setup even when a guarded fallback also exists",function()
        local head='M.setup_markdown_keymaps=function(buf)\n'
        local fallback='if not require("parley.agentic_document").attach(buf) then session_sync.attach(buf) end\n'
        local tail='end\nM.setup_buf_handler=function() end'
        assert.is_true(s1_before_fallback(head..fallback..tail))
        for _,mutation in ipairs({head..'session_sync.attach(buf)\n'..fallback..tail,
            head..'session_sync.attach(buf)\nrequire("parley.agentic_document").attach(buf)\n'..tail,
            head..fallback:gsub("if not require","if require")..tail,
            fallback..head..tail}) do
            assert.is_false(s1_before_fallback(mutation),mutation)
        end
    end)

    it("detects retired effect stages and public pending lookup exports",function()
        assert.is_false(removed_admission_surface('-- legacy_release; M.pending_lookup\nlocal pending_lookup=function() end'))
        for _,mutation in ipairs({"return {kind='legacy_release'}",'M.pending_lookup=function() end',
            'function M.pending_lookup() end','M["pending_lookup"]=function() end'}) do
            assert.is_true(removed_admission_surface(mutation),mutation)
        end
    end)

    it("keeps both tokenless creation seams behind the exact S1 admission owner",function()
        local shell=source("lua/parley/session_sync.lua")
        assert.is_true(gates_tokenless_write(shell),"central tokenless writer must refuse S1-owned buffers before IO")
        assert.is_true(gates_legacy_attach(shell),"no-identity attachment must refuse S1-owned buffers before controller reuse")
        assert.is_true(s1_before_fallback(source("lua/parley/init.lua")),"normal setup must attempt S1 before conditional standalone legacy attachment")
        for _,path in ipairs(arch.worktree_files({"lua/**/*.lua"})) do
            assert.is_false(removed_admission_surface(source(path)),path..": retired stage/public lookup returned")
        end
    end)
end)
