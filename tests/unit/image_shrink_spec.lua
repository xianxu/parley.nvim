local shrink = require('parley.image_shrink')
local root = vim.fn.getcwd()
local function read(path)
    local f = assert(io.open(path, 'rb'))
    local bytes = f:read('*a')
    f:close()
    return bytes
end
local jpeg = read(root .. '/tests/fixtures/one_pixel.jpg')
local png = read(root .. '/tests/fixtures/one_pixel.png')

describe('image shrink policy', function()
    it('uses format-specific strict eligibility and never upscales', function()
        for _, row in ipairs({
            {300*1024, 1600, 20, 'image/png', false},
            {300*1024+1, 100, 20, 'image/png', 100},
            {1, 1601, 20, 'image/png', 1600},
            {900000, 1600, 20, 'image/jpeg', false},
            {1, 20, 1601, 'image/jpeg', 1600},
            {900000, 2000, 20, 'image/gif', false},
        }) do
            assert.equals(row[5] or nil, (shrink.decide(row[1], row[2], row[3], row[4])))
        end
    end)
    it('rejects resource amplification at exact admission boundaries', function()
        assert.equals(1600, shrink.decide(1, 8000, 4000, 'image/png'))
        assert.equals(1600, shrink.decide(1, 16384, 1, 'image/png'))
        for _, dims in ipairs({{16385, 1}, {1, 16385}, {8001, 4000}}) do
            local max, note = shrink.decide(1, dims[1], dims[2], 'image/png')
            assert.is_nil(max)
            assert.matches('limit', note)
        end
    end)
    it('validates exit status, JPEG structure, output edge, and strict byte reduction', function()
        assert.equals('ok', shrink.classify(0, '', jpeg, #jpeg+1, 'fake', 1))
        for _, row in ipairs({{1, jpeg, 1}, {124, jpeg, 1}, {0, '', 1}, {0, png, 1}, {0, jpeg, 0}}) do
            local status, note = shrink.classify(row[1], 'detail', row[2], #jpeg+1, 'fake', row[3])
            assert.equals('kept', status)
            assert.matches('fake', note)
        end
        -- The valid fixture's SOF9 frame can declare a larger width without
        -- changing its structural validity; the output limit must reject it.
        local sof = assert(jpeg:find('\255\201', 1, true))
        local wide = jpeg:sub(1, sof+6) .. '\6\65' .. jpeg:sub(sof+9)
        assert.same({1601, 1}, {require('parley.assets').dimensions('image/jpeg', wide)})
        local wide_status, wide_note = shrink.classify(0, '', wide, #wide+1, 'fake', 1600)
        assert.equals('kept', wide_status)
        assert.matches('requested edge', wide_note)
        local status, note = shrink.classify(0, '', jpeg, #jpeg, 'fake', 1)
        assert.equals('kept', status)
        assert.is_nil(note)
        local _, empty = shrink.classify(0, '', nil, 100, 'fake', 1)
        assert.equals('fake wrote nothing', empty)
        local _, invalid = shrink.classify(0, '', 'garbage', 100, 'fake', 1)
        assert.equals('fake wrote something that is not a JPEG', invalid)
    end)
    it('substitutes numeric tokens without rescanning path data', function()
        local recipe = {argv={'fake','{in}','{out}','scale={max}:{max}'}}
        assert.same({'fake','/tmp/{max};x','/tmp/{in}','scale=123:123'},
            shrink.argv_for(recipe, '/tmp/{max};x', '/tmp/{in}', 123))
        assert.equals('{in}', recipe.argv[2])
    end)
end)

describe('image shrink bounded runner', function()
    local function filesystem(fault)
        local files, names, removed = {}, {}, {}
        local deps = {}
        deps.tempname = function()
            if fault == 'allocate' and #names == 1 then error('allocate failure') end
            local path = '/scratch/' .. tostring(#names+1)
            names[#names+1] = path
            return path
        end
        deps.write = function(path, bytes)
            files[path] = bytes
            if fault == 'write' then return nil, 'write failure' end
            return true
        end
        deps.read = function(path, max)
            if fault == 'read' then error('read failure') end
            return files[path] and files[path]:sub(1,max)
        end
        deps.remove = function(path) files[path] = nil; removed[#removed+1] = path end
        deps.system = function(argv, opts)
            assert.same({'sh','-c','ulimit -f 10240 || exit; exec "$@"','sh'}, vim.list_slice(argv,1,4))
            assert.equals(5000, opts.timeout)
            assert.is_false(opts.stdout)
            if fault == 'spawn' then error('spawn failure') end
            files[argv[7]] = jpeg
            return {code=0,stderr=''}
        end
        return deps, files, removed
    end
    it('cleans both files after success and caps reads at input size', function()
        local deps, files, removed = filesystem()
        local code, _, out = shrink.run({argv={'fake','{in}','{out}','{max}'}}, png, 'png', 1, deps)
        assert.equals(0, code)
        assert.equals(jpeg:sub(1,#png), out)
        assert.same({}, files)
        assert.equals(2, #removed)
    end)
    for _, fault in ipairs({'allocate','write','read','spawn'}) do
        it('cleans files on '..fault..' failure', function()
            local deps, files, removed = filesystem(fault)
            local code, err = shrink.run({argv={'fake','{in}','{out}','{max}'}}, png, 'png', 1, deps)
            assert.is_not.equals(0, code)
            assert.matches(fault, err)
            assert.same({}, files)
            assert.equals(fault == 'allocate' and 1 or 2, #removed)
        end)
    end
end)

describe('image shrink session resolution', function()
    after_each(function() shrink.configure() end)
    it('bypasses disabled, ineligible, malformed, and huge images before any probe', function()
        local probes = 0
        local env = {executable=function() probes=probes+1; return false end}
        shrink.configure({shrink=false}, env)
        assert.equals(png, shrink.shrink(png, 'png'))
        shrink.configure({}, env)
        shrink.shrink(png, 'png')
        shrink.shrink('garbage', 'png')
        -- Keep the source structurally valid while declaring an unsafe PNG canvas.
        local huge = png:sub(1,16) .. '\0\1\0\0' .. png:sub(21)
        local _, _, outcome = shrink.shrink(huge, 'png')
        assert.matches('limits', outcome.note)
        assert.equals(0, probes)
    end)
    it('reports missing tools once and resets on configure', function()
        local probes = 0
        local env = {executable=function() probes=probes+1; return false end}
        shrink.configure({}, env)
        local recipe, note = shrink.resolve()
        assert.is_nil(recipe)
        assert.matches('no image shrink tool', note)
        local _, again = shrink.resolve()
        assert.is_nil(again)
        assert.equals(5, probes)
        shrink.configure({}, env)
        shrink.resolve()
        assert.equals(10, probes)
    end)
    it('selects the first available candidate and caches it', function()
        local probes = {}
        shrink.configure({}, {executable=function(tool)
            probes[#probes+1] = tool
            return tool == 'convert'
        end})
        assert.equals('convert', shrink.resolve().tool)
        assert.equals('convert', shrink.resolve().tool)
        assert.same({'sips','magick','convert'}, probes)
    end)
    it('accepts configured embedded max and rejects missing tokens', function()
        shrink.configure({shrink_cmd={'fake','{in}','{out}','--size={max}'}})
        assert.equals('fake', shrink.resolve().tool)
        shrink.configure({shrink_cmd={'fake','{in}','{out}'}})
        local recipe, note = shrink.resolve()
        assert.is_nil(recipe)
        assert.matches('{max}', note, 1, true)
    end)
    it('formats only actionable outcomes', function()
        assert.equals('', shrink.outcome_suffix(nil))
        assert.equals('', shrink.outcome_suffix({}))
        assert.equals(' (1.0 KB → 1 B)', shrink.outcome_suffix({from=1024,to=1}))
        assert.equals(' — original kept: broken', shrink.outcome_suffix({note='broken'}))
    end)
end)

describe('filesystem-backed converter fixture', function()
    local dir, paths, deps, old_mode, old_log
    before_each(function()
        dir = vim.fn.tempname()
        vim.fn.mkdir(dir, 'p')
        paths = {}
        deps = vim.tbl_extend('force', shrink.default_deps, {
            tempname=function()
                local path = dir .. '/' .. tostring(#paths+1)
                paths[#paths+1] = path
                return path
            end,
        })
        old_mode, old_log = vim.env.PARLEY_FAKE_SIPS, vim.env.PARLEY_FAKE_SIPS_LOG
        vim.env.PARLEY_FAKE_SIPS_LOG = dir .. '/calls'
    end)
    after_each(function()
        vim.env.PARLEY_FAKE_SIPS, vim.env.PARLEY_FAKE_SIPS_LOG = old_mode, old_log
        vim.fn.delete(dir, 'rf')
    end)
    local recipe = {tool='fake_sips',argv={root..'/tests/fixtures/fake_sips','--resampleHeightWidthMax','{max}','{in}','--out','{out}'}}
    local function convert(mode)
        vim.env.PARLEY_FAKE_SIPS = mode
        local code, err, out = shrink.run(recipe, png, 'png', 1, deps)
        assert.is_nil((vim.uv or vim.loop).fs_stat(paths[1]..'.png'))
        assert.is_nil((vim.uv or vim.loop).fs_stat(paths[2]..'.jpg'))
        assert.matches('resampleHeightWidthMax', read(dir..'/calls'))
        return code, err, out
    end
    it('persists call log and honors success/failure/empty/invalid modes', function()
        assert.equals(0, convert('ok:'..root..'/tests/fixtures/one_pixel.jpg'))
        assert.equals(7, convert('fail'))
        local code, _, out = convert('empty')
        assert.equals(0, code)
        assert.equals('', out)
        code, _, out = convert('garbage')
        assert.equals(0, code)
        assert.equals('not a JPEG', out)
        assert.equals(4, #vim.fn.readfile(dir..'/calls'))
    end)
    it('kills a real slow child at the five second budget', function()
        local clock = vim.uv or vim.loop
        local start = clock.hrtime()
        assert.equals(124, convert('slow'))
        local elapsed = (clock.hrtime()-start)/1e9
        assert.is_true(elapsed >= 4.5 and elapsed < 8)
    end)
    it('enforces the operating-system output growth limit', function()
        local observed_size
        deps.remove = function(path)
            local stat = (vim.uv or vim.loop).fs_stat(path)
            if path:sub(-4) == '.jpg' then observed_size = stat and stat.size end
            return os.remove(path)
        end
        local code = convert('oversized')
        assert.is_not.equals(0, code)
        assert.is_true(observed_size > 0 and observed_size <= 10*1024*1024)
    end)
end)

describe('converter-independent metadata removal', function()
    after_each(function() shrink.configure() end)
    it('strips embedded descriptions and reports the final saved byte count', function()
        local marker = 'PARLEY244_SENTINEL'
        local metadata = '\255\225\0' .. string.char(#marker+2) .. marker
        local decorated = jpeg:sub(1,2) .. metadata .. jpeg:sub(3)
        local input = require('tests.helpers.png_gen').png_bytes(1800, 4)
        local files, index = {}, 0
        local deps = {
            tempname=function() index=index+1; return '/fake/'..index end,
            write=function(path, bytes) files[path]=bytes; return true end,
            read=function(path, max) return files[path] and files[path]:sub(1,max) end,
            remove=function(path) files[path]=nil end,
            system=function(argv)
                files[argv[7]] = decorated
                return {code=0,stderr=''}
            end,
        }
        shrink.configure({shrink_cmd={'fake','{in}','{out}','{max}'}}, nil, deps)
        local output, ext, outcome = shrink.shrink(input, 'png')
        assert.equals('jpg', ext)
        assert.is_nil(output:find(marker, 1, true))
        assert.equals(jpeg, output)
        assert.same({from=#input,to=#jpeg}, outcome)
        assert.same({}, files)
    end)
end)
