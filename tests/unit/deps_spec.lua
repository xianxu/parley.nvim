local deps = require("parley.deps")

local darwin_brew = { sysname = "Darwin", manager = "brew" }
local darwin_no_manager = { sysname = "Darwin", manager = nil }
local darwin_apt = { sysname = "Darwin", manager = "apt" }
local linux_apt = { sysname = "Linux", manager = "apt" }
local linux_brew = { sysname = "Linux", manager = "brew" }
local other_apt = { sysname = "FreeBSD", manager = "apt" }

local function ids(entries)
    local out = {}
    for _, entry in ipairs(entries) do
        out[#out + 1] = entry.id
    end
    return out
end

describe("parley.deps registry", function()
    it("exposes the ordered dependency contract", function()
        assert.are.same({
            "cliproxyapi", "osascript", "sips", "ripgrep", "imagemagick",
            "ffmpeg", "libvips", "wl-clipboard", "xclip", "pandoc", "curl",
        }, ids(deps.entries))

        for _, entry in ipairs(deps.entries) do
            assert.is_string(entry.id)
            assert.is_table(entry.executables)
            assert.is_true(#entry.executables > 0)
            assert.is_true(entry.tier == "managed" or entry.tier == "platform" or entry.tier == "advisory")
            assert.is_string(entry.feature)
            assert.is_table(entry.packages)
            assert.is_boolean(entry.formula_default)
            assert.is_boolean(entry.required)
            assert.are.same(entry, deps.get(entry.id))
        end
        assert.is_nil(deps.get("missing"))
    end)

    it("keeps executable alternatives and package metadata in the entries", function()
        assert.are.same({ "cliproxyapi", "cli-proxy-api" }, deps.get("cliproxyapi").executables)
        assert.are.same({ "magick", "convert" }, deps.get("imagemagick").executables)
        assert.are.same({ "ffmpeg" }, deps.get("ffmpeg").executables)
        assert.are.same({ brew = "vips", apt = "libvips-tools" }, deps.get("libvips").packages)
        assert.are.same({ apt = "wl-clipboard" }, deps.get("wl-clipboard").packages)
        assert.are.same({ apt = "xclip" }, deps.get("xclip").packages)
        assert.is_true(deps.get("ripgrep").formula_default)
        assert.is_true(deps.get("curl").required)
    end)

    it("applies host restrictions while treating unrestricted entries as universal", function()
        assert.is_true(deps.applicable(deps.get("osascript"), darwin_brew))
        assert.is_false(deps.applicable(deps.get("osascript"), linux_apt))
        assert.is_false(deps.applicable(deps.get("sips"), { sysname = "FreeBSD", manager = nil }))
        assert.is_true(deps.applicable(deps.get("wl-clipboard"), linux_apt))
        assert.is_false(deps.applicable(deps.get("wl-clipboard"), darwin_brew))
        assert.is_true(deps.applicable(deps.get("curl"), linux_apt))
        assert.is_true(deps.applicable(deps.get("curl"), { sysname = "FreeBSD", manager = nil }))
        assert.is_true(deps.applicable(deps.get("cliproxyapi"), nil))
    end)

    it("gives managed guidance without a host or package manager", function()
        local advice = deps.advice("cliproxyapi", nil)
        assert.matches(":ParleyProxy update", advice, 1, true)
        assert.matches("cliproxy%.binary_path", advice)
        assert.is_nil(advice:find("brew install", 1, true))
        assert.is_nil(advice:find("apt install", 1, true))
    end)

    it("gives platform guidance on Darwin without package-install commands", function()
        for _, id in ipairs({ "osascript", "sips" }) do
            local advice = deps.advice(id, darwin_brew)
            assert.matches("macOS", advice)
            assert.is_nil(advice:find("brew install", 1, true))
            assert.is_nil(advice:find("apt install", 1, true))
        end
        local curl_advice = deps.advice("curl", darwin_apt)
        assert.matches("system%-provided", curl_advice)
        assert.is_nil(curl_advice:find("brew install", 1, true))
        assert.is_nil(curl_advice:find("apt install", 1, true))
    end)

    it("selects only a manager tested for the host", function()
        assert.equals("brew install ripgrep", deps.advice("ripgrep", darwin_brew))
        assert.equals("apt install ripgrep", deps.advice("ripgrep", linux_apt))
        assert.equals("apt install curl", deps.advice("curl", linux_apt))
        assert.matches("no tested install advice", deps.advice("ripgrep", darwin_no_manager))
        assert.matches("no tested install advice", deps.advice("ripgrep", darwin_apt))
        assert.matches("no tested install advice", deps.advice("ripgrep", linux_brew))
        assert.matches("no tested install advice", deps.advice("ripgrep", other_apt))
    end)

    it("reports inapplicable dependencies explicitly", function()
        for _, id in ipairs({ "osascript", "sips" }) do
            assert.matches("not applicable", deps.advice(id, linux_apt))
        end
        for _, id in ipairs({ "wl-clipboard", "xclip" }) do
            assert.matches("not applicable", deps.advice(id, darwin_brew))
        end
    end)

    it("projects sorted unique default and all package sets", function()
        assert.are.same({ "ripgrep" }, deps.packages(darwin_brew, "default"))
        assert.are.same({ "ffmpeg", "imagemagick", "pandoc", "ripgrep", "vips" },
            deps.packages(darwin_brew, "all"))
        assert.are.same({ "ripgrep" }, deps.packages(linux_apt, "default"))
        assert.are.same({ "ffmpeg", "imagemagick", "libvips-tools", "pandoc", "ripgrep",
            "wl-clipboard", "xclip" }, deps.packages(linux_apt, "all"))
        assert.are.same({}, deps.packages(darwin_no_manager, "all"))
        assert.are.same({}, deps.packages(darwin_apt, "all"))
        assert.are.same({}, deps.packages(linux_brew, "all"))
        assert.are.same({}, deps.packages(other_apt, "all"))
    end)
end)
