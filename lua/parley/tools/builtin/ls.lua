-- `ls` — shell out to the local `ls` command.
--
-- Exposes the system's ls command directly. The tool description
-- advertises which version is available so Claude adapts its syntax.

local function detect_ls()
    if vim.fn.executable("ls") == 1 then
        local uname = vim.fn.system("uname -s"):gsub("%s+$", "")
        if uname == "Darwin" then
            return "ls", "BSD ls (macOS)"
        else
            local version = vim.fn.system("ls --version 2>&1"):match("[^\n]+") or "ls"
            return "ls", version
        end
    end
    return nil, nil
end

local ls_cmd, ls_version = detect_ls()
local argv = require("parley.tools.builtin.argv")

local LS_FLAG_CHARS = {
    a = true, A = true, l = true, h = true, R = true, t = true, r = true,
    S = true, ["1"] = true, d = true, F = true,
}

local ALLOWED_FIELDS = {
    path = true,
    flags = true,
}

local function build_description()
    if ls_cmd then
        return "List directory contents using the system ls command (" .. ls_version .. "). "
            .. "Use structured fields: path plus safe short flags such as '-la', '-R', '-t'. "
            .. "Example: { path = '.', flags = { '-la' } }. "
            .. "Paths are confined to the working directory and configured read roots."
    else
        return "List directory contents. No ls command available on this system."
    end
end

return {
    name = "ls",
    kind = "read",
    description = build_description(),
    input_schema = {
        type = "object",
        properties = {
            path = {
                type = "string",
                description = "Directory or file path to list. Relative to the working directory or absolute.",
            },
            flags = {
                type = "array",
                items = { type = "string" },
                description = "Safe ls display flags, e.g. { '-la' }, { '-R' }. Allowed compact characters: a A l h R t r S 1 d F. Long flags are not accepted.",
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
                name = "ls",
            }
        end

        local path = input.path
        if type(path) ~= "string" or path == "" then
            return {
                content = "missing or invalid required field: path",
                is_error = true,
                name = "ls",
            }
        end

        if not ls_cmd then
            return {
                content = "no ls command available on this system",
                is_error = true,
                name = "ls",
            }
        end

        local flags, flag_err = argv.validate_ls_flags(input.flags, LS_FLAG_CHARS)
        if not flags then
            return {
                content = flag_err,
                is_error = true,
                name = "ls",
            }
        end

        local cmd = { ls_cmd }
        for _, flag in ipairs(flags) do
            cmd[#cmd + 1] = flag
        end
        cmd[#cmd + 1] = path
        local result = vim.fn.system(cmd)
        local exit_code = vim.v.shell_error

        if exit_code ~= 0 then
            return {
                content = "ls error (exit " .. exit_code .. "):\n" .. (result or ""),
                is_error = true,
                name = "ls",
            }
        end

        local trimmed = (result or ""):gsub("%s+$", "")
        if trimmed == "" then
            return {
                content = "(empty directory)",
                is_error = false,
                name = "ls",
            }
        end

        return {
            content = trimmed,
            is_error = false,
            name = "ls",
        }
    end,
}
