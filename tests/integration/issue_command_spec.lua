local issues = require('parley.issues')
local vocab = require('parley.issue_vocabulary')

describe('optional sdlc command routes', function()
    local dir, saved
    local names = {'HOME','PATH','SHELL','PARLEY_FAKE_SDLC_BIN','PARLEY_FAKE_SDLC_STATE','PARLEY_FAKE_SDLC_MODE'}
    local function create(title)
        local done, result, failure = false, nil, nil
        issues.run_sdlc_issue_new(title,{issues_dir=dir..'/issues'},function(path,err)
            result, failure, done = path, err, true
        end)
        assert(vim.wait(3000,function() return done end,10),'creation did not finish')
        return result, failure
    end
    before_each(function()
        dir = vim.fn.tempname()
        vim.fn.mkdir(dir..'/bin','p')
        saved = {cwd=vim.fn.getcwd()}
        for _, name in ipairs(names) do saved[name] = vim.env[name] end
        vim.env.HOME = dir
        vim.env.PATH = dir..'/bin:/usr/bin:/bin'
        vim.env.SHELL = '/bin/bash'
        vim.env.PARLEY_FAKE_SDLC_BIN = vim.fn.getcwd()..'/tests/fixtures/fake_sdlc'
        vim.env.PARLEY_FAKE_SDLC_STATE = dir..'/state'
        vim.env.PARLEY_FAKE_SDLC_MODE = nil
        vocab.reset_for_tests()
        vim.fn.chdir(dir)
    end)
    after_each(function()
        for _, name in ipairs(names) do vim.env[name] = saved[name] end
        vocab.reset_for_tests()
        vim.fn.chdir(saved.cwd)
        vim.fn.delete(dir,'rf')
    end)
    for _, route in ipairs({'binary','function','alias'}) do
        it('uses '..route..' with literal titles and persistent fake state', function()
            if route == 'binary' then
                assert((vim.uv or vim.loop).fs_symlink(vim.env.PARLEY_FAKE_SDLC_BIN,dir..'/bin/sdlc'))
            else
                local rc = route == 'function'
                    and 'sdlc() { "$PARLEY_FAKE_SDLC_BIN" "$@"; }'
                    or [[alias sdlc='"$PARLEY_FAKE_SDLC_BIN"']]
                vim.fn.writefile({rc},dir..'/.bashrc')
            end
            local title = [[-literal 'quote' $(touch ESCAPED) `echo no`]]
            local first, err = create(title)
            assert.is_not_nil(first,err)
            local second = assert(create('second'))
            assert.is_not.equals(first,second)
            assert.equals('# '..title,vim.fn.readfile(first)[5])
            local requests = vim.fn.readfile(dir..'/state/requests.jsonl')
            assert.equals(2,#requests)
            local argv = vim.json.decode(requests[1])
            assert.equals(title,argv[#argv])
            assert.equals(0,vim.fn.filereadable('ESCAPED'))
            vim.env.PARLEY_FAKE_SDLC_MODE = 'fail'
            local failed, why = create('not created')
            assert.is_nil(failed)
            assert.matches('exit 7',why)
            assert.equals(2,#vim.fn.glob(dir..'/issues/*.md',false,true))
        end)
    end
    it('reports an unavailable command without creating files', function()
        local result, err = create('not created')
        assert.is_nil(result)
        assert.matches('sdlc',err)
        assert.equals(0,vim.fn.isdirectory(dir..'/issues'))
    end)
end)
