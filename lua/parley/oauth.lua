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

local dropbox_url_patterns = {
    { pattern = "dropbox%.com/s/[^/?#]+/([^?#]+)", link_type = "file" },
    { pattern = "dropbox%.com/scl/fi/[^/?#]+/([^?#]+)", link_type = "file" },
    { pattern = "dropbox%.com/sh/[^/?#]+/([^?#]+)", link_type = "folder" },
    { pattern = "dropbox%.com/scl/fo/[^/?#]+/([^?#]+)", link_type = "folder" },
}

local onedrive_url_patterns = {
    "onedrive%.live%.com/",
    "1drv%.ms/",
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

-- MIME types that indicate binary Office formats needing conversion to text
local office_binary_mimes = {
    ["application/vnd.openxmlformats-officedocument.wordprocessingml.document"] = "docx",
    ["application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"] = "xlsx",
    ["application/vnd.openxmlformats-officedocument.presentationml.presentation"] = "pptx",
    ["application/msword"] = "doc",
    ["application/vnd.ms-excel"] = "xls",
    ["application/vnd.ms-powerpoint"] = "ppt",
}

local public_fetch_meta_marker = "__PARLEY_REMOTE_FETCH_META__"
local provider_definitions

local function normalize_dropbox_shared_link(url)
    if not url or type(url) ~= "string" then
        return url
    end

    local base, query = url:match("^([^?#]+)%??([^#]*)")
    if not query or query == "" then
        return base or url
    end

    local kept = {}
    for pair in query:gmatch("[^&]+") do
        local key = pair:match("^([^=]+)")
        if key ~= "dl" and key ~= "raw" then
            table.insert(kept, pair)
        end
    end

    if #kept == 0 then
        return base
    end
    return base .. "?" .. table.concat(kept, "&")
end

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

---@param path string|nil
---@return boolean
M.is_dropbox_url = function(path)
    if not path or type(path) ~= "string" then
        return false
    end
    for _, entry in ipairs(dropbox_url_patterns) do
        if path:match(entry.pattern) then
            return true
        end
    end
    return false
end

---@param url string
---@return table|nil
M.parse_dropbox_url = function(url)
    if not url or type(url) ~= "string" then
        return nil
    end
    for _, entry in ipairs(dropbox_url_patterns) do
        local name = url:match(entry.pattern)
        if name then
            return {
                shared_link = normalize_dropbox_shared_link(url),
                file_name = name,
                file_type = entry.link_type,
            }
        end
    end
    return nil
end

---@param path string|nil
---@return boolean
M.is_onedrive_url = function(path)
    if not path or type(path) ~= "string" then
        return false
    end
    for _, pattern in ipairs(onedrive_url_patterns) do
        if path:match(pattern) then
            return true
        end
    end
    return false
end

-- Encode a sharing URL for the Microsoft Graph shares API.
-- Format: "u!" followed by base64url-encoded URL (no padding).
---@param url string
---@return string
M._encode_sharing_url = function(url)
    -- base64 encode
    local encoded = vim.base64.encode(url)
    -- convert to base64url: replace + with -, / with _, remove trailing =
    encoded = encoded:gsub("+", "-"):gsub("/", "_"):gsub("=+$", "")
    return "u!" .. encoded
end

---@param url string
---@return table|nil
M.parse_onedrive_url = function(url)
    if not url or type(url) ~= "string" then
        return nil
    end
    if not M.is_onedrive_url(url) then
        return nil
    end
    return {
        shared_url = url,
    }
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

-- URL-decode a percent-encoded string (%XX -> character)
---@param str string|nil
---@return string
M._url_decode = function(str)
    if not str then
        return ""
    end
    return str:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end)
end

-- Resolve scopes for a provider: config overrides > defaults, plus required scopes.
---@param config table|nil
---@param provider string|nil
---@return string # space-separated scope string
M._get_provider_scope_string = function(config, provider)
    local definition = M._get_provider_definition(provider)
    local default_scopes = definition and definition.default_scopes or {}
    local required_scopes = definition and definition.required_scopes or {}
    local scopes = (type(config) == "table" and config.scopes) or default_scopes

    -- Ensure required scopes are present
    for _, req in ipairs(required_scopes) do
        local found = false
        for _, s in ipairs(scopes) do
            if s == req then
                found = true
                break
            end
        end
        if not found then
            scopes = vim.list_extend(vim.deepcopy(scopes), { req })
        end
    end

    return table.concat(scopes, " ")
end

---@param config table|nil
---@param port number
---@return string
M._build_redirect_uri = function(config, port)
    if type(config) == "table" then
        local explicit_uri = config.redirect_uri or config.redirect_url
        if explicit_uri and explicit_uri ~= "" then
            return explicit_uri
        end
    end
    return "http://localhost:" .. tostring(port)
end

---@param config table|nil
---@return number
M._get_redirect_port = function(config)
    if type(config) ~= "table" then
        return 0
    end

    local redirect_port = config.redirect_port
    if type(redirect_port) == "string" and redirect_port ~= "" then
        redirect_port = tonumber(redirect_port)
    end
    if type(redirect_port) == "number" then
        return redirect_port
    end

    local explicit_uri = config.redirect_uri or config.redirect_url
    if type(explicit_uri) == "string" then
        local uri_port = explicit_uri:match("^https?://[^:/]+:(%d+)")
        if uri_port then
            local parsed = tonumber(uri_port)
            if parsed then
                return parsed
            end
        end
    end

    return 0
end

local function build_google_auth_url(config, port)
    local base = "https://accounts.google.com/o/oauth2/v2/auth"
    local scope = M._get_provider_scope_string(config, "google")
    local redirect_uri = M._build_redirect_uri(config, port)
    local params = {
        "client_id=" .. M._url_encode(config.client_id),
        "redirect_uri=" .. M._url_encode(redirect_uri),
        "response_type=code",
        "scope=" .. M._url_encode(scope),
        "access_type=offline",
        "prompt=consent",
    }
    return base .. "?" .. table.concat(params, "&")
end

local function build_google_token_exchange_args(config, auth_code, port)
    local redirect_uri = M._build_redirect_uri(config, port)
    return {
        "-s",
        "-X", "POST",
        "https://oauth2.googleapis.com/token",
        "-d", "code=" .. M._url_encode(auth_code),
        "-d", "client_id=" .. M._url_encode(config.client_id),
        "-d", "client_secret=" .. M._url_encode(config.client_secret),
        "-d", "redirect_uri=" .. M._url_encode(redirect_uri),
        "-d", "grant_type=authorization_code",
    }
end

local function build_google_refresh_token_args(config, account)
    return {
        "-s",
        "-X", "POST",
        "https://oauth2.googleapis.com/token",
        "-d", "client_id=" .. config.client_id,
        "-d", "client_secret=" .. config.client_secret,
        "-d", "refresh_token=" .. account.refresh_token,
        "-d", "grant_type=refresh_token",
    }
end

local function build_dropbox_auth_url(config, port)
    local base = "https://www.dropbox.com/oauth2/authorize"
    local scope = M._get_provider_scope_string(config, "dropbox")
    local redirect_uri = M._build_redirect_uri(config, port)
    local params = {
        "client_id=" .. M._url_encode(config.client_id),
        "redirect_uri=" .. M._url_encode(redirect_uri),
        "response_type=code",
        "token_access_type=offline",
        "scope=" .. M._url_encode(scope),
    }
    return base .. "?" .. table.concat(params, "&")
end

local function build_dropbox_token_exchange_args(config, auth_code, port)
    local redirect_uri = M._build_redirect_uri(config, port)
    return {
        "-s",
        "-X", "POST",
        "https://api.dropboxapi.com/oauth2/token",
        "-d", "code=" .. M._url_encode(auth_code),
        "-d", "client_id=" .. M._url_encode(config.client_id),
        "-d", "client_secret=" .. M._url_encode(config.client_secret),
        "-d", "redirect_uri=" .. M._url_encode(redirect_uri),
        "-d", "grant_type=authorization_code",
    }
end

local function build_dropbox_refresh_token_args(config, account)
    return {
        "-s",
        "-X", "POST",
        "https://api.dropboxapi.com/oauth2/token",
        "-d", "client_id=" .. M._url_encode(config.client_id),
        "-d", "client_secret=" .. M._url_encode(config.client_secret),
        "-d", "refresh_token=" .. M._url_encode(account.refresh_token),
        "-d", "grant_type=refresh_token",
    }
end

local function build_microsoft_auth_url(config, port)
    local base = "https://login.microsoftonline.com/consumers/oauth2/v2.0/authorize"
    local scope = M._get_provider_scope_string(config, "microsoft")
    local redirect_uri = M._build_redirect_uri(config, port)
    local params = {
        "client_id=" .. M._url_encode(config.client_id),
        "redirect_uri=" .. M._url_encode(redirect_uri),
        "response_type=code",
        "scope=" .. M._url_encode(scope),
        "prompt=consent",
    }
    return base .. "?" .. table.concat(params, "&")
end

local function build_microsoft_token_exchange_args(config, auth_code, port)
    local redirect_uri = M._build_redirect_uri(config, port)
    local scope = M._get_provider_scope_string(config, "microsoft")
    return {
        "-s",
        "-X", "POST",
        "https://login.microsoftonline.com/consumers/oauth2/v2.0/token",
        "-d", "code=" .. M._url_encode(auth_code),
        "-d", "client_id=" .. M._url_encode(config.client_id),
        "-d", "client_secret=" .. M._url_encode(config.client_secret),
        "-d", "redirect_uri=" .. M._url_encode(redirect_uri),
        "-d", "grant_type=authorization_code",
        "-d", "scope=" .. M._url_encode(scope),
    }
end

local function build_microsoft_refresh_token_args(config, account)
    local scope = M._get_provider_scope_string(config, "microsoft")
    return {
        "-s",
        "-X", "POST",
        "https://login.microsoftonline.com/consumers/oauth2/v2.0/token",
        "-d", "client_id=" .. M._url_encode(config.client_id),
        "-d", "client_secret=" .. M._url_encode(config.client_secret),
        "-d", "refresh_token=" .. M._url_encode(account.refresh_token),
        "-d", "grant_type=refresh_token",
        "-d", "scope=" .. M._url_encode(scope),
    }
end

-- Build OAuth authorization URL.
---@param config table # provider config or provider config map
---@param port number # local server port for redirect_uri
---@param provider string|nil
---@return string # full authorization URL
M.build_auth_url = function(config, port, provider)
    provider = provider or "google"
    if provider == "google" then
        return build_google_auth_url(config, port)
    elseif provider == "dropbox" then
        return build_dropbox_auth_url(config, port)
    elseif provider == "microsoft" then
        return build_microsoft_auth_url(config, port)
    end
    error("OAuth provider " .. tostring(provider) .. " does not implement build_auth_url")
end

-- Build curl args for exchanging an auth code for tokens.
---@param config table # provider config or provider config map
---@param auth_code string # the authorization code from the OAuth redirect
---@param port number # local server port used as redirect_uri
---@param provider string|nil
---@return table # list of curl arguments
M.build_token_exchange_args = function(config, auth_code, port, provider)
    provider = provider or "google"
    if provider == "google" then
        return build_google_token_exchange_args(config, auth_code, port)
    elseif provider == "dropbox" then
        return build_dropbox_token_exchange_args(config, auth_code, port)
    elseif provider == "microsoft" then
        return build_microsoft_token_exchange_args(config, auth_code, port)
    end
    error("OAuth provider " .. tostring(provider) .. " does not implement build_token_exchange_args")
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
        account_id = data.account_id,
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

-- In-memory OAuth account store (loaded from keychain on first use).
-- Shape: { version = 2, preferred_account_id = "...", accounts = { ... } }
local cached_account_store = nil

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
local function parse_auth_query_param(request_data, key)
    if not request_data or not key then
        return nil
    end
    local value = request_data:match("[?&]" .. key .. "=([^&%s]+)")
    if value then
        return M._url_decode(value)
    end
    return nil
end

-- Parse the auth code from an HTTP request line
---@param request_data string # raw HTTP request
---@return string|nil # the authorization code, or nil
M._parse_auth_code = function(request_data)
    return parse_auth_query_param(request_data, "code")
end

-- Parse an OAuth error from an HTTP request line.
---@param request_data string # raw HTTP request
---@return string|nil # the OAuth error value, or nil
M._parse_auth_error = function(request_data)
    return parse_auth_query_param(request_data, "error")
end

-- Parse the OAuth callback request and prepare the browser response.
---@param request_data string # raw HTTP request
---@return table # {code, auth_error, response, is_cancelled}
M._handle_auth_callback_request = function(request_data)
    local code = M._parse_auth_code(request_data)
    local auth_error = M._parse_auth_error(request_data)

    local response_body
    if code then
        response_body = "<html><body><h1>Authentication successful!</h1><p>You can close this window and return to Neovim.</p></body></html>"
    elseif auth_error == "access_denied" then
        response_body = "<html><body><h1>Authentication cancelled</h1><p>You cancelled the OAuth request. Return to Neovim to continue.</p></body></html>"
    else
        response_body = "<html><body><h1>Authentication failed</h1><p>No authorization code received.</p></body></html>"
    end

    return {
        code = code,
        auth_error = auth_error,
        is_cancelled = auth_error == "access_denied",
        response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n" .. response_body,
    }
end

---@return table
M._new_account_store = function()
    return {
        version = 3,
        preferred_account_id = nil,
        preferred_account_ids = {},
        accounts = {},
    }
end

---@param tokens table|nil
---@param provider string|nil
---@return string
M._make_account_id = function(tokens, provider)
    provider = provider or (tokens and tokens.provider) or "google"
    local source = (tokens and (tokens.refresh_token or tokens.access_token)) or tostring(os.time())
    source = tostring(source):gsub("[^%w]", "")
    if source == "" then
        source = tostring(os.time())
    end
    return provider .. "_" .. source:sub(1, 24)
end

---@param tokens table|nil
---@param provider string|nil
---@return table
M._normalize_account = function(tokens, provider)
    local account = vim.deepcopy(tokens or {})
    account.provider = provider or account.provider or "google"
    account.account_id = account.account_id or M._make_account_id(account, account.provider)
    account.invalid = account.invalid == true
    if not account.label then
        local provider_label = account.provider:gsub("^%l", string.upper)
        account.label = provider_label .. " Account " .. account.account_id:sub(-6)
    end
    return account
end

---@param store table|nil
---@return table
M._normalize_account_store = function(store)
    local normalized = M._new_account_store()
    if type(store) ~= "table" then
        return normalized
    end

    if type(store.accounts) == "table" then
        normalized.version = store.version or 3
        if type(store.preferred_account_ids) == "table" then
            normalized.preferred_account_ids = vim.deepcopy(store.preferred_account_ids)
        elseif store.preferred_account_id then
            normalized.preferred_account_ids.google = store.preferred_account_id
        end
        for _, account in ipairs(store.accounts) do
            if type(account) == "table" and account.access_token then
                table.insert(normalized.accounts, M._normalize_account(account))
            end
        end
    elseif store.access_token then
        local account = M._normalize_account(store, "google")
        normalized.accounts = { account }
        normalized.preferred_account_ids.google = account.account_id
    end

    if not normalized.preferred_account_ids.google then
        for _, account in ipairs(normalized.accounts) do
            if account.provider == "google" then
                normalized.preferred_account_ids.google = account.account_id
                break
            end
        end
    end

    normalized.preferred_account_id = normalized.preferred_account_ids.google

    return normalized
end

---@param store table
---@param account table
---@return integer|nil
M._find_account_index = function(store, account)
    if not store or type(store.accounts) ~= "table" or type(account) ~= "table" then
        return nil
    end

    for idx, existing in ipairs(store.accounts) do
        if existing.provider == account.provider and account.account_id and existing.account_id == account.account_id then
            return idx
        end
        if existing.provider == account.provider and account.refresh_token and existing.refresh_token == account.refresh_token then
            return idx
        end
    end

    return nil
end

---@param store table
---@param account table
---@param provider string|nil
---@return table
M._upsert_account = function(store, account, provider)
    local normalized = M._normalize_account(account, provider)
    local idx = M._find_account_index(store, normalized)

    if idx then
        store.accounts[idx] = vim.tbl_extend("force", store.accounts[idx], normalized)
        return store.accounts[idx]
    end

    while M._find_account_index(store, normalized) do
        normalized.account_id = normalized.account_id .. "_" .. tostring(#store.accounts + 1)
    end

    table.insert(store.accounts, normalized)
    return normalized
end

---@param store table|nil
---@param provider string|nil
---@return table|nil
M._get_preferred_account = function(store, provider)
    provider = provider or "google"
    if not store or type(store.accounts) ~= "table" then
        return nil
    end

    local preferred_account_id = nil
    if type(store.preferred_account_ids) == "table" then
        preferred_account_id = store.preferred_account_ids[provider]
    elseif provider == "google" then
        preferred_account_id = store.preferred_account_id
    end

    if preferred_account_id then
        for _, account in ipairs(store.accounts) do
            if account.provider == provider and account.account_id == preferred_account_id then
                return account
            end
        end
    end

    for _, account in ipairs(store.accounts) do
        if account.provider == provider then
            return account
        end
    end

    return nil
end

---@param store table|nil
---@param provider string|nil
---@return table
M._get_candidate_accounts = function(store, provider)
    provider = provider or "google"
    local ordered = {}
    if not store or type(store.accounts) ~= "table" then
        return ordered
    end

    local preferred = M._get_preferred_account(store, provider)
    local seen = {}

    local function maybe_insert(account)
        if not account or seen[account.account_id] then
            return
        end
        seen[account.account_id] = true
        if account.provider == provider and not account.invalid and (account.refresh_token or account.access_token) then
            table.insert(ordered, account)
        end
    end

    maybe_insert(preferred)
    for _, account in ipairs(store.accounts) do
        maybe_insert(account)
    end

    return ordered
end

-- Save OAuth account store to OS keychain.
---@param store table
---@param callback function|nil # called after save completes
M.save_account_store = function(store, callback)
    callback = callback or function() end
    cached_account_store = M._normalize_account_store(store)
    local json_data = vim.json.encode(cached_account_store)
    local platform = M._get_platform()
    local cmd_args = M.build_keychain_store_cmd(platform, json_data)
    local cmd = table.remove(cmd_args, 1)

    if platform == "linux" then
        local escaped_args = {}
        for _, arg in ipairs(cmd_args) do
            table.insert(escaped_args, vim.fn.shellescape(arg))
        end
        tasker.run(nil, "sh", { "-c", "printf '%s' " .. vim.fn.shellescape(json_data) .. " | " .. cmd .. " " .. table.concat(escaped_args, " ") }, function(code)
            if code ~= 0 then
                logger.warning("Failed to save Google OAuth account store to keychain")
            end
            callback()
        end)
    else
        tasker.run(nil, cmd, cmd_args, function(code)
            if code ~= 0 then
                logger.warning("Failed to save Google OAuth account store to keychain")
            end
            callback()
        end)
    end
end

-- Load OAuth account store from OS keychain.
---@param callback function # called with account store table
M.load_account_store = function(callback)
    if cached_account_store ~= nil then
        callback(cached_account_store)
        return
    end

    local platform = M._get_platform()
    local cmd_args = M.build_keychain_load_cmd(platform)
    local cmd = table.remove(cmd_args, 1)

    tasker.run(nil, cmd, cmd_args, function(code, signal, stdout_data)
        if code ~= 0 or not stdout_data or stdout_data == "" then
            cached_account_store = M._new_account_store()
            callback(cached_account_store)
            return
        end

        local ok, decoded = pcall(vim.json.decode, stdout_data:match("^%s*(.-)%s*$"))
        cached_account_store = ok and M._normalize_account_store(decoded) or M._new_account_store()
        callback(cached_account_store)
    end)
end

-- Backward-compatible token save wrapper.
---@param tokens table # {access_token, refresh_token, expires_at}
---@param callback function|nil # called after save completes
M.save_tokens = function(tokens, callback)
    callback = callback or function() end
    M.load_account_store(function(store)
        local provider = (tokens and tokens.provider) or "google"
        local account = M._upsert_account(store, tokens, provider)
        store.preferred_account_ids[provider] = account.account_id
        M.save_account_store(store, callback)
    end)
end

-- Backward-compatible token load wrapper.
---@param callback function # called with tokens table or nil
M.load_tokens = function(callback)
    M.load_account_store(function(store)
        callback(M._get_preferred_account(store, "google"))
    end)
end

-- Remove stored OAuth tokens (logout)
---@param callback function|nil # called with boolean success
M.logout = function(callback)
    callback = callback or function() end
    cached_account_store = nil

    local platform = M._get_platform()
    local cmd_args = M.build_keychain_delete_cmd(platform)
    local cmd = table.remove(cmd_args, 1)

    tasker.run(nil, cmd, cmd_args, function(code)
        if code == 0 then
            logger.info("Google Drive OAuth accounts removed")
            callback(true)
        else
            logger.warning("No Google OAuth accounts found to remove (or removal failed)")
            callback(false)
        end
    end)
end

-- Refresh one stored account using its refresh token.
---@param config table # provider config or provider config map
---@param provider string|nil
---@param store table
---@param account table # must have refresh_token
---@param callback function # called with updated account table or nil
M._refresh_account = function(config, provider, store, account, callback)
    provider = provider or (account and account.provider) or "google"
    if not account or not account.refresh_token then
        callback(nil)
        return
    end

    local provider_definition = M._get_provider_definition(provider)
    local provider_config = M._get_provider_config(config, provider)
    if not provider_definition or not provider_config or not provider_definition.build_refresh_token_args then
        callback(nil)
        return
    end

    local args = provider_definition.build_refresh_token_args(provider_config, account)

    tasker.run(nil, "curl", args, function(code, signal, stdout_data)
        if code ~= 0 then
            callback(nil)
            return
        end

        local new_tokens = M.parse_token_response(stdout_data)
        if new_tokens then
            new_tokens.refresh_token = new_tokens.refresh_token or account.refresh_token
            new_tokens.account_id = account.account_id
            new_tokens.label = account.label
            new_tokens.provider = provider
            new_tokens.invalid = false
            local updated_account = M._upsert_account(store, new_tokens, provider)
            M.save_account_store(store, function()
                callback(updated_account)
            end)
        else
            callback(nil)
        end
    end)
end

-- Refresh an expired access token using the refresh token.
-- Backward-compatible wrapper around the account-store refresh path.
---@param config table # provider config or provider config map
---@param tokens table # must have refresh_token
---@param callback function # called with new tokens table or nil
---@param provider string|nil
M.refresh_token = function(config, tokens, callback, provider)
    provider = provider or (tokens and tokens.provider) or "google"
    if not tokens or not tokens.refresh_token then
        callback(nil)
        return
    end

    M.load_account_store(function(store)
        local account = M._upsert_account(store, tokens, provider)
        M._refresh_account(config, provider, store, account, callback)
    end)
end

-- Save newly authenticated OAuth tokens into the account store.
---@param tokens table|nil
---@param provider string|nil
---@param callback function # called with saved account table or nil
M._persist_authenticated_account = function(tokens, provider, callback)
    provider = provider or (tokens and tokens.provider) or "google"
    if not tokens then
        callback(nil)
        return
    end

    M.load_account_store(function(store)
        local account = M._upsert_account(store, tokens, provider)
        store.preferred_account_ids[provider] = account.account_id
        M.save_account_store(store, function()
            callback(account)
        end)
    end)
end

-- Run the OAuth authorization-code exchange request.
---@param config table
---@param code string
---@param port number
---@param callback function # called with (exit_code, signal, stdout_data)
---@param provider string|nil
M._run_auth_code_exchange = function(config, code, port, callback, provider)
    local provider_config = M._get_provider_config(config, provider)
    local args = M.build_token_exchange_args(provider_config or config, code, port, provider)
    tasker.run(nil, "curl", args, callback)
end

-- Exchange an OAuth authorization code and persist the resulting account.
---@param config table
---@param code string
---@param port number
---@param callback function # called with account table or nil
---@param provider string|nil
M._exchange_auth_code = function(config, code, port, callback, provider)
    provider = provider or "google"
    M._run_auth_code_exchange(config, code, port, function(exit_code, signal, stdout_data)
        if exit_code ~= 0 then
            logger.warning(M._get_provider_display_name(provider) .. ": token exchange curl failed (exit " .. tostring(exit_code) .. "): " .. tostring(stdout_data))
            callback(nil)
            return
        end

        local tokens = M.parse_token_response(stdout_data)
        if not tokens then
            logger.warning(M._get_provider_display_name(provider) .. ": failed to parse token response: " .. tostring(stdout_data))
            callback(nil)
            return
        end
        tokens.provider = provider

        M._persist_authenticated_account(tokens, provider, callback)
    end, provider)
end

-- Start OAuth flow: open browser, wait for redirect, exchange code for tokens.
---@param config table # OAuth provider config or provider config map
---@param provider string|function|nil
---@param callback function # called with account table or nil
M.authenticate = function(config, provider, callback)
    if type(provider) == "function" and callback == nil then
        callback = provider
        provider = "google"
    end
    provider = provider or "google"
    local provider_config = M._get_provider_config(config, provider)
    local server = uv.new_tcp()
    server:bind("127.0.0.1", M._get_redirect_port(provider_config))

    local addr = server:getsockname()
    local port = addr.port

    logger.debug(M._get_provider_display_name(provider) .. ": starting auth server on port " .. port)

    server:listen(1, function(err)
        if err then
            logger.error(M._get_provider_display_name(provider) .. ": server listen error: " .. tostring(err))
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

            local callback_result = M._handle_auth_callback_request(data)

            client:write(callback_result.response, function()
                client:shutdown(function()
                    client:close()
                end)
            end)
            server:close()

            if not callback_result.code then
                vim.schedule(function()
                    if callback_result.is_cancelled then
                        vim.api.nvim_echo({{ M._get_provider_display_name(provider) .. ": Authentication was cancelled in the browser.", "WarningMsg" }}, true, {})
                    end
                    callback(nil)
                end)
                return
            end

            M._exchange_auth_code(config, callback_result.code, port, callback, provider)
        end)
    end)

    -- Timeout: close server after 30 seconds if no auth response received
    local timeout_timer = uv.new_timer()
    timeout_timer:start(30000, 0, function()
        if not server:is_closing() then
            logger.warning(M._get_provider_display_name(provider) .. ": authentication timed out after 30 seconds")
            server:close()
            vim.schedule(function()
                vim.api.nvim_echo({{ M._get_provider_display_name(provider) .. ": Authentication timed out.", "ErrorMsg" }}, true, {})
                callback(nil)
            end)
        end
        timeout_timer:close()
    end)

    -- Open browser for OAuth consent
    local auth_url = M.build_auth_url(provider_config or config, port, provider)
    local open_cmd = M._get_platform() == "darwin" and "open" or "xdg-open"
    vim.fn.jobstart({ open_cmd, auth_url }, { detach = true })

    vim.schedule(function()
        vim.api.nvim_echo({{ M._get_provider_display_name(provider) .. ": Please complete authentication in your browser...", "WarningMsg" }}, true, {})
    end)
end

-- Get a valid access token from the preferred account, refreshing or re-authenticating as needed.
-- Backward-compatible helper for older call sites.
---@param config table # OAuth provider config or provider config map
---@param callback function # called with access_token string or nil
---@param url string|nil
---@param provider string|nil
M.get_access_token = function(config, callback, url, provider)
    provider = provider or "google"
    M.load_account_store(function(store)
        local account = M._get_preferred_account(store, provider)
        if account and not M.is_token_expired(account) then
            callback(account.access_token)
            return
        end

        if account and account.refresh_token then
            M._refresh_account(config, provider, store, account, function(updated_account)
                if updated_account then
                    store.preferred_account_ids[provider] = updated_account.account_id
                    M.save_account_store(store, function()
                        callback(updated_account.access_token)
                    end)
                else
                    M._prompt_auth(
                        config,
                        M._refresh_failure_message(provider, account),
                        function(new_account)
                            callback(new_account and new_account.access_token or nil)
                        end,
                        url
                    )
                end
            end)
        else
            M._prompt_auth(
                config,
                provider_definitions[provider] and provider_definitions[provider].prompt_reason("no_credentials") or "OAuth: no saved credentials.",
                function(new_account)
                    callback(new_account and new_account.access_token or nil)
                end,
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

---@param url string
---@return string
M._display_name_for_url = function(url)
    if not url or url == "" then
        return "remote-url"
    end

    local without_fragment = url:gsub("#.*$", "")
    local name = without_fragment:match("/([^/?]+)[^/]*$") or without_fragment
    if name == "" then
        return without_fragment
    end
    return name
end

---@param content_type string|nil
---@param fallback_name string|nil
---@return string
M._guess_remote_filetype = function(content_type, fallback_name)
    local lowered = (content_type or ""):lower()
    if lowered:match("json") then
        return "json"
    end
    if lowered:match("html") then
        return "html"
    end
    if lowered:match("markdown") then
        return "markdown"
    end
    if lowered:match("csv") then
        return "csv"
    end
    if lowered:match("xml") then
        return "xml"
    end
    if fallback_name and fallback_name ~= "" then
        return vim.filetype.match({ filename = fallback_name }) or ""
    end
    return ""
end

---@param body string|nil
---@return string
M._sanitize_public_body = function(body)
    if not body or body == "" then
        return body or ""
    end

    local sanitized = body
    sanitized = sanitized:gsub('("content_access_token"%s*:%s*)"[^"]+"', '%1"[REDACTED]"')
    sanitized = sanitized:gsub('("access_token"%s*:%s*)"[^"]+"', '%1"[REDACTED]"')
    sanitized = sanitized:gsub('("refresh_token"%s*:%s*)"[^"]+"', '%1"[REDACTED]"')
    return sanitized
end

---@param url string
---@param parsed table
---@return table|nil, table|nil
M._finalize_public_response = function(url, parsed)
    local effective_url = (parsed.effective_url and parsed.effective_url ~= "") and parsed.effective_url or url
    local lowered_type = (parsed.content_type or ""):lower()

    if not parsed.body or parsed.body == "" then
        return nil, {
            kind = "other",
            message = "Remote URL fetch failed: empty response body from " .. effective_url,
        }
    end

    if lowered_type:match("text/html") then
        return nil, {
            kind = "auth",
            message = "Remote URL fetch failed: received HTML page instead of file content from " .. effective_url,
        }
    end

    if parsed.body:match('"content_access_token"%s*:') and parsed.body:match('"url"%s*:') then
        return nil, {
            kind = "auth",
            message = "Remote URL fetch failed: public URL returned an access handoff payload instead of file content for " .. effective_url,
        }
    end

    parsed.body = M._sanitize_public_body(parsed.body)
    return parsed, nil
end

---@param name string
---@param content string
---@param url string
---@param content_type string|nil
---@param effective_url string|nil
---@return string
M.format_remote_content = function(name, content, url, content_type, effective_url)
    local filetype = M._guess_remote_filetype(content_type, name)
    local lines = vim.split(content, "\n")
    local numbered_lines = {}
    for i, line in ipairs(lines) do
        table.insert(numbered_lines, string.format("%d: %s", i, line))
    end

    local header = 'File: Remote URL - "' .. name .. '"'
    local source_url = effective_url or url
    if source_url and source_url ~= "" then
        header = header .. " (fetched from " .. source_url .. ")"
    end
    if content_type and content_type ~= "" then
        header = header .. " [" .. content_type .. "]"
    end

    return header .. "\n```" .. filetype .. "\n" .. table.concat(numbered_lines, "\n") .. "\n```\n\n"
end

-- Detect if a MIME type is a binary Office format that needs conversion
---@param mime_type string|nil
---@return string|nil # file extension if binary Office format, nil otherwise
M._get_office_extension = function(mime_type)
    if not mime_type then return nil end
    return office_binary_mimes[mime_type:lower():match("^%s*(.-)%s*$")]
end

-- Convert binary Office content to plain text using pandoc or textutil
---@param binary_data string # raw binary content
---@param extension string # file extension (docx, xlsx, etc.)
---@param callback function # callback(text_content, error_message)
M._convert_office_to_text = function(binary_data, extension, callback)
    local tmp_path = os.tmpname() .. "." .. extension
    local f = io.open(tmp_path, "wb")
    if not f then
        callback(nil, "failed to create temp file for Office conversion")
        return
    end
    f:write(binary_data)
    f:close()

    -- Try pandoc first (cross-platform)
    tasker.run(nil, "pandoc", { "-t", "plain", "--wrap=none", tmp_path }, function(code, _, stdout)
        if code == 0 and stdout and stdout ~= "" then
            os.remove(tmp_path)
            callback(stdout)
            return
        end

        -- Try textutil (macOS built-in)
        tasker.run(nil, "textutil", { "-convert", "txt", "-stdout", tmp_path }, function(code2, _, stdout2)
            os.remove(tmp_path)
            if code2 == 0 and stdout2 and stdout2 ~= "" then
                callback(stdout2)
                return
            end

            callback(nil, "cannot convert ." .. extension .. " to text. Install pandoc: https://pandoc.org/installing.html")
        end)
    end)
end

---@param status_code number|nil
---@return string
M._classify_public_fetch_status = function(status_code)
    if status_code == 401 or status_code == 403 or status_code == 404 then
        return "auth"
    end
    if status_code and status_code >= 200 and status_code < 400 then
        return "success"
    end
    return "other"
end

---@param raw_response string|nil
---@return table|nil
M._parse_public_fetch_response = function(raw_response)
    if not raw_response or raw_response == "" then
        return nil
    end

    local marker_start = "\n" .. public_fetch_meta_marker .. "\n"
    local start_pos = raw_response:find(marker_start, 1, true)
    if not start_pos then
        return nil
    end

    local body = raw_response:sub(1, start_pos - 1)
    local meta = raw_response:sub(start_pos + #marker_start)
    local status_code = tonumber(meta:match("HTTP_STATUS:(%d+)"))
    local content_type = meta:match("CONTENT_TYPE:(.-)\n") or ""
    local effective_url = meta:match("EFFECTIVE_URL:(.-)\n") or ""

    return {
        body = body,
        status_code = status_code,
        content_type = content_type,
        effective_url = effective_url,
    }
end

---@param url string
---@param callback function
M._fetch_public_content = function(url, callback)
    local args = {
        "-L",
        "-s",
        "-w",
        "\n" .. public_fetch_meta_marker .. "\n"
            .. "HTTP_STATUS:%{http_code}\n"
            .. "CONTENT_TYPE:%{content_type}\n"
            .. "EFFECTIVE_URL:%{url_effective}\n",
        url,
    }

    tasker.run(nil, "curl", args, function(code, _, stdout_data)
        if code ~= 0 then
            callback(nil, {
                kind = "transport",
                message = "Remote URL fetch failed: curl exited with code " .. tostring(code) .. " for " .. url,
            })
            return
        end

        local parsed = M._parse_public_fetch_response(stdout_data)
        if not parsed or not parsed.status_code then
            callback(nil, {
                kind = "transport",
                message = "Remote URL fetch failed: invalid response while accessing " .. url,
            })
            return
        end

        local kind = M._classify_public_fetch_status(parsed.status_code)
        if kind == "success" then
            local finalized, finalize_err = M._finalize_public_response(url, parsed)
            if finalize_err then
                callback(nil, finalize_err)
                return
            end
            callback(finalized, nil)
            return
        end

        callback(nil, {
            kind = kind,
            status_code = parsed.status_code,
            effective_url = parsed.effective_url,
            message = "Remote URL fetch failed: HTTP "
                .. tostring(parsed.status_code)
                .. " for "
                .. (parsed.effective_url ~= "" and parsed.effective_url or url),
        })
    end)
end

---@param url string
---@param public_result table|nil
---@param public_err table|nil
---@param provider string|nil
---@param info table|nil
---@return table
M._decide_fetch_action = function(url, public_result, public_err, provider, info)
    if public_result then
        local source_url = public_result.effective_url ~= "" and public_result.effective_url or url
        return {
            action = "public",
            display_name = M._display_name_for_url(source_url),
            source_url = source_url,
        }
    end

    if not public_err or public_err.kind ~= "auth" then
        return {
            action = "error",
            message = public_err and public_err.message or ("Remote URL fetch failed for " .. url),
        }
    end

    local provider_definition = M._get_provider_definition(provider)
    if not provider_definition then
        return {
            action = "error",
            message = public_err.message,
        }
    end

    if not info then
        return {
            action = "error",
            message = provider_definition.missing_url_message and provider_definition.missing_url_message(url) or public_err.message,
        }
    end

    return {
        action = "oauth",
    }
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

-- Detect the OAuth provider for a URL based on well-known host patterns.
---@param url string|nil # the URL to check
---@return string|nil # provider name (e.g. "google") or nil if unknown
M._detect_provider_for_url = function(url)
    if not url or type(url) ~= "string" then
        return nil
    end
    for provider_name, definition in pairs(provider_definitions or {}) do
        for _, pattern in ipairs(definition.detect_patterns or {}) do
            if url:match(pattern) then
                return provider_name
            end
        end
    end
    return nil
end

-- Prompt the user to authenticate with an OAuth provider via vim.ui.select.
-- When a url is provided and matches a well-known provider, skips the picker.
-- Extensible: add future providers (MS OAuth, etc.) to the providers table.
---@param config table # OAuth provider config
---@param reason string # human-readable reason shown to the user
---@param callback function # called with account table or nil if cancelled
---@param url string|nil # optional URL to auto-detect provider
M._prompt_auth = function(config, reason, callback, url)
    local detected = M._detect_provider_for_url(url)
    local providers = M._get_provider_prompt_choices(detected)

    -- Helper: authenticate with a given provider entry
    local function auth_with_provider(selected)
        if not M._has_provider_config(selected.provider, config) then
            logger.warning(M._get_provider_display_name(selected.provider) .. ": missing OAuth client configuration")
            callback(nil)
            return
        end

        M.authenticate(config, selected.provider, function(account)
            if account then
                callback(account)
            else
                callback(nil)
            end
        end)
    end

    -- Auto-detect provider from URL
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

---@param error table
---@return string
M._format_api_error_message = function(error)
    local message = error.message or "unknown error"
    if error.code ~= nil then
        return "Google Drive API: " .. message .. " (code: " .. tostring(error.code) .. ")"
    end
    return "Google Drive API: " .. message
end

---@param url string
---@param info table
---@param access_token string
---@param callback function
M._fetch_google_api_once = function(url, info, access_token, callback)
    local meta_url = M.build_metadata_url(info.file_id)
    local meta_args = {
        "-s",
        "-H", "Authorization: Bearer " .. access_token,
        meta_url,
    }

    tasker.run(nil, "curl", meta_args, function(code, signal, stdout_data)
        if code ~= 0 then
            callback({ kind = "other", error = "Google Drive API: failed to fetch file metadata" })
            return
        end

        local ok, meta = pcall(vim.json.decode, stdout_data)
        if not ok or not meta then
            logger.warning("Google Drive API: failed to parse metadata response: " .. tostring(stdout_data))
            callback({ kind = "other", error = "Google Drive API: invalid metadata response" })
            return
        end

        if meta.error then
            local err = {
                code = meta.error.code,
                message = meta.error.message or "unknown error",
            }
            logger.warning("Google Drive API metadata error: " .. M._format_api_error_message(err))
            callback({
                kind = M._classify_api_error(err.code),
                error = M._format_api_error_message(err),
            })
            return
        end

        if not meta.name then
            logger.warning("Google Drive API: metadata response missing 'name' field: " .. tostring(stdout_data))
            callback({ kind = "other", error = "Google Drive API: invalid metadata response (missing file name)" })
            return
        end

        local file_name = meta.name
        local export_mime = M.get_export_mime(info.file_type)
        local content_url
        if export_mime then
            content_url = M.build_export_url(info.file_id, export_mime)
        elseif meta.mimeType and meta.mimeType:match("google%-apps") then
            content_url = M.build_export_url(info.file_id, "text/plain")
        else
            content_url = M.build_download_url(info.file_id)
        end

        local content_args = {
            "-s",
            "-H", "Authorization: Bearer " .. access_token,
            content_url,
        }

        tasker.run(nil, "curl", content_args, function(content_code, _, content_data)
            if content_code ~= 0 or not content_data or content_data == "" then
                callback({ kind = "other", error = "Google Drive API: failed to fetch file content for " .. file_name })
                return
            end

            local err_ok, err_data = pcall(vim.json.decode, content_data)
            if err_ok and err_data and err_data.error then
                local err = {
                    code = err_data.error.code,
                    message = err_data.error.message or "unknown error",
                }

                if M._classify_api_error(err.code) == "auth" then
                    callback({ kind = "auth", error = M._format_api_error_message(err) })
                    return
                end

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
                            callback({ kind = "other", error = M._format_api_error_message(err) })
                            return
                        end

                        local fb_ok, fb_err = pcall(vim.json.decode, fb_data)
                        if fb_ok and fb_err and fb_err.error then
                            local fallback_error = {
                                code = fb_err.error.code,
                                message = fb_err.error.message or "unknown error",
                            }
                            callback({
                                kind = M._classify_api_error(fallback_error.code),
                                error = M._format_api_error_message(fallback_error),
                            })
                            return
                        end

                        callback({
                            kind = "success",
                            content = M.format_google_content(file_name, info.file_type, fb_data, url),
                        })
                    end)
                    return
                end

                callback({ kind = "other", error = M._format_api_error_message(err) })
                return
            end

            callback({
                kind = "success",
                content = M.format_google_content(file_name, info.file_type, content_data, url),
            })
        end)
    end)
end

---@param error_code number|nil
---@param error_body table|nil
---@return string
M._classify_dropbox_api_error = function(error_code, error_body)
    if error_code == 401 or error_code == 403 then
        return "auth"
    end

    local summary = ""
    if type(error_body) == "table" then
        summary = tostring(error_body.error_summary or error_body.error or "")
    end
    summary = summary:lower()

    if summary:match("access_denied") or summary:match("expired_access_token") or summary:match("invalid_access_token") then
        return "auth"
    end

    return "other"
end

---@param error table
---@return string
M._format_dropbox_api_error_message = function(error)
    local message = error.message or error.error_summary or "unknown error"
    if error.code ~= nil then
        return "Dropbox API: " .. message .. " (code: " .. tostring(error.code) .. ")"
    end
    return "Dropbox API: " .. message
end

---@param error_body table|nil
---@return boolean
M._is_dropbox_unsupported_link_type = function(error_body)
    if type(error_body) ~= "table" then
        return false
    end
    local summary = tostring(error_body.error_summary or error_body.error or ""):lower()
    return summary:match("unsupported_link_type") ~= nil
end

---@param access_token string
---@param info table
---@param callback function
M._run_dropbox_metadata_request = function(access_token, info, callback)
    local args = {
        "-s",
        "-X", "POST",
        "https://api.dropboxapi.com/2/sharing/get_shared_link_metadata",
        "-H", "Authorization: Bearer " .. access_token,
        "-H", "Content-Type: application/json",
        "--data", vim.json.encode({ url = info.shared_link }),
    }
    tasker.run(nil, "curl", args, callback)
end

---@param access_token string
---@param info table
---@param callback function
M._run_dropbox_file_request = function(access_token, info, callback)
    local args = {
        "-s",
        "-X", "POST",
        "-w",
        "\n" .. public_fetch_meta_marker .. "\n"
            .. "HTTP_STATUS:%{http_code}\n"
            .. "CONTENT_TYPE:%{content_type}\n",
        "https://content.dropboxapi.com/2/sharing/get_shared_link_file",
        "-H", "Authorization: Bearer " .. access_token,
        "-H", "Dropbox-API-Arg: " .. vim.json.encode({ url = info.shared_link }),
    }
    tasker.run(nil, "curl", args, callback)
end

---@param url string
---@param info table
---@param access_token string
---@param callback function
M._fetch_dropbox_api_once = function(url, info, access_token, callback)
    if info and info.file_name and info.file_name:lower():match("%.paper$") then
        callback({ kind = "other", error = "Dropbox API: Dropbox Paper shared links are not supported yet." })
        return
    end

    M._run_dropbox_metadata_request(access_token, info, function(code, _, stdout_data)
        if code ~= 0 then
            callback({ kind = "other", error = "Dropbox API: failed to fetch shared link metadata" })
            return
        end

        local ok, meta = pcall(vim.json.decode, stdout_data)
        if not ok or not meta then
            callback({ kind = "other", error = "Dropbox API: invalid shared link metadata response" })
            return
        end

        if meta.error_summary or meta.error then
            if M._is_dropbox_unsupported_link_type(meta) then
                callback({ kind = "other", error = "Dropbox API: this Dropbox shared link type is not supported yet." })
                return
            end
            local err = {
                code = meta.error and meta.error.code or nil,
                error_summary = meta.error_summary,
                message = meta.error_summary or (meta.error and meta.error[".tag"]) or "unknown error",
            }
            callback({
                kind = M._classify_dropbox_api_error(err.code, meta),
                error = M._format_dropbox_api_error_message(err),
            })
            return
        end

        local tag = meta[".tag"]
        if tag == "folder" or info.file_type == "folder" then
            callback({ kind = "other", error = "Dropbox API: shared folders are not supported yet." })
            return
        end

        local file_name = meta.name or info.file_name or M._display_name_for_url(url)
        M._run_dropbox_file_request(access_token, info, function(file_code, _, file_stdout)
            if file_code ~= 0 then
                callback({ kind = "other", error = "Dropbox API: failed to fetch shared file content for " .. file_name })
                return
            end

            local parsed = M._parse_public_fetch_response(file_stdout)
            if not parsed or not parsed.status_code then
                callback({ kind = "other", error = "Dropbox API: invalid file download response" })
                return
            end

            if parsed.status_code < 200 or parsed.status_code >= 300 then
                local err_ok, err_data = pcall(vim.json.decode, parsed.body)
                if err_ok and M._is_dropbox_unsupported_link_type(err_data) then
                    callback({ kind = "other", error = "Dropbox API: this Dropbox shared link type is not supported yet." })
                    return
                end
                local err = {
                    code = parsed.status_code,
                    error_summary = err_ok and err_data and err_data.error_summary or nil,
                    message = err_ok and err_data and (err_data.error_summary or err_data.error) or "failed to fetch shared file content",
                }
                callback({
                    kind = M._classify_dropbox_api_error(parsed.status_code, err_ok and err_data or nil),
                    error = M._format_dropbox_api_error_message(err),
                })
                return
            end

            callback({
                kind = "success",
                content = M.format_remote_content(file_name, parsed.body, url, parsed.content_type, url),
            })
        end)
    end)
end

---@param error_code number|nil
---@return string
M._classify_microsoft_api_error = function(error_code)
    if error_code == 401 or error_code == 403 then
        return "auth"
    end
    return "other"
end

---@param error table
---@return string
M._format_microsoft_api_error_message = function(error)
    local message = error.message or "unknown error"
    if error.code ~= nil then
        return "OneDrive API: " .. message .. " (code: " .. tostring(error.code) .. ")"
    end
    return "OneDrive API: " .. message
end

---@param access_token string
---@param encoded_share string
---@param callback function
M._run_microsoft_metadata_request = function(access_token, encoded_share, callback)
    local args = {
        "-s",
        "-H", "Authorization: Bearer " .. access_token,
        "https://graph.microsoft.com/v1.0/shares/" .. encoded_share .. "/driveItem",
    }
    tasker.run(nil, "curl", args, callback)
end

---@param access_token string
---@param encoded_share string
---@param callback function
M._run_microsoft_content_request = function(access_token, encoded_share, callback)
    local args = {
        "-s",
        "-L",
        "-w",
        "\n" .. public_fetch_meta_marker .. "\n"
            .. "HTTP_STATUS:%{http_code}\n"
            .. "CONTENT_TYPE:%{content_type}\n",
        "-H", "Authorization: Bearer " .. access_token,
        "https://graph.microsoft.com/v1.0/shares/" .. encoded_share .. "/driveItem/content",
    }
    tasker.run(nil, "curl", args, callback)
end

---@param url string
---@param info table
---@param access_token string
---@param callback function
M._fetch_microsoft_api_once = function(url, info, access_token, callback)
    local encoded_share = M._encode_sharing_url(info.shared_url or url)

    M._run_microsoft_metadata_request(access_token, encoded_share, function(code, _, stdout_data)
        if code ~= 0 then
            callback({ kind = "other", error = "OneDrive API: failed to fetch file metadata" })
            return
        end

        local ok, meta = pcall(vim.json.decode, stdout_data)
        if not ok or not meta then
            callback({ kind = "other", error = "OneDrive API: invalid metadata response" })
            return
        end

        if meta.error then
            local err = {
                code = meta.error.code,
                message = meta.error.message or "unknown error",
            }
            callback({
                kind = M._classify_microsoft_api_error(
                    type(meta.error.code) == "number" and meta.error.code or
                    (meta.error.code == "unauthenticated" and 401 or
                     meta.error.code == "accessDenied" and 403 or 400)
                ),
                error = M._format_microsoft_api_error_message(err),
            })
            return
        end

        if meta.folder then
            callback({ kind = "other", error = "OneDrive API: shared folders are not supported yet." })
            return
        end

        local file_name = meta.name or M._display_name_for_url(url)

        M._run_microsoft_content_request(access_token, encoded_share, function(content_code, _, content_stdout)
            if content_code ~= 0 then
                callback({ kind = "other", error = "OneDrive API: failed to fetch file content for " .. file_name })
                return
            end

            local parsed = M._parse_public_fetch_response(content_stdout)
            if not parsed or not parsed.status_code then
                callback({ kind = "other", error = "OneDrive API: invalid file download response" })
                return
            end

            if parsed.status_code < 200 or parsed.status_code >= 300 then
                local err_ok, err_data = pcall(vim.json.decode, parsed.body)
                local err = {
                    code = parsed.status_code,
                    message = err_ok and err_data and (err_data.error and err_data.error.message or err_data.error_description)
                        or "failed to fetch file content",
                }
                callback({
                    kind = M._classify_microsoft_api_error(parsed.status_code),
                    error = M._format_microsoft_api_error_message(err),
                })
                return
            end

            -- Check if content is a binary Office format that needs conversion
            local mime_type = meta.file and meta.file.mimeType or parsed.content_type
            local office_ext = M._get_office_extension(mime_type)
            if office_ext then
                M._convert_office_to_text(parsed.body, office_ext, function(text, err)
                    if text then
                        callback({
                            kind = "success",
                            content = M.format_remote_content(file_name, text, url, "text/plain", url),
                        })
                    else
                        callback({ kind = "other", error = "OneDrive API: " .. (err or "failed to convert Office document") })
                    end
                end)
                return
            end

            callback({
                kind = "success",
                content = M.format_remote_content(file_name, parsed.body, url, parsed.content_type, url),
            })
        end)
    end)
end

provider_definitions = {
    dropbox = {
        display_name = "Dropbox (OAuth)",
        default_scopes = { "sharing.read" },
        detect_patterns = {
            "dropbox%.com/s/",
            "dropbox%.com/scl/fi/",
            "dropbox%.com/sh/",
            "dropbox%.com/scl/fo/",
        },
        parse_url = function(url)
            return M.parse_dropbox_url(url)
        end,
        build_auth_url = function(config, port)
            return build_dropbox_auth_url(config, port)
        end,
        build_token_exchange_args = function(config, code, port)
            return build_dropbox_token_exchange_args(config, code, port)
        end,
        build_refresh_token_args = function(config, account)
            return build_dropbox_refresh_token_args(config, account)
        end,
        classify_api_error = function(error_code, error_body)
            return M._classify_dropbox_api_error(error_code, error_body)
        end,
        format_api_error = function(error)
            return M._format_dropbox_api_error_message(error)
        end,
        fetch_with_access_token = function(url, info, access_token, callback)
            return M._fetch_dropbox_api_once(url, info, access_token, callback)
        end,
        missing_url_message = function(url)
            return "Public access failed and Dropbox OAuth does not support this URL format: " .. url
        end,
        prompt_reason = function(kind, details)
            if kind == "no_credentials" then
                return "Dropbox OAuth: No saved credentials. Please authenticate to access Dropbox shared files."
            end
            if kind == "reauth" and details and details ~= "" then
                return details .. " — Re-authenticate with a different Dropbox account?"
            end
            return "Dropbox OAuth: authentication cancelled or failed."
        end,
        refresh_failure_message = "Dropbox OAuth: token refresh failed for this account.",
        missing_refresh_token_message = "Dropbox OAuth: no refresh token available for this account.",
    },
    google = {
        display_name = "Google Drive (OAuth)",
        default_scopes = { "https://www.googleapis.com/auth/drive.readonly" },
        detect_patterns = {
            "docs%.google%.com/",
            "drive%.google%.com/",
        },
        parse_url = function(url)
            return M.parse_url(url)
        end,
        build_auth_url = function(config, port)
            return build_google_auth_url(config, port)
        end,
        build_token_exchange_args = function(config, code, port)
            return build_google_token_exchange_args(config, code, port)
        end,
        build_refresh_token_args = function(config, account)
            return build_google_refresh_token_args(config, account)
        end,
        classify_api_error = function(error_code)
            return M._classify_api_error(error_code)
        end,
        format_api_error = function(error)
            return M._format_api_error_message(error)
        end,
        fetch_with_access_token = function(url, info, access_token, callback)
            return M._fetch_google_api_once(url, info, access_token, callback)
        end,
        missing_url_message = function(url)
            return "Public access failed and Google OAuth does not support this URL format: " .. url
        end,
        prompt_reason = function(kind, details)
            if kind == "no_credentials" then
                return "Google OAuth: No saved credentials. Please authenticate to access Google Drive files."
            end
            if kind == "reauth" and details and details ~= "" then
                return details .. " — Re-authenticate with a different account?"
            end
            return "Google OAuth: authentication cancelled or failed."
        end,
        refresh_failure_message = "Google OAuth: token refresh failed for this account.",
        missing_refresh_token_message = "Google OAuth: no refresh token available for this account.",
    },
    microsoft = {
        display_name = "OneDrive (OAuth)",
        default_scopes = { "Files.Read", "Files.Read.All" },
        required_scopes = { "offline_access" },
        detect_patterns = {
            "onedrive%.live%.com/",
            "1drv%.ms/",
        },
        parse_url = function(url)
            return M.parse_onedrive_url(url)
        end,
        build_auth_url = function(config, port)
            return build_microsoft_auth_url(config, port)
        end,
        build_token_exchange_args = function(config, code, port)
            return build_microsoft_token_exchange_args(config, code, port)
        end,
        build_refresh_token_args = function(config, account)
            return build_microsoft_refresh_token_args(config, account)
        end,
        classify_api_error = function(error_code)
            return M._classify_microsoft_api_error(error_code)
        end,
        format_api_error = function(error)
            return M._format_microsoft_api_error_message(error)
        end,
        fetch_with_access_token = function(url, info, access_token, callback)
            return M._fetch_microsoft_api_once(url, info, access_token, callback)
        end,
        missing_url_message = function(url)
            return "Public access failed and OneDrive OAuth does not support this URL format: " .. url
        end,
        prompt_reason = function(kind, details)
            if kind == "no_credentials" then
                return "OneDrive OAuth: No saved credentials. Please authenticate to access OneDrive files."
            end
            if kind == "reauth" and details and details ~= "" then
                return details .. " — Re-authenticate with a different Microsoft account?"
            end
            return "OneDrive OAuth: authentication cancelled or failed."
        end,
        refresh_failure_message = "OneDrive OAuth: token refresh failed for this account.",
        missing_refresh_token_message = "OneDrive OAuth: no refresh token available for this account.",
    },
}

---@param provider string|nil
---@return table|nil
M._get_provider_definition = function(provider)
    if not provider then
        return nil
    end
    return provider_definitions[provider]
end

---@param provider string|nil
---@return string
M._get_provider_display_name = function(provider)
    local definition = M._get_provider_definition(provider)
    return definition and definition.display_name or tostring(provider or "OAuth")
end

---@param provider string|nil
---@return table
M._get_provider_prompt_choices = function(provider)
    local choices = {}
    if provider then
        local definition = M._get_provider_definition(provider)
        if definition then
            table.insert(choices, {
                provider = provider,
                name = definition.display_name,
            })
        end
        return choices
    end

    for provider_name, definition in pairs(provider_definitions) do
        table.insert(choices, {
            provider = provider_name,
            name = definition.display_name,
        })
    end
    table.sort(choices, function(a, b)
        return a.name < b.name
    end)
    return choices
end

---@param provider string|nil
---@param url string
---@return table|nil
M._parse_provider_url = function(provider, url)
    local definition = M._get_provider_definition(provider)
    if not definition or not definition.parse_url then
        return nil
    end
    return definition.parse_url(url)
end

---@param config table|nil
---@param provider string|nil
---@return table|nil
M._get_provider_config = function(config, provider)
    provider = provider or "google"
    if type(config) ~= "table" then
        return nil
    end
    if config.client_id or config.client_secret or config.scopes then
        return provider == "google" and config or nil
    end
    if type(config.oauth) == "table" then
        local nested = M._get_provider_config(config.oauth, provider)
        if nested then
            return nested
        end
    end
    if type(config.providers) == "table" then
        return config.providers[provider]
    end
    if type(config[provider]) == "table" then
        return config[provider]
    end
    return nil
end

---@param provider string|nil
---@param config table|nil
---@return boolean
M._has_provider_config = function(provider, config)
    local provider_config = M._get_provider_config(config, provider)
    return type(provider_config) == "table"
        and provider_config.client_id ~= nil
        and provider_config.client_id ~= ""
        and provider_config.client_secret ~= nil
        and provider_config.client_secret ~= ""
end

---@param provider string|nil
---@param account table
---@return string
M._missing_refresh_token_message = function(provider, account)
    local definition = M._get_provider_definition(provider)
    return (definition and definition.missing_refresh_token_message) or "OAuth: no refresh token available for this account."
end

---@param provider string|nil
---@param account table
---@return string
M._refresh_failure_message = function(provider, account)
    local definition = M._get_provider_definition(provider)
    return (definition and definition.refresh_failure_message) or "OAuth: token refresh failed for this account."
end

---@param config table
---@param store table
---@param url string
---@param info table
---@param account table
---@param callback function
---@param provider string|nil
M._try_account_fetch = function(config, store, url, info, account, callback, provider)
    provider = provider or (account and account.provider) or "google"
    local provider_definition = M._get_provider_definition(provider)
    if not provider_definition or not provider_definition.fetch_with_access_token then
        callback({
            kind = "other",
            error = "OAuth provider " .. tostring(provider) .. " does not implement authenticated fetch.",
            account = account,
        })
        return
    end
    local function attempt(current_account, allow_refresh_on_auth)
        if not current_account.access_token or M.is_token_expired(current_account) then
            if not current_account.refresh_token then
                callback({
                    kind = "auth",
                    error = M._missing_refresh_token_message(provider, current_account),
                    account = current_account,
                })
                return
            end

            M._refresh_account(config, provider, store, current_account, function(updated_account)
                if not updated_account then
                    callback({
                        kind = "auth",
                        error = M._refresh_failure_message(provider, current_account),
                        account = current_account,
                    })
                    return
                end
                attempt(updated_account, false)
            end)
            return
        end

        provider_definition.fetch_with_access_token(url, info, current_account.access_token, function(result)
            result.account = current_account
            if result.kind == "auth" and allow_refresh_on_auth and current_account.refresh_token then
                M._refresh_account(config, provider, store, current_account, function(updated_account)
                    if not updated_account then
                        callback(result)
                        return
                    end
                    attempt(updated_account, false)
                end)
                return
            end

            callback(result)
        end)
    end

    attempt(account, true)
end

---@param config table
---@param url string
---@param info table
---@param callback function
---@param provider string|nil
M._try_saved_accounts = function(config, url, info, callback, provider)
    provider = provider or "google"
    M.load_account_store(function(store)
        local candidates = M._get_candidate_accounts(store, provider)
        if #candidates == 0 then
            callback({ kind = "none" })
            return
        end

        local idx = 1
        local last_auth_error = nil

        local function try_next()
            local account = candidates[idx]
            idx = idx + 1

            if not account then
                callback({ kind = "exhausted", error = last_auth_error })
                return
            end

            M._try_account_fetch(config, store, url, info, account, function(result)
                if result.kind == "success" then
                    local saved_account = M._upsert_account(store, result.account, provider)
                    saved_account.last_used_at = os.time()
                    saved_account.invalid = false
                    store.preferred_account_ids[provider] = saved_account.account_id
                    M.save_account_store(store, function()
                        callback({
                            kind = "success",
                            content = result.content,
                            account = saved_account,
                        })
                    end)
                elseif result.kind == "auth" then
                    last_auth_error = result.error
                    try_next()
                else
                    callback(result)
                end
            end, provider)
        end

        try_next()
    end)
end

-- Fetch file content from Google Drive
-- This is the main entry point called from helper.lua
---@param url string # Google Drive/Docs URL
---@param config table # OAuth provider config or provider config map
---@param callback function # called with (formatted_content_string, error_string)
M.fetch_content = function(url, config, callback)
    local provider = M._detect_provider_for_url(url)
    local info = M._parse_provider_url(provider, url)
    local provider_definition = M._get_provider_definition(provider)

    M._fetch_public_content(url, function(public_result, public_err)
        local decision = M._decide_fetch_action(url, public_result, public_err, provider, info)

        if decision.action == "public" then
            callback(M.format_remote_content(
                decision.display_name,
                public_result.body,
                url,
                public_result.content_type,
                public_result.effective_url
            ))
            return
        end

        if decision.action == "error" then
            callback(nil, decision.message)
            return
        end

        if not M._has_provider_config(provider, config) then
            callback(nil, M._get_provider_display_name(provider) .. ": missing OAuth client configuration.")
            return
        end

        M._try_saved_accounts(config, url, info, function(result)
            if result.kind == "success" then
                callback(result.content)
                return
            end

            if result.kind == "other" then
                callback(nil, result.error)
                return
            end

            local reason = provider_definition and provider_definition.prompt_reason("no_credentials")
                or "OAuth: no saved credentials."
            if result.kind == "exhausted" and result.error then
                reason = provider_definition and provider_definition.prompt_reason("reauth", result.error)
                    or (result.error .. " — Re-authenticate with a different account?")
            end

            M._prompt_auth(config, reason, function(new_account)
                if not new_account then
                    callback(nil, provider_definition and provider_definition.prompt_reason("cancelled")
                        or "OAuth: authentication cancelled or failed.")
                    return
                end

                M.load_account_store(function(store)
                    local account = M._upsert_account(store, new_account, provider)
                    store.preferred_account_ids[provider] = account.account_id
                    M.save_account_store(store, function()
                        M._try_account_fetch(config, store, url, info, account, function(auth_result)
                            if auth_result.kind == "success" then
                                local saved_account = M._upsert_account(store, auth_result.account, provider)
                                saved_account.last_used_at = os.time()
                                saved_account.invalid = false
                                store.preferred_account_ids[provider] = saved_account.account_id
                                M.save_account_store(store, function()
                                    callback(auth_result.content)
                                end)
                            else
                                callback(nil, auth_result.error or (provider_definition and provider_definition.prompt_reason("cancelled")
                                    or "OAuth: authentication cancelled or failed."))
                            end
                        end, provider)
                    end)
                end)
            end, url)
        end, provider)
    end)
end

return M
