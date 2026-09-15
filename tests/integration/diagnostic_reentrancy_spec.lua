local D=require('parley.document')
local R=require('parley.diagnostic_refresh')
local T=require('parley.timezone_diagnostics')
local F=require('parley.skill_render')
local buffers,groups={},{}
local function fixture()
    local buf=vim.api.nvim_create_buf(false,true);buffers[#buffers+1]=buf
    vim.api.nvim_buf_set_lines(buf,0,-1,false,{'time 2026-07-12T12:00:00Z and term[^term]','','[^term]: Definition.'})
    local doc=D.attach(buf,{schedule=false});D.drain(doc)
    R.refresh(buf,{schedule=false})
    for _=1,100 do if R.step(buf).status=='publish' then return buf,doc end end
    error('publication not reached')
end
local function on_publication(buf,n,callback)
    local id=vim.api.nvim_create_augroup('ParleyDiagnosticReentrant'..buf,{clear=true});groups[#groups+1]=id
    local count=0
    vim.api.nvim_create_autocmd('DiagnosticChanged',{group=id,buffer=buf,callback=function()
        count=count+1
        if count==n then callback() end
    end})
end
local function count(buf,ns)return #vim.diagnostic.get(buf,{namespace=ns})end
describe('diagnostic effect publication ownership',function()
    after_each(function()
        for _,id in ipairs(groups)do pcall(vim.api.nvim_del_augroup_by_id,id)end
        for _,buf in ipairs(buffers)do if vim.api.nvim_buf_is_valid(buf)then vim.api.nvim_buf_delete(buf,{force=true})end end
        buffers,groups={},{}
    end)
    for _,index in ipairs({1,2})do
        it('preserves source invalidation during diagnostic effect '..index,function()
            local buf=fixture();local fired=false
            on_publication(buf,index,function()
                fired=true;vim.api.nvim_buf_set_lines(buf,0,-1,false,{'removed'})
            end)
            R.step(buf);assert.is_true(fired)
            assert.equals('idle',R.drain(buf,1000).status)
            assert.equals(0,count(buf,T.diag_namespace()))
            assert.equals(0,count(buf,F.diag_namespace()))
        end)
        it('retires detached publication before further effects '..index,function()
            local buf,doc=fixture()
            on_publication(buf,index,function()D.detach(doc)end)
            R.step(buf)
            assert.equals('detached',R.step(buf).status)
            assert.equals(0,count(buf,T.diag_namespace()))
            assert.equals(0,count(buf,F.diag_namespace()))
        end)
    end
    it('does not resume the same publisher from a synchronous diagnostic callback',function()
        local buf=fixture();local nested
        on_publication(buf,1,function()nested=R.step(buf)end)
        assert.equals('idle',R.step(buf).status)
        assert.equals('busy',nested.status)
        assert.equals(1,count(buf,T.diag_namespace()))
        assert.equals(1,count(buf,F.diag_namespace()))
    end)
    it('preserves a replacement refresh started during retirement',function()
        local buf=fixture();R.step(buf)
        on_publication(buf,1,function()
            R.refresh(buf,{schedule=false});assert.equals('idle',R.drain(buf,1000).status)
        end)
        R.clear(buf)
        assert.equals(1,count(buf,T.diag_namespace()))
        assert.equals(1,count(buf,F.diag_namespace()))
    end)
    it('fences a publisher when native reload replaces its buffer lifetime',function()
        local path=vim.fn.tempname()
        vim.fn.writefile({'time 2026-07-12T12:00:00Z'},path)
        local buf=vim.fn.bufadd(path);vim.fn.bufload(buf);buffers[#buffers+1]=buf
        local doc=D.attach(buf,{schedule=false});D.drain(doc);R.refresh(buf,{schedule=false})
        for _=1,100 do if R.step(buf).status=='publish'then break end end
        on_publication(buf,1,function()
            vim.fn.writefile({'reloaded without timestamp'},path)
            vim.api.nvim_buf_call(buf,function()vim.cmd('edit!')end)
        end)
        R.step(buf)
        assert.equals('reloaded without timestamp',vim.api.nvim_buf_get_lines(buf,0,1,false)[1])
        R.refresh(buf,{schedule=false});assert.equals('idle',R.drain(buf,1000).status)
        assert.equals(0,count(buf,T.diag_namespace()))
        vim.fn.delete(path)
    end)
    it('preserves invalidation when an injected reader changes source then throws',function()
        local buf=fixture();R.clear(buf)
        local reader=require('parley.line_reader').for_buffer(buf);local fired=false
        R.refresh(buf,{schedule=false,reader={chunk=function(_,request)
            if not fired then
                fired=true;vim.api.nvim_buf_set_lines(buf,0,-1,false,{'removed'})
                error('obsolete reader')
            end
            return reader:chunk(request)
        end}})
        assert.equals('idle',R.drain(buf,1000).status)
        assert.is_true(fired);assert.equals(0,count(buf,T.diag_namespace()))
    end)
    it('does not overwrite invalidation from a converter callback',function()
        local buf=fixture();R.clear(buf);local fired=false
        R.refresh(buf,{schedule=false,to_local=function(epoch)
            if not fired then
                fired=true;vim.api.nvim_buf_set_lines(buf,0,-1,false,{'removed'})
                assert.equals('busy',R.step(buf).status)
                error('obsolete converter')
            end
            return os.date('*t',epoch)
        end})
        assert.equals('idle',R.drain(buf,1000).status)
        assert.is_true(fired);assert.equals(0,count(buf,T.diag_namespace()))
    end)

end)
