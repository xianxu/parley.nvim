-- `grep` — search file contents by shelling out to the local grep tool.
--
-- Detects ripgrep (rg) or system grep at load time and advertises
-- which version is available in the tool description. Claude sees
-- this and adapts its arguments accordingly.

local version = require("parley.tools.version")
local argv = require("parley.tools.builtin.argv")

local function detect_grep()
    if vim.fn.executable("rg") == 1 then
        local stable = version.stable_command_version(vim.fn.system("rg --version"):match("[^\n]+"), "ripgrep")
        return "rg", stable
    elseif vim.fn.executable("grep") == 1 then
        local stable = version.stable_command_version(vim.fn.system("grep --version 2>&1"):match("[^\n]+"), "grep")
        return "grep", stable
    end
    return nil, nil
end

local grep_cmd, grep_version = detect_grep()

local GREP_FLAGS = {
    ["-n"] = true,
    ["--line-number"] = true,
    ["-w"] = true,
    ["--word-regexp"] = true,
    ["-F"] = true,
    ["--fixed-strings"] = true,
    ["--hidden"] = true,
    ["--no-ignore"] = true,
}

local ALLOWED_FIELDS = {
    pattern = true,
    path = true,
    paths = true,
    glob = true,
    type = true,
    ignore_case = true,
    context = true,
    context_before = true,
    context_after = true,
    flags = true,
}

local function build_description()
    if grep_cmd == "rg" then
        return "Search file contents using ripgrep (" .. grep_version .. "). "
            .. "Use structured fields: pattern, path/paths, glob, type, ignore_case, context, and safe flags. "
            .. "Example: { pattern = 'foo', path = 'lua', glob = '*.lua' }. "
            .. "Paths are confined to the working directory and configured read roots."
    elseif grep_cmd == "grep" then
        return "Search file contents using system grep (" .. grep_version .. "). "
            .. "Use structured fields: pattern, path/paths, ignore_case, context, and safe flags. "
            .. "Paths are confined to the working directory and configured read roots."
    else
        return "Search file contents. No grep command available on this system."
    end
end

return {
    name = "grep",
    kind = "read",
    description = build_description(),
    input_schema = {
        type = "object",
        properties = {
            pattern = {
                type = "string",
                description = "Regex or fixed-string pattern to search for.",
            },
            path = {
                type = "string",
                description = "File or directory path to search. Defaults to '.'.",
            },
            paths = {
                type = "array",
                items = { type = "string" },
                description = "File or directory paths to search. Overrides path when present.",
            },
            glob = {
                type = "string",
                description = "File glob filter, e.g. '*.lua'. Supported natively by ripgrep.",
            },
            type = {
                type = "string",
                description = "Ripgrep file type filter, e.g. 'lua'. Ignored by system grep fallback.",
            },
            ignore_case = {
                type = "boolean",
                description = "Case-insensitive search.",
            },
            context = {
                type = "integer",
                description = "Context lines before and after each match.",
            },
            context_before = {
                type = "integer",
                description = "Context lines before each match.",
            },
            context_after = {
                type = "integer",
                description = "Context lines after each match.",
            },
            flags = {
                type = "array",
                items = { type = "string" },
                description = "Safe read-only flags only: -n, --line-number, -w, --word-regexp, -F, --fixed-strings, --hidden, --no-ignore.",
            },
        },
        required = { "pattern" },
    },
    handler = function(input)
        input = input or {}
        local ok_fields, fields_err = argv.reject_unknown_fields(input, ALLOWED_FIELDS)
        if not ok_fields then
            return {
                content = fields_err,
                is_error = true,
                name = "grep",
            }
        end

        local pattern = input.pattern
        if type(pattern) ~= "string" or pattern == "" then
            return {
                content = "missing or invalid required field: pattern",
                is_error = true,
                name = "grep",
            }
        end

        if not grep_cmd then
            return {
                content = "no grep command available on this system (neither rg nor grep found)",
                is_error = true,
                name = "grep",
            }
        end

        local flags, flag_err = argv.validate_flags(input.flags, GREP_FLAGS)
        if not flags then
            return {
                content = flag_err,
                is_error = true,
                name = "grep",
            }
        end

        local cmd = { grep_cmd }
        for _, flag in ipairs(flags) do
            cmd[#cmd + 1] = flag
        end
        if input.ignore_case then
            cmd[#cmd + 1] = "-i"
        end
        local context = argv.nonnegative_int(input.context, "context")
        if input.context ~= nil and context == nil then
            return { content = "context must be a non-negative integer", is_error = true, name = "grep" }
        end
        local before = argv.nonnegative_int(input.context_before, "context_before")
        if input.context_before ~= nil and before == nil then
            return { content = "context_before must be a non-negative integer", is_error = true, name = "grep" }
        end
        local after = argv.nonnegative_int(input.context_after, "context_after")
        if input.context_after ~= nil and after == nil then
            return { content = "context_after must be a non-negative integer", is_error = true, name = "grep" }
        end
        if context then
            cmd[#cmd + 1] = "-C"
            cmd[#cmd + 1] = tostring(context)
        end
        if before then
            cmd[#cmd + 1] = "-B"
            cmd[#cmd + 1] = tostring(before)
        end
        if after then
            cmd[#cmd + 1] = "-A"
            cmd[#cmd + 1] = tostring(after)
        end
        if grep_cmd == "rg" then
            if type(input.glob) == "string" and input.glob ~= "" then
                cmd[#cmd + 1] = "--glob"
                cmd[#cmd + 1] = input.glob
            end
            if type(input.type) == "string" and input.type ~= "" then
                cmd[#cmd + 1] = "--type"
                cmd[#cmd + 1] = input.type
            end
        elseif type(input.glob) == "string" and input.glob ~= "" then
            cmd[#cmd + 1] = "--include"
            cmd[#cmd + 1] = input.glob
        end
        if grep_cmd == "grep" then
            cmd[#cmd + 1] = "-r"
        end
        cmd[#cmd + 1] = pattern
        local ok, path_err = argv.append_path_args(cmd, input.paths or input.path or ".")
        if not ok then
            return { content = path_err, is_error = true, name = "grep" }
        end

        local result = vim.fn.system(cmd)
        local exit_code = vim.v.shell_error

        -- rg: 0=matches, 1=no matches, 2+=error
        -- grep: 0=matches, 1=no matches, 2+=error
        if exit_code >= 2 then
            return {
                content = grep_cmd .. " error (exit " .. exit_code .. "):\n" .. (result or ""),
                is_error = true,
                name = "grep",
            }
        end

        local trimmed = (result or ""):gsub("%s+$", "")
        if trimmed == "" then
            return {
                content = "no matches found",
                is_error = false,
                name = "grep",
            }
        end

        return {
            content = trimmed,
            is_error = false,
            name = "grep",
        }
    end,
}
