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

describe("google_drive: OAuth URL construction", function()
    it("D1: builds correct authorization URL", function()
        local url = gd.build_auth_url({
            client_id = "test-client-id.apps.googleusercontent.com",
            scopes = { "https://www.googleapis.com/auth/drive.readonly" },
        }, 52847)

        assert.is_true(url:match("accounts%.google%.com/o/oauth2/v2/auth") ~= nil)
        assert.is_true(url:match("client_id=test%-client%-id") ~= nil)
        assert.is_true(url:match("redirect_uri=http") ~= nil)
        assert.is_true(url:match("localhost%%3A52847") ~= nil)
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

        assert.is_true(type(args) == "table")
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
