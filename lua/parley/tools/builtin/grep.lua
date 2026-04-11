-- `grep` — search file contents by shelling out to the local grep tool.
--
-- Detects ripgrep (rg) or system grep at load time and advertises
-- which version is available in the tool description. Claude sees
-- this and adapts its arguments accordingly.

local function detect_grep()
    if vim.fn.executable("rg") == 1 then
        local version = vim.fn.system("rg --version"):match("[^\n]+") or "ripgrep"
        return "rg", version
    elseif vim.fn.executable("grep") == 1 then
        local version = vim.fn.system("grep --version 2>&1"):match("[^\n]+") or "grep"
        return "grep", version
    end
    return nil, nil
end

local grep_cmd, grep_version = detect_grep()

local function build_description()
    if grep_cmd == "rg" then
        return "Search file contents using ripgrep (" .. grep_version .. "). "
            .. "Supports full ripgrep syntax: regex patterns, --glob for file filters, "
            .. "--type for language filters (js, py, lua, etc.), -i for case-insensitive, "
            .. "-A/-B/-C for context lines, --multiline for cross-line patterns. "
            .. "Pass arguments as a single command string (everything after 'rg'). "
            .. "Confined to the working directory."
    elseif grep_cmd == "grep" then
        return "Search file contents using system grep (" .. grep_version .. "). "
            .. "Pass arguments as a single command string (everything after 'grep'). "
            .. "Use -r for recursive, -n for line numbers, -i for case-insensitive, "
            .. "-E for extended regex. Confined to the working directory."
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
            command = {
                type = "string",
                description = grep_cmd == "rg"
                    and "Arguments to pass to ripgrep, e.g. 'pattern', '-i pattern --glob *.lua', '--type lua pattern'. Do NOT include the 'rg' command itself."
                    or "Arguments to pass to grep, e.g. '-rn pattern .', '-ri pattern --include=*.lua'. Do NOT include the 'grep' command itself.",
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

        -- Shell out to the detected grep command.
        local full_cmd = grep_cmd .. " " .. cmd_args
        local result = vim.fn.system(full_cmd)
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
