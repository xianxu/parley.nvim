-- Disposable ariadne#252-shaped repositories for #308 specs: a bare remote, a
-- `writer` clone that owns the orphan `issue-tracker` branch, and a `reader`
-- clone (the checkout parley looks at) with details files on main.
local fixture_directory = require("tests.helpers.fixture_directory")

local M = {}

local IDENTITY = {
    "-c", "user.name=parley-test", "-c", "user.email=parley-test@example.invalid",
    "-c", "commit.gpgsign=false", "-c", "init.defaultBranch=main",
}

function M.git(dir, args)
    local argv = { "git", "-C", dir }
    vim.list_extend(argv, IDENTITY)
    vim.list_extend(argv, args)
    local result = vim.system(argv, { text = true, env = { GIT_TERMINAL_PROMPT = "0" } }):wait()
    assert(result.code == 0, table.concat(argv, " ") .. "\n" .. (result.stderr or ""))
    return result.stdout
end

local function card_text(name, fields)
    local id = name:match("^(%d+)")
    return table.concat({
        "---",
        "id: " .. id,
        "status: " .. fields.status,
        "created: " .. (fields.created or "2026-09-01"),
        "updated: " .. (fields.updated or "2026-09-01"),
        "github_issue:",
        "tracker:",
        "    version: 1",
        "---",
        "",
        "# " .. fields.title,
        "",
    }, "\n")
end

-- Details file as `sdlc issue new` leaves it: a card_mirror snapshot.
function M.details_text(name, fields)
    local id = name:match("^(%d+)")
    return table.concat({
        "---",
        "id: " .. id,
        "status: " .. fields.status,
        "deps: []",
        "github_issue:",
        "created: " .. (fields.created or "2026-09-01"),
        "updated: " .. (fields.updated or "2026-09-01"),
        "card_mirror: 'abc' # card fields mirrored from issue-cards; edit via sdlc",
        "---",
        "",
        "# " .. fields.title,
        "",
    }, "\n")
end

local function write(path, text)
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
    vim.fn.writefile(vim.split(text, "\n", { plain = true }), path)
end

-- Commit a card on the writer's issue-tracker branch and push it.
function M.write_card(writer, name, fields)
    write(writer .. "/workshop/issue-cards/" .. name, card_text(name, fields))
    M.git(writer, { "add", "workshop/issue-cards/" .. name })
    M.git(writer, { "commit", "-q", "-m", "tracker: " .. name })
    M.git(writer, { "push", "-q", "origin", "issue-tracker" })
end

-- cards: { [filename] = {status, title, ...} }. Details on main mirror the
-- initial card values; `details` overrides them per filename.
function M.create(cards, details)
    local base = vim.fn.resolve(vim.fn.tempname())
    local repos = { base = base, remote = base .. "/remote.git", writer = base .. "/writer", reader = base .. "/reader" }
    vim.fn.mkdir(base, "p")
    M.git(base, { "init", "-q", "--bare", repos.remote })
    M.git(base, { "clone", "-q", repos.remote, repos.writer })

    write(repos.writer .. "/workshop/issue-tracker.json", '{"version":1}')
    for name, fields in pairs(cards) do
        write(repos.writer .. "/workshop/issues/" .. name,
            M.details_text(name, (details or {})[name] or fields))
    end
    M.git(repos.writer, { "add", "." })
    M.git(repos.writer, { "commit", "-q", "-m", "main" })
    M.git(repos.writer, { "push", "-q", "-u", "origin", "main" })

    M.git(repos.writer, { "checkout", "-q", "--orphan", "issue-tracker" })
    M.git(repos.writer, { "rm", "-rq", "--cached", "." })
    vim.fn.delete(repos.writer .. "/workshop", "rf")
    write(repos.writer .. "/issue-tracker.json", '{"version":1}')
    for name, fields in pairs(cards) do
        write(repos.writer .. "/workshop/issue-cards/" .. name, card_text(name, fields))
    end
    M.git(repos.writer, { "add", "." })
    M.git(repos.writer, { "commit", "-q", "-m", "tracker" })
    M.git(repos.writer, { "push", "-q", "origin", "issue-tracker" })

    M.git(base, { "clone", "-q", repos.remote, repos.reader })
    return repos
end

function M.destroy(repos)
    if repos then
        fixture_directory.remove(repos.base)
    end
end

return M
