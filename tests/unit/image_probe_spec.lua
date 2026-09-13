local probe = require('tests.helpers.image_probe')

describe('independent image dimension probes', function()
    local reports = {
        sips = 'pixelWidth: 1600\npixelHeight: 1066\n',
        magick = '1600 1066', convert = '1600 1066',
        ffmpeg = '{"streams":[{"width":1600,"height":1066}]}',
        vipsthumbnail = '1600\n1066\n',
    }
    local commands = {
        sips = {'sips', '-g', 'pixelWidth', '-g', 'pixelHeight', '/tmp/output image.jpg'},
        magick = {'magick', '/tmp/output image.jpg', '-format', '%w %h', 'info:'},
        convert = {'convert', '/tmp/output image.jpg', '-format', '%w %h', 'info:'},
        ffmpeg = {'ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries',
            'stream=width,height', '-of', 'json', '/tmp/output image.jpg'},
        vipsthumbnail = {'vipsheader', '-f', 'width', '-f', 'height', '/tmp/output image.jpg'},
    }
    for name, report in pairs(reports) do
        it('probes ' .. name .. ' without relying on another converter', function()
            local calls = {}
            local w, h = probe.dimensions(name, '/tmp/output image.jpg', function(argv)
                calls[#calls+1] = argv
                assert.same(commands[name], argv)
                if name ~= 'sips' then assert.is_not.equals('sips', argv[1]) end
                return {code=0, stdout=report, stderr=''}
            end)
            assert.equals(1600, w)
            assert.equals(1066, h)
            assert.equals(1, #calls)
        end)
    end
    it('rejects failed probes', function()
        assert.has_error(function()
            probe.dimensions('ffmpeg', 'x', function() return {code=127, stderr='ffprobe missing'} end)
        end)
    end)
    it('rejects malformed dimensions', function()
        assert.has_error(function()
            probe.dimensions('magick', 'x', function() return {code=0, stdout='invalid'} end)
        end)
    end)
end)
