-- `find` — shell out to the local `find` command.
--
-- Exposes the system's find command directly. The tool description
-- advertises which version is available so Claude adapts its syntax.

local function detect_find()
    if vim.fn.executable("find") == 1 then
        -- macOS find doesn't support --version; just identify it by OS
        local uname = vim.fn.system("uname -s"):gsub("%s+$", "")
        if uname == "Darwin" then
            return "find", "BSD find (macOS)"
        else
            local version = vim.fn.system("find --version 2>&1"):match("[^\n]+") or "find"
            return "find", version
        end
    end
    return nil, nil
end

local find_cmd, find_version = detect_find()
local argv = require("parley.tools.builtin.argv")

local ALLOWED_FIELDS = {
    path = true,
    name = true,
    iname = true,
    type = true,
    maxdepth = true,
    mindepth = true,
}

local function build_description()
    if find_cmd then
        return "Search for files and directories using the system find command (" .. find_version .. "). "
            .. "Use structured fields: path, name/iname, type, maxdepth, and mindepth. "
            .. "Example: { path = '.', name = '*.lua', type = 'f' }. "
            .. "Paths are confined to the working directory and configured read roots."
    else
        return "Search for files and directories. No find command available on this system."
    end
end

return {
    name = "find",
    kind = "read",
    description = build_description(),
    input_schema = {
        type = "object",
        properties = {
            path = {
                type = "string",
                description = "Directory path to search. Relative to the working directory or absolute.",
            },
            name = {
                type = "string",
                description = "Find entries whose basename matches this pattern, e.g. '*.lua'.",
            },
            iname = {
                type = "string",
                description = "Case-insensitive basename pattern.",
            },
            type = {
                type = "string",
                description = "Entry type: f (file), d (directory), or l (symlink).",
            },
            maxdepth = {
                type = "integer",
                description = "Maximum directory depth.",
            },
            mindepth = {
                type = "integer",
                description = "Minimum directory depth.",
            },
        },
        required = { "path" },
    },
    handler = function(input)
        input = input or {}
        local ok_fields, fields_err = argv.reject_unknown_fields(input, ALLOWED_FIELDS)
        if not ok_fields then
            return {
                content = fields_err,
                is_error = true,
                name = "find",
            }
        end

        local path = input.path
        if type(path) ~= "string" or path == "" then
            return {
                content = "missing or invalid required field: path",
                is_error = true,
                name = "find",
            }
        end

        if not find_cmd then
            return {
                content = "no find command available on this system",
                is_error = true,
                name = "find",
            }
        end

        local cmd = { find_cmd, path }
        local maxdepth = argv.nonnegative_int(input.maxdepth, "maxdepth")
        if input.maxdepth ~= nil and maxdepth == nil then
            return { content = "maxdepth must be a non-negative integer", is_error = true, name = "find" }
        end
        local mindepth = argv.nonnegative_int(input.mindepth, "mindepth")
        if input.mindepth ~= nil and mindepth == nil then
            return { content = "mindepth must be a non-negative integer", is_error = true, name = "find" }
        end
        if maxdepth then
            cmd[#cmd + 1] = "-maxdepth"
            cmd[#cmd + 1] = tostring(maxdepth)
        end
        if mindepth then
            cmd[#cmd + 1] = "-mindepth"
            cmd[#cmd + 1] = tostring(mindepth)
        end
        if input.name then
            if type(input.name) ~= "string" or input.name == "" then
                return { content = "name must be a non-empty string", is_error = true, name = "find" }
            end
            cmd[#cmd + 1] = "-name"
            cmd[#cmd + 1] = input.name
        end
        if input.iname then
            if type(input.iname) ~= "string" or input.iname == "" then
                return { content = "iname must be a non-empty string", is_error = true, name = "find" }
            end
            cmd[#cmd + 1] = "-iname"
            cmd[#cmd + 1] = input.iname
        end
        if input.type then
            if input.type ~= "f" and input.type ~= "d" and input.type ~= "l" then
                return { content = "type must be one of: f, d, l", is_error = true, name = "find" }
            end
            cmd[#cmd + 1] = "-type"
            cmd[#cmd + 1] = input.type
        end

        local result = vim.fn.system(cmd)
        local exit_code = vim.v.shell_error

        if exit_code ~= 0 then
            return {
                content = "find error (exit " .. exit_code .. "):\n" .. (result or ""),
                is_error = true,
                name = "find",
            }
        end

        local trimmed = (result or ""):gsub("%s+$", "")
        if trimmed == "" then
            return {
                content = "no results found",
                is_error = false,
                name = "find",
            }
        end

        return {
            content = trimmed,
            is_error = false,
            name = "find",
        }
    end,
}
