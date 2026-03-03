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
