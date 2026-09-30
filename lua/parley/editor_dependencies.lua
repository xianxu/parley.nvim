-- Pinned editor payloads. This pure registry is shared by runtime and packaging.
-- Archive and extracted Preview hashes were measured from the pinned upstream bytes.
local M = {}

local PLUGINS = {
    { name = "blink.cmp", repo = "saghen/blink.cmp",
        commit = "78336bc89ee5365633bcf754d93df01678b5c08f",
        sha256 = "74a12c86fd74ea28b37cccad0cf41ec2afff6a0ee07747ad38cc6eee869cce38",
        scope = "app" },
    { name = "catppuccin", repo = "catppuccin/nvim",
        commit = "edefef779ab08ce1a4a404713e3012b0d202bd35",
        sha256 = "92a674e334d9d3905316815fd977af9e127b7bc476b9b7d3798f8a61b8da54e1",
        scope = "app" },
    { name = "lazy.nvim", repo = "folke/lazy.nvim",
        commit = "85c7ff3711b730b4030d03144f6db6375044ae82",
        sha256 = "aa21e5d973015a8fdf5000dd3becbdcc12086751be5ffda7bfd54e2e20d02068",
        scope = "app" },
    { name = "lualine.nvim", repo = "nvim-lualine/lualine.nvim",
        commit = "221ce6b2d999187044529f49da6554a92f740a96",
        sha256 = "0bb7ae9af7c16ce56292f0fb38f57dfbdd48a071a5f08e0bff8bed6b9b02006b",
        scope = "app" },
    { name = "markdown-preview.nvim", repo = "iamcco/markdown-preview.nvim",
        commit = "a923f5fc5ba36a3b17e289dc35dc17f66d0548ee",
        sha256 = "03ca7c0f1862990ecb7aeba96072e51ac86db6580d693c4594284f9d45f8e8c5",
        scope = "app" },
    { name = "nightfox", repo = "EdenEast/nightfox.nvim",
        commit = "4dacd3f0185a2227bdf3b6c0975a8f0bf87cac9a",
        sha256 = "32ea7b73371f4ec469535b271adc1d6a06d97ef6754500c04056a21f6193aa77",
        scope = "app" },
    { name = "onedark", repo = "navarasu/onedark.nvim",
        commit = "df4792accde9db0043121f32628bcf8e645d9aea",
        sha256 = "ad83b5b7e028666e939a3ab7cfee92128c8bb16616632443f270138587684e3b",
        scope = "app" },
    { name = "plenary.nvim", repo = "nvim-lua/plenary.nvim",
        commit = "74b06c6c75e4eeb3108ec01852001636d85a932b",
        sha256 = "d9e7562417b49f4c9c0bf6f7edeb1d798665d967dbfaad428b893c28f36478ba",
        scope = "app" },
    { name = "screenkey.nvim", repo = "NStefan002/screenkey.nvim",
        commit = "16390931d847b1d5d77098daccac4e55654ac9e2",
        sha256 = "bca3a627f3f05a4edbb6d94477ef40be72f3d0119b644bec0c75b6c3a0de7f6b",
        scope = "recording" },
    { name = "solarized", repo = "altercation/vim-colors-solarized",
        commit = "528a59f26d12278698bb946f8fb82a63711eec21",
        sha256 = "2dde12f226e9400a5a8c9288dfd43ec52e26bb47b4641f6ccb940e8cda712fb7",
        scope = "app" },
    { name = "telescope.nvim", repo = "nvim-telescope/telescope.nvim",
        commit = "a0bbec21143c7bc5f8bb02e0005fa0b982edc026",
        sha256 = "0fe624b8a7974827bafd5930d206135f5d8d82cfcc979e0df6f0bee6c98478b5",
        scope = "app" },
    { name = "tokyonight", repo = "folke/tokyonight.nvim",
        commit = "cdc07ac78467a233fd62c493de29a17e0cf2b2b6",
        sha256 = "8b35026b9eda8d9e2f15e3282f91aa92e8a012932ed96c8c95168399d06ce2a8",
        scope = "app" },
}

local ARTIFACTS = {
    ["linux"] = {
        sha256 = "95eb4d2774c62e93998c41361fe2276a5134ef173dddab29026d34ef80ad44ef",
        binary_sha256 = "cc0373706714b8002a65dfb61d1b71ceffcd77d51fc17472acc0aa14d9bf1416",
    },
    ["macos"] = {
        sha256 = "580552e6506f858d9e7b2215888d62edbf5511e3201dd62c91afe502c3142204",
        binary_sha256 = "fa2825f30b4da22b6754cf09090ca17ed20debdc55072d9214f1e40b2b9aa474",
    },
    ["macos-arm64"] = {
        sha256 = "339f9a968fbbc4197259f811dd3f9780459f9d903532a29befcf16679b97babd",
        binary_sha256 = "850e3973513f3e187b87612a15c5fdacc6e82b58b130f36f8e7d9ff93cbd9f4c",
    },
}
local function copy(record)
    local result = {}
    for key, value in pairs(record) do result[key] = value end
    return result
end

local function safe_name(value)
    return type(value) == 'string' and value:match('^[%w][%w._-]*$') ~= nil
end

local function hex(value, length)
    return type(value) == 'string' and #value == length and value:match('^[0-9a-f]+$') ~= nil
end

local function plugin_url(plugin)
    return 'https://codeload.github.com/' .. plugin.repo .. '/tar.gz/' .. plugin.commit
end

local function artifact_url(artifact)
    return 'https://github.com/iamcco/markdown-preview.nvim/releases/download/v'
        .. artifact.version .. '/' .. artifact.member .. '.tar.gz'
end

-- Validate the exported transport shape, without reading files or invoking Neovim.
function M.validate_manifest(manifest)
    assert(type(manifest) == 'table' and manifest.schema_version == 1, 'unsupported editor manifest schema')
    assert(type(manifest.plugins) == 'table', 'editor manifest plugins must be an array')
    local count, last = 0, 0
    for key in pairs(manifest.plugins) do
        assert(type(key) == 'number' and key >= 1 and key == math.floor(key), 'plugins must be a dense array')
        count, last = count + 1, math.max(last, key)
    end
    assert(count > 0 and count == last, 'plugins must be a nonempty dense array')
    local names = {}
    for _, plugin in ipairs(manifest.plugins) do
        assert(type(plugin) == 'table' and safe_name(plugin.name), 'invalid editor plugin name')
        assert(not names[plugin.name], 'duplicate editor plugin name: ' .. plugin.name)
        names[plugin.name] = true
        assert(type(plugin.repo) == 'string', 'invalid editor plugin repository')
        local owner, repo = plugin.repo:match('^([^/]+)/([^/]+)$')
        assert(safe_name(owner) and safe_name(repo), 'invalid editor plugin repository')
        assert(hex(plugin.commit, 40), 'editor plugin requires a full commit')
        assert(hex(plugin.sha256, 64), 'editor plugin requires a SHA256')
        assert(plugin.scope == 'app' or plugin.scope == 'recording', 'invalid editor plugin scope')
        assert(plugin.url == plugin_url(plugin), 'editor plugin URL must identify its pinned archive')
    end
    local artifact = manifest.artifact
    assert(type(artifact) == 'table' and ARTIFACTS[artifact.platform], 'unsupported Preview platform')
    assert(type(artifact.version) == 'string' and artifact.version:match('^%d+%.%d+%.%d+$'),
        'Preview requires a release version')
    assert(artifact.member == 'markdown-preview-' .. artifact.platform, 'invalid Preview archive member')
    assert(artifact.output == 'plugins/markdown-preview.nvim/app/bin/' .. artifact.member,
        'invalid Preview output layout')
    assert(hex(artifact.sha256, 64) and hex(artifact.binary_sha256, 64), 'Preview requires archive and binary SHA256')
    assert(artifact.url == artifact_url(artifact), 'Preview URL must identify its versioned archive')
    return true
end

function M.plugins(profile)
    profile = profile or 'app'
    assert(profile == 'app' or profile == 'recording', 'unknown editor profile: ' .. tostring(profile))
    local result = {}
    for _, plugin in ipairs(PLUGINS) do
        if plugin.scope == 'app' or profile == 'recording' then
            local record = copy(plugin)
            record.url = plugin_url(record)
            result[#result + 1] = record
        end
    end
    table.sort(result, function(a, b) return a.name < b.name end)
    return result
end

function M.plugin(name)
    for _, plugin in ipairs(PLUGINS) do
        if plugin.name == name then return { plugin.repo, name = plugin.name, commit = plugin.commit } end
    end
    error('unknown editor plugin: ' .. tostring(name))
end

function M.artifact(platform)
    assert(ARTIFACTS[platform], 'unsupported Preview platform: ' .. tostring(platform))
    local result = copy(ARTIFACTS[platform])
    result.platform, result.version = platform, '0.0.10'
    result.member = 'markdown-preview-' .. platform
    result.output = 'plugins/markdown-preview.nvim/app/bin/' .. result.member
    result.url = artifact_url(result)
    return result
end

function M.export(profile, platform)
    local result = { schema_version = 1, plugins = M.plugins(profile), artifact = M.artifact(platform) }
    M.validate_manifest(result)
    return result
end

return M
