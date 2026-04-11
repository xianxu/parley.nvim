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

local function build_description()
    if find_cmd then
        return "Search for files and directories using the system find command (" .. find_version .. "). "
            .. "Pass arguments as a single command string (everything after 'find'). "
            .. "Example: '. -name \"*.lua\" -type f', '. -maxdepth 2 -name \"*.md\"'. "
            .. "Confined to the working directory."
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
            command = {
                type = "string",
                description = "Arguments to pass to find, e.g. '. -name \"*.lua\" -type f'. Do NOT include the 'find' command itself.",
            },
        },
        required = { "command" },
    },
    handler = function(input)
        input = input or {}
        local cmd_args = input.command
        if type(cmd_args) ~= "string" or cmd_args == "" then
            return {
                content = "missing or invalid required field: command",
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

        local full_cmd = find_cmd .. " " .. cmd_args
        local result = vim.fn.system(full_cmd)
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
