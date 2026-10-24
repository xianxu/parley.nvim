local review = require('parley.skills.review')
local skilldir = assert(vim.api.nvim_get_runtime_file('lua/parley/skills/review/SKILL.md', false)[1]):match('^(.*)/SKILL.md$')
local function source(args)
    local skill = assert(io.open(skilldir .. '/SKILL.md', 'r'))
    local body = skill:read('*a'); skill:close()
    return review.skill.source({skill_dir=skilldir,skill_md=body,args=args or {}})
end

describe('mode-free packaged review source', function()
    it('has no mode selector arguments or standing instruction pipeline', function()
        assert.same({},review.skill.args)
        local ok, body=pcall(source,{mode='unknown',modes={'proofreading'},instruction='STANDING_SENTINEL'})
        assert.is_true(ok,body)
        assert.is_nil(body:find('STANDING_SENTINEL',1,true))
        assert.is_nil(body:find('Selected round flags',1,true))
        assert.is_nil(body:find('## Operator instruction\n',1,true))
        assert.truthy(body:find('# Collaborative editing',1,true))
        assert.truthy(body:find('## copy-editing',1,true))
        assert.truthy(body:find('## proofreading',1,true))
    end)

    it('states the exact local question limitation and snapshot classification', function()
        local body=source()
        assert.truthy(body:find('questions are answered in a side doc by Couch review; left unchanged',1,true))
        assert.truthy(body:find('review_asks',1,true))
        assert.truthy(body:find('zero-based',1,true))
        assert.is_nil(body:find('answer questions in place',1,true))
    end)

    it('does not offer or rewrite retired mode metadata',function()
        local send=require('parley.review_send')
        assert.is_nil(send.completion_start)
        assert.is_nil(send.requote)
        assert.is_nil(send.attach)
        assert.same({},require('parley.frontmatter_enum').candidates('collaboration-mode','','/any.md'))
        local defaults=require('parley.defaults')
        local function scan(value)
            if type(value)=='string' then
                assert.is_nil(value:find('collaboration-mode:',1,true))
                assert.is_nil(value:find('process-instruction:',1,true))
            elseif type(value)=='table' then for _,v in pairs(value)do scan(v)end end
        end
        scan(defaults)
    end)
    it('refuses oversized local snapshots before a full buffer read',function()
        local buf=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{string.rep('x',1048577)})
        local original=vim.api.nvim_buf_get_lines
        local reads=0
        vim.api.nvim_buf_get_lines=function(b,first,last,strict)
            if b==buf and first==0 and last==-1 then reads=reads+1 end
            return original(b,first,last,strict)
        end
        local ok,err=pcall(review.run_via_invoke,buf,{})
        vim.api.nvim_buf_get_lines=original
        vim.api.nvim_buf_delete(buf,{force=true})
        assert.is_true(ok,err)
        assert.equals(0,reads)
    end)

end)
