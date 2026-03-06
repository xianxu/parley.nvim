local tmp_dir = "/tmp/parley-test-remote-references-" .. os.time()

local parley = require("parley")
parley.setup({
    chat_dir = tmp_dir,
    state_dir = tmp_dir .. "/state",
    providers = {},
    api_keys = {},
})

describe("_resolve_remote_references", function()
    local google_drive
    local original_fetch_content
    local chat_file = tmp_dir .. "/chat.md"

    before_each(function()
        google_drive = require("parley.google_drive")
        original_fetch_content = google_drive.fetch_content
        parley._remote_reference_cache = nil
        os.remove(parley._remote_reference_cache_file())
    end)

    after_each(function()
        google_drive.fetch_content = original_fetch_content
    end)

    it("delegates current-question remote URLs to fetch_content so the fetcher can probe public access", function()
        local calls = {}
        google_drive.fetch_content = function(url, config, callback)
            table.insert(calls, url)
            callback(nil, "Remote URL fetch failed: HTTP 404 for " .. url)
        end

        local parsed_chat = {
            exchanges = {
                {
                    question = {
                        content = "Review this",
                        file_references = {
                            { path = "https://example.com/file.txt" },
                        },
                    },
                },
            },
        }

        local resolved
        parley._resolve_remote_references({
            parsed_chat = parsed_chat,
            config = parley.config,
            chat_file = chat_file,
            exchange_idx = 1,
        }, function(result)
            resolved = result
        end)

        assert.same({ "https://example.com/file.txt" }, calls)
        assert.is_not_nil(resolved)
        assert.is_true(resolved["https://example.com/file.txt"]:match("Remote URL fetch failed: HTTP 404") ~= nil)
    end)

    it("uses cached prior-question content, fetches only the current question, and ignores later questions", function()
        local calls = {}
        local current_url = "https://example.com/current.txt"
        local prior_url = "https://example.com/prior.txt"
        local future_url = "https://example.com/future.txt"
        local prior_content = "File: prior\ncached prior content\n\n"

        local chat_cache = parley._get_chat_remote_reference_cache(chat_file)
        chat_cache[prior_url] = prior_content
        parley._save_remote_reference_cache()

        google_drive.fetch_content = function(url, config, callback)
            table.insert(calls, url)
            callback("File: current\nfresh current content\n\n", nil)
        end

        local parsed_chat = {
            exchanges = {
                {
                    question = {
                        content = "Earlier question",
                        file_references = {
                            { path = prior_url },
                        },
                    },
                },
                {
                    question = {
                        content = "Current question",
                        file_references = {
                            { path = current_url },
                        },
                    },
                },
                {
                    question = {
                        content = "Future question",
                        file_references = {
                            { path = future_url },
                        },
                    },
                },
            },
        }

        local resolved
        parley._resolve_remote_references({
            parsed_chat = parsed_chat,
            config = parley.config,
            chat_file = chat_file,
            exchange_idx = 2,
        }, function(result)
            resolved = result
        end)

        assert.same({ current_url }, calls)
        assert.equals(prior_content, resolved[prior_url])
        assert.equals("File: current\nfresh current content\n\n", resolved[current_url])
        assert.is_nil(resolved[future_url])
    end)

    it("caches fetch errors as content and reuses them for earlier questions until that question is refreshed", function()
        local url = "https://example.com/doc.txt"
        local calls = 0
        google_drive.fetch_content = function(fetch_url, config, callback)
            calls = calls + 1
            callback(nil, "Remote URL fetch failed: HTTP 404 for " .. fetch_url)
        end

        local first_question = {
            exchanges = {
                {
                    question = {
                        content = "Question one",
                        file_references = {
                            { path = url },
                        },
                    },
                },
            },
        }

        local first_resolved
        parley._resolve_remote_references({
            parsed_chat = first_question,
            config = parley.config,
            chat_file = chat_file,
            exchange_idx = 1,
        }, function(result)
            first_resolved = result
        end)

        local cached_error = parley._format_remote_reference_error_content(
            url,
            "Remote URL fetch failed: HTTP 404 for " .. url
        )
        assert.equals(1, calls)
        assert.equals(cached_error, first_resolved[url])

        google_drive.fetch_content = function()
            error("prior-question cached error should not be refetched")
        end

        local later_question = {
            exchanges = {
                {
                    question = {
                        content = "Question one",
                        file_references = {
                            { path = url },
                        },
                    },
                },
                {
                    question = {
                        content = "Question two",
                        file_references = {},
                    },
                },
            },
        }

        local second_resolved
        parley._resolve_remote_references({
            parsed_chat = later_question,
            config = parley.config,
            chat_file = chat_file,
            exchange_idx = 2,
        }, function(result)
            second_resolved = result
        end)

        assert.equals(cached_error, second_resolved[url])
    end)

    it("refreshes the current question even when the same URL was already cached by an earlier question", function()
        local url = "https://example.com/shared.txt"
        local calls = {}

        local chat_cache = parley._get_chat_remote_reference_cache(chat_file)
        chat_cache[url] = "File: shared\nstale cached content\n\n"
        parley._save_remote_reference_cache()

        google_drive.fetch_content = function(fetch_url, config, callback)
            table.insert(calls, fetch_url)
            callback("File: shared\nfresh content\n\n", nil)
        end

        local parsed_chat = {
            exchanges = {
                {
                    question = {
                        content = "Question one",
                        file_references = {
                            { path = url },
                        },
                    },
                },
                {
                    question = {
                        content = "Question two",
                        file_references = {
                            { path = url },
                        },
                    },
                },
            },
        }

        local resolved
        parley._resolve_remote_references({
            parsed_chat = parsed_chat,
            config = parley.config,
            chat_file = chat_file,
            exchange_idx = 2,
        }, function(result)
            resolved = result
        end)

        assert.same({ url }, calls)
        assert.equals("File: shared\nfresh content\n\n", resolved[url])
        assert.equals("File: shared\nfresh content\n\n", parley._get_chat_remote_reference_cache(chat_file)[url])
    end)
end)

describe("google_drive.fetch_content", function()
    local google_drive
    local original_get_access_token
    local original_fetch_public_content

    before_each(function()
        google_drive = require("parley.google_drive")
        original_get_access_token = google_drive.get_access_token
        original_fetch_public_content = google_drive._fetch_public_content
    end)

    after_each(function()
        google_drive.get_access_token = original_get_access_token
        google_drive._fetch_public_content = original_fetch_public_content
    end)

    it("uses direct public content without requesting OAuth", function()
        local auth_requested = false
        google_drive._fetch_public_content = function(url, callback)
            callback({
                body = google_drive._sanitize_public_body('{"title":"Public note","body":"hello"}'),
                content_type = "application/json",
                effective_url = url,
                status_code = 200,
            }, nil)
        end
        google_drive.get_access_token = function(config, callback, url)
            auth_requested = true
            callback(nil)
        end

        local content
        google_drive.fetch_content("https://example.com/file.txt", parley.config.google_drive or {}, function(result, result_err)
            content = result
        end)

        assert.is_false(auth_requested)
        assert.is_not_nil(content)
        assert.is_true(content:match("Remote URL") ~= nil)
        assert.is_true(content:match("Public note") ~= nil)
    end)

    it("treats HTML landing pages as failed public fetches", function()
        local finalized, err = google_drive._finalize_public_response("https://www.dropbox.com/s/example", {
            body = "<!DOCTYPE html><html><head><title>Dropbox</title></head><body>viewer shell</body></html>",
            content_type = "text/html; charset=utf-8",
            effective_url = "https://www.dropbox.com/s/example",
        })

        assert.is_nil(finalized)
        assert.is_not_nil(err)
        assert.equals("auth", err.kind)
        assert.is_true(err.message:match("received HTML page instead of file content") ~= nil)
    end)

    it("treats access handoff JSON as failed public fetches", function()
        local finalized, err = google_drive._finalize_public_response("https://www.dropbox.com/s/example", {
            body = '{"url":"https://www.dropbox.com/cloud_docs/view/abc","content_access_token":"secret-token"}',
            content_type = "application/json",
            effective_url = "https://www.dropbox.com/s/example",
        })

        assert.is_nil(finalized)
        assert.is_not_nil(err)
        assert.equals("auth", err.kind)
        assert.is_true(err.message:match("access handoff payload") ~= nil)
    end)

    it("covers the URL fetch decision sequence", function()
        local cases = {
            {
                name = "public success returns public action",
                url = "https://example.com/file.txt",
                public_result = {
                    body = "hello",
                    content_type = "text/plain",
                    effective_url = "https://example.com/file.txt",
                },
                expected_action = "public",
                expected_name = "file.txt",
            },
            {
                name = "non-auth public failure returns error",
                url = "https://example.com/file.txt",
                public_err = {
                    kind = "other",
                    message = "Remote URL fetch failed: HTTP 500 for https://example.com/file.txt",
                },
                expected_action = "error",
                expected_message = "Remote URL fetch failed: HTTP 500 for https://example.com/file.txt",
            },
            {
                name = "auth failure with unknown provider returns error",
                url = "https://example.com/file.txt",
                public_err = {
                    kind = "auth",
                    message = "Remote URL fetch failed: HTTP 404 for https://example.com/file.txt",
                },
                expected_action = "error",
                expected_message = "Remote URL fetch failed: HTTP 404 for https://example.com/file.txt",
            },
            {
                name = "auth failure with known provider but unsupported format returns error",
                url = "https://docs.google.com/forms/d/form123/edit",
                public_err = {
                    kind = "auth",
                    message = "Remote URL fetch failed: HTTP 404 for https://docs.google.com/forms/d/form123/edit",
                },
                provider = "google",
                expected_action = "error",
                expected_message = "Public access failed and Google OAuth does not support this URL format: https://docs.google.com/forms/d/form123/edit",
            },
            {
                name = "auth failure with known provider and supported format returns oauth",
                url = "https://docs.google.com/document/d/abc123/edit",
                public_err = {
                    kind = "auth",
                    message = "Remote URL fetch failed: HTTP 404 for https://docs.google.com/document/d/abc123/edit",
                },
                provider = "google",
                info = { file_id = "abc123", file_type = "document" },
                expected_action = "oauth",
            },
        }

        for _, case in ipairs(cases) do
            local decision = google_drive._decide_fetch_action(
                case.url,
                case.public_result,
                case.public_err,
                case.provider,
                case.info
            )

            assert.equals(case.expected_action, decision.action, case.name)
            if case.expected_name then
                assert.equals(case.expected_name, decision.display_name, case.name)
            end
            if case.expected_message then
                assert.equals(case.expected_message, decision.message, case.name)
            end
        end
    end)

    it("does not request OAuth when public access fails for an unknown provider", function()
        local auth_requested = false
        google_drive._fetch_public_content = function(url, callback)
            callback(nil, {
                kind = "auth",
                message = "Remote URL fetch failed: HTTP 404 for " .. url,
            })
        end
        google_drive.get_access_token = function(config, callback, url)
            auth_requested = true
            callback(nil)
        end

        local content, err
        google_drive.fetch_content("https://example.com/file.txt", parley.config.google_drive or {}, function(result, result_err)
            content = result
            err = result_err
        end)

        assert.is_false(auth_requested)
        assert.is_nil(content)
        assert.equals("Remote URL fetch failed: HTTP 404 for https://example.com/file.txt", err)
    end)

    it("requests OAuth only after public auth failure for a supported provider", function()
        local requested_url
        google_drive._fetch_public_content = function(url, callback)
            callback(nil, {
                kind = "auth",
                message = "Remote URL fetch failed: HTTP 404 for " .. url,
            })
        end
        google_drive.get_access_token = function(config, callback, url)
            requested_url = url
            callback(nil)
        end

        local content, err
        google_drive.fetch_content("https://docs.google.com/document/d/abc123/edit", parley.config.google_drive or {}, function(result, result_err)
            content = result
            err = result_err
        end)

        assert.equals("https://docs.google.com/document/d/abc123/edit", requested_url)
        assert.is_nil(content)
        assert.equals("Google OAuth: authentication cancelled or failed.", err)
    end)
end)
