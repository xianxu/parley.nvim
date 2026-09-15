local outline = require("parley.outline")
local Document=require('parley.document')
local function settle(buf) Document.drain(Document.attach(buf,{schedule=false}),1000) end

describe('Indexed live outline',function()
    it('returns bounded pages and follows surviving selection identity',function()
        local b=vim.api.nvim_create_buf(false,true); vim.api.nvim_set_current_buf(b)
        local lines={}; for i=1,25 do lines[i]='💬: q'..i end
        vim.api.nvim_buf_set_lines(b,0,-1,false,lines); settle(b)
        local page,result=outline._build_picker_items(b,{chat_user_prefix='💬:'},{is_chat=true})
        assert.is_true(#page<=8); assert.equals('more',result.status)
        assert.is_not_nil(page[1].value.identity)
        local chosen=page[2].value
        vim.api.nvim_buf_set_lines(b,0,0,false,{'new'}); settle(b)
        local success,row=outline._jump_to_outline_location({bufnr=b,name='',lnum=chosen.lnum,
            identity=chosen.identity,windows={vim.api.nvim_get_current_win()}},{chat_user_prefix='💬:'})
        assert.is_true(success); assert.equals(3,row)
        vim.api.nvim_buf_delete(b,{force=true})
    end)
    it('refuses a surviving heading during uncertainty and after code reclassification',function()
        local b=vim.api.nvim_create_buf(false,true);vim.api.nvim_set_current_buf(b)
        vim.api.nvim_buf_set_lines(b,0,-1,false,{'intro','# heading','body','tail'});settle(b)
        local page=outline._build_picker_items(b,{chat_user_prefix='💬:'},{is_chat=false})
        local chosen=page[1].value
        local selection={bufnr=b,name='',lnum=chosen.lnum,identity=chosen.identity,is_chat=false}
        vim.api.nvim_buf_set_lines(b,0,1,false,{'```'})
        assert.is_false(Document.lookup(Document.get(b),chosen.identity).metadata.confirmed)
        vim.api.nvim_win_set_cursor(0,{4,0})
        assert.is_false(outline._jump_to_outline_location(selection,{chat_user_prefix='💬:'}))
        assert.same({4,0},vim.api.nvim_win_get_cursor(0))
        settle(b)
        assert.is_true(Document.lookup(Document.get(b),chosen.identity).metadata.confirmed)
        assert.is_false(outline._jump_to_outline_location(selection,{chat_user_prefix='💬:'}))
        assert.same({4,0},vim.api.nvim_win_get_cursor(0))
        vim.api.nvim_buf_delete(b,{force=true})
    end)
    it('refuses identityless navigation when no current outline candidate is confirmed',function()
        local b=vim.api.nvim_create_buf(false,true);vim.api.nvim_set_current_buf(b)
        vim.api.nvim_buf_set_lines(b,0,-1,false,{'plain','tail'})
        Document.attach(b,{schedule=false});vim.api.nvim_win_set_cursor(0,{2,0})
        local selection={bufnr=b,name='',lnum=1}
        assert.is_false(outline._jump_to_outline_location(selection,{chat_user_prefix='💬:'}))
        settle(b)
        assert.is_false(outline._jump_to_outline_location(selection,{chat_user_prefix='💬:'}))
        assert.same({2,0},vim.api.nvim_win_get_cursor(0))
        vim.api.nvim_buf_delete(b,{force=true})
    end)
    it('revalidates after focus autocommands invalidate the selected context',function()
        local b=vim.api.nvim_create_buf(false,true);vim.api.nvim_set_current_buf(b)
        vim.api.nvim_buf_set_lines(b,0,-1,false,{'intro','# heading','tail'});settle(b)
        local page=outline._build_picker_items(b,{chat_user_prefix='💬:'},{is_chat=false})
        local chosen=page[1].value
        local other=vim.api.nvim_create_buf(false,true);vim.api.nvim_set_current_buf(other)
        local id=vim.api.nvim_create_autocmd('BufEnter',{buffer=b,once=true,callback=function()
            vim.api.nvim_buf_set_lines(b,0,1,false,{'```'})
        end})
        local ok=outline._jump_to_outline_location({bufnr=b,name='',identity=chosen.identity,
            lnum=chosen.lnum,is_chat=false},{chat_user_prefix='💬:'})
        pcall(vim.api.nvim_del_autocmd,id)
        assert.is_false(ok)
        vim.api.nvim_buf_delete(b,{force=true});vim.api.nvim_buf_delete(other,{force=true})
    end)
    it('returns pending without materializing an unread buffer',function()
        local b=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_buf_set_lines(b,0,-1,false,{'💬: q'})
        Document.attach(b,{schedule=false})
        local items,result=outline._build_picker_items(b,{chat_user_prefix='💬:'},{is_chat=true})
        assert.same({},items); assert.equals('opaque',result.status)
        vim.api.nvim_buf_delete(b,{force=true})
    end)
    it('caps label reads, pages all candidates, and rejects stale cursors',function()
        local b=vim.api.nvim_create_buf(false,true)
        local lines={};for i=1,20 do lines[i]='💬: '..string.rep('x',10000)..i end
        vim.api.nvim_buf_set_lines(b,0,-1,false,lines); settle(b)
        local reader=require('parley.line_reader');local read_bytes=0;local largest=0;local full=false
        local observer=reader.set_observer(b,function(e)
            read_bytes=read_bytes+(e.bytes_read or 0);largest=math.max(largest,e.bytes_read or 0)
            full=full or e.full_buffer
        end)
        local cursor,first_cursor,count=nil,nil,0
        repeat
            local page,result=outline._build_picker_items(b,{chat_user_prefix='💬:'},{is_chat=true,cursor=cursor})
            assert.is_true(#page<=8);count=count+#page;cursor=result.cursor;first_cursor=first_cursor or cursor
        until not cursor
        assert.equals(20,count); assert.is_true(largest<=4096); assert.equals(20*4096,read_bytes)
        assert.is_false(full)
        reader.clear_observer(b,observer)
        vim.api.nvim_buf_set_text(b,0,10,0,10,{'x'})
        local _,stale=outline._build_picker_items(b,{chat_user_prefix='💬:'},{is_chat=true,cursor=first_cursor})
        assert.equals('stale',stale.status)
        vim.api.nvim_buf_delete(b,{force=true})
    end)
    it('loads pending live pages asynchronously and refuses a deleted selection',function()
        local b=vim.api.nvim_create_buf(false,true);vim.api.nvim_set_current_buf(b)
        vim.api.nvim_buf_set_lines(b,0,-1,false,{'💬: q','body'})
        local loaded
        outline._load_live_items(b,{chat_user_prefix='💬:'},{is_chat=true},function(items) loaded=items end)
        assert.is_true(vim.wait(2000,function()return loaded~=nil end,5))
        assert.equals(1,#loaded)
        local chosen=loaded[1].value
        vim.api.nvim_buf_set_lines(b,0,1,false,{'plain'})
        local success=outline._jump_to_outline_location({bufnr=b,name='',identity=chosen.identity,
            lnum=chosen.lnum},{chat_user_prefix='💬:'})
        assert.is_false(success)
        vim.api.nvim_buf_delete(b,{force=true})
    end)
    it('lets native timers run before all live outline pages complete',function()
        local b=vim.api.nvim_create_buf(false,true)
        local lines={};for i=1,160 do lines[i]='💬: question '..i end
        vim.api.nvim_buf_set_lines(b,0,-1,false,lines);settle(b)
        local completed,observed=false,nil
        outline._load_live_items(b,{chat_user_prefix='💬:'},{is_chat=true},function()completed=true end)
        vim.defer_fn(function()observed=completed end,2)
        assert.is_true(vim.wait(500,function()return observed~=nil end,1))
        vim.api.nvim_buf_delete(b,{force=true})
        assert.is_false(observed)
    end)
    it('cancels queued loading when an unloaded buffer remains valid',function()
        local b=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_buf_set_lines(b,0,-1,false,{'💬: q'})
        local doc=Document.attach(b,{schedule=false})
        local scheduled={};local original=vim.defer_fn
        vim.defer_fn=function(fn)
            scheduled[#scheduled+1]=fn
            return {is_closing=function()return false end,stop=function()end,close=function()end}
        end
        local completed=false
        local success,err=pcall(function()
            outline._load_live_items(b,{chat_user_prefix='💬:'},{is_chat=true},function()completed=true end)
            Document.repair_step(doc)
            assert.is_true(#scheduled>0)
            vim.api.nvim_buf_delete(b,{unload=true,force=true})
            assert.is_true(vim.api.nvim_buf_is_valid(b));assert.is_false(vim.api.nvim_buf_is_loaded(b))
            for _,fn in ipairs(scheduled) do fn() end
            assert.is_nil(Document.get(b));assert.is_false(completed)
        end)
        vim.defer_fn=original
        vim.api.nvim_buf_delete(b,{force=true})
        assert.is_true(success,err)
    end)
end)

describe("Outline navigation", function()
    local original_notify

    before_each(function()
        original_notify = vim.notify
        vim.notify = function() end
    end)

    after_each(function()
        vim.notify = original_notify
    end)

    it("jumps directly to the selected outline line", function()
        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(bufnr)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
            "# Heading",
            "",
            "💬: First question",
            "Plain text",
            "## Section",
        })

        settle(bufnr)
        local ok, jumped_lnum = outline._jump_to_outline_location({
            bufnr = bufnr,
            name = vim.api.nvim_buf_get_name(bufnr),
            windows = { vim.api.nvim_get_current_win() },
            lnum = 3,
        }, {
            chat_user_prefix = "💬:",
        })

        assert.is_true(ok)
        assert.equals(3, jumped_lnum)
        assert.same({ 3, 0 }, vim.api.nvim_win_get_cursor(0))
    end)

    it("falls back to the nearest outline item when the requested line is not one", function()
        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(bufnr)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
            "Some text",
            "",
            "💬: First question",
            "Plain text",
            "More text",
        })

        settle(bufnr)
        local ok, jumped_lnum = outline._jump_to_outline_location({
            bufnr = bufnr,
            name = vim.api.nvim_buf_get_name(bufnr),
            windows = { vim.api.nvim_get_current_win() },
            lnum = 4,
        }, {
            chat_user_prefix = "💬:",
        })

        assert.is_true(ok)
        assert.equals(3, jumped_lnum)
        assert.same({ 3, 0 }, vim.api.nvim_win_get_cursor(0))
    end)
end)

-- Drive the real tree builder and selection callback against on-disk chats.
describe("Outline branch destinations (#250)", function()
    local parley = require("parley")
    local picker = require("parley.float_picker")
    local tmp, original_open, original_notify, options, notices

    before_each(function()
        tmp = vim.fn.tempname()
        vim.fn.mkdir(tmp, "p")
        tmp = vim.uv.fs_realpath(tmp)
        parley.setup({ chat_dir = tmp, state_dir = tmp .. "/state", providers = {}, api_keys = {} })
        original_open, original_notify = picker.open, vim.notify
        notices = {}
        picker.open = function(opts) options = opts end
        vim.notify = function(msg) notices[#notices + 1] = msg end
    end)

    after_each(function()
        picker.open, vim.notify = original_open, original_notify
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_get_name(buf):find(tmp, 1, true) then
                vim.api.nvim_buf_delete(buf, { force = true })
            end
        end
        vim.fn.delete(tmp, "rf")
    end)

    local function filename(name)
        local ids = { parent = "00", child = "01", leaf = "02", missing = "03" }
        return "2026-09-14.10-00-" .. ids[name] .. ".000_" .. name .. ".md"
    end

    local function chat(name, body)
        local path = tmp .. "/" .. filename(name)
        body = (body or ""):gsub("([%a]+)%.md", filename)
        vim.fn.writefile({ "---", "topic: " .. name, "file: " .. vim.fn.fnamemodify(path, ":t"), "---", "💬: question", body }, path)
        return path
    end

    local function open_outline(path)
        vim.cmd("edit " .. vim.fn.fnameescape(path))
        outline.question_picker(parley.config)
    end

    local function branch_to(path)
        for _, item in ipairs(options.items) do
            if item.value.child_path == path then return item end
        end
        error("missing branch to " .. path)
    end

    for _, inline in ipairs({ false, true }) do
        it("opens an unloaded " .. (inline and "inline" or "standalone") .. " child at line 1", function()
            local child = chat("child")
            local ref = inline and "[🌿: child](child.md)" or "🌿: child.md: Child"
            open_outline(chat("parent", ref))
            options.on_select(branch_to(child))
            assert.equals(child, vim.api.nvim_buf_get_name(0))
            assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
        end)
    end

    it("opens a nested branch and retains question destinations", function()
        local leaf = chat("leaf")
        chat("child", "🌿: leaf.md: Leaf")
        open_outline(chat("parent", "🌿: child.md: Child"))
        options.on_select(branch_to(leaf))
        assert.equals(leaf, vim.api.nvim_buf_get_name(0))
        assert.same({ 1, 0 }, vim.api.nvim_win_get_cursor(0))
        for _, item in ipairs(options.items) do
            if item.value.file == leaf and item.type == "question" then
                settle(vim.api.nvim_get_current_buf())
                options.on_select(item)
                assert.same({ 5, 0 }, vim.api.nvim_win_get_cursor(0))
                return
            end
        end
        error("missing leaf question")
    end)

    it("preselects a preface's question and lands on its question line", function()
        local path = chat("parent")
        vim.fn.writefile({ "---", "topic: parent", "file: " .. filename("parent"), "---",
            "💬: first", "🤖: answer", "text", "@@label@@", "💬: original wording" }, path)
        vim.cmd("edit " .. vim.fn.fnameescape(path))
        vim.api.nvim_win_set_cursor(0, { 8, 0 })
        outline.question_picker(parley.config)
        local selected = options.items[options.initial_index]
        assert.equals("  label", selected.display)
        assert.equals(9, selected.value.lnum)
        settle(vim.api.nvim_get_current_buf())
        options.on_select(selected)
        assert.same({ 9, 0 }, vim.api.nvim_win_get_cursor(0))
    end)

    it("refuses a stale tree question instead of navigating to its neighbor", function()
        local path=chat("parent")
        open_outline(path)
        local chosen
        for _,item in ipairs(options.items) do
            if item.type=="question" then chosen=item;break end
        end
        assert.is_not_nil(chosen)
        local b=vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_lines(b,4,-1,false,{"plain", "💬: neighbor"})
        settle(b)
        vim.api.nvim_win_set_cursor(0,{1,0})
        options.on_select(chosen)
        assert.same({1,0},vim.api.nvim_win_get_cursor(0))
        assert.truthy(table.concat(notices,"\n"):find("Outline",1,true))
    end)

    it("binds a disk-derived selection to its original question text", function()
        open_outline(chat("parent"))
        local chosen
        for _,item in ipairs(options.items) do if item.type=="question" then chosen=item;break end end
        assert.is_not_nil(chosen)
        local b=vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_lines(b,4,5,false,{"💬: replacement question"});settle(b)
        vim.api.nvim_win_set_cursor(0,{1,0});options.on_select(chosen)
        assert.same({1,0},vim.api.nvim_win_get_cursor(0))
    end)
    it("binds a confirmed live tree selection to its relocating identity", function()
        local path=chat("parent")
        vim.cmd("edit "..vim.fn.fnameescape(path));settle(vim.api.nvim_get_current_buf())
        outline.question_picker(parley.config)
        local chosen
        for _,item in ipairs(options.items) do if item.type=="question" then chosen=item;break end end
        assert.is_not_nil(chosen)
        local b=vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_lines(b,4,4,false,{"new text"});settle(b)
        vim.api.nvim_win_set_cursor(0,{1,0});options.on_select(chosen)
        assert.same({6,0},vim.api.nvim_win_get_cursor(0))
    end)

    it("opens the root file entry at file start without claiming row semantics", function()
        open_outline(chat("parent"))
        local root_item=options.items[1]
        assert.is_true(root_item.value.file_start)
        vim.api.nvim_win_set_cursor(0,{5,0})
        options.on_select(root_item)
        assert.same({1,0},vim.api.nvim_win_get_cursor(0))
    end)

    it("reports a missing child without opening an empty file", function()
        local parent = chat("parent", "🌿: missing.md: Missing")
        open_outline(parent)
        options.on_select(branch_to(tmp .. "/" .. filename("missing")))
        assert.equals(parent, vim.api.nvim_buf_get_name(0))
        assert.equals(-1, vim.fn.bufnr(tmp .. "/" .. filename("missing")))
        assert.truthy(table.concat(notices, "\n"):find("missing.md", 1, true))
    end)
end)
