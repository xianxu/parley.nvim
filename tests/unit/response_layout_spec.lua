local Layout=require('parley.response_layout')
local config={chat_branch_prefix='🌿:',chat_local_prefix='🔒:'}
local function prepare(lines,extra)
    return Layout.prepare(vim.tbl_extend('force',{lines=lines,first_row=7,first_byte=100,
        header_lines={'🤖: agent'}},extra or {}),config)
end
local function serialized(lines) return #lines>0 and table.concat(lines,'\n')..'\n' or '' end
-- Byte provenance, not a text-search oracle: equal copies cannot substitute for
-- the original annotation bytes at any intermediate cancellation point.
local function apply_with_provenance(lines,layout)
    local source=serialized(lines);local bytes={}
    for i=1,#source do bytes[i]={text=source:sub(i,i),origin=i-1} end
    local required={}
    for _,span in ipairs(layout.protected) do
        for i=span.first_offset,span.end_offset-1 do required[i]=true end
    end
    local function verify()
        local surviving={};for _,b in ipairs(bytes) do if b.origin then surviving[b.origin]=true end end
        for id in pairs(required) do assert.is_true(surviving[id],'original annotation byte deleted') end
    end
    for n=#layout.gaps,1,-1 do
        local gap=layout.gaps[n]
        -- Cancel after ANY destructive byte, including halfway through a
        -- finite replacement's deletion phase, then resume the same oracle.
        for _=gap.first_offset+1,gap.end_offset do table.remove(bytes,gap.first_offset+1);verify() end
        for i=#gap.text,1,-1 do table.insert(bytes,gap.first_offset+1,{text=gap.text:sub(i,i)});verify() end
    end
    local out={};for _,b in ipairs(bytes) do out[#out+1]=b.text end
    return table.concat(out)
end

describe('response replacement layout',function()
    it('excludes every annotation byte from every destructive gap',function()
        local lines={'','🤖: old','generated','🌿: child.md: child','old prose',
            'before [🌿: λ](one.md) and [🌿: two](two.md) after','🔒: personal','tail'}
        local result=prepare(lines)
        assert.equals(4,#result.protected)
        assert.equals('\n🤖: agent\n\n🌿: child.md: child\n[🌿: λ](one.md)\n[🌿: two](two.md)\n🔒: personal\n',
            apply_with_provenance(lines,result))
        for _,gap in ipairs(result.gaps) do
            for _,keep in ipairs(result.protected) do
                assert.is_true(gap.end_offset<=keep.first_offset or gap.first_offset>=keep.end_offset)
            end
        end
    end)
    it('freezes source coordinates, stream insertion and untouched composer suffix',function()
        local lines={'','🤖: old','answer'};local result=prepare(lines)
        assert.same({first_row=7,last_row=10,first_byte=100,last_byte=100+#serialized(lines)},result.target)
        assert.same({row=10,col=0,byte=100+#serialized(lines)},result.suffix)
        assert.same({row=7,col=0,byte=100},result.gaps[1].first)
        assert.same(result.suffix,result.gaps[1].last)
        assert.equals(#result.shell.text-1,result.shell.stream_offset)
        assert.equals('\n🤖: agent\n\n',apply_with_provenance(lines,result))
        lines[1]='changed';assert.equals(7,result.target.first_row)
    end)
    it('inserts before a leading survivor and distinguishes identical links by origin',function()
        local lines={'🔒: keep','[🌿: same](x.md)[🌿: same](x.md)'}
        local result=prepare(lines)
        assert.equals(0,result.gaps[1].first_offset);assert.equals(0,result.gaps[1].end_offset)
        assert.equals(3,#result.protected)
        assert.equals('\n🤖: agent\n\n🔒: keep\n[🌿: same](x.md)\n[🌿: same](x.md)\n',
            apply_with_provenance(lines,result))
    end)
    it('uses canonical configured annotation recognition and preserves exact inline syntax',function()
        local lines={'BR: child.md: child','PRIVATE: mine','x [BR:  label  ](path.md) y'}
        local result=Layout.prepare({lines=lines,first_row=0,first_byte=0,header_lines={'BOT:'}},
            {chat_branch_prefix='BR:',chat_local_prefix='PRIVATE:'})
        assert.equals('\nBOT:\n\nBR: child.md: child\nPRIVATE: mine\n[BR:  label  ](path.md)\n',
            apply_with_provenance(lines,result))
    end)
    it('keeps only documented single-line private annotations, including inside fences',function()
        local lines={'```','🔒: single line','continuation is generated','```'}
        local result=prepare(lines)
        assert.equals(1,#result.protected)
        assert.equals('\n🤖: agent\n\n🔒: single line\n',apply_with_provenance(lines,result))
    end)
    it('handles an unanswered question with an empty finite insertion span',function()
        local result=prepare({})
        assert.equals(1,#result.gaps);assert.equals(0,result.gaps[1].end_offset)
        assert.equals(7,result.suffix.row);assert.equals(100,result.suffix.byte)
        assert.equals('\n🤖: agent\n\n',apply_with_provenance({},result))
    end)
    it('matches legacy survivor references without rewriting their raw link bytes',function()
        local lines={'generated [🌿: λ ](child.md) sentence','🌿: other.md: other','🔒: mine'}
        local old=require('parley.annotation').survivors(lines,config)
        local plan=prepare(lines);local actual=apply_with_provenance(lines,plan)
        local collected={}
        for text in actual:gmatch('([^\n]+)') do
            local refs=require('parley.annotation').survivors({text},config)
            for _,ref in ipairs(refs) do collected[#collected+1]=ref end
        end
        assert.same(old,collected)
        assert.truthy(actual:find('[🌿: λ ](child.md)',1,true))
    end)
    it('keeps exact UTF8 byte columns and leaves supplied next-question/footnote suffix untouched',function()
        local lines={'λ [🌿: 笔记](file.md) ω'}
        local plan=prepare(lines)
        local keep=plan.protected[1]
        assert.equals(#'λ ',keep.first_offset)
        assert.equals(#'λ ',keep.first.col)
        assert.equals(100+#'λ ',keep.first.byte)
        assert.equals(keep.first_offset+#keep.raw,keep.end_offset)
        local suffix='\n@@next@@\n💬: composed by human\n\n---\n[^1]: footnote\n'
        local result=apply_with_provenance(lines,plan)..suffix
        assert.equals(suffix,result:sub(-#suffix))
    end)
    it('rejects malformed source coordinates and embedded line separators',function()
        assert.has_error(function() prepare({'a\nb'}) end)
        assert.has_error(function() prepare({'a'},{first_row=-1}) end)
        assert.has_error(function() prepare({'a'},{first_byte=0.5}) end)
        assert.has_error(function() prepare({'a'},{header_lines={}}) end)
    end)
end)
