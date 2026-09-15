local D=require('parley.document')
describe('scoped header authority',function()
    local buf,doc,region,generation,grant
    before_each(function()
        buf=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'# topic: ?','- model: test','---','','💬: question','🤖: answer','text','','💬: next'})
        doc=D.attach(buf,{schedule=false})
        assert.equals('idle',D.drain(doc,10000).status)
        region=D.query(doc,0,1)[1]
        generation=D.transition(doc,{kind='register_generation'}).generation
    end)
    after_each(function()if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf,{force=true}) end end)
    local function acquire(first,last)
        local result=D.transition(doc,{kind='acquire',generation=generation,regions={{entity=region.handle,
            marker_revision=1,revision=1,confirmed=true,first=first or region.start_byte,last=last or region.end_byte-1}}})
        grant=result.grants and result.grants[1]
        return result
    end
    it('acquires a topic row independently of answer and question edits',function()
        assert.is_true(acquire().ok)
        local column=#'💬: next'
        vim.api.nvim_buf_set_text(buf,8,column,8,column,{' draft'})
        assert.equals('valid',D.snapshot(doc).grants[grant].status)
        local g=D.snapshot(doc).grants[grant]
        local old=vim.api.nvim_buf_get_lines(buf,0,1,false)[1]
        local result=D.apply(doc,{epoch=D.snapshot(doc).epoch,generation=generation,grant=grant,
            entity=region.handle,revision=g.revision,operation='topic',patches={{
                start={row=0,col=0,byte=0},finish={row=0,col=#old,byte=#old},
                expected_old=old,text='# topic: new'}}})
        assert.equals('applied',result.status)
        assert.equals('# topic: new',vim.api.nvim_buf_get_lines(buf,0,1,false)[1])
        assert.equals('💬: next draft',vim.api.nvim_buf_get_lines(buf,8,9,false)[1])
    end)
    it('refuses header authority crossing into another row',function()
        assert.is_false(acquire(0,region.end_byte+1).ok)
    end)
    it('revokes the topic writer on human replacement even when old bytes return',function()
        assert.is_true(acquire().ok)
        vim.api.nvim_buf_set_lines(buf,0,1,false,{'# topic: ?'})
        local current=D.snapshot(doc).grants[grant]
        assert.is_true(current==nil or current.status=='revoked')
    end)
end)
