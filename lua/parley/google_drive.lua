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
    local scope = table.concat(config.scopes, " ")
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

return M
