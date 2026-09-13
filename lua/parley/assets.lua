-- lua/parley/assets.lua
--
-- Chat assets: the per-chat sidecar folder for what markdown cannot hold.
--
-- THE TRANSCRIPT IS THE INDEX; this folder holds only bytes that a transcript
-- line references — nothing reads the folder to discover content. It is keyed
-- by the chat's TIMESTAMP, never its slug, so a slug rename or a chat move
-- never orphans it (#231; the #224 lesson — the timestamp is the identity,
-- the slug is decoration). Layout:
--
--   <chat-dir>/assets/<chat-timestamp>/<asset-timestamp>.<ext>
--
-- referenced from the chat as `![](assets/<chat-timestamp>/<file>)`.
--
-- ONE WRITER: `save` is the only code that creates the folder, names a file
-- and forms a link. The clipboard paste, #239's model-generated images, both
-- chat movers, every chat deleter and the tree export all go through this
-- module (ARCH-DRY) — never through their own `mkdir`/`rename`/`delete`.
--
-- EVERY OCCURRENCE IS AN IMAGE ON THE WIRE. A transcript may link one file
-- many times; each link is its own block, so the request budget and the
-- content are keyed by an occurrence `id` the builder assigns ("<order>:<n>",
-- n = position within that question), never by path (#231 review C1). Twenty-
-- one links to one file are twenty-one candidates and stop at the cap.
--
-- BYTES MUST LOOK LIKE THEIR TYPE (#231 review C4, ARCH-SECURE): the folder is
-- writable by anything, so `read_bounded` refuses a non-regular file, relays
-- every read error, and checks the magic bytes against the extension's media
-- type; `question_content` checks them again before it forms a block. Empty,
-- truncated, text-as-.png or a directory named x.png is a note, never a block.
--
-- Everything above `default_io` is PURE (string work, plus vim.base64 and
-- vim.json for the content and the send guard). The IO functions (save /
-- read_bounded / move_with / delete_with / copy_into / removal_note) take an
-- injectable `io_` table so unit tests run on an in-memory fake with
-- injectable failure (ARCH-MOCK). Every IO function reports what happened —
-- `ok, err` or `n, errs` — and never counts an attempted operation as done.
--
-- `default_io` is MAIN-LOOP ONLY: it uses vim.fn, which a libuv callback
-- refuses. clipboard_image.read_png schedules its on_done before any of it
-- runs.

local chat_slug = require("parley.chat_slug")

local M = {}

M.DIR = "assets"

-- Anthropic's per-image cap is the strictest of the three wires; one constant
-- and one sentence (`too_big`) govern paste (refuse) and send (note).
M.MAX_BYTES = 10 * 1024 * 1024

-- Per request: Gemini's inline total (the strictest) measured on the final
-- JSON-encoded payload, and Anthropic's many-image threshold as the count.
M.MAX_REQUEST_BYTES = 20 * 1024 * 1024
M.MAX_REQUEST_IMAGES = 20

-- Fixed per-image JSON envelope charged by the planner, above any wire's
-- actual envelope (`{"type":"image","source":{...}}` plus the media type).
M.BLOCK_OVERHEAD = 256

M.OMITTED_NOTE = "[An image was attached to this question; it is no longer included.]"

local MEDIA_TYPES = {
    png = "image/png",
    jpg = "image/jpeg",
    jpeg = "image/jpeg",
    gif = "image/gif",
    webp = "image/webp",
}

--- Split a path into directory and basename (string ops only, no vim.fs).
--- A bare basename has no directory: returns nil, basename.
local function split(path)
    local dir, base = tostring(path):match("^(.*)/([^/]+)$")
    if not dir then
        return nil, tostring(path)
    end
    return dir, base
end

--------------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------------

--- The chat's asset key: its timestamp prefix. nil for a file that is not a
--- timestamp-named chat — a plain note has no stable identity to key on.
--- Widening this to notes is the one place a notes-side paste would change.
---@param chat_path string|nil
---@return string|nil ts
function M.key_for(chat_path)
    if chat_path == nil then
        return nil
    end
    local _, base = split(chat_path)
    local ts = chat_slug.parse_filename(base)
    return ts
end

--- Absolute asset folder for a chat, or nil + reason.
---@param chat_path string
---@return string|nil folder
---@return string|nil err
function M.folder_for(chat_path)
    local dir = split(chat_path)
    local ts = M.key_for(chat_path)
    if not dir or not ts then
        return nil, "not a timestamp-named chat: " .. tostring(chat_path)
    end
    return M.folder_in(dir, ts)
end

--- The folder for key `ts` inside `dir` — the destination form movers and
--- export use.
---@param dir string
---@param ts string
---@return string
function M.folder_in(dir, ts)
    return dir .. "/" .. M.DIR .. "/" .. ts
end

--- Link target relative to the chat file.
---@param ts string
---@param filename string
---@return string
function M.relative_path(ts, filename)
    return M.DIR .. "/" .. ts .. "/" .. filename
end

--- The one link shape written into the transcript.
---@param relative string
---@return string
function M.markdown_link(relative)
    return "![](" .. relative .. ")"
end

--- `<stamp>.<ext>`, then `<stamp>-2.<ext>`, … while `exists(name)` is true.
--- Two pastes in one millisecond therefore never collide.
---@param stamp string
---@param ext string
---@param exists fun(name: string): boolean
---@return string
function M.unique_name(stamp, ext, exists)
    local name = stamp .. "." .. ext
    local n = 1
    while exists(name) do
        n = n + 1
        name = stamp .. "-" .. n .. "." .. ext
    end
    return name
end

--- Media type by extension; nil when no wire would accept it.
---@param path string
---@return string|nil
function M.media_type(path)
    local ext = tostring(path):match("%.(%w+)$")
    return ext and MEDIA_TYPES[ext:lower()] or nil
end

--- The one size sentence, for paste refusals and send notes alike.
---@param n integer
---@return string
function M.too_big(n)
    return ("%d bytes exceeds the %d-byte limit"):format(n, M.MAX_BYTES)
end

-- Structural checks per media type (BR-4). One rule for all four formats:
-- the container's records must parse from the first byte to the last with
-- correct boundaries, AND at least one image-bearing record must be present,
-- non-empty, with its mandatory header fields valid (dimensions ≥ 1, the
-- format's fixed-value fields, and a header length that matches its record).
-- A signature, a header, a header+trailer pair, or an image record with no
-- data is not an image — each would otherwise become outbound image content.
-- Every walker is pure and bounded: it reads record lengths and header
-- fields and steps over record bodies, never decoding pixels or verifying
-- CRCs; a record that overruns the buffer, a trailer that is not the last
-- byte, a missing or empty image record, or an out-of-range header field is
-- `false`. `.` in a pattern matches any byte, NUL included.

--- Big-endian u32 at 1-based offset `i` (caller guarantees the bytes exist).
local function u32be(bytes, i)
    local a, b, c, d = bytes:byte(i, i + 3)
    return ((a * 256 + b) * 256 + c) * 256 + d
end

--- Little-endian u32 at 1-based offset `i` (caller guarantees the bytes exist).
local function u32le(bytes, i)
    local a, b, c, d = bytes:byte(i, i + 3)
    return ((d * 256 + c) * 256 + b) * 256 + a
end

--- Big-endian u16 at 1-based offset `i` (caller guarantees the bytes exist).
local function u16be(bytes, i)
    local a, b = bytes:byte(i, i + 1)
    return a * 256 + b
end

--- Little-endian u16 at 1-based offset `i` (caller guarantees the bytes exist).
local function u16le(bytes, i)
    local a, b = bytes:byte(i, i + 1)
    return b * 256 + a
end

-- PNG grammar:  signature(8)  chunk*
--   chunk = length(4 BE) type(4) data(length) crc(4)
-- The first chunk is IHDR with length 13; at least one IDAT carries the
-- image; the last chunk is IEND (length 0) and its end is the end of the
-- buffer.
-- IHDR fields: width(4) height(4) — each 1..2^31-1; bit-depth(1) valid for
-- colour-type(1) per the table below; compression(1) 0; filter(1) 0;
-- interlace(1) 0 or 1. The IDAT chunks must total ≥ 1 byte (a single
-- zero-length IDAT is an empty image), and colour type 3 needs a PLTE chunk
-- (1..256 three-byte entries) before the first IDAT.
local PNG_MAX_DIM = 0x7FFFFFFF
local PNG_DEPTHS = {
    [0] = { [1] = true, [2] = true, [4] = true, [8] = true, [16] = true }, -- greyscale
    [2] = { [8] = true, [16] = true }, -- truecolour
    [3] = { [1] = true, [2] = true, [4] = true, [8] = true }, -- indexed
    [4] = { [8] = true, [16] = true }, -- greyscale + alpha
    [6] = { [8] = true, [16] = true }, -- truecolour + alpha
}
--- Validate the 13 IHDR data bytes at `pos`; returns ok, colour type.
local function png_ihdr(bytes, pos)
    local width, height = u32be(bytes, pos), u32be(bytes, pos + 4)
    local depth, colour, compression, filter, interlace = bytes:byte(pos + 8, pos + 12)
    local depths = PNG_DEPTHS[colour]
    local ok = width >= 1
        and width <= PNG_MAX_DIM
        and height >= 1
        and height <= PNG_MAX_DIM
        and depths ~= nil
        and depths[depth] == true
        and compression == 0
        and filter == 0
        and interlace <= 1
    return ok, colour
end
local function is_png(bytes)
    local n = #bytes
    if bytes:find("^\137PNG\r\n\26\n") == nil then
        return false
    end
    local pos, first, colour, plte, idat_bytes = 9, true, nil, false, 0
    while true do
        if pos + 8 > n + 1 then
            return false -- no room for length + type
        end
        local len = u32be(bytes, pos)
        local kind = bytes:sub(pos + 4, pos + 7)
        local nxt = pos + 12 + len -- past data + crc
        if nxt > n + 1 then
            return false -- chunk overruns the buffer
        end
        if first then
            if kind ~= "IHDR" or len ~= 13 then
                return false
            end
            local ok
            ok, colour = png_ihdr(bytes, pos + 8)
            if not ok then
                return false
            end
            first = false
        elseif kind == "IDAT" then
            idat_bytes = idat_bytes + len
        elseif kind == "PLTE" and idat_bytes == 0 then
            plte = len >= 3 and len <= 768 and len % 3 == 0
        elseif kind == "IEND" then
            return len == 0 and nxt == n + 1 and idat_bytes >= 1 and (colour ~= 3 or plte)
        end
        pos = nxt
    end
end

-- JPEG grammar:  SOI  segment*  SOS  entropy-coded-data  EOI
--   segment = 0xFF marker [length(2 BE) payload(length - 2)]
-- Standalone markers (SOI, EOI, TEM, RST0–7) carry no length; every other
-- marker has a length ≥ 2 that must fit. Fill bytes (extra 0xFF) may precede
-- a marker. A frame header (SOF0–15, excluding DHT/JPG/DAC which share the
-- 0xC range) must precede the first SOS; after SOS the scan runs to the EOI,
-- which is the last two bytes. Stuffed 0xFF00 and RST markers inside the
-- scan are data and are not walked.
-- SOF payload: precision(1) 8 or 12; height(2) ≥ 1 — a zero height is only
-- legal when a DNL segment supplies it later, which no image the wires
-- accept relies on, so it is refused here; width(2) ≥ 1; Nf(1) 1, 3 or 4;
-- then 3 bytes per component, so length = 8 + 3·Nf.
-- SOS payload: Ns(1) 1..4 and ≤ Nf; 2 bytes per component; then 3 fixed
-- bytes, so length = 6 + 2·Ns; at least one scan byte must follow.
local JPEG_STANDALONE = { [0xD8] = true, [0xD9] = true, [0x01] = true }
for m = 0xD0, 0xD7 do
    JPEG_STANDALONE[m] = true
end
local JPEG_NOT_SOF = { [0xC4] = true, [0xC8] = true, [0xCC] = true }
local JPEG_PRECISION = { [8] = true, [12] = true }
local JPEG_COMPONENTS = { [1] = true, [3] = true, [4] = true }
local function is_sof(marker)
    return marker >= 0xC0 and marker <= 0xCF and not JPEG_NOT_SOF[marker]
end
--- Validate the SOF segment whose 0xFF is at `pos` with segment length
--- `len` (the segment is known to fit); returns Nf, or nil when invalid.
local function jpeg_sof(bytes, pos, len)
    if len < 8 then
        return nil
    end
    local nf = bytes:byte(pos + 9)
    if len ~= 8 + 3 * nf or not JPEG_COMPONENTS[nf] or not JPEG_PRECISION[bytes:byte(pos + 4)] then
        return nil
    end
    if u16be(bytes, pos + 5) < 1 or u16be(bytes, pos + 7) < 1 then
        return nil
    end
    return nf
end
local function is_jpeg(bytes)
    local n = #bytes
    if bytes:find("^\255\216") == nil or bytes:sub(-2) ~= "\255\217" then
        return false
    end
    local pos, nf = 3, nil
    while true do
        if bytes:byte(pos) ~= 0xFF then
            return false
        end
        while bytes:byte(pos + 1) == 0xFF do
            pos = pos + 1 -- fill bytes
        end
        local marker = bytes:byte(pos + 1)
        if marker == nil then
            return false
        end
        if marker == 0xDA then
            -- SOS: header segment, then at least one byte of scan data, then EOI.
            if nf == nil or pos + 3 > n then
                return false
            end
            local len = u16be(bytes, pos + 2)
            local scan = pos + 2 + len
            if len < 6 or scan > n - 2 then
                return false
            end
            local ns = bytes:byte(pos + 4)
            return ns >= 1 and ns <= 4 and ns <= nf and len == 6 + 2 * ns
        elseif marker == 0xD9 then
            return false -- EOI before any scan
        elseif JPEG_STANDALONE[marker] then
            pos = pos + 2
        else
            if pos + 3 > n then
                return false
            end
            local len = u16be(bytes, pos + 2)
            if len < 2 or pos + 2 + len > n then
                return false
            end
            if is_sof(marker) then
                nf = jpeg_sof(bytes, pos, len)
                if nf == nil then
                    return false
                end
            end
            pos = pos + 2 + len
        end
    end
end

-- GIF grammar:  header(6)  screen-descriptor(7)  [global-color-table]  block*  trailer
--   block = 0x21 label sub-blocks            (extension)
--         | 0x2C descriptor(9) [local-color-table] lzw-min-code-size sub-blocks
--   sub-blocks = (length(1) data(length))* 0x00
--   color-table = 3 * 2^(size + 1) bytes when the packed byte's high bit is set
-- The trailer 0x3B must be the last byte; at least one image descriptor
-- must be present.
-- Screen descriptor: width(2 LE) height(2 LE) ≥ 1. Image descriptor:
-- left(2) top(2) width(2) height(2) with width/height ≥ 1 and the image
-- inside the logical screen; LZW minimum code size 2..8 (the spec's range —
-- 2 is the floor even for 1-bit images, 8 the ceiling for 256 colours);
-- the image's sub-blocks must carry ≥ 1 data byte in total.
local function gif_color_table(packed)
    if packed >= 0x80 then
        return 3 * 2 ^ (packed % 8 + 1)
    end
    return 0
end
--- Step over sub-blocks starting at `pos`; returns the position after the
--- terminator and the total data bytes, or nil when they overrun.
local function gif_sub_blocks(bytes, pos, n)
    local total = 0
    while true do
        local len = bytes:byte(pos)
        if len == nil then
            return nil
        elseif len == 0 then
            return pos + 1, total
        end
        pos = pos + 1 + len
        total = total + len
        if pos > n then
            return nil
        end
    end
end
local function is_gif(bytes)
    local n = #bytes
    if bytes:find("^GIF8[79]a") == nil or n < 13 then
        return false
    end
    local screen_w, screen_h = u16le(bytes, 7), u16le(bytes, 9)
    if screen_w < 1 or screen_h < 1 then
        return false
    end
    local pos = 14 + gif_color_table(bytes:byte(11))
    local image = false
    while true do
        local introducer = bytes:byte(pos)
        if introducer == 0x3B then
            return pos == n and image
        elseif introducer == 0x21 then
            pos = gif_sub_blocks(bytes, pos + 2, n)
        elseif introducer == 0x2C then
            local packed = bytes:byte(pos + 9)
            if packed == nil then
                return false
            end
            local left, top = u16le(bytes, pos + 1), u16le(bytes, pos + 3)
            local width, height = u16le(bytes, pos + 5), u16le(bytes, pos + 7)
            local code_size_at = pos + 10 + gif_color_table(packed)
            local code_size = bytes:byte(code_size_at)
            if width < 1 or height < 1 or left + width > screen_w or top + height > screen_h then
                return false
            end
            if code_size == nil or code_size < 2 or code_size > 8 then
                return false
            end
            local data
            pos, data = gif_sub_blocks(bytes, code_size_at + 1, n)
            if pos == nil or data < 1 then
                return false
            end
            image = true
        else
            return false
        end
        if pos == nil then
            return false
        end
    end
end

-- WebP grammar:  "RIFF" size(4 LE) "WEBP" chunk*
--   chunk = fourcc(4) length(4 LE) data(length) [pad to even]
-- The RIFF size is the buffer length minus 8 and the chunks walk to the
-- end exactly. A `VP8 ` or `VP8L` chunk with a valid header is the image;
-- a `VP8X` extended header is not — it must be followed by a `VP8 `/`VP8L`
-- chunk (alpha or animation alone is not an image).
-- VP8L data: signature byte 0x2F, then 14-bit width-1, 14-bit height-1,
-- an alpha bit and a 3-bit version that must be 0 — 5 bytes minimum, and
-- the minus-one encoding makes the dimensions ≥ 1 by construction.
-- `VP8 ` data: a 3-byte frame tag whose bit 0 is clear (a key frame — an
-- interframe has nothing to show on its own), the start code 9D 01 2A at
-- bytes 4–6, then 14-bit width and height (each ≥ 1) in two 16-bit LE
-- words — 10 bytes minimum.
-- VP8X data: flags(1), reserved(3), 24-bit canvas width-1 and height-1 —
-- 10 bytes; the canvas dimensions are ≥ 1 by construction, so the header
-- check is that the 10 bytes exist.
local VP8_START_CODE = "\157\1\42"
-- Header bytes are not image data (the invariant every walker enforces: an
-- image-bearing record must carry at least one byte BEYOND its mandatory
-- header — a PNG IDAT byte, a JPEG scan byte, a GIF sub-block byte, a WebP
-- bitstream byte after the VP8L/VP8 header). VP8L: 1 signature + 4 header
-- bytes, so len >= 6.
local function webp_vp8l(bytes, pos, len)
    if len < 6 or bytes:byte(pos) ~= 0x2F then
        return false
    end
    return math.floor(u32le(bytes, pos + 1) / 2 ^ 29) == 0
end
-- VP8: 3-byte frame tag + 3-byte start code + 4 bytes of dims = 10 header
-- bytes; the first partition must follow, so len >= 11.
local function webp_vp8(bytes, pos, len)
    if len < 11 or bytes:byte(pos) % 2 ~= 0 or bytes:sub(pos + 3, pos + 5) ~= VP8_START_CODE then
        return false
    end
    return u16le(bytes, pos + 6) % 16384 >= 1 and u16le(bytes, pos + 8) % 16384 >= 1
end
local WEBP_HEADERS = {
    ["VP8L"] = webp_vp8l,
    ["VP8 "] = webp_vp8,
    ["VP8X"] = function(_, _, len)
        return len >= 10
    end,
}
local function is_webp(bytes)
    local n = #bytes
    if n < 12 or bytes:sub(1, 4) ~= "RIFF" or bytes:sub(9, 12) ~= "WEBP" or u32le(bytes, 5) ~= n - 8 then
        return false
    end
    local pos, bitstream = 13, false
    while pos <= n do
        if pos + 8 > n + 1 then
            return false -- no room for fourcc + length
        end
        local fourcc = bytes:sub(pos, pos + 3)
        local len = u32le(bytes, pos + 4)
        local nxt = pos + 8 + len + len % 2
        if nxt > n + 1 then
            return false -- chunk (or its pad byte) overruns the buffer
        end
        local header = WEBP_HEADERS[fourcc]
        if header then
            if not header(bytes, pos + 8, len) then
                return false
            end
            bitstream = bitstream or fourcc ~= "VP8X"
        end
        pos = nxt
    end
    return bitstream
end

local VALIDATORS = {
    ["image/png"] = is_png,
    ["image/jpeg"] = is_jpeg,
    ["image/gif"] = is_gif,
    ["image/webp"] = is_webp,
}

--- Do these bytes have the structure of a `media_type` image? One rule for
--- every format: the container's records walk from the first byte to the
--- last with correct boundaries, and at least one image-bearing record is
--- present. False for empty, truncated, corrupt, header-only or mismatched
--- bytes and for a type no wire accepts. Record boundaries only; pixels and
--- CRCs are not decoded. PURE.
---@param media_type string|nil
---@param bytes string|nil
---@return boolean
function M.looks_like(media_type, bytes)
    local valid = media_type and VALIDATORS[media_type]
    if not valid or type(bytes) ~= "string" then
        return false
    end
    return valid(bytes) == true
end

--- The one sentence for bytes that fail looks_like.
local function not_an_image(media_type)
    return "not a " .. tostring(media_type) .. " image"
end

--------------------------------------------------------------------------------
-- Attachment grammar (ARCH-SECURE — the transcript is model-writable)
--------------------------------------------------------------------------------

-- A line that is exactly `![…](assets/<ts>/<name>)`, blanks allowed either
-- side, where <ts> is exactly a chat timestamp (no slug) and <name> is
-- [A-Za-z0-9][A-Za-z0-9._-]* without `..` and with an accepted image
-- extension. Anything else — absolute, `..`, URL, backtick, wrong folder,
-- inline in prose, a second link on the line — is prose, never read.
local LINK = "^%s*!%[[^%]]*%]%((" .. M.DIR .. "/([^/%)%s]+)/([^/%)%s]+))%)%s*$"
local NAME = "^[A-Za-z0-9][A-Za-z0-9._%-]*$"

--- Parse one transcript line as an attachment.
---@param line string|nil
---@return table|nil # { path, ts, name, media_type }
function M.parse_attachment(line)
    if line == nil then
        return nil
    end
    local rel, ts, name = tostring(line):match(LINK)
    if not rel then
        return nil
    end
    -- parse_filename returns the timestamp PREFIX; equality rejects a slug.
    if chat_slug.parse_filename(ts) ~= ts then
        return nil
    end
    if not name:match(NAME) or name:find("..", 1, true) then
        return nil
    end
    local media_type = M.media_type(name)
    if not media_type then
        return nil
    end
    return { path = rel, ts = ts, name = name, media_type = media_type }
end

--- Every attachment line in a block of text, in order. The buffer-block
--- rebuild path uses this; the parser applies parse_attachment per line —
--- one grammar, two callers.
---@param text string|nil
---@return table[]
function M.attachments_in(text)
    local out = {}
    if text == nil then
        return out
    end
    for line in (tostring(text) .. "\n"):gmatch("([^\n]*)\n") do
        local att = M.parse_attachment(line)
        if att then
            out[#out + 1] = att
        end
    end
    return out
end

--------------------------------------------------------------------------------
-- Request budget (decision 6: one rule, in serialized bytes, deterministic)
--------------------------------------------------------------------------------

--- Base64 length of `n` raw bytes: ⌈n/3⌉·4.
---@param n integer
---@return integer
function M.encoded_size(n)
    return math.ceil(n / 3) * 4
end

local NOTE_BUDGET = "not sent: request budget"
local NOTE_UNPLANNED = "not sent: not planned"

--- The one note line shape, shared by the planner (to charge it) and by
--- question_content (to emit it).
local function note_line(path, reason)
    return "[attachment " .. path .. " " .. reason .. "]"
end

--- The reason a candidate carries before the budget is consulted: a failed
--- stat or an oversized file is a note whatever the budget says; nil means
--- "an image, if it fits".
local function pre_reason(c, max_bytes)
    if c.size == nil then
        return "could not be read: " .. tostring(c.err or "unknown")
    end
    if c.size > max_bytes then
        return "not sent: " .. M.too_big(c.size)
    end
    return nil
end

--- Decide which attachment OCCURRENCES a request carries. PURE and
--- deterministic; total over well-formed candidates.
---
--- A candidate is one occurrence of a link — `id` is the caller-assigned key
--- ("<order>:<n>", n = the link's position within that question) and must be
--- unique across the list; `path` may repeat, and each repeat is charged and
--- counted on its own (one link = one image block on the wire). A missing or
--- duplicate `id` is a caller bug and raises — silently merging occurrences
--- is exactly the cap bypass this key exists to prevent.
---
--- The budget starts charged with `text_bytes` and with the note every
--- candidate WOULD get if excluded (a conservative margin — an included
--- image keeps its note charge). Then images are taken NEWEST FIRST (highest
--- `order`, then latest position) while `encoded_size(size) + block_overhead`
--- and the image count still fit — a strict prefix: the first image that
--- does not fit closes the request to every older one. A missing size (stat
--- failed) or a size over `max_bytes` is a note and never consumes the count.
--- Text alone over the request limit includes nothing and sets `warning`.
---
---@param candidates table[] # { id, order, path, size|nil, err|nil } in exchange order
---@param text_bytes integer # UTF-8 length of every retained text the request carries
---@param limits table|nil # { max_bytes, max_request_bytes, max_images, block_overhead }
---@return table # { included = { [id] = true }, notes = { [id] = reason }, warning|nil }
function M.plan_budget(candidates, text_bytes, limits)
    limits = limits or {}
    local max_bytes = limits.max_bytes or M.MAX_BYTES
    local max_request = limits.max_request_bytes or M.MAX_REQUEST_BYTES
    local max_images = limits.max_images or M.MAX_REQUEST_IMAGES
    local overhead = limits.block_overhead or M.BLOCK_OVERHEAD

    local plan = { included = {}, notes = {} }
    local used = text_bytes or 0

    -- Charge every note up front; settle the pre-decided ones now.
    local fitting, seen = {}, {}
    for i, c in ipairs(candidates or {}) do
        if type(c.id) ~= "string" or c.id == "" then
            error(("plan_budget: candidate %d (%s) has no id"):format(i, tostring(c.path)))
        end
        if seen[c.id] then
            error(("plan_budget: duplicate candidate id %q"):format(c.id))
        end
        seen[c.id] = true
        local reason = pre_reason(c, max_bytes)
        if reason then
            plan.notes[c.id] = reason
            used = used + #note_line(c.path, reason) + 1
        else
            used = used + #note_line(c.path, NOTE_BUDGET) + 1
            fitting[#fitting + 1] = { c = c, pos = i }
        end
    end

    if used > max_request and (text_bytes or 0) > max_request then
        plan.warning = ("retained text alone is %d bytes, over the %d-byte request limit; no images sent"):format(
            text_bytes, max_request)
    end

    -- Newest first: order descending, then position descending. Sorting a
    -- copy with an explicit tie-break keeps the result deterministic.
    table.sort(fitting, function(a, b)
        local ao, bo = a.c.order or 0, b.c.order or 0
        if ao ~= bo then
            return ao > bo
        end
        return a.pos > b.pos
    end)

    -- A strict prefix: the first image that does not fit (bytes or count)
    -- closes the request to every older one, so an older image is never sent
    -- while a newer one is withheld.
    local count, closed = 0, plan.warning ~= nil
    for _, f in ipairs(fitting) do
        local cost = M.encoded_size(f.c.size) + overhead
        if not closed and count < max_images and used + cost <= max_request then
            plan.included[f.c.id] = true
            used = used + cost
            count = count + 1
        else
            closed = true
            plan.notes[f.c.id] = NOTE_BUDGET
        end
    end
    return plan
end

--- Bytes of the final encoded payload — the number the send guard compares.
---@param payload table
---@return integer
function M.payload_size(payload)
    return #vim.json.encode(payload)
end

--- Does this one table (not its children) carry inline image bytes in any
--- wire's shape? Returns the media type and the base64 field's holder + key
--- so elide_image_data can share the recognition.
local function image_slot(t)
    if type(t) ~= "table" then
        return nil
    end
    if t.type == "image" and type(t.source) == "table" and type(t.source.data) == "string" then
        return t.source.media_type, t.source, "data"
    end
    if type(t.image_url) == "table" and type(t.image_url.url) == "string" and t.image_url.url:sub(1, 5) == "data:" then
        return t.image_url.url:match("^data:([^;,]+)"), t.image_url, "url"
    end
    if type(t.inlineData) == "table" and type(t.inlineData.data) == "string" then
        return t.inlineData.mimeType, t.inlineData, "data"
    end
    return nil
end

--- True when the payload carries inline image bytes anywhere, in any of the
--- three wire shapes (Anthropic `source.data`, OpenAI data-URL
--- `image_url.url`, Gemini `inlineData.data`).
---@param payload any
---@return boolean
function M.has_image(payload)
    if type(payload) ~= "table" then
        return false
    end
    if image_slot(payload) then
        return true
    end
    for _, v in pairs(payload) do
        if type(v) == "table" and M.has_image(v) then
            return true
        end
    end
    return false
end

--------------------------------------------------------------------------------
-- Content blocks
--------------------------------------------------------------------------------

--- Internal (Anthropic-shaped) content for a preserved question: one image
--- block per attachment OCCURRENCE whose `id` is in `plan.included`, first;
--- one text block last. Notes come first in the text — the plan's, then one
--- for any read that fails, overflows or yields bytes that do not look like
--- the declared media type AFTER planning — visible to the model and in the
--- log, never a dangling block. An occurrence the plan never saw (its id is
--- neither included nor noted, or it has no id) is noted as such, not read.
---@param text string
---@param attachments table[]|nil # { id, path, media_type } — `id` as given to plan_budget
---@param plan table|nil # from plan_budget
---@param read fun(rel: string): string|nil, string|nil # the bounded reader
---@return string|table
function M.question_content(text, attachments, plan, read)
    if not attachments or #attachments == 0 then
        return text
    end
    local included = plan and plan.included or {}
    local planned_notes = plan and plan.notes or {}
    local blocks, notes = {}, {}
    for _, att in ipairs(attachments) do
        if att.id ~= nil and included[att.id] then
            local bytes, err = read(att.path)
            if not bytes then
                notes[#notes + 1] = note_line(att.path, "could not be read: " .. tostring(err))
            elseif #bytes > M.MAX_BYTES then
                notes[#notes + 1] = note_line(att.path, "not sent: " .. M.too_big(#bytes))
            elseif not M.looks_like(att.media_type, bytes) then
                notes[#notes + 1] = note_line(att.path, not_an_image(att.media_type))
            else
                blocks[#blocks + 1] = {
                    type = "image",
                    source = { type = "base64", media_type = att.media_type, data = vim.base64.encode(bytes) },
                }
            end
        else
            notes[#notes + 1] = note_line(att.path, att.id ~= nil and planned_notes[att.id] or NOTE_UNPLANNED)
        end
    end
    local body = text
    if #notes > 0 then
        body = table.concat(notes, "\n") .. "\n" .. text
    end
    if #blocks == 0 then
        return body
    end
    blocks[#blocks + 1] = { type = "text", text = body }
    return blocks
end

--- The memory-window placeholder for a summarized question, plus the note
--- when an image was attached (so the model is not left inferring it).
---@param omit_user_text string
---@param attachments table[]|nil
---@return string
function M.omitted_text(omit_user_text, attachments)
    if attachments and #attachments > 0 then
        return omit_user_text .. "\n" .. M.OMITTED_NOTE
    end
    return omit_user_text
end

--------------------------------------------------------------------------------
-- Log elision (decision 14: logs never hold the bytes)
--------------------------------------------------------------------------------

--- Raw byte count of a base64 string (padding-aware).
local function decoded_size(b64)
    local padding = #b64:match("=*$")
    return math.floor(#b64 * 3 / 4) - padding
end

--- Deep copy of `value` with every inline image payload — Anthropic
--- `source.data`, OpenAI data-URL `image_url.url`, Gemini `inlineData.data` —
--- replaced by `"<mime, N bytes>"`. Non-tables pass through.
---@param value any
---@return any
function M.elide_image_data(value)
    if type(value) ~= "table" then
        return value
    end
    local out = {}
    for k, v in pairs(value) do
        out[k] = M.elide_image_data(v)
    end
    local mime, holder, key = image_slot(out)
    if holder then
        local b64 = holder[key]
        if key == "url" then
            b64 = b64:match("^data:[^,]*,(.*)$") or ""
        end
        holder[key] = ("<%s, %d bytes>"):format(mime or "image", decoded_size(b64))
    end
    return out
end

--------------------------------------------------------------------------------
-- IO shell. Every function below takes `io_` (defaults to default_io).
-- MAIN LOOP ONLY: default_io uses vim.fn, which a libuv callback refuses.
--------------------------------------------------------------------------------

--- Size of a REGULAR file, or nil + reason. A directory, socket, fifo or
--- device is not something to read as an image (io.open on a directory
--- succeeds on macOS; the failure would surface only at f:read, or not at
--- all for an empty read). One check, shared by stat and read.
local function regular_size(p)
    local st, err = vim.uv.fs_stat(p)
    if not st then
        return nil, err or ("cannot stat " .. p)
    end
    if st.type ~= "file" then
        return nil, "not a regular file: " .. p
    end
    return st.size
end

M.default_io = {
    exists = function(p)
        return vim.fn.filereadable(p) == 1 or vim.fn.isdirectory(p) == 1
    end,
    -- Size in bytes of a regular file, or nil + reason. Stat before read
    -- keeps a read bounded and keeps a directory out of a read.
    stat = regular_size,
    -- "p": create parents; an existing directory is not an error.
    mkdir = function(p)
        local ok, err = pcall(vim.fn.mkdir, p, "p")
        if not ok then
            return false, tostring(err)
        end
        if err ~= 1 then
            return false, "mkdir failed: " .. p
        end
        return true
    end,
    -- Checks write AND close; a partial file is removed on either failure so
    -- nothing on disk claims a success that did not happen.
    write = function(p, bytes)
        local f, err = io.open(p, "wb")
        if not f then
            return false, tostring(err)
        end
        local wok, werr = f:write(bytes)
        local cok, cerr = f:close()
        if not wok or not cok then
            os.remove(p)
            return false, tostring(wok and cerr or werr)
        end
        return true
    end,
    -- At most `max` bytes of a regular file. A failed f:read is nil, err —
    -- never "". Only a genuinely empty regular file reads as "" (f:read(n)
    -- yields a bare nil at EOF; a failure carries a message).
    read = function(p, max)
        local size, serr = regular_size(p)
        if not size then
            return nil, serr
        end
        local f, err = io.open(p, "rb")
        if not f then
            return nil, tostring(err)
        end
        local data, rerr = f:read(max)
        f:close()
        if data == nil then
            if rerr then
                return nil, "read failed: " .. tostring(rerr)
            end
            return ""
        end
        return data
    end,
    rename = function(a, b)
        local ok, err = os.rename(a, b)
        if not ok then
            return nil, tostring(err)
        end
        return true
    end,
    -- Destructive: callers pass only a path folder_for constructed.
    -- vim.fn.delete(…, "rf") does not follow symlinks.
    remove_tree = function(p)
        if vim.fn.delete(p, "rf") ~= 0 then
            return nil, "delete failed: " .. p
        end
        return true
    end,
    -- Plain files directly inside `p`, sorted; a missing directory lists
    -- nothing (checked first: readdir echoes E484 even under pcall).
    list = function(p)
        local out = {}
        if vim.fn.isdirectory(p) ~= 1 then
            return out
        end
        for _, name in ipairs(vim.fn.readdir(p)) do
            if vim.fn.filereadable(p .. "/" .. name) == 1 then
                out[#out + 1] = name
            end
        end
        table.sort(out)
        return out
    end,
    now = function()
        return require("parley.logger").now()
    end,
}

--- THE writer. Saves `bytes` as a new asset of `chat_path` and returns the
--- link target relative to the chat file plus the absolute path. Refuses a
--- non-chat path and an oversized image before touching disk; a failed mkdir
--- writes nothing; a failed write leaves no partial file (default_io.write
--- removes it).
---@param chat_path string
---@param bytes string
---@param ext string # e.g. "png"
---@param io_ table|nil
---@return string|nil rel
---@return string|nil abs
---@return string|nil err
function M.save(chat_path, bytes, ext, io_)
    io_ = io_ or M.default_io
    local folder, err = M.folder_for(chat_path)
    if not folder then
        return nil, nil, err
    end
    if #bytes > M.MAX_BYTES then
        return nil, nil, M.too_big(#bytes)
    end
    local mok, merr = io_.mkdir(folder)
    if not mok then
        return nil, nil, "could not create " .. folder .. ": " .. tostring(merr)
    end
    local name = M.unique_name(io_.now(), ext, function(n)
        return io_.exists(folder .. "/" .. n)
    end)
    local abs = folder .. "/" .. name
    local wok, werr = io_.write(abs, bytes)
    if not wok then
        return nil, nil, "could not write " .. abs .. ": " .. tostring(werr)
    end
    return M.relative_path(M.key_for(chat_path), name), abs
end

--- Bytes of an asset named by its transcript-relative path, bounded and
--- checked: stat first (a non-regular file or one over MAX_BYTES → refused
--- without reading), then read at most MAX_BYTES + 1 and check the size
--- again in case the file grew, then check the bytes begin with the
--- signature of the media type the extension declares (`looks_like`) — an
--- empty, truncated, or mismatched file is `nil, "not a <mime> image"`. The
--- relative path must stay inside the chat's directory — the grammar already
--- guarantees that for parsed lines; this is the second lock on the door.
---@param chat_path string
---@param relative string
---@param io_ table|nil
---@return string|nil bytes
---@return string|nil err
function M.read_bounded(chat_path, relative, io_)
    io_ = io_ or M.default_io
    local dir = split(chat_path)
    if not dir then
        return nil, "chat path has no directory: " .. tostring(chat_path)
    end
    if relative == nil or relative == "" or relative:sub(1, 1) == "/" or relative:find("..", 1, true) then
        return nil, "not a chat-relative asset path: " .. tostring(relative)
    end
    local p = dir .. "/" .. relative
    local size, serr = io_.stat(p)
    if not size then
        return nil, serr
    end
    if size > M.MAX_BYTES then
        return nil, M.too_big(size)
    end
    local bytes, rerr = io_.read(p, M.MAX_BYTES + 1)
    if not bytes then
        return nil, rerr
    end
    if #bytes > M.MAX_BYTES then
        return nil, M.too_big(#bytes)
    end
    local media_type = M.media_type(relative)
    if not M.looks_like(media_type, bytes) then
        return nil, not_an_image(media_type)
    end
    return bytes
end

--- The one clash rule the pre-check and move_with share: the chat's folder
--- (when it exists) and where it goes under `dst_dir`, or nil + err when the
--- destination is taken. nil alone means there is nothing to move.
---@param chat_src string
---@param dst_dir string
---@param io_ table|nil
---@return string|nil src
---@return string|nil dst_or_err
function M.move_conflict(chat_src, dst_dir, io_)
    io_ = io_ or M.default_io
    local src = M.folder_for(chat_src)
    if not src or not io_.exists(src) then
        return nil
    end
    local dst = M.folder_in(dst_dir, M.key_for(chat_src))
    if io_.exists(dst) then
        return nil, "asset folder already exists: " .. dst
    end
    return src, dst
end

--- Carry the folder when its chat moves. No folder → true, nothing to do;
--- clash → nil, err with nothing done; mkdir/rename failure → nil, err with
--- the source untouched (the caller reports a stranded folder).
---@param chat_src string
---@param chat_dst string
---@param io_ table|nil
---@return boolean|nil ok
---@return string|nil err
function M.move_with(chat_src, chat_dst, io_)
    io_ = io_ or M.default_io
    local dst_dir = split(chat_dst)
    if not dst_dir then
        return nil, "destination has no directory: " .. tostring(chat_dst)
    end
    local src, dst = M.move_conflict(chat_src, dst_dir, io_)
    if not src then
        if dst then
            return nil, dst -- the clash message
        end
        return true
    end
    local parent = dst_dir .. "/" .. M.DIR
    local mok, merr = io_.mkdir(parent)
    if not mok then
        return nil, "could not create " .. parent .. ": " .. tostring(merr)
    end
    local rok, rerr = io_.rename(src, dst)
    if not rok then
        return nil, "could not move " .. src .. ": " .. tostring(rerr)
    end
    return true
end

--- Remove the folder with its chat. Only a path folder_for constructed from
--- a chat the caller is already deleting; a non-chat path or a missing folder
--- removes nothing and is true. A failed removal is nil, err — the folder
--- stays for the next delete; the caller's file deletion still proceeds.
---@param chat_path string
---@param io_ table|nil
---@return boolean|nil ok
---@return string|nil err
function M.delete_with(chat_path, io_)
    io_ = io_ or M.default_io
    local folder = M.folder_for(chat_path)
    if not folder or not io_.exists(folder) then
        return true
    end
    local ok, err = io_.remove_tree(folder)
    if not ok then
        return nil, "could not remove " .. folder .. ": " .. tostring(err)
    end
    return true
end

--- What a delete prompt appends so it names the folder it removes:
--- `" and assets/<ts>/ (N files)"`, or `""` when there is no folder.
---@param chat_path string
---@param io_ table|nil
---@return string
function M.removal_note(chat_path, io_)
    io_ = io_ or M.default_io
    local folder = M.folder_for(chat_path)
    if not folder or not io_.exists(folder) then
        return ""
    end
    local n = #io_.list(folder)
    return (" and %s/%s/ (%d file%s)"):format(M.DIR, M.key_for(chat_path), n, n == 1 and "" or "s")
end

--- Copy the folder's files to `<export_dir>/assets/<ts>/` so exported links
--- keep resolving. Copies, never moves. `n` counts successful writes only;
--- every failed mkdir, stat, read or write is an entry in `errs`.
---@param chat_path string
---@param export_dir string
---@param io_ table|nil
---@return integer n
---@return string[] errs
function M.copy_into(chat_path, export_dir, io_)
    io_ = io_ or M.default_io
    local errs = {}
    local folder = M.folder_for(chat_path)
    if not folder or not io_.exists(folder) then
        return 0, errs
    end
    local dst = M.folder_in(export_dir, M.key_for(chat_path))
    local mok, merr = io_.mkdir(dst)
    if not mok then
        errs[#errs + 1] = "could not create " .. dst .. ": " .. tostring(merr)
        return 0, errs
    end
    local n = 0
    for _, name in ipairs(io_.list(folder)) do
        local src = folder .. "/" .. name
        local size, serr = io_.stat(src)
        local bytes, rerr
        if size then
            bytes, rerr = io_.read(src, size)
        end
        if not bytes then
            errs[#errs + 1] = "could not read " .. src .. ": " .. tostring(serr or rerr)
        else
            local wok, werr = io_.write(dst .. "/" .. name, bytes)
            if not wok then
                errs[#errs + 1] = "could not write " .. dst .. "/" .. name .. ": " .. tostring(werr)
            else
                n = n + 1
            end
        end
    end
    return n, errs
end

return M
