-- Independent codec metadata oracles for live conformance; never use Parley's parser.
local M = {}

function M.dimensions(tool, path, run)
    local commands = {
        sips = {'sips', '-g', 'pixelWidth', '-g', 'pixelHeight', path},
        magick = {'magick', path, '-format', '%w %h', 'info:'},
        convert = {'convert', path, '-format', '%w %h', 'info:'},
        ffmpeg = {'ffprobe', '-v', 'error', '-select_streams', 'v:0',
            '-show_entries', 'stream=width,height', '-of', 'json', path},
        vipsthumbnail = {'vipsheader', '-f', 'width', '-f', 'height', path},
    }
    local argv = assert(commands[tool], 'No independent probe for ' .. tool)
    run = run or function(args)
        return vim.system(args, {text=true, timeout=5000}):wait()
    end
    local result = run(argv)
    assert(result.code == 0, argv[1] .. ' probe failed: ' .. (result.stderr or ''))
    local output = result.stdout or ''
    local width, height
    if tool == 'sips' then
        width, height = output:match('pixelWidth: (%d+)'), output:match('pixelHeight: (%d+)')
    elseif tool == 'ffmpeg' then
        local stream = (vim.json.decode(output).streams or {})[1] or {}
        width, height = stream.width, stream.height
    else
        width, height = output:match('^%s*(%d+)%s+(%d+)%s*$')
    end
    width, height = tonumber(width), tonumber(height)
    assert(width and height and width > 0 and height > 0, argv[1] .. ' returned invalid dimensions')
    return width, height
end

return M
