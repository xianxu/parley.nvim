local User=require('parley.document.user_edits')
local State=require('parley.document.state')
local Fake=require('tests.helpers.fake_document_editor')
local function fixture()
    local f=Fake.new({'prefix','protected note','tail'})
    local editor={buf=1,epoch=1,driver=f.driver}
    local structure={};local authority=State.new({epoch=1})
    local gen=State.transition(authority,{kind='register_generation'}).generation
    local proof={entity='q',first=7,last=7,revision=1,marker_revision=1,confirmed=true}
    local grant=State.transition(authority,{kind='acquire',generation=gen,regions={proof}}).grants[1]
    local witness=assert(State.successor_new(authority,{epoch=1,generation=gen,grant=grant,entity='q',revision=1},proof))
    local intent={operation='replacement',regions={{first={row=1,col=0},last={row=1,col=0}}}}
    return structure,editor,authority,witness,intent
end
local function edit(editor,first,last,bytes,oldrow,oldcol,newrow,newcol)
    User.observe(editor,{first=first,last=last,new_bytes=bytes,
        old_end={row=oldrow,col=oldcol},new_end={row=newrow,col=newcol}})
end
describe('private successor source guards',function()
    it('captures an exact point only through a live finite successor',function()
        assert.is_function(User.capture_successor)
        local s,e,a,w,i=fixture()
        assert.is_nil(User.capture_successor(s,e,1,i,a,{}))
        local token=assert(User.capture_successor(s,e,1,i,a,w))
        edit(e,12,12,3,1,5,1,8)
        assert.is_table(User.resolve(s,e,1,token))
        State.successor_cancel(a,w)
        assert.is_nil(User.capture_successor(s,e,1,i,a,w))
    end)
    it('relocates strict preceding edits and permanently expires all point contact',function()
        assert.is_function(User.capture_successor)
        for _,event in ipairs({{7,7,1,1,0,1,1},{6,7,0,1,0,0,6},{6,8,0,1,1,0,6},{7,8,1,1,1,1,1}})do
            local s,e,a,w,i=fixture();local token=assert(User.capture_successor(s,e,1,i,a,w))
            edit(e,unpack(event));assert.is_nil(User.resolve(s,e,1,token))
            edit(e,0,0,0,0,0,0,0);assert.is_nil(User.resolve(s,e,1,token))
        end
        local s,e,a,w,i=fixture();local token=assert(User.capture_successor(s,e,1,i,a,w))
        edit(e,0,0,2,0,0,1,0)
        local resolved=assert(User.resolve(s,e,1,token))
        assert.equals(9,resolved.regions[1].first.byte);assert.equals(2,resolved.regions[1].first.row)
    end)
    it('does not let user intent flags weaken ordinary empty selections',function()
        local s,e,_,_,i=fixture();i.successor=true;i.exact_point=true
        local token=assert(User.capture(s,e,1,i))
        edit(e,12,12,1,1,5,1,6)
        assert.is_nil(User.resolve(s,e,1,token))
    end)
end)
