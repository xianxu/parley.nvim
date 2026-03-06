-- Unit tests for Google Drive URL parsing and helpers

local oauth = require("parley.oauth")

describe("oauth: URL detection", function()
    it("A1: detects Google Docs URL", function()
        assert.is_true(oauth.is_google_url("https://docs.google.com/document/d/abc123/edit"))
    end)

    it("A2: detects Google Sheets URL", function()
        assert.is_true(oauth.is_google_url("https://docs.google.com/spreadsheets/d/abc123/edit"))
    end)

    it("A3: detects Google Slides URL", function()
        assert.is_true(oauth.is_google_url("https://docs.google.com/presentation/d/abc123/edit"))
    end)

    it("A4: detects Google Drive file URL", function()
        assert.is_true(oauth.is_google_url("https://drive.google.com/file/d/abc123/view"))
    end)

    it("A5: rejects non-Google URL", function()
        assert.is_false(oauth.is_google_url("https://example.com/file.txt"))
    end)

    it("A6: rejects local file path", function()
        assert.is_false(oauth.is_google_url("/home/user/file.txt"))
    end)

    it("A7: rejects nil", function()
        assert.is_false(oauth.is_google_url(nil))
    end)
end)

describe("oauth: URL parsing", function()
    it("B1: extracts file ID from Google Docs URL", function()
        local info = oauth.parse_url("https://docs.google.com/document/d/abc123XYZ/edit")
        assert.equals("abc123XYZ", info.file_id)
        assert.equals("document", info.file_type)
    end)

    it("B2: extracts file ID from Google Docs URL without trailing path", function()
        local info = oauth.parse_url("https://docs.google.com/document/d/abc123XYZ")
        assert.equals("abc123XYZ", info.file_id)
        assert.equals("document", info.file_type)
    end)

    it("B3: extracts file ID from Google Sheets URL", function()
        local info = oauth.parse_url("https://docs.google.com/spreadsheets/d/sheet456/edit#gid=0")
        assert.equals("sheet456", info.file_id)
        assert.equals("spreadsheet", info.file_type)
    end)

    it("B4: extracts file ID from Google Slides URL", function()
        local info = oauth.parse_url("https://docs.google.com/presentation/d/slide789/edit")
        assert.equals("slide789", info.file_id)
        assert.equals("presentation", info.file_type)
    end)

    it("B5: extracts file ID from Google Drive file URL", function()
        local info = oauth.parse_url("https://drive.google.com/file/d/drive_file_001/view")
        assert.equals("drive_file_001", info.file_id)
        assert.equals("drive_file", info.file_type)
    end)

    it("B6: returns nil for unsupported URL", function()
        local info = oauth.parse_url("https://docs.google.com/forms/d/form123/edit")
        assert.is_nil(info)
    end)

    it("B7: returns nil for non-Google URL", function()
        local info = oauth.parse_url("https://example.com/file.txt")
        assert.is_nil(info)
    end)
end)

describe("oauth: export MIME type", function()
    it("C1: Google Doc exports as markdown", function()
        assert.equals("text/markdown", oauth.get_export_mime("document"))
    end)

    it("C2: Google Sheet exports as CSV", function()
        assert.equals("text/csv", oauth.get_export_mime("spreadsheet"))
    end)

    it("C3: Google Slides exports as plain text", function()
        assert.equals("text/plain", oauth.get_export_mime("presentation"))
    end)

    it("C4: drive_file returns nil (downloaded directly, not exported)", function()
        assert.is_nil(oauth.get_export_mime("drive_file"))
    end)
end)

describe("oauth: OAuth URL construction", function()
    it("D1: builds correct authorization URL", function()
        local url = oauth.build_auth_url({
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

describe("oauth: token exchange curl args", function()
    it("E1: builds correct token exchange curl arguments", function()
        local args = oauth.build_token_exchange_args({
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

describe("oauth: keychain commands", function()
    it("F1: builds macOS keychain store command", function()
        local cmd = oauth.build_keychain_store_cmd("darwin", '{"access_token":"abc"}')
        assert.equals("security", cmd[1])
        assert.is_true(vim.tbl_contains(cmd, "add-generic-password"))
        assert.is_true(vim.tbl_contains(cmd, "parley-nvim-google-oauth"))
    end)

    it("F2: builds macOS keychain load command", function()
        local cmd = oauth.build_keychain_load_cmd("darwin")
        assert.equals("security", cmd[1])
        assert.is_true(vim.tbl_contains(cmd, "find-generic-password"))
        assert.is_true(vim.tbl_contains(cmd, "parley-nvim-google-oauth"))
    end)

    it("F2b: builds macOS keychain delete command", function()
        local cmd = oauth.build_keychain_delete_cmd("darwin")
        assert.equals("security", cmd[1])
        assert.is_true(vim.tbl_contains(cmd, "delete-generic-password"))
        assert.is_true(vim.tbl_contains(cmd, "parley-nvim-google-oauth"))
    end)

    it("F3: builds Linux keychain store command", function()
        local cmd = oauth.build_keychain_store_cmd("linux", '{"access_token":"abc"}')
        assert.equals("secret-tool", cmd[1])
        assert.is_true(vim.tbl_contains(cmd, "store"))
    end)

    it("F4: builds Linux keychain load command", function()
        local cmd = oauth.build_keychain_load_cmd("linux")
        assert.equals("secret-tool", cmd[1])
        assert.is_true(vim.tbl_contains(cmd, "lookup"))
    end)

    it("F4b: builds Linux keychain delete command", function()
        local cmd = oauth.build_keychain_delete_cmd("linux")
        assert.equals("secret-tool", cmd[1])
        assert.is_true(vim.tbl_contains(cmd, "clear"))
        assert.is_true(vim.tbl_contains(cmd, "parley-nvim-google-oauth"))
    end)
end)

describe("oauth: API URL construction", function()
    it("G1: builds metadata URL", function()
        local url = oauth.build_metadata_url("file123")
        assert.equals("https://www.googleapis.com/drive/v3/files/file123?fields=mimeType,name", url)
    end)

    it("G2: builds export URL for Google Doc", function()
        local url = oauth.build_export_url("file123", "text/markdown")
        assert.equals("https://www.googleapis.com/drive/v3/files/file123/export?mimeType=text/markdown", url)
    end)

    it("G3: builds download URL for Drive file", function()
        local url = oauth.build_download_url("file123")
        assert.equals("https://www.googleapis.com/drive/v3/files/file123?alt=media", url)
    end)
end)

describe("oauth: token parsing", function()
    it("H1: parses token exchange response JSON", function()
        local json = '{"access_token":"ya29.abc","refresh_token":"1//ref","expires_in":3600,"token_type":"Bearer"}'
        local tokens = oauth.parse_token_response(json)
        assert.equals("ya29.abc", tokens.access_token)
        assert.equals("1//ref", tokens.refresh_token)
        assert.is_true(tokens.expires_at > os.time())
    end)

    it("H2: parse_token_response returns nil on invalid JSON", function()
        local tokens = oauth.parse_token_response("not json")
        assert.is_nil(tokens)
    end)

    it("H3: parse_token_response returns nil when access_token missing", function()
        local tokens = oauth.parse_token_response('{"error":"invalid_grant"}')
        assert.is_nil(tokens)
    end)

    it("H4: is_token_expired returns true for expired token", function()
        local tokens = { access_token = "abc", expires_at = os.time() - 100 }
        assert.is_true(oauth.is_token_expired(tokens))
    end)

    it("H5: is_token_expired returns false for valid token", function()
        local tokens = { access_token = "abc", expires_at = os.time() + 3600 }
        assert.is_false(oauth.is_token_expired(tokens))
    end)
end)

describe("oauth: account store helpers", function()
    it("H6: migrates legacy single-token storage into a multi-account store", function()
        local store = oauth._normalize_account_store({
            access_token = "ya29.legacy",
            refresh_token = "1//legacy",
            expires_at = 12345,
        })

        assert.equals(2, store.version)
        assert.equals(1, #store.accounts)
        assert.equals("ya29.legacy", store.accounts[1].access_token)
        assert.equals("1//legacy", store.accounts[1].refresh_token)
        assert.equals(store.accounts[1].account_id, store.preferred_account_id)
    end)

    it("H7: upserts accounts by refresh token instead of duplicating them", function()
        local store = oauth._new_account_store()
        local first = oauth._upsert_account(store, {
            access_token = "ya29.first",
            refresh_token = "1//same",
            expires_at = 100,
        })
        local updated = oauth._upsert_account(store, {
            access_token = "ya29.updated",
            refresh_token = "1//same",
            expires_at = 200,
        })

        assert.equals(1, #store.accounts)
        assert.equals(first.account_id, updated.account_id)
        assert.equals("ya29.updated", store.accounts[1].access_token)
        assert.equals(200, store.accounts[1].expires_at)
    end)

    it("H8: returns preferred non-invalid account first when ordering candidates", function()
        local store = oauth._normalize_account_store({
            preferred_account_id = "acct_c",
            accounts = {
                { account_id = "acct_a", access_token = "a", refresh_token = "ra", expires_at = 100 },
                { account_id = "acct_b", access_token = "b", refresh_token = "rb", expires_at = 100, invalid = true },
                { account_id = "acct_c", access_token = "c", refresh_token = "rc", expires_at = 100 },
            },
        })

        local candidates = oauth._get_candidate_accounts(store)
        assert.equals(2, #candidates)
        assert.equals("acct_c", candidates[1].account_id)
        assert.equals("acct_a", candidates[2].account_id)
    end)
end)

describe("oauth: saved account iteration", function()
    local original_load_account_store
    local original_try_account_fetch
    local original_save_account_store

    before_each(function()
        original_load_account_store = oauth.load_account_store
        original_try_account_fetch = oauth._try_account_fetch
        original_save_account_store = oauth.save_account_store
    end)

    after_each(function()
        oauth.load_account_store = original_load_account_store
        oauth._try_account_fetch = original_try_account_fetch
        oauth.save_account_store = original_save_account_store
    end)

    it("H9: tries accounts in order until one succeeds", function()
        local tried = {}
        oauth.load_account_store = function(callback)
            callback(oauth._normalize_account_store({
                preferred_account_id = "acct_a",
                accounts = {
                    { account_id = "acct_a", access_token = "a", refresh_token = "ra", expires_at = 100 },
                    { account_id = "acct_b", access_token = "b", refresh_token = "rb", expires_at = 100 },
                },
            }))
        end
        oauth.save_account_store = function(store, callback)
            callback()
        end
        oauth._try_account_fetch = function(config, store, url, info, account, callback)
            table.insert(tried, account.account_id)
            if account.account_id == "acct_a" then
                callback({ kind = "auth", error = "Google Drive API: forbidden", account = account })
            else
                callback({ kind = "success", content = "ok", account = account })
            end
        end

        local result
        oauth._try_saved_accounts({}, "https://docs.google.com/document/d/abc123/edit", { file_id = "abc123" }, function(res)
            result = res
        end)

        assert.same({ "acct_a", "acct_b" }, tried)
        assert.equals("success", result.kind)
        assert.equals("ok", result.content)
        assert.equals("acct_b", result.account.account_id)
    end)

    it("H10: stops on non-auth error without trying later accounts", function()
        local tried = {}
        oauth.load_account_store = function(callback)
            callback(oauth._normalize_account_store({
                preferred_account_id = "acct_a",
                accounts = {
                    { account_id = "acct_a", access_token = "a", refresh_token = "ra", expires_at = 100 },
                    { account_id = "acct_b", access_token = "b", refresh_token = "rb", expires_at = 100 },
                },
            }))
        end
        oauth.save_account_store = function(store, callback)
            callback()
        end
        oauth._try_account_fetch = function(config, store, url, info, account, callback)
            table.insert(tried, account.account_id)
            if account.account_id == "acct_a" then
                callback({ kind = "other", error = "Google Drive API: invalid metadata response", account = account })
            else
                callback({ kind = "success", content = "unexpected", account = account })
            end
        end

        local result
        oauth._try_saved_accounts({}, "https://docs.google.com/document/d/abc123/edit", { file_id = "abc123" }, function(res)
            result = res
        end)

        assert.same({ "acct_a" }, tried)
        assert.equals("other", result.kind)
        assert.equals("Google Drive API: invalid metadata response", result.error)
    end)
end)

describe("oauth: auth code parsing", function()
    it("I1: parses auth code from HTTP GET request", function()
        local request = "GET /callback?code=4/0AX4XfWh_abc123&scope=https://www.googleapis.com/auth/drive.readonly HTTP/1.1\r\nHost: localhost:52847\r\n\r\n"
        local code = oauth._parse_auth_code(request)
        assert.equals("4/0AX4XfWh_abc123", code)
    end)

    it("I2: returns nil when no code present", function()
        local request = "GET /callback?error=access_denied HTTP/1.1\r\n\r\n"
        local code = oauth._parse_auth_code(request)
        assert.is_nil(code)
    end)

    it("I3: parses OAuth denial from HTTP GET request", function()
        local request = "GET /callback?error=access_denied&state=abc123 HTTP/1.1\r\nHost: localhost:52847\r\n\r\n"
        local err = oauth._parse_auth_error(request)
        assert.equals("access_denied", err)
    end)

    it("I4: returns nil when no OAuth error is present", function()
        local request = "GET /callback?code=4/0AX4XfWh_abc123 HTTP/1.1\r\nHost: localhost:52847\r\n\r\n"
        local err = oauth._parse_auth_error(request)
        assert.is_nil(err)
    end)
end)

describe("oauth: auth callback handling", function()
    it("I5: returns success callback metadata and browser response when code is present", function()
        local request = "GET /callback?code=4/0AX4XfWh_abc123 HTTP/1.1\r\nHost: localhost:52847\r\n\r\n"
        local result = oauth._handle_auth_callback_request(request)

        assert.equals("4/0AX4XfWh_abc123", result.code)
        assert.is_nil(result.auth_error)
        assert.is_false(result.is_cancelled)
        assert.is_true(result.response:match("Authentication successful!") ~= nil)
    end)

    it("I6: returns cancellation metadata and browser response for access_denied", function()
        local request = "GET /callback?error=access_denied HTTP/1.1\r\nHost: localhost:52847\r\n\r\n"
        local result = oauth._handle_auth_callback_request(request)

        assert.is_nil(result.code)
        assert.equals("access_denied", result.auth_error)
        assert.is_true(result.is_cancelled)
        assert.is_true(result.response:match("Authentication cancelled") ~= nil)
    end)

    it("I7: returns failure browser response when callback has no code or OAuth error", function()
        local request = "GET /callback HTTP/1.1\r\nHost: localhost:52847\r\n\r\n"
        local result = oauth._handle_auth_callback_request(request)

        assert.is_nil(result.code)
        assert.is_nil(result.auth_error)
        assert.is_false(result.is_cancelled)
        assert.is_true(result.response:match("Authentication failed") ~= nil)
    end)
end)

describe("oauth: auth code exchange", function()
    local original_run_auth_code_exchange
    local original_load_account_store
    local original_save_account_store

    before_each(function()
        original_run_auth_code_exchange = oauth._run_auth_code_exchange
        original_load_account_store = oauth.load_account_store
        original_save_account_store = oauth.save_account_store
    end)

    after_each(function()
        oauth._run_auth_code_exchange = original_run_auth_code_exchange
        oauth.load_account_store = original_load_account_store
        oauth.save_account_store = original_save_account_store
    end)

    it("I8: exchanges code and persists the authenticated account", function()
        local saved_store
        oauth._run_auth_code_exchange = function(config, code, port, callback)
            assert.equals("auth-code-123", code)
            assert.equals(52847, port)
            callback(0, 0, '{"access_token":"ya29.abc","refresh_token":"1//ref","expires_in":3600}')
        end
        oauth.load_account_store = function(callback)
            callback(oauth._new_account_store())
        end
        oauth.save_account_store = function(store, callback)
            saved_store = vim.deepcopy(store)
            callback()
        end

        local account
        oauth._exchange_auth_code({
            client_id = "test-client-id",
            client_secret = "test-secret",
        }, "auth-code-123", 52847, function(result)
            account = result
        end)

        assert.is_not_nil(account)
        assert.equals("ya29.abc", account.access_token)
        assert.equals("1//ref", account.refresh_token)
        assert.equals(account.account_id, saved_store.preferred_account_id)
        assert.equals(1, #saved_store.accounts)
    end)

    it("I9: returns nil when the token exchange command fails", function()
        oauth._run_auth_code_exchange = function(config, code, port, callback)
            callback(1, 0, "")
        end

        local account = false
        oauth._exchange_auth_code({}, "auth-code-123", 52847, function(result)
            account = result
        end)

        assert.is_nil(account)
    end)

    it("I10: returns nil when the token response cannot be parsed", function()
        oauth._run_auth_code_exchange = function(config, code, port, callback)
            callback(0, 0, '{"error":"invalid_grant"}')
        end

        local account = false
        oauth._exchange_auth_code({}, "auth-code-123", 52847, function(result)
            account = result
        end)

        assert.is_nil(account)
    end)
end)

describe("oauth: content formatting", function()
    it("J1: formats Google Doc content like local files", function()
        local content = "Hello world\nSecond line"
        local formatted = oauth.format_google_content("My Document", "document", content)
        assert.is_true(formatted:match("Google Doc") ~= nil)
        assert.is_true(formatted:match("My Document") ~= nil)
        assert.is_true(formatted:match("1: Hello world") ~= nil)
        assert.is_true(formatted:match("2: Second line") ~= nil)
    end)

    it("J2: formats Google Sheet content with CSV label", function()
        local content = "a,b,c\n1,2,3"
        local formatted = oauth.format_google_content("Budget", "spreadsheet", content)
        assert.is_true(formatted:match("Google Sheet") ~= nil)
        assert.is_true(formatted:match("Budget") ~= nil)
    end)
end)

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

describe("oauth: auto-detect OAuth provider from URL", function()
    it("M1: detects Google for docs.google.com URL", function()
        assert.equals("google", oauth._detect_provider_for_url("https://docs.google.com/document/d/abc123/edit"))
    end)

    it("M2: detects Google for drive.google.com URL", function()
        assert.equals("google", oauth._detect_provider_for_url("https://drive.google.com/file/d/abc123/view"))
    end)

    it("M3: detects Google for Google Sheets URL", function()
        assert.equals("google", oauth._detect_provider_for_url("https://docs.google.com/spreadsheets/d/abc123/edit"))
    end)

    it("M4: detects Google for Google Slides URL", function()
        assert.equals("google", oauth._detect_provider_for_url("https://docs.google.com/presentation/d/abc123/edit"))
    end)

    it("M5: returns nil for unknown URL", function()
        assert.is_nil(oauth._detect_provider_for_url("https://example.com/file.txt"))
    end)

    it("M6: returns nil for nil input", function()
        assert.is_nil(oauth._detect_provider_for_url(nil))
    end)

    it("M7: returns nil for non-string input", function()
        assert.is_nil(oauth._detect_provider_for_url(123))
    end)
end)

describe("oauth: API error classification", function()
    it("L1: classifies 401 as auth error", function()
        assert.equals("auth", oauth._classify_api_error(401))
    end)

    it("L2: classifies 403 as auth error", function()
        assert.equals("auth", oauth._classify_api_error(403))
    end)

    it("L3: classifies 404 as auth error", function()
        assert.equals("auth", oauth._classify_api_error(404))
    end)

    it("L4: classifies 500 as other error", function()
        assert.equals("other", oauth._classify_api_error(500))
    end)

    it("L5: classifies 400 as other error", function()
        assert.equals("other", oauth._classify_api_error(400))
    end)

    it("L6: classifies nil as other error", function()
        assert.equals("other", oauth._classify_api_error(nil))
    end)
end)
