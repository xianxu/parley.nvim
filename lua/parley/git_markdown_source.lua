local finder_scan = require("parley.finder_scan")

local M = {}
local FAILURE_KIND = finder_scan.FAILURE_KIND
local STDERR_CAP = 4096
local PATH_FRAGMENT_CAP = 16384

local function close_handle(handle)
    if handle and not handle:is_closing() then
        pcall(handle.close, handle)
    end
end

M.list = function(options, on_complete)
    assert(type(options) == "table", "Git list options must be a table")
    assert(type(options.root) == "string", "Git list root is required")
    assert(type(on_complete) == "function", "Git list completion callback is required")

    local uv = options.uv or vim.uv or vim.loop
    local stdout = uv.new_pipe(false)
    local stderr = uv.new_pipe(false)
    local process
    local cancelled = false
    local completed = false
    local exited = false
    local stdout_eof = false
    local stderr_eof = false
    local exit_code
    local pending_path = ""
    local stderr_text = ""
    local paths = {}
    local path_seen = {}
    local failure
    local kill_requested = false
    local handle = {}

    local function request_kill()
        if kill_requested or not process then
            return
        end
        kill_requested = true
        pcall(process.kill, process, "sigterm")
    end

    local function set_failure(kind, diagnostic)
        if not failure then
            failure = { kind = kind, diagnostic = diagnostic }
        end
    end

    local function finish_if_ready()
        if cancelled or completed or not exited or not stdout_eof or not stderr_eof then
            return
        end
        completed = true
        close_handle(process)

        if not failure and exit_code ~= 0 then
            set_failure(FAILURE_KIND.process_exit, stderr_text)
        end
        if failure then
            local diagnostic = failure.diagnostic
            if type(diagnostic) ~= "string" or diagnostic == "" then
                diagnostic = stderr_text ~= "" and stderr_text or failure.kind
            end
            on_complete({
                root_ordinal = options.root_ordinal,
                status = "failed",
                failure = {
                    kind = failure.kind,
                    diagnostic = finder_scan.sanitize_diagnostic(diagnostic),
                },
            })
            return
        end

        table.sort(paths)
        on_complete({
            root_ordinal = options.root_ordinal,
            status = "success",
            paths = paths,
        })
    end

    local function retire_stdout()
        if stdout_eof then
            return
        end
        stdout_eof = true
        pcall(stdout.read_stop, stdout)
        close_handle(stdout)
    end

    local function retire_stderr()
        if stderr_eof then
            return
        end
        stderr_eof = true
        pcall(stderr.read_stop, stderr)
        close_handle(stderr)
    end

    local function fail_stdout(kind, diagnostic)
        set_failure(kind, diagnostic)
        pending_path = ""
        paths = {}
        path_seen = {}
        retire_stdout()
        request_kill()
        finish_if_ready()
    end

    local function consume_stdout(data)
        local cursor = 1
        while cursor <= #data and not stdout_eof do
            local delimiter = data:find("\0", cursor, true)
            local fragment = delimiter and data:sub(cursor, delimiter - 1) or data:sub(cursor)
            if #pending_path + #fragment > PATH_FRAGMENT_CAP then
                fail_stdout(FAILURE_KIND.path_fragment_too_long)
                return
            end
            pending_path = pending_path .. fragment
            if not delimiter then
                return
            end
            if pending_path ~= "" and not path_seen[pending_path] then
                path_seen[pending_path] = true
                paths[#paths + 1] = pending_path
            end
            pending_path = ""
            cursor = delimiter + 1
        end
    end

    local args = {
        "-C", options.root,
        "ls-files", "-z", "--cached", "--others", "--exclude-standard", "--", "*.md",
    }
    local spawn_error
    process, spawn_error = uv.spawn(options.executable or "git", {
        args = args,
        env = options.env,
        stdio = { nil, stdout, stderr },
    }, function(code)
        exited = true
        exit_code = code
        if cancelled then
            close_handle(process)
            return
        end
        finish_if_ready()
    end)

    if not process then
        close_handle(stdout)
        close_handle(stderr)
        vim.schedule(function()
            if cancelled or completed then
                return
            end
            completed = true
            on_complete({
                root_ordinal = options.root_ordinal,
                status = "failed",
                failure = {
                    kind = FAILURE_KIND.process_spawn,
                    diagnostic = finder_scan.sanitize_diagnostic(
                        type(spawn_error) == "string" and spawn_error or "Git process spawn failed"
                    ),
                },
            })
        end)
    else
        stdout:read_start(function(error_value, data)
            if cancelled or stdout_eof then
                return
            end
            if error_value then
                fail_stdout(FAILURE_KIND.process_stream, error_value)
            elseif data then
                consume_stdout(data)
            else
                if pending_path ~= "" then
                    fail_stdout(FAILURE_KIND.process_stream, "unterminated NUL path")
                else
                    retire_stdout()
                    finish_if_ready()
                end
            end
        end)

        stderr:read_start(function(error_value, data)
            if cancelled or stderr_eof then
                return
            end
            if error_value then
                set_failure(FAILURE_KIND.process_stream, error_value)
                retire_stderr()
                request_kill()
                finish_if_ready()
            elseif data then
                local remaining = STDERR_CAP - #stderr_text
                if remaining > 0 then
                    stderr_text = stderr_text .. data:sub(1, remaining)
                end
            else
                retire_stderr()
                finish_if_ready()
            end
        end)
    end

    handle.cancel = function()
        if cancelled or completed then
            return
        end
        cancelled = true
        request_kill()
        pcall(stdout.read_stop, stdout)
        pcall(stderr.read_stop, stderr)
        close_handle(stdout)
        close_handle(stderr)
        if exited then
            close_handle(process)
        end
    end
    handle.is_cancelled = function()
        return cancelled
    end
    return handle
end

return M
