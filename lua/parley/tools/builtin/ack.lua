-- `ack` — shell out to the local `ack` command (if installed).
--
-- Only registered if ack is available. The tool description advertises
-- the version so Claude adapts its syntax.

local function detect_ack()
    if vim.fn.executable("ack") == 1 then
        local version = vim.fn.system("ack --version 2>&1"):match("[^\n]+") or "ack"
        return "ack", version
    end
    return nil, nil
end

local ack_cmd, ack_version = detect_ack()

local function build_description()
    if ack_cmd then
        return "Search file contents using ack (" .. ack_version .. "). "
            .. "ack is a grep-like tool optimized for source code. "
            .. "Pass arguments as a single command string (everything after 'ack'). "
            .. "Supports Perl-compatible regex, --type for language filters (--lua, --python, etc.), "
            .. "-i for case-insensitive, -A/-B/-C for context lines. "
            .. "Confined to the working directory."
    else
        return "Search file contents using ack. Not available on this system."
    end
end

return {
    name = "ack",
    kind = "read",
    -- Mark as unavailable when ack is not installed so the tool
    -- registry can skip it.
    available = ack_cmd ~= nil,
    description = build_description(),
    input_schema = {
        type = "object",
        properties = {
            command = {
                type = "string",
                description = "Arguments to pass to ack, e.g. 'pattern', '-i pattern --lua', '--type=python pattern'. Do NOT include the 'ack' command itself.",
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
                name = "ack",
            }
        end

        if not ack_cmd then
            return {
                content = "ack is not installed on this system. Use grep instead.",
                is_error = true,
                name = "ack",
            }
        end

        local full_cmd = ack_cmd .. " " .. cmd_args
        local result = vim.fn.system(full_cmd)
        local exit_code = vim.v.shell_error

        -- ack: 0=matches, 1=no matches, 2+=error
        if exit_code >= 2 then
            return {
                content = "ack error (exit " .. exit_code .. "):\n" .. (result or ""),
                is_error = true,
                name = "ack",
            }
        end

        local trimmed = (result or ""):gsub("%s+$", "")
        if trimmed == "" then
            return {
                content = "no matches found",
                is_error = false,
                name = "ack",
            }
        end

        return {
            content = trimmed,
            is_error = false,
            name = "ack",
        }
    end,
}
