local collaboration=require('parley.skills.review.collaboration')
local review=require('parley.skills.review')
local function lines(text)
    local out={};for line in (text..'\n'):gmatch('(.-)\n')do out[#out+1]=line end;return out
end
local function markers(text)return review.parse_markers(lines(text))end
local function classify(text,kind)
    local out={};for _,m in ipairs(markers(text))do if m.ready then out[#out+1]={line=m.line,col=m.col,raw=m.raw,kind=kind or 'command'}end end
    return {review_asks=out}
end

describe('collaborative local admission',function()
    it('notices retired or malformed metadata without refusing a round',function()
        for _,value in ipairs({'unknown','','{chat: [Missing]}'})do
            local plan,err=collaboration.resolve({'---','collaboration-mode: '..value,'---','🤖[tighten this]'})
            assert.is_nil(err)
            assert.is_table(plan)
            assert.is_true(#plan.warnings>0)
        end
    end)

    it('keeps ready robot asks inside chat eligible while items remain operator-owned',function()
        local text='@@chat@@\n## Inbox\n1. Operator item\n\n🤖[tighten the introduction]'
        local plan=assert(collaboration.resolve(lines(text)))
        assert.equals(1,#collaboration.eligible(plan,markers(text)))
        local err=collaboration.validate_edits(text,{{old_string='Operator item',new_string='Changed',explain='bad'}},classify(text))
        assert.is_string(err)
        assert.is_nil(collaboration.validate_edits(text,{{old_string='🤖[tighten the introduction]',new_string='Done.',explain='ok'}},classify(text)))
    end)

    it('protects tag and heading attachment before any command edit',function()
        local text='@@chat@@\n## Inbox\n\n🤖[tighten this]'
        for _,old in ipairs({'@@chat@@','## Inbox'})do
            assert.is_string(collaboration.validate_edits(text,{{old_string=old,new_string='changed',explain='bad'}},classify(text)))
        end
    end)

    it('keeps chat heading and item boundaries attached across adjacent edits',function()
        local cases={
            {text='🤖[tighten]\n@@chat@@\n## Inbox\n1. Operator item',old='🤖[tighten]\n'},
            {text='---\ncollaboration-mode: {chat: [Inbox]}\n---\n🤖[tighten]\n## Inbox\n- Operator item',old='🤖[tighten]\n'},
            {text='@@chat@@\n## Inbox\n🤖[tighten]\n1. Operator item',old='🤖[tighten]\n'},
            {text='---\ncollaboration-mode: {chat: [Inbox]}\n---\n## Inbox\n- Operator item\n🤖[tighten]',old='## Inbox'},
        }
        for _,case in ipairs(cases)do
            assert.is_string(collaboration.validate_edits(case.text,{{old_string=case.old,new_string='Changed',explain='bad'}},classify(case.text)))
        end
    end)

    it('preserves a declared question and validates a command batch',function()
        local text='🤖[why?]\n🤖[tighten this]'
        local input=classify(text);input.review_asks[1].kind='question'
        local err,summary=collaboration.validate_edits(text,{{old_string='🤖[tighten this]',new_string='Tight.',explain='ok'}},input)
        assert.is_nil(err)
        assert.equals(1,summary.deferred)
        assert.equals('🤖[why?]\nTight.',summary.content)
    end)

    it('does not infer authority from missing classifications',function()
        assert.is_string(collaboration.validate_edits('🤖[why?]',{{old_string='🤖[why?]',new_string='Answer',explain='bad'}},{}))
    end)
    it('shares one typed tag projection between a chat parse and its section operation',function()
        local structure=require('parley.skills.review.chat_structure')
        local saved=structure.snapshot
        local calls=0
        structure.snapshot=function(input)calls=calls+1;return saved(input)end
        local text={'topic: tags','---','@@chat@@','## Inbox','body'}
        local config=require('parley').config
        local ok,err=pcall(function()
            local parsed=require('parley.chat_parser').parse_chat(text,2,config)
            require('parley.entity_range').range(parsed,text,4,{config=config})
        end)
        structure.snapshot=saved
        assert.is_true(ok,err)
        assert.equals(1,calls)
    end)

    it('does not open a valid chat tag as a file reference',function()
        local buf=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_buf_set_name(buf,vim.fn.tempname()..'.md')
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'@@chat@@','## Inbox','body'})
        local saved=vim.api.nvim_get_current_buf()
        vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_win_set_cursor(0,{1,0})
        local opened=false
        local ok,result=pcall(require('parley')._open_reference_under_cursor,buf,'@@chat@@',0,false,
            function()opened=true;return true end)
        vim.api.nvim_set_current_buf(saved)
        vim.api.nvim_buf_delete(buf,{force=true})
        assert.is_true(ok,result)
        assert.equals('none',result)
        assert.is_false(opened)
    end)

end)

describe('closed unreadable metadata ownership', function()
    it('preserves closed legacy bytes and excludes enclosed asks while allowing body commands', function()
        for _, header in ipairs({
            {'---','...','presentation: inline','notes: 🤖[literal metadata]','---'},
            {' --- ','presentation: inline','notes: 🤖[literal metadata]','---'},
            {'---\r','presentation: inline\r','notes: 🤖[literal metadata]\r','---\r'},
        }) do
            local document={}
            for _,line in ipairs(header)do document[#document+1]=line end
            document[#document+1]='🤖[tighten this]'
            local text=table.concat(document,'\n')
            local plan=assert(collaboration.resolve(document))
            local eligible=collaboration.eligible(plan,markers(text))
            assert.equals(1,#eligible)
            assert.equals(#header,eligible[1].line)
            local input={review_asks={{line=#header,col=0,raw='🤖[tighten this]',kind='command'}}}
            assert.is_string(collaboration.validate_edits(text,{{old_string='presentation: inline',new_string='changed',explain='bad'}},input))
            assert.is_nil(collaboration.validate_edits(text,{{old_string='🤖[tighten this]',new_string='Done.',explain='ok'}},input))
        end
    end)
end)

describe('literal eligibility work', function()
    it('bounds lookup growth for real fenced blocks followed by ready asks', function()
        local function work(count)
            local document,asks={},{}
            for _=1,count do
                for _,line in ipairs({'```','literal','```',''})do document[#document+1]=line end
            end
            for _=1,count do
                asks[#asks+1]={line=#document,col=0,raw='🤖[tighten]',ready=true}
                document[#document+1]='🤖[tighten]'
            end
            local plan=assert(collaboration.resolve(document))
            local running=jit.status()
            jit.off();jit.flush()
            local ticks=0
            debug.sethook(function()ticks=ticks+1 end,'',1)
            local ok,eligible=pcall(collaboration.eligible,plan,asks)
            debug.sethook()
            if running then jit.on()end
            assert.is_true(ok)
            assert.equals(count,#eligible)
            return ticks
        end
        local small,large=work(64),work(128)
        assert.is_true(large<small*2.5+100,('eligibility VM work grew from %d to %d'):format(small,large))
    end)
    it('excludes markers whose bytes cross a code literal boundary', function()
        local document={'`literal` tail','ordinary'}
        local plan=assert(collaboration.resolve(document))
        assert.same({},collaboration.eligible(plan,{{line=0,col=4,raw='ral` tail',ready=true}}))
        assert.equals(1,#collaboration.eligible(plan,{{line=1,col=0,raw='ordinary',ready=true}}))
    end)
end)
