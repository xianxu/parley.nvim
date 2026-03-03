# Google Drive Support Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable users to reference Google Drive files in chat using `@@https://docs.google.com/...` syntax, with OAuth authentication and OS keychain token persistence.

**Architecture:** New `lua/parley/google_drive.lua` module handles OAuth, token management, URL parsing, and file fetching. Minimal changes to `helper.lua` (URL detection), `init.lua` (async file fetching), and `config.lua` (credentials). Uses `vim.loop` TCP server for OAuth redirect and existing `tasker.run` for curl commands.

**Tech Stack:** Lua, vim.loop (libuv), Google Drive API v3, Google OAuth 2.0, OS keychain (macOS `security` CLI, Linux `secret-tool`)

**Design doc:** `docs/plans/2026-03-02-google-drive-support-design.md`

---

### Task 1: URL Parsing — tests and implementation

**Files:**
- Create: `tests/unit/google_drive_spec.lua`
- Create: `lua/parley/google_drive.lua`

**Step 1: Write the failing tests**

Create `tests/unit/google_drive_spec.lua`:

```lua
-- Unit tests for Google Drive URL parsing and helpers

local gd = require("parley.google_drive")

describe("google_drive: URL detection", function()
    it("A1: detects Google Docs URL", function()
        assert.is_true(gd.is_google_url("https://docs.google.com/document/d/abc123/edit"))
    end)

    it("A2: detects Google Sheets URL", function()
        assert.is_true(gd.is_google_url("https://docs.google.com/spreadsheets/d/abc123/edit"))
    end)

    it("A3: detects Google Slides URL", function()
        assert.is_true(gd.is_google_url("https://docs.google.com/presentation/d/abc123/edit"))
    end)

    it("A4: detects Google Drive file URL", function()
        assert.is_true(gd.is_google_url("https://drive.google.com/file/d/abc123/view"))
    end)

    it("A5: rejects non-Google URL", function()
        assert.is_false(gd.is_google_url("https://example.com/file.txt"))
    end)

    it("A6: rejects local file path", function()
        assert.is_false(gd.is_google_url("/home/user/file.txt"))
    end)

    it("A7: rejects nil", function()
        assert.is_false(gd.is_google_url(nil))
    end)
end)

describe("google_drive: URL parsing", function()
    it("B1: extracts file ID from Google Docs URL", function()
        local info = gd.parse_url("https://docs.google.com/document/d/abc123XYZ/edit")
        assert.equals("abc123XYZ", info.file_id)
        assert.equals("document", info.file_type)
    end)

    it("B2: extracts file ID from Google Docs URL without trailing path", function()
        local info = gd.parse_url("https://docs.google.com/document/d/abc123XYZ")
        assert.equals("abc123XYZ", info.file_id)
        assert.equals("document", info.file_type)
    end)

    it("B3: extracts file ID from Google Sheets URL", function()
        local info = gd.parse_url("https://docs.google.com/spreadsheets/d/sheet456/edit#gid=0")
        assert.equals("sheet456", info.file_id)
        assert.equals("spreadsheet", info.file_type)
    end)

    it("B4: extracts file ID from Google Slides URL", function()
        local info = gd.parse_url("https://docs.google.com/presentation/d/slide789/edit")
        assert.equals("slide789", info.file_id)
        assert.equals("presentation", info.file_type)
    end)

    it("B5: extracts file ID from Google Drive file URL", function()
        local info = gd.parse_url("https://drive.google.com/file/d/drive_file_001/view")
        assert.equals("drive_file_001", info.file_id)
        assert.equals("drive_file", info.file_type)
    end)

    it("B6: returns nil for unsupported URL", function()
        local info = gd.parse_url("https://docs.google.com/forms/d/form123/edit")
        assert.is_nil(info)
    end)

    it("B7: returns nil for non-Google URL", function()
        local info = gd.parse_url("https://example.com/file.txt")
        assert.is_nil(info)
    end)
end)

describe("google_drive: export MIME type", function()
    it("C1: Google Doc exports as markdown", function()
        assert.equals("text/markdown", gd.get_export_mime("document"))
    end)

    it("C2: Google Sheet exports as CSV", function()
        assert.equals("text/csv", gd.get_export_mime("spreadsheet"))
    end)

    it("C3: Google Slides exports as plain text", function()
        assert.equals("text/plain", gd.get_export_mime("presentation"))
    end)

    it("C4: drive_file returns nil (downloaded directly, not exported)", function()
        assert.is_nil(gd.get_export_mime("drive_file"))
    end)
end)
```

**Step 2: Create minimal `lua/parley/google_drive.lua` to make tests pass**

```lua
local logger = require("parley.logger")

local M = {}

-- URL patterns for Google Drive/Docs
local url_patterns = {
    { pattern = "docs%.google%.com/document/d/([^/&#]+)", file_type = "document" },
    { pattern = "docs%.google%.com/spreadsheets/d/([^/&#]+)", file_type = "spreadsheet" },
    { pattern = "docs%.google%.com/presentation/d/([^/&#]+)", file_type = "presentation" },
    { pattern = "drive%.google%.com/file/d/([^/&#]+)", file_type = "drive_file" },
}

-- Export MIME types for Google Workspace file types
local export_mimes = {
    document = "text/markdown",
    spreadsheet = "text/csv",
    presentation = "text/plain",
}

-- Check if a path is a Google Drive/Docs URL
---@param path string|nil # the path to check
---@return boolean # true if path is a recognized Google URL
M.is_google_url = function(path)
    if not path or type(path) ~= "string" then
        return false
    end
    for _, entry in ipairs(url_patterns) do
        if path:match(entry.pattern) then
            return true
        end
    end
    return false
end

-- Parse a Google Drive/Docs URL and extract file ID and type
---@param url string # the Google URL
---@return table|nil # {file_id, file_type} or nil if not recognized
M.parse_url = function(url)
    if not url or type(url) ~= "string" then
        return nil
    end
    for _, entry in ipairs(url_patterns) do
        local file_id = url:match(entry.pattern)
        if file_id then
            return {
                file_id = file_id,
                file_type = entry.file_type,
            }
        end
    end
    return nil
end

-- Get the export MIME type for a Google Workspace file type
---@param file_type string # one of: document, spreadsheet, presentation, drive_file
---@return string|nil # MIME type for export, or nil for direct download types
M.get_export_mime = function(file_type)
    return export_mimes[file_type]
end

return M
```

**Step 3: Run tests to verify they pass**

Run: `make test`
Expected: All A1-A7, B1-B7, C1-C4 tests PASS

**Step 4: Commit**

```bash
git add lua/parley/google_drive.lua tests/unit/google_drive_spec.lua
git commit -m "feat: add google_drive module with URL parsing"
```

---

### Task 2: OAuth URL construction and token helpers

**Files:**
- Modify: `lua/parley/google_drive.lua`
- Modify: `tests/unit/google_drive_spec.lua`
- Modify: `lua/parley/config.lua:25-38` (add google_drive config)

**Step 1: Add config defaults**

In `lua/parley/config.lua`, after the `api_keys` block (line 38) and before `providers` (line 42), add:

```lua
-- Google Drive OAuth configuration for @@ URL references
google_drive = {
    client_id = "",
    client_secret = "",
    scopes = { "https://www.googleapis.com/auth/drive.readonly" },
},
```

Note: client_id and client_secret will be populated once a Google Cloud project is set up. For now, leave empty so users must provide their own.

**Step 2: Write failing tests for OAuth URL construction**

Append to `tests/unit/google_drive_spec.lua`:

```lua
describe("google_drive: OAuth URL construction", function()
    it("D1: builds correct authorization URL", function()
        local url = gd.build_auth_url({
            client_id = "test-client-id.apps.googleusercontent.com",
            scopes = { "https://www.googleapis.com/auth/drive.readonly" },
        }, 52847)

        assert.is_true(url:match("accounts%.google%.com/o/oauth2/v2/auth") ~= nil)
        assert.is_true(url:match("client_id=test%-client%-id") ~= nil)
        assert.is_true(url:match("redirect_uri=http://localhost:52847/callback") ~= nil)
        assert.is_true(url:match("response_type=code") ~= nil)
        assert.is_true(url:match("access_type=offline") ~= nil)
        assert.is_true(url:match("scope=https") ~= nil)
    end)
end)

describe("google_drive: token exchange curl args", function()
    it("E1: builds correct token exchange curl arguments", function()
        local args = gd.build_token_exchange_args({
            client_id = "test-client-id",
            client_secret = "test-secret",
        }, "auth-code-123", 52847)

        -- Should be a list of curl arguments
        assert.is_true(type(args) == "table")
        -- Should contain the token endpoint
        local args_str = table.concat(args, " ")
        assert.is_true(args_str:match("oauth2%.googleapis%.com/token") ~= nil)
        assert.is_true(args_str:match("auth%-code%-123") ~= nil)
        assert.is_true(args_str:match("authorization_code") ~= nil)
    end)
end)

describe("google_drive: keychain commands", function()
    it("F1: builds macOS keychain store command", function()
        local cmd = gd.build_keychain_store_cmd("darwin", '{"access_token":"abc"}')
        assert.equals("security", cmd[1])
        assert.is_true(vim.tbl_contains(cmd, "add-generic-password"))
        assert.is_true(vim.tbl_contains(cmd, "parley-nvim-google-oauth"))
    end)

    it("F2: builds macOS keychain load command", function()
        local cmd = gd.build_keychain_load_cmd("darwin")
        assert.equals("security", cmd[1])
        assert.is_true(vim.tbl_contains(cmd, "find-generic-password"))
        assert.is_true(vim.tbl_contains(cmd, "parley-nvim-google-oauth"))
    end)

    it("F3: builds Linux keychain store command", function()
        local cmd = gd.build_keychain_store_cmd("linux", '{"access_token":"abc"}')
        assert.equals("secret-tool", cmd[1])
        assert.is_true(vim.tbl_contains(cmd, "store"))
    end)

    it("F4: builds Linux keychain load command", function()
        local cmd = gd.build_keychain_load_cmd("linux")
        assert.equals("secret-tool", cmd[1])
        assert.is_true(vim.tbl_contains(cmd, "lookup"))
    end)
end)

describe("google_drive: API URL construction", function()
    it("G1: builds metadata URL", function()
        local url = gd.build_metadata_url("file123")
        assert.equals("https://www.googleapis.com/drive/v3/files/file123?fields=mimeType,name", url)
    end)

    it("G2: builds export URL for Google Doc", function()
        local url = gd.build_export_url("file123", "text/markdown")
        assert.equals("https://www.googleapis.com/drive/v3/files/file123/export?mimeType=text/markdown", url)
    end)

    it("G3: builds download URL for Drive file", function()
        local url = gd.build_download_url("file123")
        assert.equals("https://www.googleapis.com/drive/v3/files/file123?alt=media", url)
    end)
end)
```

**Step 3: Run tests to confirm they fail**

Run: `make test`
Expected: D1, E1, F1-F4, G1-G3 FAIL (functions not defined)

**Step 4: Implement the functions in `lua/parley/google_drive.lua`**

Add to the module:

```lua
-- Build Google OAuth authorization URL
---@param config table # {client_id, scopes}
---@param port number # localhost redirect port
---@return string # the authorization URL
M.build_auth_url = function(config, port)
    local scope = table.concat(config.scopes, " ")
    local params = {
        "client_id=" .. config.client_id,
        "redirect_uri=" .. M._url_encode("http://localhost:" .. port .. "/callback"),
        "response_type=code",
        "scope=" .. M._url_encode(scope),
        "access_type=offline",
        "prompt=consent",
    }
    return "https://accounts.google.com/o/oauth2/v2/auth?" .. table.concat(params, "&")
end

-- URL-encode a string
---@param str string
---@return string
M._url_encode = function(str)
    return str:gsub("([^%w%-%.%_%~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
end

-- Build curl arguments for token exchange
---@param config table # {client_id, client_secret}
---@param auth_code string # authorization code from OAuth redirect
---@param port number # the port used for redirect
---@return table # curl argument list
M.build_token_exchange_args = function(config, auth_code, port)
    return {
        "-s",
        "-X", "POST",
        "https://oauth2.googleapis.com/token",
        "-d", "code=" .. auth_code,
        "-d", "client_id=" .. config.client_id,
        "-d", "client_secret=" .. config.client_secret,
        "-d", "redirect_uri=http://localhost:" .. port .. "/callback",
        "-d", "grant_type=authorization_code",
    }
end

-- Build OS keychain store command
---@param platform string # "darwin" or "linux"
---@param json_data string # JSON string to store
---@return table # command as argument list
M.build_keychain_store_cmd = function(platform, json_data)
    if platform == "darwin" then
        return {
            "security", "add-generic-password",
            "-U",  -- update if exists
            "-s", "parley-nvim-google-oauth",
            "-a", "default",
            "-w", json_data,
        }
    else
        -- Linux: pipe json_data to stdin of secret-tool
        return {
            "secret-tool", "store",
            "--label", "parley-nvim-google-oauth",
            "service", "parley-nvim-google-oauth",
            "account", "default",
        }
    end
end

-- Build OS keychain load command
---@param platform string # "darwin" or "linux"
---@return table # command as argument list
M.build_keychain_load_cmd = function(platform)
    if platform == "darwin" then
        return {
            "security", "find-generic-password",
            "-s", "parley-nvim-google-oauth",
            "-a", "default",
            "-w",
        }
    else
        return {
            "secret-tool", "lookup",
            "service", "parley-nvim-google-oauth",
            "account", "default",
        }
    end
end

-- Build Google Drive API metadata URL
---@param file_id string
---@return string
M.build_metadata_url = function(file_id)
    return "https://www.googleapis.com/drive/v3/files/" .. file_id .. "?fields=mimeType,name"
end

-- Build Google Drive API export URL
---@param file_id string
---@param mime_type string
---@return string
M.build_export_url = function(file_id, mime_type)
    return "https://www.googleapis.com/drive/v3/files/" .. file_id .. "/export?mimeType=" .. mime_type
end

-- Build Google Drive API download URL
---@param file_id string
---@return string
M.build_download_url = function(file_id)
    return "https://www.googleapis.com/drive/v3/files/" .. file_id .. "?alt=media"
end
```

**Step 5: Run tests to verify they pass**

Run: `make test`
Expected: All A-G tests PASS

**Step 6: Commit**

```bash
git add lua/parley/google_drive.lua tests/unit/google_drive_spec.lua lua/parley/config.lua
git commit -m "feat: add OAuth URL construction, keychain helpers, and API URL builders"
```

---

### Task 3: Token persistence — load/save via keychain

**Files:**
- Modify: `lua/parley/google_drive.lua`
- Modify: `tests/unit/google_drive_spec.lua`

This task implements the actual token load/save functions that call keychain commands via `tasker.run`. These are async and use callbacks.

**Step 1: Write the failing tests**

Append to `tests/unit/google_drive_spec.lua`:

```lua
describe("google_drive: token parsing", function()
    it("H1: parses token exchange response JSON", function()
        local json = '{"access_token":"ya29.abc","refresh_token":"1//ref","expires_in":3600,"token_type":"Bearer"}'
        local tokens = gd.parse_token_response(json)
        assert.equals("ya29.abc", tokens.access_token)
        assert.equals("1//ref", tokens.refresh_token)
        assert.is_true(tokens.expires_at > os.time())
    end)

    it("H2: parse_token_response returns nil on invalid JSON", function()
        local tokens = gd.parse_token_response("not json")
        assert.is_nil(tokens)
    end)

    it("H3: parse_token_response returns nil when access_token missing", function()
        local tokens = gd.parse_token_response('{"error":"invalid_grant"}')
        assert.is_nil(tokens)
    end)

    it("H4: is_token_expired returns true for expired token", function()
        local tokens = { access_token = "abc", expires_at = os.time() - 100 }
        assert.is_true(gd.is_token_expired(tokens))
    end)

    it("H5: is_token_expired returns false for valid token", function()
        local tokens = { access_token = "abc", expires_at = os.time() + 3600 }
        assert.is_false(gd.is_token_expired(tokens))
    end)
end)
```

**Step 2: Run tests to confirm they fail**

Run: `make test`
Expected: H1-H5 FAIL

**Step 3: Implement token parsing in `lua/parley/google_drive.lua`**

```lua
-- Parse OAuth token exchange response
---@param json_str string # raw JSON response from token endpoint
---@return table|nil # {access_token, refresh_token, expires_at} or nil on error
M.parse_token_response = function(json_str)
    local ok, data = pcall(vim.json.decode, json_str)
    if not ok or not data or not data.access_token then
        return nil
    end
    return {
        access_token = data.access_token,
        refresh_token = data.refresh_token,
        expires_at = os.time() + (data.expires_in or 3600),
    }
end

-- Check if an access token is expired (with 60s buffer)
---@param tokens table # {access_token, expires_at}
---@return boolean
M.is_token_expired = function(tokens)
    if not tokens or not tokens.expires_at then
        return true
    end
    return os.time() >= (tokens.expires_at - 60)
end
```

**Step 4: Run tests to verify they pass**

Run: `make test`
Expected: All H1-H5 PASS

**Step 5: Commit**

```bash
git add lua/parley/google_drive.lua tests/unit/google_drive_spec.lua
git commit -m "feat: add token response parsing and expiry checking"
```

---

### Task 4: OAuth flow — TCP server and browser redirect

**Files:**
- Modify: `lua/parley/google_drive.lua`

This task implements the actual OAuth flow. It's inherently async and requires browser interaction, so it can only be manually tested. The core functions are:

1. `M.start_auth_server(callback)` -- starts TCP server, returns port
2. `M.authenticate(config, callback)` -- orchestrates the full OAuth flow

**Step 1: Implement the OAuth flow**

Add to `lua/parley/google_drive.lua`:

```lua
local uv = vim.loop
local tasker = require("parley.tasker")

-- In-memory token cache (loaded from keychain on first use)
local cached_tokens = nil

-- Detect platform
---@return string # "darwin" or "linux"
M._get_platform = function()
    local sysname = uv.os_uname().sysname
    if sysname == "Darwin" then
        return "darwin"
    end
    return "linux"
end

-- Save tokens to OS keychain
---@param tokens table # {access_token, refresh_token, expires_at}
---@param callback function|nil # called after save completes
M.save_tokens = function(tokens, callback)
    callback = callback or function() end
    cached_tokens = tokens
    local json_data = vim.json.encode(tokens)
    local platform = M._get_platform()
    local cmd_args = M.build_keychain_store_cmd(platform, json_data)
    local cmd = table.remove(cmd_args, 1)

    if platform == "linux" then
        -- Linux secret-tool reads from stdin; use shell to pipe
        tasker.run(nil, "sh", { "-c", "echo " .. vim.fn.shellescape(json_data) .. " | " .. cmd .. " " .. table.concat(cmd_args, " ") }, function(code)
            if code ~= 0 then
                logger.warning("Failed to save Google OAuth tokens to keychain")
            end
            callback()
        end)
    else
        tasker.run(nil, cmd, cmd_args, function(code)
            if code ~= 0 then
                logger.warning("Failed to save Google OAuth tokens to keychain")
            end
            callback()
        end)
    end
end

-- Load tokens from OS keychain
---@param callback function # called with tokens table or nil
M.load_tokens = function(callback)
    if cached_tokens and not M.is_token_expired(cached_tokens) then
        callback(cached_tokens)
        return
    end

    local platform = M._get_platform()
    local cmd_args = M.build_keychain_load_cmd(platform)
    local cmd = table.remove(cmd_args, 1)

    tasker.run(nil, cmd, cmd_args, function(code, signal, stdout_data)
        if code ~= 0 or not stdout_data or stdout_data == "" then
            callback(nil)
            return
        end

        local ok, tokens = pcall(vim.json.decode, stdout_data:match("^%s*(.-)%s*$"))
        if ok and tokens and tokens.access_token then
            cached_tokens = tokens
            callback(tokens)
        else
            callback(nil)
        end
    end)
end

-- Refresh an expired access token using the refresh token
---@param config table # {client_id, client_secret}
---@param tokens table # must have refresh_token
---@param callback function # called with new tokens table or nil
M.refresh_token = function(config, tokens, callback)
    if not tokens or not tokens.refresh_token then
        callback(nil)
        return
    end

    local args = {
        "-s",
        "-X", "POST",
        "https://oauth2.googleapis.com/token",
        "-d", "client_id=" .. config.client_id,
        "-d", "client_secret=" .. config.client_secret,
        "-d", "refresh_token=" .. tokens.refresh_token,
        "-d", "grant_type=refresh_token",
    }

    tasker.run(nil, "curl", args, function(code, signal, stdout_data)
        if code ~= 0 then
            callback(nil)
            return
        end

        local new_tokens = M.parse_token_response(stdout_data)
        if new_tokens then
            -- Preserve refresh_token (not always returned in refresh response)
            new_tokens.refresh_token = new_tokens.refresh_token or tokens.refresh_token
            M.save_tokens(new_tokens, function()
                callback(new_tokens)
            end)
        else
            callback(nil)
        end
    end)
end

-- Parse the auth code from an HTTP request line
---@param request_data string # raw HTTP request
---@return string|nil # the authorization code, or nil
M._parse_auth_code = function(request_data)
    return request_data:match("[?&]code=([^&%s]+)")
end

-- Start OAuth flow: open browser, wait for redirect, exchange code for tokens
---@param config table # google_drive config with client_id, client_secret, scopes
---@param callback function # called with tokens table or nil
M.authenticate = function(config, callback)
    local server = uv.new_tcp()
    server:bind("127.0.0.1", 0)

    local addr = server:getsockname()
    local port = addr.port

    logger.debug("Google OAuth: starting auth server on port " .. port)

    server:listen(1, function(err)
        if err then
            logger.error("Google OAuth: server listen error: " .. tostring(err))
            server:close()
            callback(nil)
            return
        end

        local client = uv.new_tcp()
        server:accept(client)

        client:read_start(function(read_err, data)
            if read_err or not data then
                client:close()
                server:close()
                return
            end

            local code = M._parse_auth_code(data)

            -- Send response to browser
            local response_body
            if code then
                response_body = "<html><body><h1>Authentication successful!</h1><p>You can close this window and return to Neovim.</p></body></html>"
            else
                response_body = "<html><body><h1>Authentication failed</h1><p>No authorization code received.</p></body></html>"
            end
            local response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n" .. response_body

            client:write(response, function()
                client:shutdown(function()
                    client:close()
                end)
            end)
            server:close()

            if not code then
                vim.schedule(function()
                    callback(nil)
                end)
                return
            end

            -- Exchange auth code for tokens
            local args = M.build_token_exchange_args(config, code, port)
            tasker.run(nil, "curl", args, function(exit_code, signal, stdout_data)
                if exit_code ~= 0 then
                    callback(nil)
                    return
                end

                local tokens = M.parse_token_response(stdout_data)
                if tokens then
                    M.save_tokens(tokens, function()
                        callback(tokens)
                    end)
                else
                    logger.warning("Google OAuth: failed to parse token response")
                    callback(nil)
                end
            end)
        end)
    end)

    -- Open browser for OAuth consent
    local auth_url = M.build_auth_url(config, port)
    local open_cmd = M._get_platform() == "darwin" and "open" or "xdg-open"
    vim.fn.jobstart({ open_cmd, auth_url }, { detach = true })

    vim.schedule(function()
        vim.api.nvim_echo({{ "Google OAuth: Please complete authentication in your browser...", "WarningMsg" }}, true, {})
    end)
end

-- Get a valid access token, refreshing or re-authenticating as needed
---@param config table # google_drive config
---@param callback function # called with access_token string or nil
M.get_access_token = function(config, callback)
    M.load_tokens(function(tokens)
        if tokens and not M.is_token_expired(tokens) then
            callback(tokens.access_token)
            return
        end

        if tokens and tokens.refresh_token then
            M.refresh_token(config, tokens, function(new_tokens)
                if new_tokens then
                    callback(new_tokens.access_token)
                else
                    -- Refresh failed, re-authenticate
                    M.authenticate(config, function(auth_tokens)
                        if auth_tokens then
                            callback(auth_tokens.access_token)
                        else
                            callback(nil)
                        end
                    end)
                end
            end)
        else
            M.authenticate(config, function(auth_tokens)
                if auth_tokens then
                    callback(auth_tokens.access_token)
                else
                    callback(nil)
                end
            end)
        end
    end)
end
```

**Step 2: Add a unit test for _parse_auth_code**

Append to `tests/unit/google_drive_spec.lua`:

```lua
describe("google_drive: auth code parsing", function()
    it("I1: parses auth code from HTTP GET request", function()
        local request = "GET /callback?code=4/0AX4XfWh_abc123&scope=https://www.googleapis.com/auth/drive.readonly HTTP/1.1\r\nHost: localhost:52847\r\n\r\n"
        local code = gd._parse_auth_code(request)
        assert.equals("4/0AX4XfWh_abc123", code)
    end)

    it("I2: returns nil when no code present", function()
        local request = "GET /callback?error=access_denied HTTP/1.1\r\n\r\n"
        local code = gd._parse_auth_code(request)
        assert.is_nil(code)
    end)
end)
```

**Step 3: Run tests**

Run: `make test`
Expected: All tests PASS (I1, I2 included)

**Step 4: Commit**

```bash
git add lua/parley/google_drive.lua tests/unit/google_drive_spec.lua
git commit -m "feat: implement OAuth flow with TCP server and token management"
```

---

### Task 5: File content fetching from Google Drive API

**Files:**
- Modify: `lua/parley/google_drive.lua`
- Modify: `tests/unit/google_drive_spec.lua`

**Step 1: Write failing test for content formatting**

Append to `tests/unit/google_drive_spec.lua`:

```lua
describe("google_drive: content formatting", function()
    it("J1: formats Google Doc content like local files", function()
        local content = "Hello world\nSecond line"
        local formatted = gd.format_google_content("My Document", "document", content)
        assert.is_true(formatted:match("Google Doc") ~= nil)
        assert.is_true(formatted:match("My Document") ~= nil)
        assert.is_true(formatted:match("1: Hello world") ~= nil)
        assert.is_true(formatted:match("2: Second line") ~= nil)
    end)

    it("J2: formats Google Sheet content with CSV label", function()
        local content = "a,b,c\n1,2,3"
        local formatted = gd.format_google_content("Budget", "spreadsheet", content)
        assert.is_true(formatted:match("Google Sheet") ~= nil)
        assert.is_true(formatted:match("Budget") ~= nil)
    end)
end)
```

**Step 2: Run tests to confirm they fail**

Run: `make test`
Expected: J1-J2 FAIL

**Step 3: Implement content formatting and fetching**

Add to `lua/parley/google_drive.lua`:

```lua
-- Human-readable labels for file types
local type_labels = {
    document = "Google Doc",
    spreadsheet = "Google Sheet",
    presentation = "Google Slides",
    drive_file = "Google Drive File",
}

-- Filetype hints for syntax highlighting in code fences
local type_filetypes = {
    document = "markdown",
    spreadsheet = "csv",
    presentation = "",
    drive_file = "",
}

-- Format fetched Google content to match helper.format_file_content output
---@param name string # document title
---@param file_type string # one of: document, spreadsheet, presentation, drive_file
---@param content string # raw file content
---@return string # formatted content with header and line numbers
M.format_google_content = function(name, file_type, content)
    local label = type_labels[file_type] or "Google Drive File"
    local filetype = type_filetypes[file_type] or ""

    local lines = vim.split(content, "\n")
    local numbered_lines = {}
    for i, line in ipairs(lines) do
        table.insert(numbered_lines, string.format("%d: %s", i, line))
    end
    local numbered_content = table.concat(numbered_lines, "\n")

    return "File: " .. label .. " - \"" .. name .. "\"\n```" .. filetype .. "\n" .. numbered_content .. "\n```\n\n"
end

-- Fetch file content from Google Drive
-- This is the main entry point called from helper.lua
---@param url string # Google Drive/Docs URL
---@param config table # google_drive config
---@param callback function # called with (formatted_content_string, error_string)
M.fetch_content = function(url, config, callback)
    local info = M.parse_url(url)
    if not info then
        callback(nil, "Unsupported Google URL: " .. url)
        return
    end

    M.get_access_token(config, function(access_token)
        if not access_token then
            callback(nil, "Google OAuth: failed to get access token. Try again to re-authenticate.")
            return
        end

        -- First, get file metadata (name and MIME type)
        local meta_url = M.build_metadata_url(info.file_id)
        local meta_args = {
            "-s",
            "-H", "Authorization: Bearer " .. access_token,
            meta_url,
        }

        tasker.run(nil, "curl", meta_args, function(code, signal, stdout_data)
            if code ~= 0 then
                callback(nil, "Google Drive API: failed to fetch file metadata")
                return
            end

            local ok, meta = pcall(vim.json.decode, stdout_data)
            if not ok or not meta or not meta.name then
                callback(nil, "Google Drive API: invalid metadata response")
                return
            end

            local file_name = meta.name

            -- Determine how to fetch content
            local export_mime = M.get_export_mime(info.file_type)
            local content_url
            if export_mime then
                content_url = M.build_export_url(info.file_id, export_mime)
            else
                -- For non-native Google types, check if it's a Google type by mimeType
                if meta.mimeType and meta.mimeType:match("google%-apps") then
                    -- It's a Google type we don't have explicit handling for
                    content_url = M.build_export_url(info.file_id, "text/plain")
                else
                    content_url = M.build_download_url(info.file_id)
                end
            end

            local content_args = {
                "-s",
                "-H", "Authorization: Bearer " .. access_token,
                content_url,
            }

            tasker.run(nil, "curl", content_args, function(content_code, _, content_data)
                if content_code ~= 0 or not content_data or content_data == "" then
                    callback(nil, "Google Drive API: failed to fetch file content for " .. file_name)
                    return
                end

                -- Check for API error responses
                local err_ok, err_data = pcall(vim.json.decode, content_data)
                if err_ok and err_data and err_data.error then
                    local err_msg = err_data.error.message or "unknown error"
                    -- If markdown export fails, fall back to plain text
                    if export_mime == "text/markdown" then
                        logger.debug("Google Drive: markdown export failed, falling back to plain text")
                        local fallback_url = M.build_export_url(info.file_id, "text/plain")
                        local fallback_args = {
                            "-s",
                            "-H", "Authorization: Bearer " .. access_token,
                            fallback_url,
                        }
                        tasker.run(nil, "curl", fallback_args, function(fb_code, _, fb_data)
                            if fb_code ~= 0 or not fb_data or fb_data == "" then
                                callback(nil, "Google Drive API: " .. err_msg)
                                return
                            end
                            callback(M.format_google_content(file_name, info.file_type, fb_data))
                        end)
                        return
                    end
                    callback(nil, "Google Drive API: " .. err_msg)
                    return
                end

                callback(M.format_google_content(file_name, info.file_type, content_data))
            end)
        end)
    end)
end
```

**Step 4: Run tests**

Run: `make test`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add lua/parley/google_drive.lua tests/unit/google_drive_spec.lua
git commit -m "feat: implement Google Drive file content fetching and formatting"
```

---

### Task 6: Integrate with helper.lua — URL detection and delegation

**Files:**
- Modify: `lua/parley/helper.lua:241-258` (modify `format_file_content`)
- Modify: `tests/unit/google_drive_spec.lua`

The key insight: `helper.format_file_content(path)` is called synchronously in `_build_messages`. Google Drive fetching is async. We need a new async path.

**Step 1: Add `is_remote_url` helper to `helper.lua`**

After line 236 in `lua/parley/helper.lua` (after `is_directory`), add:

```lua
-- Check if a path is a remote URL (e.g., Google Docs)
---@param path string # path to check
---@return boolean # true if path is a URL
_H.is_remote_url = function(path)
    return path:match("^https?://") ~= nil
end
```

**Step 2: Add a test for it**

Append to `tests/unit/google_drive_spec.lua`:

```lua
describe("helper: URL detection", function()
    local helpers = require("parley.helper")

    it("K1: detects HTTPS URL", function()
        assert.is_true(helpers.is_remote_url("https://docs.google.com/document/d/abc/edit"))
    end)

    it("K2: detects HTTP URL", function()
        assert.is_true(helpers.is_remote_url("http://example.com/file"))
    end)

    it("K3: rejects local path", function()
        assert.is_false(helpers.is_remote_url("/home/user/file.txt"))
    end)

    it("K4: rejects relative path", function()
        assert.is_false(helpers.is_remote_url("./file.txt"))
    end)
end)
```

**Step 3: Run tests**

Run: `make test`
Expected: All tests PASS

**Step 4: Commit**

```bash
git add lua/parley/helper.lua tests/unit/google_drive_spec.lua
git commit -m "feat: add is_remote_url helper for URL detection in @@ references"
```

---

### Task 7: Integrate with init.lua — async file fetching in _build_messages

**Files:**
- Modify: `lua/parley/init.lua:2860-2876` (file reference processing loop)
- Modify: `lua/parley/init.lua` (near `chat_respond` call to `_build_messages`)
- Modify: `tests/unit/build_messages_spec.lua`

This is the most complex integration. Currently `_build_messages` is synchronous. We need to handle async Google Drive fetches while keeping local file handling synchronous.

**Strategy:** Make `_build_messages` detect remote URLs and collect them. Add a new wrapper function `_resolve_file_references` that fetches all remote content first (async), then calls `_build_messages` with the resolved content.

**Step 1: Add remote content resolution to init.lua**

In `lua/parley/init.lua`, modify the file reference processing loop (lines 2860-2876). Change it to check for remote URLs and use pre-resolved content:

Replace lines 2860-2876 with:

```lua
            -- Use the precomputed file references instead of scanning for them again
            for _, file_ref in ipairs(exchange.question.file_references) do
                local path = file_ref.path

                logger.debug("Processing file reference: " .. path)

                -- Check if this is a pre-resolved remote reference
                if opts.resolved_remote_content and opts.resolved_remote_content[path] then
                    file_content = opts.resolved_remote_content[path]
                -- Check if this is a directory or has directory pattern markers (* or **/)
                elseif
                    helpers.is_directory(path)
                    or path:match("/%*%*?/?") -- Contains /** or /**/
                    or path:match("/%*%.%w+$")
                then -- Contains /*.ext pattern
                    file_content = helpers.process_directory_pattern(path)
                else
                    file_content = helpers.format_file_content(path)
                end
            end
```

**Step 2: Add `_resolve_remote_references` function to init.lua**

Add this new function before `chat_respond` (around line 2937):

```lua
-- Resolve all remote (URL-based) file references asynchronously before building messages
-- Calls callback with resolved_remote_content map when all fetches complete
---@param parsed_chat table # parsed chat structure
---@param config table # plugin config
---@param callback function # called with resolved_remote_content table
M._resolve_remote_references = function(parsed_chat, config, callback)
    local helpers = require("parley.helper")
    local google_drive = require("parley.google_drive")
    local remote_refs = {}

    -- Collect all remote URL references
    for _, exchange in ipairs(parsed_chat.exchanges) do
        if exchange.question and exchange.question.file_references then
            for _, file_ref in ipairs(exchange.question.file_references) do
                if helpers.is_remote_url(file_ref.path) then
                    table.insert(remote_refs, file_ref.path)
                end
            end
        end
    end

    if #remote_refs == 0 then
        callback({})
        return
    end

    local resolved = {}
    local pending = #remote_refs
    local logger = require("parley.logger")

    for _, url in ipairs(remote_refs) do
        if google_drive.is_google_url(url) then
            google_drive.fetch_content(url, config.google_drive, function(content, err)
                if content then
                    resolved[url] = content
                else
                    resolved[url] = "File: " .. url .. "\n[Error: " .. (err or "Failed to fetch") .. "]\n\n"
                    logger.warning("Failed to fetch Google Drive content: " .. (err or "unknown error"))
                end
                pending = pending - 1
                if pending == 0 then
                    callback(resolved)
                end
            end)
        else
            -- Unsupported remote URL type
            resolved[url] = "File: " .. url .. "\n[Error: Unsupported URL type. Only Google Drive URLs are currently supported.]\n\n"
            pending = pending - 1
            if pending == 0 then
                callback(resolved)
            end
        end
    end
end
```

**Step 3: Modify `chat_respond` to use async resolution**

In `lua/parley/init.lua`, find where `_build_messages` is called (around line 3046). Wrap it with the remote resolution:

Replace the `_build_messages` call block with:

```lua
    -- Resolve remote file references, then build messages
    M._resolve_remote_references(parsed_chat, M.config, function(resolved_remote_content)
        local messages = M._build_messages({
            parsed_chat = parsed_chat,
            start_index = start_index,
            end_index = end_index,
            exchange_idx = exchange_idx,
            agent = agent,
            config = M.config,
            helpers = require("parley.helper"),
            logger = require("parley.logger"),
            resolved_remote_content = resolved_remote_content,
        })

        -- Continue with the rest of chat_respond (dispatch, etc.)
        -- ... existing code that follows the _build_messages call ...
    end)
```

Note: The exact integration will require reading the surrounding code in `chat_respond` to ensure the callback wrapping is correct. The agent implementing this should read `init.lua:3040-3100` to see what code follows the `_build_messages` call and needs to be inside the callback.

**Step 4: Add integration test for build_messages with remote content**

Append to `tests/unit/build_messages_spec.lua`:

```lua
describe("_build_messages: remote file references", function()
    it("uses resolved_remote_content for URL references", function()
        local file_refs = {
            { line = "@@https://docs.google.com/document/d/abc123/edit",
              path = "https://docs.google.com/document/d/abc123/edit",
              original_line_index = 2 }
        }
        local pc = parsed_chat({ exchange("Review this doc", nil, nil, file_refs) })

        local resolved = {
            ["https://docs.google.com/document/d/abc123/edit"] = "File: Google Doc - \"Test\"\n```markdown\n1: Hello\n```\n\n"
        }

        local messages = parley._build_messages({
            parsed_chat = pc,
            start_index = 1,
            end_index = 100,
            exchange_idx = 1,
            agent = agent(),
            config = parley.config,
            helpers = stub_helpers,
            logger = stub_logger,
            resolved_remote_content = resolved,
        })

        -- Should have system (prompt) + system (file content) + user (question)
        assert.equals(3, #messages)
        assert.equals("system", messages[2].role)
        assert.is_true(messages[2].content:match("Google Doc") ~= nil)
        assert.equals("user", messages[3].role)
        assert.equals("Review this doc", messages[3].content)
    end)
end)
```

**Step 5: Run tests**

Run: `make test`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add lua/parley/init.lua tests/unit/build_messages_spec.lua
git commit -m "feat: integrate Google Drive async fetching into message building pipeline"
```

---

### Task 8: Manual testing and polish

**Files:**
- Potentially modify: any file for bug fixes discovered during manual testing

**Step 1: Set up Google Cloud credentials**

1. Go to Google Cloud Console, create a project
2. Enable Google Drive API
3. Create OAuth 2.0 credentials (Desktop application type)
4. Add `http://localhost` to authorized redirect URIs
5. Copy client_id and client_secret

**Step 2: Configure parley**

In your Neovim config:

```lua
require('parley').setup({
    -- ... existing config ...
    google_drive = {
        client_id = "YOUR_CLIENT_ID.apps.googleusercontent.com",
        client_secret = "YOUR_CLIENT_SECRET",
    },
})
```

**Step 3: Test the full flow**

1. Open Neovim, create a new parley chat
2. Type a question with a Google Docs reference:
   ```
   💬: Please review this document
   @@https://docs.google.com/document/d/YOUR_DOC_ID/edit
   ```
3. Submit the question
4. Browser should open for OAuth consent (first time only)
5. After consenting, the document content should be fetched and included in the LLM prompt
6. Verify the response references the document content

**Step 4: Test subsequent requests (cached token)**

1. Submit another question with a different Google Doc URL
2. Should NOT open browser again (token cached in keychain)
3. Content should be fetched and included

**Step 5: Test error cases**

1. Try an invalid Google Doc URL -- should show error message
2. Try a URL to a document you don't have access to -- should show permission error
3. Try a non-Google URL -- should show unsupported URL error

**Step 6: Run full test suite**

Run: `make test`
Expected: All tests PASS

**Step 7: Commit any fixes**

```bash
git add -A
git commit -m "fix: polish Google Drive integration based on manual testing"
```

---

### Task 9: Final cleanup and PR

**Step 1: Run full test suite one final time**

Run: `make test`
Expected: All tests PASS

**Step 2: Review all changes**

```bash
git diff main..HEAD --stat
```

Verify:
- New file: `lua/parley/google_drive.lua`
- New file: `tests/unit/google_drive_spec.lua`
- Modified: `lua/parley/config.lua` (google_drive config section)
- Modified: `lua/parley/helper.lua` (is_remote_url function)
- Modified: `lua/parley/init.lua` (resolved_remote_content in _build_messages, _resolve_remote_references, chat_respond async wrapping)
- Modified: `tests/unit/build_messages_spec.lua` (remote content test)
- Design doc: `docs/plans/2026-03-02-google-drive-support-design.md`

**Step 3: Create PR**

```bash
gh pr create \
    --title "Support Google Drive file references via OAuth" \
    --body "Closes #23. Adds support for @@https://docs.google.com/... URLs in chat questions. Authenticates via OAuth with localhost redirect, caches tokens in OS keychain."
```
