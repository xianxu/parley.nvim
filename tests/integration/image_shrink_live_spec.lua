local shrink = require('parley.image_shrink')
local assets = require('parley.assets')
local png_gen = require('tests.helpers.png_gen')

describe('live image shrink recipe conformance', function()
    for _, candidate in ipairs(shrink.RECIPES) do
        local recipe = candidate
        it('conforms for ' .. recipe.tool, function()
            if vim.env.PARLEY_LIVE_SHRINK ~= '1' then
                pending('opt in with PARLEY_LIVE_SHRINK=1')
                return
            end
            if vim.fn.executable(recipe.tool) ~= 1 then
                pending(recipe.tool .. ' is not installed')
                return
            end
            for _, dimensions in ipairs({{1800, 1200}, {400, 300}}) do
                local width, height = dimensions[1], dimensions[2]
                local input = png_gen.png_bytes(width, height)
                local max = assert(shrink.decide(#input, width, height, 'image/png'))
                local started = (vim.uv or vim.loop).hrtime()
                local code, err, output = shrink.run(recipe, input, 'png', max)
                local elapsed_ms = ((vim.uv or vim.loop).hrtime() - started) / 1e6
                local status, note = shrink.classify(code, err, output, #input, recipe.tool, max)
                assert.equals('ok', status, note)
                local out_width, out_height = assets.dimensions('image/jpeg', output)
                assert.equals(math.min(1600, width), math.max(out_width, out_height))
                assert.is_true(out_width <= width and out_height <= height)
                assert.is_true(#output < #input)
                assert.is_true(#output < 300 * 1024)
                if vim.fn.executable('sips') == 1 then
                    local path = vim.fn.tempname() .. '.jpg'
                    local ok, why = pcall(function()
                        assert(assets.default_io.write(path, output))
                        local probe = vim.system({'sips', '-g', 'pixelWidth', '-g', 'pixelHeight', path},
                            {text=true, timeout=5000}):wait()
                        assert.equals(0, probe.code, probe.stderr)
                        assert.equals(out_width, tonumber(probe.stdout:match('pixelWidth: (%d+)')))
                        assert.equals(out_height, tonumber(probe.stdout:match('pixelHeight: (%d+)')))
                    end)
                    os.remove(path)
                    assert.is_true(ok, why)
                end
                print(string.format('%s %dx%d: %d bytes -> %dx%d %d bytes in %.1f ms',
                    recipe.tool, width, height, #input, out_width, out_height, #output, elapsed_ms))
            end
        end)
    end
end)

describe('live metadata removal', function()
    it('removes descriptions retained by sips', function()
        if vim.env.PARLEY_LIVE_SHRINK ~= '1' or vim.fn.executable('sips') ~= 1 then
            pending('requires PARLEY_LIVE_SHRINK=1 and sips')
            return
        end
        local dir = vim.fn.tempname()
        vim.fn.mkdir(dir, 'p')
        local marker = 'PARLEY244_SENTINEL'
        local ok, why = pcall(function()
            assert(assets.default_io.write(dir .. '/source.png', png_gen.png_bytes(1800,1200)))
            local prepared = vim.system({'sips','-s','format','jpeg','-s','formatOptions','100',
                '-s','description',marker,dir..'/source.png','--out',dir..'/source.jpg'},
                {text=true,timeout=5000}):wait()
            assert.equals(0, prepared.code, prepared.stderr)
            local input = assert(assets.default_io.read(dir..'/source.jpg', assets.MAX_BYTES))
            assert.is_not_nil(input:find(marker,1,true))
            shrink.configure({shrink_cmd=shrink.RECIPES[1].argv})
            local output, ext, outcome = shrink.shrink(input,'jpg')
            assert.equals('jpg', ext)
            assert.is_not_nil(outcome.to, outcome.note)
            assert.is_nil(output:find(marker,1,true))
            assert(assets.default_io.write(dir..'/output.jpg',output))
            local probe = vim.system({'sips','-g','description',dir..'/output.jpg'},
                {text=true,timeout=5000}):wait()
            assert.equals(0,probe.code,probe.stderr)
            assert.is_nil(probe.stdout:find(marker,1,true))
        end)
        shrink.configure()
        vim.fn.delete(dir,'rf')
        assert.is_true(ok,why)
    end)
end)
