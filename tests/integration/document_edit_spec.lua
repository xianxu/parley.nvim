describe('document editor', function()
    local E, buf, events, editor
    before_each(function()
        E = require('parley.document.editor')
        buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {'α', 'tail'})
        events = {}
        editor = E.new(buf, {epoch=7, on_event=function(event) events[#events+1]=event end})
        editor:attach()
    end)
    after_each(function() if buf and vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf,{force=true}) end end)
    it('normalizes UTF8 and canonical empty buffer bytes', function()
        vim.api.nvim_buf_set_text(buf,0,0,0,2,{'β','x'})
        assert.equals(0,events[1].first)
        assert.equals(2,events[1].last)
        assert.equals(4,events[1].new_bytes)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{})
        local e=events[2]
        assert.equals(1,e.new_bytes)
        assert.equals(1,e.new_total)
        assert.equals(1,e.new_rows)
    end)
    it('matches exact receipts and validates before and after each patch',function()
        local calls=0
        local result=editor:apply({epoch=7,generation='op',grant='g',entity='b',patches={
            {start={row=0,col=0,byte=0},finish={row=0,col=2,byte=2},expected_old='α',text='β'},
        }},function() calls=calls+1; return true end)
        assert.equals('applied',result.status)
        assert.equals(2,calls)
        assert.equals('g',events[1].owner.grant)
        assert.equals(1,#result.receipts)
    end)
    it('keeps partial receipts and validates callbacks even when native mutation throws',function()
        local fake=require('tests.helpers.fake_document_editor').new({'α','tail'})
        local ed=E.new(-100,{epoch=7,driver=fake.driver,on_event=function() end});ed:attach()
        fake.mutate_then_error=true
        local calls=0
        local result=ed:apply({epoch=7,generation='op',operation='write',grant='g',entity='b',patches={
            {start={row=0,col=0,byte=0},finish={row=0,col=2,byte=2},expected_old='α',text='β'},
        }},function() calls=calls+1;return true end)
        assert.equals('error',result.status)
        assert.equals(2,calls)
        assert.equals(1,#result.receipts)
        assert.equals('write',result.receipts[1].owner.operation)
        assert.equals('β',fake.lines[1]);ed:detach()
    end)
    it('stops after nested unexpected edits and preserves both receipts',function()
        local fake=require('tests.helpers.fake_document_editor').new({'α','tail'})
        local ed=E.new(-101,{epoch=7,driver=fake.driver,on_event=function() end});ed:attach()
        fake.after_delivery=function(f) f:edit(1,0,1,0,{'human'}) end
        local calls=0
        local patch={start={row=0,col=0,byte=0},finish={row=0,col=2,byte=2},expected_old='α',text='β'}
        local result=ed:apply({epoch=7,grant='g',patches={patch,patch}},function() calls=calls+1;return true end)
        assert.equals('interrupted',result.status)
        assert.equals(3,calls)
        assert.equals(2,#result.receipts)
        assert.is_nil(result.receipts[2].owner);ed:detach()
    end)
    it('matches the stateful fake against native UTF8 multiline callback descriptors',function()
        local fake=require('tests.helpers.fake_document_editor').new({'α','tail'})
        local observed={}
        local ed=E.new(-102,{epoch=7,driver=fake.driver,on_event=function(e) observed[#observed+1]=e end});ed:attach()
        local edits={{0,0,0,2,{'β','abc'}},{1,1,2,2,{'x'}},{0,0,1,0,{''}}}
        for _,args in ipairs(edits) do
            fake:edit(unpack(args));vim.api.nvim_buf_set_text(buf,unpack(args))
            local a,b=vim.deepcopy(observed[#observed]),vim.deepcopy(events[#events])
            a.tick=nil;b.tick=nil
            assert.same(b,a)
            assert.same(vim.api.nvim_buf_get_lines(buf,0,-1,false),fake.lines)
        end
        fake:set_lines(0,-1,{})
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{})
        local a,b=vim.deepcopy(observed[#observed]),vim.deepcopy(events[#events])
        a.tick=nil;b.tick=nil;assert.same(b,a)
        ed:detach()
    end)
    it('treats undo and redo as unowned edits',function()
        vim.api.nvim_set_current_buf(buf)
        vim.cmd('let &undolevels = &undolevels')
        vim.api.nvim_buf_set_text(buf,0,0,0,2,{'beta'})
        vim.cmd('undo')
        vim.cmd('redo')
        local edits=0
        for _,event in ipairs(events) do
            if event.kind=='edit' then edits=edits+1;assert.is_nil(event.owner) end
        end
        assert.equals(3,edits)
        assert.equals('beta',vim.api.nvim_buf_get_lines(buf,0,1,false)[1])
    end)
    it('rejects stale payloads, oversize patches and callback writes without mutation',function()
        local patch={start={row=0,col=0,byte=0},finish={row=0,col=2,byte=2},expected_old='xx',text='β'}
        assert.equals('stale',editor:apply({epoch=7,patches={patch}},function() return true end).status)
        patch.text=string.rep('x',65537)
        assert.equals('chunkneeded',editor:apply({epoch=7,patches={patch}},function() return true end).status)
        editor.on_event=function()
            assert.equals('busy',editor:apply({epoch=7,patches={}},function() return true end).status)
        end
        vim.api.nvim_buf_set_text(buf,0,0,0,2,{'β'})
    end)
    it('separates lifecycle callbacks and rejects old epochs after reload',function()
        local fake=require('tests.helpers.fake_document_editor').new({'old'})
        local seen={}
        local ed
        ed=E.new(-103,{epoch=7,driver=fake.driver,on_event=function(e)
            seen[#seen+1]=e
            if e.kind=='reload' then ed:set_epoch(8) end
        end});ed:attach()
        fake:changedtick();fake:reload({'new'});fake:edit(0,0,0,0,{'x'});ed:detach()
        assert.equals('tick',seen[1].kind)
        assert.equals('reload',seen[2].kind)
        assert.equals(8,seen[3].epoch)
        assert.equals('detach',seen[4].kind)
        assert.equals('stale',ed:apply({epoch=7,patches={}},function() return true end).status)
    end)
    it('keeps fail-before-delivery separate from mutation receipts and bounds reader chunks',function()
        local fake=require('tests.helpers.fake_document_editor').new({string.rep('x',100000)})
        local ed=E.new(-104,{epoch=7,driver=fake.driver,on_event=function() end});ed:attach()
        local chunk=ed:chunk({request_id=1,row=0,col=0,max_bytes=65536})
        assert.equals(65536,#chunk.bytes);assert.is_false(chunk.eol)
        fake.fail_before=true
        local result=ed:apply({epoch=7,patches={{start={row=0,col=0,byte=0},finish={row=0,col=0,byte=0},
            expected_old='',text='new'}}},function() return true end)
        assert.equals('error',result.status);assert.equals(0,#result.receipts)
        assert.equals(100000,#fake.lines[1]);ed:detach()
    end)
    it('tracks logical intermediate row totals during a grouped native undo',function()
        vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'q','a','answer','next','draft'})
        vim.cmd('let &undolevels = &undolevels')
        vim.api.nvim_buf_set_text(buf,4,2,4,2,{'',''})
        vim.api.nvim_buf_set_text(buf,4,2,5,0,{''})
        events={}
        vim.cmd('undo')
        local edits={}
        for _,event in ipairs(events) do if event.kind=='edit' then edits[#edits+1]=event end end
        assert.equals(2,#edits)
        assert.equals(6,edits[1].new_rows)
        assert.equals(6,edits[2].old_rows)
        assert.equals(5,edits[2].new_rows)
    end)
    local function append_owned(ed,buffer,generation,grant,text)
        local line=vim.api.nvim_buf_get_lines(buffer,0,1,false)[1]
        local at=#line
        local plan={epoch=7,generation=generation,operation='chunk',grant=grant,entity='answer',patches={
            {start={row=0,col=at,byte=at},finish={row=0,col=at,byte=at},expected_old='',text=text},
        }}
        local result=ed:apply(plan,function() return true end)
        assert.equals('applied',result.status,result.error)
        return plan
    end
    local function first_line() return vim.api.nvim_buf_get_lines(buf,0,1,false)[1] end
    it('joins only successive chunks from the same live writer receipt',function()
        vim.api.nvim_set_current_buf(buf)
        assert.is_false(editor:can_join_undo({epoch=7,generation='a',grant='g'}))
        local plan=append_owned(editor,buf,'a','g','one')
        assert.is_true(editor:can_join_undo(plan))
        append_owned(editor,buf,'a','g','two')
        vim.cmd('undo')
        assert.equals('α',first_line())
        assert.is_false(editor:can_join_undo(plan))
        vim.cmd('redo')
        assert.equals('αonetwo',first_line())
        assert.is_false(editor:can_join_undo(plan))
    end)
    it('keeps human edits and interleaved writers in separate undo blocks in one Lua call',function()
        vim.api.nvim_set_current_buf(buf)
        local plan=append_owned(editor,buf,'a','g','A')
        vim.api.nvim_buf_set_text(buf,0,3,0,3,{'H'})
        assert.is_false(editor:can_join_undo(plan))
        append_owned(editor,buf,'a','g','B')
        assert.is_false(editor:can_join_undo({epoch=7,generation='b',grant='h'}))
        append_owned(editor,buf,'b','h','C')
        vim.cmd('undo');assert.equals('αAHB',first_line())
        vim.cmd('undo');assert.equals('αAH',first_line())
        vim.cmd('undo');assert.equals('αA',first_line())
        vim.cmd('undo');assert.equals('α',first_line())
    end)
    it('preserves local and global undolevels and existing history',function()
        vim.api.nvim_set_current_buf(buf)
        local global=vim.go.undolevels
        vim.bo[buf].undolevels=77
        vim.api.nvim_buf_set_text(buf,0,2,0,2,{'human'})
        append_owned(editor,buf,'a','g','generated')
        assert.equals(global,vim.go.undolevels)
        assert.equals(77,vim.bo[buf].undolevels)
        vim.cmd('undo');assert.equals('αhuman',first_line())
        vim.cmd('undo');assert.equals('α',first_line())
    end)
    it('invalidates undo receipt on epoch changes and unsuccessful partial operations',function()
        vim.api.nvim_set_current_buf(buf)
        local plan=append_owned(editor,buf,'a','g','A')
        editor:set_epoch(8)
        assert.is_false(editor:can_join_undo(plan))
        editor:set_epoch(7)
        assert.is_false(editor:can_join_undo(plan))
        local line=first_line()
        local result=editor:apply({epoch=7,generation='a',grant='g',patches={
            {start={row=0,col=#line,byte=#line},finish={row=0,col=#line,byte=#line},expected_old='',text='B'},
            {start={row=0,col=0,byte=0},finish={row=0,col=1,byte=1},expected_old='!',text='C'},
        }},function() return true end)
        assert.equals('stale',result.status)
        assert.equals(1,#result.receipts)
        assert.is_false(editor:can_join_undo(plan))
    end)
end)
