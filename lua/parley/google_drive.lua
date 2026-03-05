local M = {}

local uv = vim.loop
local tasker = require("parley.tasker")
local logger = require("parley.logger")

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

-- URL-encode a string (replace non-alphanumeric chars with %XX)
---@param str string # the string to encode
---@return string # URL-encoded string
M._url_encode = function(str)
    if not str then
        return ""
    end
    str = str:gsub("([^%w%-%.%_%~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    return str
end

-- Build Google OAuth authorization URL
---@param config table # config with client_id, scopes fields
---@param port number # local server port for redirect_uri
---@return string # full authorization URL
M.build_auth_url = function(config, port)
    local base = "https://accounts.google.com/o/oauth2/v2/auth"
    local scopes = config.scopes or { "https://www.googleapis.com/auth/drive.readonly" }
    local scope = table.concat(scopes, " ")
    local params = {
        "client_id=" .. M._url_encode(config.client_id),
        "redirect_uri=" .. M._url_encode("http://localhost:" .. tostring(port)),
        "response_type=code",
        "scope=" .. M._url_encode(scope),
        "access_type=offline",
        "prompt=consent",
    }
    return base .. "?" .. table.concat(params, "&")
end

-- Build curl args for exchanging an auth code for tokens
---@param config table # config with client_id, client_secret fields
---@param auth_code string # the authorization code from the OAuth redirect
---@param port number # local server port used as redirect_uri
---@return table # list of curl arguments
M.build_token_exchange_args = function(config, auth_code, port)
    return {
        "-s",
        "-X", "POST",
        "https://oauth2.googleapis.com/token",
        "-d", "code=" .. M._url_encode(auth_code),
        "-d", "client_id=" .. M._url_encode(config.client_id),
        "-d", "client_secret=" .. M._url_encode(config.client_secret),
        "-d", "redirect_uri=" .. M._url_encode("http://localhost:" .. tostring(port)),
        "-d", "grant_type=authorization_code",
    }
end

-- Build OS keychain store command
---@param platform string # "darwin" or "linux"
---@param json_data string # JSON string to store
---@return table # command as list of arguments
M.build_keychain_store_cmd = function(platform, json_data)
    if platform == "darwin" then
        return {
            "security", "add-generic-password",
            "-U",
            "-s", "parley-nvim-google-oauth",
            "-a", "default",
            "-w", json_data,
        }
    else
        return {
            "secret-tool", "store",
            "--label", "parley-nvim-google-oauth",
            "service", "parley-nvim-google-oauth",
            "account", "default",
        }
    end
end

-- Build OS keychain delete command
---@param platform string # "darwin" or "linux"
---@return table # command as list of arguments
M.build_keychain_delete_cmd = function(platform)
    if platform == "darwin" then
        return {
            "security", "delete-generic-password",
            "-s", "parley-nvim-google-oauth",
            "-a", "default",
        }
    else
        return {
            "secret-tool", "clear",
            "service", "parley-nvim-google-oauth",
            "account", "default",
        }
    end
end

-- Build OS keychain load command
---@param platform string # "darwin" or "linux"
---@return table # command as list of arguments
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
---@param file_id string # the Google Drive file ID
---@return string # metadata API URL
M.build_metadata_url = function(file_id)
    return "https://www.googleapis.com/drive/v3/files/" .. file_id .. "?fields=mimeType,name"
end

-- Build Google Drive API export URL
---@param file_id string # the Google Drive file ID
---@param mime_type string # the MIME type to export as
---@return string # export API URL
M.build_export_url = function(file_id, mime_type)
    return "https://www.googleapis.com/drive/v3/files/" .. file_id .. "/export?mimeType=" .. mime_type
end

-- Build Google Drive API download URL
---@param file_id string # the Google Drive file ID
---@return string # download API URL
M.build_download_url = function(file_id)
    return "https://www.googleapis.com/drive/v3/files/" .. file_id .. "?alt=media"
end

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

-- Parse the auth code from an HTTP request line
---@param request_data string # raw HTTP request
---@return string|nil # the authorization code, or nil
M._parse_auth_code = function(request_data)
    return request_data:match("[?&]code=([^&%s]+)")
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
        -- Linux secret-tool reads from stdin via printf to avoid shell injection
        local escaped_args = {}
        for _, arg in ipairs(cmd_args) do
            table.insert(escaped_args, vim.fn.shellescape(arg))
        end
        tasker.run(nil, "sh", { "-c", "printf '%s' " .. vim.fn.shellescape(json_data) .. " | " .. cmd .. " " .. table.concat(escaped_args, " ") }, function(code)
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

-- Remove stored OAuth tokens (logout)
---@param callback function|nil # called with boolean success
M.logout = function(callback)
    callback = callback or function() end
    cached_tokens = nil

    local platform = M._get_platform()
    local cmd_args = M.build_keychain_delete_cmd(platform)
    local cmd = table.remove(cmd_args, 1)

    tasker.run(nil, cmd, cmd_args, function(code)
        if code == 0 then
            logger.info("Google Drive OAuth tokens removed")
            callback(true)
        else
            logger.warning("No Google OAuth tokens found to remove (or removal failed)")
            callback(false)
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
            vim.schedule(function()
                callback(nil)
            end)
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

    -- Timeout: close server after 2 minutes if no auth response received
    local timeout_timer = uv.new_timer()
    timeout_timer:start(120000, 0, function()
        if not server:is_closing() then
            logger.warning("Google OAuth: authentication timed out after 2 minutes")
            server:close()
            vim.schedule(function()
                vim.api.nvim_echo({{ "Google OAuth: Authentication timed out.", "ErrorMsg" }}, true, {})
                callback(nil)
            end)
        end
        timeout_timer:close()
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
M.get_access_token = function(config, callback, url)
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
                    -- Refresh failed, prompt user instead of auto-opening browser
                    M._prompt_auth(
                        config,
                        "Google OAuth: Token refresh failed. Please re-authenticate.",
                        callback,
                        url
                    )
                end
            end)
        else
            -- No tokens, prompt user instead of auto-opening browser
            M._prompt_auth(
                config,
                "Google OAuth: No saved credentials. Please authenticate to access Google Drive files.",
                callback,
                url
            )
        end
    end)
end

-- Format fetched Google content to match helper.format_file_content output
---@param name string # document title
---@param file_type string # one of: document, spreadsheet, presentation, drive_file
---@param content string # raw file content
---@param url string|nil # original URL for context
---@return string # formatted content with header and line numbers
M.format_google_content = function(name, file_type, content, url)
    local label = type_labels[file_type] or "Google Drive File"
    local filetype = type_filetypes[file_type] or ""

    local lines = vim.split(content, "\n")
    local numbered_lines = {}
    for i, line in ipairs(lines) do
        table.insert(numbered_lines, string.format("%d: %s", i, line))
    end
    local numbered_content = table.concat(numbered_lines, "\n")

    local header = "File: " .. label .. " - \"" .. name .. "\""
    if url then
        header = header .. " (fetched from " .. url .. ")"
    end

    return header .. "\n```" .. filetype .. "\n" .. numbered_content .. "\n```\n\n"
end

-- Classify a Google API error code as auth-related or not.
-- Returns "auth" for errors that may be resolved by re-authenticating.
-- Google returns 404 for both "not found" and "no access" (privacy), so we
-- treat it as auth-related to give the user a chance to switch accounts.
---@param error_code number|nil # the HTTP error code from the API
---@return string # "auth" or "other"
M._classify_api_error = function(error_code)
    if error_code == 401 or error_code == 403 or error_code == 404 then
        return "auth"
    end
    return "other"
end

-- Map of URL host patterns to OAuth provider names.
-- Used to auto-select the correct provider without prompting the user.
local url_provider_map = {
    { pattern = "docs%.google%.com/", provider = "google" },
    { pattern = "drive%.google%.com/", provider = "google" },
}

-- Detect the OAuth provider for a URL based on well-known host patterns.
---@param url string|nil # the URL to check
---@return string|nil # provider name (e.g. "google") or nil if unknown
M._detect_provider_for_url = function(url)
    if not url or type(url) ~= "string" then
        return nil
    end
    for _, entry in ipairs(url_provider_map) do
        if url:match(entry.pattern) then
            return entry.provider
        end
    end
    return nil
end

-- Prompt the user to authenticate with an OAuth provider via vim.ui.select.
-- When a url is provided and matches a well-known provider, skips the picker.
-- Extensible: add future providers (MS OAuth, etc.) to the providers table.
---@param config table # google_drive config
---@param reason string # human-readable reason shown to the user
---@param callback function # called with access_token (string) or nil if cancelled
---@param url string|nil # optional URL to auto-detect provider
M._prompt_auth = function(config, reason, callback, url)
    -- Provider list (add entries here for future OAuth providers)
    local providers = {
        { name = "Google Drive (OAuth)", provider = "google" },
    }

    -- Helper: authenticate with a given provider entry
    local function auth_with_provider(selected)
        if selected.provider == "google" then
            M.authenticate(config, function(tokens)
                if tokens then
                    callback(tokens.access_token)
                else
                    callback(nil)
                end
            end)
        else
            logger.warning("OAuth provider " .. selected.provider .. " not yet implemented")
            callback(nil)
        end
    end

    -- Auto-detect provider from URL
    local detected = M._detect_provider_for_url(url)
    if detected then
        for _, p in ipairs(providers) do
            if p.provider == detected then
                vim.schedule(function()
                    vim.api.nvim_echo({{ reason, "WarningMsg" }}, true, {})
                    logger.debug("Auto-selected OAuth provider: " .. p.name)
                    auth_with_provider(p)
                end)
                return
            end
        end
    end

    -- Fall back to picker when provider can't be auto-detected
    vim.schedule(function()
        vim.api.nvim_echo({{ reason, "WarningMsg" }}, true, {})

        local display_items = {}
        for _, p in ipairs(providers) do
            table.insert(display_items, p.name)
        end
        table.insert(display_items, "Skip")

        vim.ui.select(display_items, {
            prompt = "Authenticate to access remote file:",
        }, function(choice, idx)
            if not choice or choice == "Skip" then
                callback(nil)
                return
            end

            local selected = providers[idx]
            if not selected then
                callback(nil)
                return
            end

            auth_with_provider(selected)
        end)
    end)
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

    -- Inner function that performs the actual fetch with a given access_token.
    -- retry_allowed prevents infinite loops: true on first attempt, false on retry.
    local function do_fetch(access_token, retry_allowed)
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
            if not ok or not meta then
                logger.warning("Google Drive API: failed to parse metadata response: " .. tostring(stdout_data))
                callback(nil, "Google Drive API: invalid metadata response")
                return
            end

            -- Check for API error response (e.g., 401 Unauthorized, 403 Forbidden, 404 Not Found)
            if meta.error then
                local err_code = meta.error.code
                local err_msg = (meta.error.message or "unknown error")
                    .. " (code: " .. tostring(err_code or "?") .. ")"
                logger.warning("Google Drive API metadata error: " .. err_msg)

                -- If auth-related and retry allowed, prompt user to re-authenticate
                if retry_allowed and M._classify_api_error(err_code) == "auth" then
                    cached_tokens = nil
                    M._prompt_auth(
                        config,
                        "Google Drive API: " .. err_msg .. " — Re-authenticate with a different account?",
                        function(new_token)
                            if new_token then
                                do_fetch(new_token, false)
                            else
                                callback(nil, "Google Drive API: " .. err_msg)
                            end
                        end,
                        url
                    )
                    return
                end

                callback(nil, "Google Drive API: " .. err_msg)
                return
            end

            if not meta.name then
                logger.warning("Google Drive API: metadata response missing 'name' field: " .. tostring(stdout_data))
                callback(nil, "Google Drive API: invalid metadata response (missing file name)")
                return
            end

            local file_name = meta.name

            -- Determine how to fetch content
            local export_mime = M.get_export_mime(info.file_type)
            local content_url
            if export_mime then
                content_url = M.build_export_url(info.file_id, export_mime)
            else
                if meta.mimeType and meta.mimeType:match("google%-apps") then
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
                            callback(M.format_google_content(file_name, info.file_type, fb_data, url))
                        end)
                        return
                    end
                    callback(nil, "Google Drive API: " .. err_msg)
                    return
                end

                callback(M.format_google_content(file_name, info.file_type, content_data, url))
            end)
        end)
    end

    -- Start by getting access token, then fetch
    M.get_access_token(config, function(access_token)
        if not access_token then
            callback(nil, "Google OAuth: authentication cancelled or failed.")
            return
        end
        do_fetch(access_token, true)
    end, url)
end

return M
