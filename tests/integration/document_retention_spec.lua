local Document=require('parley.document')
local Folds=require('parley.tool_folds')
local Highlighter=require('parley.highlighter')
local Diagnostics=require('parley.diagnostic_refresh')
local Outline=require('parley.outline')
local config=require('parley.config')
Highlighter.setup({config=config})
local function collect()
    vim.wait(10,function()return false end,1)
    collectgarbage('collect');collectgarbage('collect');collectgarbage('collect')
end
local function populate(weak,folds)
    for i=1,50 do
        local buf=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: question','body'})
        local doc=Document.attach(buf,{schedule=false})
        weak[i]=doc
        if folds then Folds.setup(buf) end
        vim.api.nvim_buf_delete(buf,{force=true})
    end
end
describe('document lifetime ownership',function()
    it('collects all native detached documents after their last external reference leaves',function()
        local weak=setmetatable({},{__mode='v'})
        populate(weak,false);collect()
        local retained=0;for _ in pairs(weak) do retained=retained+1 end
        assert.equals(0,retained)
    end)
    it('releases all production consumers and queued callbacks together after native deletion',function()
        local weak=setmetatable({},{__mode='v'})
        local completed=0
        local function attach_consumers()
            for i=1,50 do
                local buf=vim.api.nvim_create_buf(false,true)
                vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: question','🤖: answer','UTC: 2026-01-01','[^a]: note'})
                local doc=Highlighter.rebuild_structure(buf)
                weak[i]=doc
                Folds.setup(buf);Diagnostics.refresh(buf)
                Outline._load_live_items(buf,config,{is_chat=true},function()completed=completed+1 end)
                -- Queue a real repair publication and renderer redraw; deletion
                -- must retire those callbacks before they can revisit the doc.
                assert.equals('idle',Document.drain(doc,1000).status)
                Diagnostics.step(buf)
                vim.api.nvim_buf_delete(buf,{force=true})
                assert.equals('detached',Diagnostics.step(buf).status)
            end
        end
        attach_consumers();collect()
        local retained=0;for _ in pairs(weak) do retained=retained+1 end
        assert.equals(0,retained);assert.equals(0,completed)
    end)
    it('retires consumers after native reload and keeps a held detached document readable',function()
        local path=vim.fn.tempname()
        vim.fn.writefile({'💬: old','🤖: old'},path)
        local buf=vim.fn.bufadd(path);vim.fn.bufload(buf)
        local doc=Highlighter.rebuild_structure(buf)
        Folds.setup(buf);Diagnostics.refresh(buf)
        Outline._load_live_items(buf,config,{is_chat=true},function()end)
        vim.fn.writefile({'💬: replacement','🤖: replacement'},path)
        vim.api.nvim_buf_call(buf,function()vim.cmd('edit!')end)
        assert.equals('💬: replacement',vim.api.nvim_buf_get_lines(buf,0,1,false)[1])
        -- Neovim may retire Lua buffer listeners during :edit! rather than
        -- emit on_reload. Both routes must leave the retired facade usable.
        if not Document.get(buf) then
            assert.same({},Document.query(doc,0,1))
            Highlighter.rebuild_structure(buf);Folds.setup(buf);Diagnostics.refresh(buf)
        else assert.equals(doc,Document.get(buf)) end
        vim.api.nvim_buf_delete(buf,{force=true});vim.fn.delete(path);collect()
        assert.same({},Document.query(doc,0,1))
        assert.equals('detached',Diagnostics.step(buf).status)
        local ok,commands=pcall(vim.api.nvim_get_autocmds,{group='ParleyToolFolds'..buf})
        assert.is_true(not ok or #commands==0)
    end)
    it('preserves the detached query contract while the caller retains its document',function()
        local buf=vim.api.nvim_create_buf(false,true)
        local doc=Document.attach(buf,{schedule=false})
        vim.api.nvim_buf_delete(buf,{force=true});collect()
        assert.same({rows=0,bytes=0},Document.size(doc))
        assert.same({},Document.query(doc,0,1))
        assert.equals('detached',Document.exchange(doc,0).status)
        assert.is_table(Document.snapshot(doc))
        assert.is_nil(Document.get(buf))
    end)
    it('deletes buffer-owned fold autocmd groups and releases their document closures',function()
        local buf=vim.api.nvim_create_buf(false,true)
        Folds.setup(buf)
        local name='ParleyToolFolds'..buf
        assert.is_true(#vim.api.nvim_get_autocmds({group=name})>0)
        vim.api.nvim_buf_delete(buf,{force=true})
        local ok,commands=pcall(vim.api.nvim_get_autocmds,{group=name})
        assert.is_true(not ok or #commands==0)
        local weak=setmetatable({},{__mode='v'})
        populate(weak,true);collect()
        local retained=0;for _ in pairs(weak) do retained=retained+1 end
        assert.equals(0,retained)
    end)
end)
