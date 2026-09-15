-- Tool dispatcher — the DRY safety layer between response_tools and
-- individual handler functions.
--
-- Handlers (lua/parley/tools/builtin/*.lua) are pure. They know
-- nothing about cwd-scope, symlink resolution, truncation, or
-- error wrapping. Every safety concern lives HERE so there's
-- exactly one place to audit and one place to fix.
--
-- SINGLE source for each invariant:
--   - read base + confinement:    resolve_read_path
--   - write-root confinement:     resolve_path_in_cwd
--   - result size cap:            truncate / truncate_preserving_footer (M5)
--   - pcall-guarded handler call: execute_call
--   - dirty-buffer guard:         check_dirty_buffer (M5)
--   - pre-image capture:          ensure_backup (M5)
--   - post-write reload:          _checktime_if_loaded (M5)

local M = {}

local types = require("parley.tools.types")

--------------------------------------------------------------------------------
-- Path resolution
--------------------------------------------------------------------------------

-- Resolve a configured read root to a canonical absolute path. Roots may be
-- absolute (`/x`), home-relative (`~/x`, `~` expanded), or relative to cwd
-- (`../`, `sub/dir`). Returns the realpath, the normalized path if it does not
-- resolve, or nil for an invalid root. (#140)
-- Missing nested leaves inherit the identity of their nearest existing
-- ancestor. A dangling symlink or non-ENOENT lookup failure is not absence.
function M.canonical_path(path)
    if type(path)~='string' or path=='' or #path>4096 or path:find('%z')then return nil end
    local current=vim.fs.normalize(path)
    if current:sub(1,1)~='/'then return nil end
    local suffix={}
    while true do
        local real=vim.loop.fs_realpath(current)
        if real then
            for i=#suffix,1,-1 do real=real:gsub('/+$','')..'/'..suffix[i]end
            return real
        end
        local stat,err,code=vim.loop.fs_lstat(current)
        if stat or not (code=='ENOENT' or tostring(err):match('^ENOENT'))then return nil end
        local parent=vim.fs.dirname(current)
        if not parent or parent==current then return nil end
        suffix[#suffix+1]=vim.fs.basename(current);current=parent
    end
end

local function resolve_root(root, cwd)
    if type(root) ~= "string" or root == "" then
        return nil
    end
    if root:sub(1, 1) == "~" then
        root = vim.fn.expand(root)
    end
    local abs = root:sub(1, 1) == "/" and vim.fs.normalize(root)
        or vim.fs.normalize(cwd .. "/" .. root)
    return M.canonical_path(abs)
end

--- Resolve a possibly-relative path against cwd, normalize, resolve
--- symlinks via fs_realpath, and reject anything whose real path
--- escapes cwd (and every configured read root).
---
--- Handles the three cases the tool loop needs:
---
---   1. Existing file inside cwd → returns canonical realpath
---   2. Existing file outside cwd (or symlink resolving outside) → rejected
---   3. NEW file (doesn't exist yet) inside cwd → returns
---      `realpath(parent) .. "/" .. basename`. This is what
---      write_file needs when creating a fresh file: the file
---      itself doesn't exist, but its parent dir does, and that
---      parent must be inside cwd.
---
--- `allowed_roots` (read tools only, #140): extra roots a path may resolve
--- under, in addition to cwd. Each is resolved + symlink-canonicalized, so a
--- symlink escaping every root is still rejected. nil/empty → cwd-only.
---
--- Returns `abs_path` on success, or `(nil, err_msg)` on rejection.
---
--- @param path string
--- @param cwd string
--- @param allowed_roots string[]|nil  extra read roots (absolute/~/relative-to-cwd)
--- @return string|nil abs_path
--- @return string|nil err_msg
function M.resolve_path_in_cwd(path, cwd, allowed_roots)
    if type(path) ~= "string" or path == "" then
        return nil, "path must be a non-empty string"
    end

    -- Normalize the joined path lexically first, so "../" and "./"
    -- segments are collapsed before we hit the filesystem.
    local joined
    if path:sub(1, 1) == "/" then
        joined = vim.fs.normalize(path)
    else
        joined = vim.fs.normalize(cwd .. "/" .. path)
    end

    -- Resolve existing symlink ancestors before admitting missing descendants.
    local real_path = M.canonical_path(joined)
    if not real_path then return nil, "cannot resolve path: " .. path end

    -- Resolve the cwd too so the comparison is between two canonical
    -- absolute paths (handles symlinked /tmp → /private/tmp on macOS).
    local real_cwd = M.canonical_path(cwd)
    if not real_cwd then return nil,"invalid working directory" end

    -- Allowed base dirs: cwd, plus any configured read roots (#140). A path is
    -- inside a base iff it equals the base OR starts with base + "/". String
    -- comparison is safe because both sides are canonical fs_realpath outputs.
    local bases = { real_cwd }
    for _, root in ipairs(allowed_roots or {}) do
        local r = resolve_root(root, cwd)
        if r then
            table.insert(bases, r)
        end
    end

    for _, base in ipairs(bases) do
        if real_path == base or base == "/" or real_path:sub(1, #base + 1) == base .. "/" then
            return real_path
        end
    end

    if allowed_roots then
        return nil, "path outside working directory and configured read roots: "
            .. path .. " (add a root to parley `tool_read_roots` to allow it)"
    end
    return nil, "path outside working directory: " .. path
end

--- Read-side resolver (#192): resolve `path` against `cwd` (the neighborhood
--- write root — the single base), confine the realpath to cwd ∪ read_roots,
--- and require the target to exist (reads never synthesize a new-file leaf).
--- Existence is checked up front so every not-found flavor (missing file,
--- missing parent, dangling symlink) reports the path AS TYPED; base +
--- confinement then delegate to resolve_path_in_cwd — one mechanism for
--- reads and writes, reads differing only by extra roots + existence.
function M.resolve_read_path(path, cwd, read_roots)
    if type(path) ~= "string" or path == "" then
        return nil, "path must be a non-empty string"
    end
    local joined = path:sub(1, 1) == "/" and vim.fs.normalize(path)
        or vim.fs.normalize(cwd .. "/" .. path)
    if not vim.loop.fs_realpath(joined) then
        return nil, "read path not found: " .. path
    end
    return M.resolve_path_in_cwd(path, cwd, read_roots or {})
end

--------------------------------------------------------------------------------
-- Result truncation
--------------------------------------------------------------------------------

--- Byte-length truncation with a trailing marker.
---
--- Used by execute_call to cap the size of each ToolResult at
--- `opts.max_bytes` (default 100KB via the agent config). M5 will
--- add a metadata-preserving variant (truncate_preserving_footer)
--- that write_file uses to keep its `pre-image:` footer intact.
---
--- Pure. Handles nil content as empty string.
---
--- @param content string|nil
--- @param max_bytes number
--- @return string
function M.truncate(content, max_bytes)
    content = content or ""
    if #content <= max_bytes then return content end
    local omitted = #content - max_bytes
    return content:sub(1, max_bytes) .. string.format("\n... [truncated: %d bytes omitted]", omitted)
end

-- #139: horizontal output pager. Window `content` to lines [offset, offset+limit)
-- (offset 1-indexed) and, when the window doesn't cover the whole output, append a
-- footer naming the true total + how to page/narrow. Pure. Returns the windowed
-- string (with footer) and the total line count.
M.PAGE_DEFAULT_LIMIT = 200
M.PAGE_MAX_LIMIT = 2000

function M.page_lines(content, offset, limit)
    content = content or ""
    local lines = vim.split(content, "\n", { plain = true })
    -- A trailing newline yields a spurious empty final element; drop it so the
    -- count matches the visible lines.
    if #lines > 1 and lines[#lines] == "" then
        table.remove(lines)
    end
    local total = #lines
    offset = math.max(1, math.floor(offset or 1))
    limit = math.max(1, math.floor(limit or M.PAGE_DEFAULT_LIMIT))

    if offset > total then
        return "... [no lines at offset " .. offset .. "; output has " .. total .. " line(s)]", total
    end

    local last = math.min(offset + limit - 1, total)
    local window = {}
    for i = offset, last do
        window[#window + 1] = lines[i]
    end
    local text = table.concat(window, "\n")

    local windowed = (offset > 1) or (last < total)
    if windowed then
        local note = (last < total)
            and (" — pass offset=" .. (last + 1) .. " for the next page, or narrow your query")
            or " — end of output"
        text = text .. "\n... [lines " .. offset .. "-" .. last .. " of " .. total .. note .. "]"
    end
    return text, total
end

--------------------------------------------------------------------------------
-- Handler invocation
--------------------------------------------------------------------------------

local function inside(base,path)return base=='/' or path==base or path:sub(1,#base+1)==base..'/'end
local function prepare_input(call,def,policy,opts)
    local input=vim.deepcopy(call.input or {})
    if policy then
        if def.default_path and input.path==nil and input.file_path==nil and input.paths==nil then input.path=def.default_path end
        local function resolve(path)
            local abs,err
            if def.kind=='write'then abs,err=M.resolve_path_in_cwd(path,policy.write_root)
            else abs,err=M.resolve_read_path(path,policy.write_root,policy.read_roots or {})end
            if not abs then return nil,err end
            if opts.private_directory and inside(opts.private_directory,abs)then return nil,'private answer recovery path is not a tool resource'end
            return abs
        end
        for _,key in ipairs({'path','file_path'})do
            if input[key]~=nil then
                local abs,err=resolve(input[key]);if not abs then return nil,err end;input[key]=abs
            end
        end
        if input.paths~=nil then
            if type(input.paths)~='table'then return nil,'paths must be an array of strings'end
            local count=0;for k in pairs(input.paths)do
                count=count+1;if type(k)~='number' or k<1 or k%1~=0 or count>32 then return nil,'invalid paths'end
            end
            local paths={}
            for i=1,count do local abs,err=resolve(input.paths[i]);if not abs then return nil,err end;paths[i]=abs end
            input.paths=paths
        end
    end
    local page
    if types.is_pageable(def)then
        page={offset=tonumber(input.offset) or 1,limit=math.min(tonumber(input.limit) or opts.page_limit or M.PAGE_DEFAULT_LIMIT,M.PAGE_MAX_LIMIT)}
        if page.offset~=page.offset or page.limit~=page.limit or math.abs(page.offset)==math.huge or math.abs(page.limit)==math.huge then return nil,'invalid page'end
        input.offset=nil;input.limit=nil
    end
    return input,page
end
local function normalize(call,page,opts,result,evidence)
    if type(result)~='table' or type(result.content)~='string' then
        result={content='handler returned invalid result',is_error=true}
    else result=vim.deepcopy(result)end
    result.id=call.id;result.name=call.name
    if page and not result.is_error then result.content=M.page_lines(result.content,page.offset,page.limit)end
    local footer
    if evidence and evidence.backup_confirmed==true and type(evidence.backup_path)=='string' then
        footer='\npre-image: '..evidence.backup_path
        if result.content:sub(-#footer)==footer then result.content=result.content:sub(1,-#footer-1)end
    end
    local budget=opts.max_bytes
    if footer and budget and #footer>budget then
        result.content=('Confirmed backup path exceeds result limit'):sub(1,budget)
        result.is_error=true;result.truncated=true;return result
    end
    if budget then
        budget=budget-(footer and #footer or 0)
        if #result.content>budget then
            local marker=string.format('\n... [truncated: %d bytes omitted]',#result.content)
            local keep=math.max(0,budget-#marker)
            for _=1,3 do
                marker=string.format('\n... [truncated: %d bytes omitted]',#result.content-keep)
                keep=math.max(0,budget-#marker)
            end
            result.content=#marker<=budget and result.content:sub(1,keep)..marker or result.content:sub(1,budget)
            result.truncated=true
        end
    end
    if footer then result.content=result.content..footer end
    return result
end

--- Execute a ToolCall against the registered handler, with:
---   - registry lookup (is_error on unknown name)
---   - pcall around handler (is_error on raise)
---   - non-table return guard (is_error on misbehaving handler)
---   - id/name stamping on the returned result
---   - byte-length truncation when opts.max_bytes is set
---
--- The returned ToolResult is ALWAYS well-shaped even when things
--- go wrong — the tool loop driver can serialize it directly without
--- further checks.
---
--- @param call ToolCall { id, name, input }
--- @param tools_registry table module exposing `get(name)` (parley.tools)
--- @param opts table|nil { max_bytes?: number, root_policy?: RootPolicy, cwd?: string, read_roots?: string[] }
--- @return ToolResult
function M.execute_call(call, tools_registry, opts)
    opts = opts or {}
    local policy = opts.root_policy
    if not policy and opts.cwd then
        policy = require("parley.neighborhood").policy_from_roots(opts.cwd, nil, opts.read_roots)
    end

    local def = tools_registry.get(call.name)
    if not def then
        return {
            id = call.id,
            name = call.name,
            content = "Tool '" .. call.name .. "' is not available on this client. Please continue without it.",
            is_error = true,
        }
    end

    local input,page=prepare_input(call,def,policy,opts)
    if not input then return {id=call.id,name=call.name,content=page,is_error=true}end

    -- HANDLER invocation, pcall-guarded. A raising handler becomes an
    -- error ToolResult rather than propagating the error up to the
    -- tool loop (which would leave an orphan 🔧: block and break the
    -- cancel-cleanup invariant).
    local ok, result = pcall(def.handler, input, { root_policy = policy })
    if not ok then
        return {
            id = call.id,
            name = call.name,
            content = "handler error: " .. tostring(result),
            is_error = true,
        }
    end
    if type(result) ~= "table" then
        return {
            id = call.id,
            name = call.name,
            content = "handler returned non-table: " .. type(result),
            is_error = true,
        }
    end

    return normalize(call,page,opts,result)
end

-- Capabilities and preparation receipts are private. Public copies carry no
-- authority to replace a captured definition or normalization policy.
local profiles=setmetatable({},{__mode='k'})
local preparations=setmetatable({},{__mode='k'})
function M.capture(definitions,opts)
    if type(definitions)~='table' or type(opts)~='table' or type(opts.root_policy)~='table'then return nil,'captured root policy required'end
    local policy=vim.deepcopy(opts.root_policy)
    policy.write_root=M.canonical_path(policy.write_root)
    if not policy.write_root then return nil,'invalid write root'end
    local roots={}
    for _,root in ipairs(policy.read_roots or {})do
        local canonical=resolve_root(root,policy.write_root);if not canonical then return nil,'invalid read root'end
        roots[#roots+1]=canonical
    end
    policy.read_roots=roots
    local context={root_policy=policy,cwd=policy.write_root}
    for _,key in ipairs({'buf','chat_roots','help_root','help_catalog','max_file_bytes','max_bytes'})do
        context[key]=vim.deepcopy(opts[key])
    end
    local private=opts.private_directory or opts.state_dir and require('parley.recovery_paths').directory(opts.state_dir)
    if private then context.private_directory=M.canonical_path(private);if not context.private_directory then return nil,'invalid private directory'end end
    if context.help_root then context.help_root=M.canonical_path(context.help_root);if not context.help_root then return nil,'invalid help root'end end
    if context.chat_roots then
        local filtered={}
        for _,entry in ipairs(context.chat_roots)do
            local path=type(entry)=='table' and entry.dir or entry
            local resolved=M.resolve_path_in_cwd(path,policy.write_root,policy.read_roots)
            if resolved and not (context.private_directory and inside(context.private_directory,resolved))then
                if type(entry)=='table'then entry.dir=resolved;filtered[#filtered+1]=entry else filtered[#filtered+1]=resolved end
            end
        end
        context.chat_roots=filtered
    end
    local options={max_bytes=opts.max_bytes,page_limit=opts.page_limit,private_directory=context.private_directory}
    for _,key in ipairs({'max_bytes','page_limit'})do
        local value=options[key]
        if value~=nil and (type(value)~='number' or value<1 or value>=math.huge or value%1~=0)then return nil,'invalid '..key end
    end
    local defs={};local count=0
    for _,def in pairs(definitions)do
        count=count+1
        if count>128 then return nil,'too many tool capabilities'end
        local valid,why=types.validate_definition(def);if not valid then return nil,why end
        if type(def.execute_async)~='function'then return nil,'tool lacks asynchronous execution: '..def.name end
        if defs[def.name]then return nil,'duplicate tool capability'end
        defs[def.name]=vim.deepcopy(def)
    end
    local profile={};profiles[profile]={definitions=defs,context=context,options=options};return profile
end
function M.context(profile)return vim.deepcopy(assert(profiles[profile],'invalid captured tool profile').context)end
function M.capabilities(profile)
    local p=assert(profiles[profile],'invalid captured tool profile');local out={}
    for name,def in pairs(p.definitions)do out[name]={execute_async=def.execute_async,config=vim.deepcopy(def.config or {})}end
    return out
end
function M.prepare(profile,call)
    local p=profiles[profile];if not p then return nil,'invalid captured tool profile'end
    local valid,why=types.validate_call(call);if not valid then return nil,why end
    local def=p.definitions[call.name];if not def then return nil,'tool not in captured capabilities'end
    local input,page=prepare_input(call,def,p.context.root_policy,p.options)
    if not input then return nil,page end
    local claims={{scope='global',mode='write'}}
    if def.resources then
        local resource_context=vim.deepcopy(p.context);resource_context.config=vim.deepcopy(def.config or {})
        local ok,value=pcall(def.resources,vim.deepcopy(input),resource_context)
        if not ok or type(value)~='table'then return nil,'invalid tool resource declaration'end
        claims={};local count=0
        for k in pairs(value)do
            count=count+1;if type(k)~='number' or k<1 or k%1~=0 or count>32 then return nil,'invalid tool resource claims'end
        end
        for i=1,count do
            local claim=value[i]
            if type(claim)~='table' or (claim.mode~='read' and claim.mode~='write')then return nil,'invalid resource mode'end
            if claim.scope=='global' then
                if claim.mode~='write' or claim.path~=nil then return nil,'invalid global claim'end
                claims[i]={scope='global',mode='write'}
            else
                if claim.scope~='file' and claim.scope~='subtree'then return nil,'invalid resource scope'end
                local roots=claim.mode=='read' and p.context.root_policy.read_roots or nil
                local path,err=M.resolve_path_in_cwd(claim.path,p.context.cwd,roots)
                if not path and claim.mode=='read' and def.name=='parley_help' and p.context.help_root then
                    path,err=M.resolve_path_in_cwd(claim.path,p.context.help_root)
                end
                if not path then return nil,err end
                if p.context.private_directory and inside(p.context.private_directory,path)then return nil,'private answer recovery resource'end
                claims[i]={scope=claim.scope,mode=claim.mode,path=path}
            end
        end
    end
    local token={};preparations[token]={call={id=call.id,name=call.name},page=page,options=p.options}
    return {input=input,claims=claims,token=token}
end
function M.normalize(token,result,evidence)
    local p=assert(preparations[token],'invalid tool preparation receipt')
    return normalize(p.call,p.page,p.options,result,evidence)
end

return M
