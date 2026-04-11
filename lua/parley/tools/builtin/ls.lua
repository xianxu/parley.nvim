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

local function build_description()
    if ls_cmd then
        return "List directory contents using the system ls command (" .. ls_version .. "). "
            .. "Pass arguments as a single command string (everything after 'ls'). "
            .. "Example: '.', '-la', '-R lua/parley'. "
            .. "Confined to the working directory."
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
            command = {
                type = "string",
                description = "Arguments to pass to ls, e.g. '.', '-la', '-R lua/parley'. Do NOT include the 'ls' command itself.",
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

        local full_cmd = ls_cmd .. " " .. cmd_args
        local result = vim.fn.system(full_cmd)
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
