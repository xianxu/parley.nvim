-- Native review routing must refuse unsupported declared maps before invoking
-- the existing provider/tool owner. No source files or fake write owner needed.
local review=require('parley.skills.review')
local driver=require('parley.skill_invoke')
local cases={
    {'flow nested node after chat','collaboration-mode: {chat: [Notes], other: {nested: false}}'},
    {'flow nested node before chat','collaboration-mode: {other: {nested: false}, chat: [Notes]}'},
    {'block nested node after chat','collaboration-mode:\n  chat: [Notes]\n  other:\n    nested: false'},
    {'block nested node before chat','collaboration-mode:\n  other:\n    nested: false\n  chat: [Notes]'},
    {'flow quote before value decoding','collaboration-mode: {chat: [Notes], other: "unterminated}'},
    {'first block-member quote','collaboration-mode:\n  other: "unterminated\n  chat: [Notes]'},
}
local function document(body)
    local lines={'---'}
    for line in (body..'\n'):gmatch('(.-)\n')do lines[#lines+1]=line end
    for _,line in ipairs({'---','# Notes','1. operator text','','🤖[tighten this]'})do lines[#lines+1]=line end
    return lines
end

describe('unread declared map review dispatch',function()
    for _,case in ipairs(cases)do
        it('surfaces Couch recovery before provider dispatch: '..case[1],function()
            local saved,calls=driver.invoke,0
            local buf=vim.api.nvim_create_buf(false,true)
            driver.invoke=function()calls=calls+1 end
            local ok,err=pcall(function()
                vim.cmd('messages clear')
                local lines=document(case[2])
                vim.api.nvim_buf_set_lines(buf,0,-1,false,lines)
                local tick=vim.api.nvim_buf_get_changedtick(buf)
                review.run_via_invoke(buf,{})
                assert.equals(tick,vim.api.nvim_buf_get_changedtick(buf))
                assert.same(lines,vim.api.nvim_buf_get_lines(buf,0,-1,false))
            end)
            driver.invoke=saved
            require('parley.skills.review.projection').set_applying(buf,false)
            vim.api.nvim_buf_delete(buf,{force=true})
            assert.is_true(ok,err)
            assert.equals(0,calls)
            assert.is_truthy(vim.fn.execute('messages'):find('use Couch review',1,true))
        end)
    end
end)
