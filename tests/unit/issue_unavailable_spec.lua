local vocab = require('parley.issue_vocabulary')
local issues = require('parley.issues')
local records = require('parley.issue_finder_records')

describe('unavailable optional issue vocabulary', function()
    local dir, warnings, buf
    local lines = {'---', 'id: 000001', 'status: working', 'deps: []',
        'updated: 2000-01-01', '---', '# Example', '## Plan', '- [ ] Child'}
    before_each(function()
        dir = vim.fn.tempname()
        vim.fn.mkdir(dir, 'p')
        warnings = {}
        issues.setup({config={issues_dir=dir..'/issues'},
            logger={warning=function(msg) warnings[#warnings+1]=msg end}})
        vocab.reload({path=dir..'/missing.json'})
        buf = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,lines)
        vim.bo[buf].modified = false
    end)
    after_each(function()
        if buf and vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf,{force=true}) end
        vocab.reset_for_tests()
        vim.fn.delete(dir,'rf')
    end)
    it('preserves raw status without inventing a default or category', function()
        assert.equals('working',issues.parse_frontmatter(lines).status)
        assert.is_nil(issues.parse_frontmatter({'---','id: 1','---'}).status)
        assert.same({},issues.status_values())
        assert.same({},issues.complete_frontmatter_values('status',''))
        assert.is_false(issues.is_open_status('open'))
        assert.is_false(issues.is_active_status('working'))
        assert.is_false(issues.is_terminal_status('done'))
        local status, err = issues.cycle_status_value('working')
        assert.is_nil(status)
        assert.matches('unavailable',err)
    end)
    it('sorts all input permutations by ID without a model', function()
        local a,b,c = {id='1',status='done'},{id='2',status='open'},{id='3',status='working'}
        for _, item in ipairs({a,b,c}) do
            item.identity = {key=item.id,source={root_ordinal=1,unresolved_absolute='/'..item.id}}
        end
        for _, input in ipairs({{a,b,c},{a,c,b},{b,a,c},{b,c,a},{c,a,b},{c,b,a}}) do
            assert.same({a,b,c},issues.topo_sort(input))
            assert.same({a,b,c},records.materialize(input))
        end
        local archived_a = vim.tbl_extend('force',a,{archived=true,mtime=20})
        local archived_b = vim.tbl_extend('force',b,{archived=true,mtime=10})
        assert.same({archived_b,archived_a},records.materialize({archived_a,archived_b},{archived=true}))
        assert.same({},records.materialize({
            vim.tbl_extend('force',a,{archived=true,mtime=20}),
            vim.tbl_extend('force',b,{archived=true,mtime=10}),
        },{archived=false})) -- active view must not admit archive records
    end)
    for _, command in ipairs({'cmd_issue_status','cmd_issue_new','cmd_issue_decompose','cmd_issue_next'}) do
        it('refuses '..command..' before changes', function()
            vim.api.nvim_win_set_cursor(0,{9,0})
            issues[command]()
            assert.same(lines,vim.api.nvim_buf_get_lines(buf,0,-1,false))
            assert.is_false(vim.bo[buf].modified)
            assert.equals(0,vim.fn.isdirectory(dir..'/issues'))
            assert.matches('unavailable',assert(warnings[1]))
        end)
    end
    it('does not dispatch creation or render a lifecycle-dependent template', function()
        local called = false
        issues.run_sdlc_issue_new('title',{},function(path,err)
            assert.is_nil(path)
            assert.matches('unavailable',err)
            called=true
        end,function() error('must not dispatch') end)
        assert.is_true(called)
        local content, err = issues.render_issue_template({title='title'})
        assert.is_nil(content)
        assert.matches('unavailable',err)
    end)
end)
