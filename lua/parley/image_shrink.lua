-- Image conversion policy and one bounded subprocess seam (#244).
local assets = require("parley.assets")
local argv_recipe = require("parley.argv_recipe")

local M = {
    TIMEOUT_MS = 5000,
    MAX_EDGE = 1600,
    MIN_BYTES = 300 * 1024,
    MAX_AXIS = 16384,
    MAX_PIXELS = 32000000,
    QUALITY = 80,
    OUT_EXT = "jpg",
    IN = "{in}",
    OUT = "{out}",
    MAX = "{max}",
}

-- Ordered by preference. Paths are whole argv values; only numeric {max}
-- may be embedded. The vips suffix is constant script text with paths in argv.
M.RECIPES = {
    {
        tool = "sips",
        argv = {
            "sips", "-s", "format", "jpeg", "-s", "formatOptions", tostring(M.QUALITY),
            "--resampleHeightWidthMax", "{max}", "{in}", "--out", "{out}",
        },
        install = "sips ships with macOS",
    },
    {
        tool = "magick",
        argv = {
            "magick", "{in}", "-auto-orient", "-resize", "{max}x{max}>",
            "-background", "white", "-alpha", "remove", "-quality", tostring(M.QUALITY), "-strip", "{out}",
        },
        install = "install ImageMagick (brew install imagemagick)",
    },
    {
        tool = "convert",
        argv = {
            "convert", "{in}", "-auto-orient", "-resize", "{max}x{max}>",
            "-background", "white", "-alpha", "remove", "-quality", tostring(M.QUALITY), "-strip", "{out}",
        },
        install = "install ImageMagick (brew install imagemagick)",
    },
    {
        tool = "ffmpeg",
        argv = {
            "ffmpeg", "-y", "-loglevel", "error", "-i", "{in}", "-vf",
            "scale=w='min({max},iw)':h='min({max},ih)':force_original_aspect_ratio=decrease",
            "-frames:v", "1", "-q:v", "4", "-map_metadata", "-1", "-f", "image2", "{out}",
        },
        install = "install ffmpeg (brew install ffmpeg)",
    },
    {
        tool = "vipsthumbnail",
        argv = {
            "sh", "-c",
            'exec vipsthumbnail "$1" --size "$3x$3>" -o "$2[Q=' .. M.QUALITY .. ',strip]"',
            "sh", "{in}", "{out}", "{max}",
        },
        install = "install libvips (brew install vips)",
    },
}

--- Target edge or nil, plus an optional diagnostic for unsafe input.
--- Admission precedes executable probes and external decoding (ARCH-CONSTRAINTS).
function M.decide(size, width, height, media_type)
    if media_type ~= "image/png" and media_type ~= "image/jpeg" then
        return nil
    end
    if not width or not height then
        return nil
    end
    if width > M.MAX_AXIS or height > M.MAX_AXIS or width * height > M.MAX_PIXELS then
        return nil, "image exceeds conversion limits (16384 px per axis, 32 MP)"
    end
    local edge = math.max(width, height)
    if edge > M.MAX_EDGE or (media_type == "image/png" and size > M.MIN_BYTES) then
        return math.min(edge, M.MAX_EDGE)
    end
end

--- Produce argv without mutating the recipe or rescanning substituted paths.
function M.argv_for(recipe, input, output, max)
    return argv_recipe.substitute(recipe.argv, {
        [M.IN] = input,
        [M.OUT] = output,
    }, { [M.MAX] = tostring(max) })
end

--- Accept only successful, smaller JPEGs within the requested dimensions.
--- Ineffective size reduction is silent; other failures name the converter.
function M.classify(code, stderr, output, input_size, tool, requested_edge)
    local function kept(reason)
        return "kept", tostring(tool) .. " " .. reason
    end
    if code ~= 0 then
        local detail = (stderr or ""):gsub("%s+$", "")
        if code == 124 then
            return kept("timed out after " .. M.TIMEOUT_MS .. " ms"
                .. (detail ~= "" and ": " .. detail or ""))
        end
        return kept("exit " .. tostring(code) .. (detail ~= "" and ": " .. detail or ""))
    end
    if not output or output == "" then
        return kept("wrote nothing")
    end
    local width, height = assets.dimensions("image/jpeg", output)
    if not width then
        return kept("wrote something that is not a JPEG")
    end
    if math.max(width, height) > requested_edge then
        return kept("output exceeds requested edge")
    end
    if #output >= input_size then
        return "kept"
    end
    return "ok"
end

-- Dependencies own filesystem operations and synchronous process completion.
-- Reuse the asset writer's checked close and bounded regular-file reader.
M.default_deps = {
    tempname = function()
        return vim.fn.tempname()
    end,
    write = assets.default_io.write,
    read = assets.default_io.read,
    remove = function(path)
        return os.remove(path)
    end,
    system = function(argv, opts)
        return vim.system(argv, opts):wait()
    end,
}

--- Return exit code, stderr, and complete output within the 10 MiB cap.
--- Constant shell text limits per-file growth to <=10 MiB before exec. Both
--- paths are cleaned even after allocation/write/spawn/read failures; genuine
--- cleanup failures are reported after every removal has been attempted.
function M.run(recipe, bytes, ext, max, deps)
    deps = deps or M.default_deps
    local paths = {}
    local function allocate(suffix)
        local name = assert(deps.tempname(), "temporary path allocation failed") .. suffix
        paths[#paths + 1] = name
        return name
    end
    local ok, code, stderr, output = pcall(function()
        local input = allocate("." .. ext)
        local out = allocate("." .. M.OUT_EXT)
        local written, err = deps.write(input, bytes)
        if not written then
            error(err or "could not write input")
        end
        local argv = { "sh", "-c", 'ulimit -f 10240 || exit; exec "$@"', "sh" }
        vim.list_extend(argv, M.argv_for(recipe, input, out, max))
        local result = deps.system(argv, { timeout = M.TIMEOUT_MS, stdout = false, text = true })
        -- Preserve completeness through metadata stripping and classification.
        -- One extra byte detects output beyond the cap without unbounded reads.
        local result_code = result.code or 1
        local converted = deps.read(out, assets.MAX_BYTES + 1)
        if converted and #converted > assets.MAX_BYTES then
            return result_code ~= 0 and result_code or 1,
                (result.stderr or "") .. " output exceeds " .. assets.MAX_BYTES .. "-byte limit", nil
        end
        return result_code, result.stderr or "", converted
    end)
    if not ok then
        code, stderr, output = 1, tostring(code), nil
    end
    local cleanup_errors = {}
    for _, path in ipairs(paths) do
        local removed_ok, removed, err, errno = pcall(deps.remove, path)
        if not removed_ok or (not removed and errno ~= 2) then
            local reason = removed_ok and (err or "removal failed") or removed
            cleanup_errors[#cleanup_errors + 1] = path .. ": " .. tostring(reason)
        end
    end
    if #cleanup_errors > 0 then
        local diagnostic = "cleanup failed: " .. table.concat(cleanup_errors, "; ")
        stderr = stderr ~= "" and (stderr .. "; " .. diagnostic) or diagnostic
        code = code ~= 0 and code or 1
        output = nil
    end
    return code, stderr, output
end

local config, environment, dependencies = {}, nil, nil
local resolution = { status = "unprobed" }

--- Setup resets session resolution, including the once-only missing-tool note.
function M.configure(cfg, env, deps)
    config, environment, dependencies = cfg or {}, env, deps
    resolution = { status = "unprobed" }
end

--- One tagged session state: unprobed, found(recipe), or missing(already noted).
function M.resolve()
    if resolution.status ~= "unprobed" then
        return resolution.recipe
    end
    local executable = environment and environment.executable or function(tool)
        return vim.fn.executable(tool) == 1
    end
    local recipe, note = argv_recipe.select(config.shrink_cmd, M.RECIPES, executable, {
        config_key = "assets.shrink_cmd",
        tokens = { M.IN, M.OUT },
        embedded_tokens = { M.MAX },
        purpose = "for image conversion",
        none = "no image shrink tool found",
    })
    resolution = recipe and { status = "found", recipe = recipe } or { status = "missing" }
    return recipe, note
end

--- Transform bytes and extension together, retaining originals on any failure.
function M.shrink(bytes, ext)
    if config.shrink == false then
        return bytes, ext
    end
    local media_type = assets.media_type("image." .. ext)
    local width, height = assets.dimensions(media_type, bytes)
    local max, note = M.decide(#bytes, width, height, media_type)
    if not max then
        return bytes, ext, note and { note = note } or nil
    end
    local recipe
    recipe, note = M.resolve()
    if not recipe then
        return bytes, ext, note and { note = note } or nil
    end
    local code, stderr, output = M.run(recipe, bytes, ext, max, dependencies)
    if code == 0 and output and output ~= "" then
        -- Some converters retain EXIF/comments. Sanitize independently of the
        -- selected tool; invalid bytes stay intact for the classifier's note.
        output = assets.strip_jpeg_metadata(output) or output
    end
    local status
    status, note = M.classify(code, stderr, output, #bytes, recipe.tool, max)
    if status == "ok" then
        return output, M.OUT_EXT, { from = #bytes, to = #output }
    end
    return bytes, ext, note and { note = note } or nil
end

function M.outcome_suffix(outcome)
    if not outcome or not (outcome.note or outcome.to) then
        return ""
    end
    if outcome.note then
        return " — original kept: " .. outcome.note
    end
    return " (" .. assets.human_size(outcome.from) .. " → " .. assets.human_size(outcome.to) .. ")"
end

return M
