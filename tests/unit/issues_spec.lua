-- Unit tests for lua/parley/issues.lua pure functions
--
-- Tests parse_frontmatter, parse_deps_value, next_runnable,
-- cycle_status_value, topo_sort, slugify, extract_title, format_deps

local tmp_dir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-issues-" .. os.time()

-- Bootstrap parley (needed for chat_parser dependency)
local parley = require("parley")
parley.setup({
    chat_dir = tmp_dir,
    state_dir = tmp_dir .. "/state",
    providers = {},
    api_keys = {},
})

local issues = require("parley.issues")
local issue_vocabulary = require("parley.issue_vocabulary")

local function fake_issue_vocab(statuses)
    return issue_vocabulary.from_table({
        categories = {
            open = { statuses[1] },
            active = { statuses[2], statuses[3] },
            terminal = vim.list_slice(statuses, 4),
        },
        lifecycle = {
            { from = statuses[1], to = statuses[2], event = "claim", guards = {} },
            { from = statuses[2], to = statuses[3], event = "block", guards = {} },
            { from = statuses[3], to = statuses[4], event = "close", guards = {} },
        },
    })
end

--------------------------------------------------------------------------------
-- resolve_issues_dir (#116 M2 — seed precedence: user override > cue > default)
--------------------------------------------------------------------------------

describe("resolve_issues_dir", function()
    it("uses the explicit user override when present (wins over cue)", function()
        assert.equals("my/issues", issues.resolve_issues_dir("my/issues", "workshop/issues", "workshop/issues"))
    end)

    it("uses the cue home when the user did not override", function()
        assert.equals("workshop/issues", issues.resolve_issues_dir(nil, "workshop/issues", "fallback/dir"))
    end)

    it("falls back to the built-in default when neither override nor cue", function()
        assert.equals("fallback/dir", issues.resolve_issues_dir(nil, nil, "fallback/dir"))
    end)
end)

--------------------------------------------------------------------------------
-- parse_issue_new_output (#116 M3 — extract the created path from sdlc output)
--------------------------------------------------------------------------------

describe("parse_issue_new_output", function()
    it("returns the bare created path (sdlc writes it to stdout, last line)", function()
        assert.equals("workshop/issues/000160-foo.md",
            issues.parse_issue_new_output("workshop/issues/000160-foo.md\n"))
    end)

    it("extracts the bare path from merged stdout+stderr (Created line + sync warning)", function()
        local merged = "Created workshop/issues/000160-foo.md\n"
            .. "issue created but auto-sync to main did not complete: offline\n"
            .. "workshop/issues/000160-foo.md\n"
        assert.equals("workshop/issues/000160-foo.md", issues.parse_issue_new_output(merged))
    end)

    it("extracts an absolute path under a directory containing spaces (#116 M3 I1 consequence)", function()
        -- M3 forwards an absolute --issues-dir, so dest can be an absolute path
        -- whose dir contains spaces; the colored '[ok] Created <path>' line is
        -- excluded by containing "Created", the bare stdout path is kept.
        local merged = "  [ok] Created /Users/John Doe/r/workshop/issues/000001-foo.md\n"
            .. "/Users/John Doe/r/workshop/issues/000001-foo.md\n"
        assert.equals("/Users/John Doe/r/workshop/issues/000001-foo.md", issues.parse_issue_new_output(merged))
    end)

    it("returns nil when only the spaced 'Created <path>' line is present", function()
        assert.is_nil(issues.parse_issue_new_output("Created workshop/issues/000160-foo.md\n"))
    end)

    it("returns nil for empty or pathless output", function()
        assert.is_nil(issues.parse_issue_new_output(""))
        assert.is_nil(issues.parse_issue_new_output("some error\nno path here\n"))
    end)
end)

--------------------------------------------------------------------------------
-- run_sdlc_issue_new (#116 M3 — delegate creation to `sdlc issue new`)
--------------------------------------------------------------------------------

describe("run_sdlc_issue_new", function()
    -- async runner: receives (argv, on_complete) and calls on_complete(output, code)
    local function fake(output, code, cap)
        return function(argv, on_complete)
            if cap then cap.argv = argv end
            on_complete(output, code)
        end
    end
    -- drive the async call (the fake calls back inline → stays synchronous) + capture
    local function run(title, opts, runner)
        local r = {}
        issues.run_sdlc_issue_new(title, opts, function(path, err)
            r.path, r.err = path, err
        end, runner)
        return r
    end

    it("calls back with the created path on success; argv = sdlc issue new <title>", function()
        local cap = {}
        local r = run("My Title", {}, fake("workshop/issues/000160-my-title.md\n", 0, cap))
        assert.is_nil(r.err)
        assert.equals("workshop/issues/000160-my-title.md", r.path)
        assert.are.same({ "sdlc", "issue", "new", "--", "My Title" }, cap.argv)
    end)

    it("forwards absolute --issues-dir/--history-dir (git-root-anchored, #116 M3 I1)", function()
        local cap = {}
        run("t", { issues_dir = "/r/workshop/issues", history_dir = "/r/workshop/history" },
            fake("/r/workshop/issues/000001-t.md\n", 0, cap))
        assert.are.same(
            { "sdlc", "issue", "new", "--issues-dir", "/r/workshop/issues",
              "--history-dir", "/r/workshop/history", "--", "t" },
            cap.argv)
    end)

    it("appends -- so a title starting with '-' is positional, not a flag", function()
        local cap = {}
        run("-n weird title", {}, fake("workshop/issues/000001-n-weird-title.md\n", 0, cap))
        assert.are.same({ "sdlc", "issue", "new", "--", "-n weird title" }, cap.argv)
    end)

    it("calls back with an error on a non-zero exit", function()
        local r = run("t", {}, fake("title is required\n", 1))
        assert.is_nil(r.path)
        assert.is_truthy(r.err and r.err:find("exit 1", 1, true))
    end)

    it("errors when sdlc succeeds but prints no parseable path", function()
        local r = run("t", {}, fake("nothing useful\n", 0))
        assert.is_nil(r.path)
        assert.is_truthy(r.err and r.err:find("no created path", 1, true))
    end)

    -- NB: opts.deps is a forward API for an eventual child-flow migration; the
    -- current cmd_issue_decompose does NOT use this function (and its dep direction
    -- is the opposite of --deps — parent.deps += child). Don't wire decompose here.
    it("passes --deps (comma-joined) when opts.deps is set", function()
        local cap = {}
        run("child task", { deps = { "000116" } }, fake("workshop/issues/000161-child.md\n", 0, cap))
        assert.are.same({ "sdlc", "issue", "new", "--deps", "000116", "--", "child task" }, cap.argv)
    end)
end)

describe("build_spawn_argv (#116 M3 — sdlc as PATH binary vs shell function)", function()
    it("spawns the argv directly when sdlc is a resolvable executable", function()
        local argv = { "sdlc", "issue", "new", "--", "t" }
        assert.are.same(argv, issues.build_spawn_argv(argv, true, "/bin/zsh"))
    end)

    it("wraps in an interactive shell when sdlc is a function/alias (the live E475 fix)", function()
        local out = issues.build_spawn_argv({ "sdlc", "issue", "new", "--", "my title" }, false, "/bin/zsh")
        assert.are.same("/bin/zsh", out[1])
        assert.are.same("-i", out[2])
        assert.are.same("-c", out[3])
        assert.is_truthy(out[4]:find("'sdlc' 'issue' 'new'", 1, true)) -- each word shellescaped
        assert.is_truthy(out[4]:find("'my title'", 1, true)) -- title quoted intact (space preserved)
    end)
end)

--------------------------------------------------------------------------------
-- slugify
--------------------------------------------------------------------------------

describe("slugify", function()
    it("converts title to lowercase slug", function()
        assert.equals("auth-token-refresh", issues.slugify("Auth Token Refresh"))
    end)

    it("handles special characters", function()
        assert.equals("fix-bug-123", issues.slugify("Fix bug #123!"))
    end)

    it("collapses multiple dashes", function()
        assert.equals("a-b", issues.slugify("a   b"))
    end)

    it("strips leading/trailing dashes", function()
        assert.equals("hello", issues.slugify("--hello--"))
    end)

    it("handles empty string", function()
        assert.equals("", issues.slugify(""))
    end)
end)

--------------------------------------------------------------------------------
-- parse_deps_value
--------------------------------------------------------------------------------

describe("parse_deps_value", function()
    it("parses empty brackets", function()
        assert.same({}, issues.parse_deps_value("[]"))
    end)

    it("parses single dep", function()
        assert.same({ "0001" }, issues.parse_deps_value("[0001]"))
    end)

    it("parses multiple deps", function()
        assert.same({ "0001", "0003" }, issues.parse_deps_value("[0001, 0003]"))
    end)

    it("parses without brackets", function()
        assert.same({ "0001", "0002" }, issues.parse_deps_value("0001, 0002"))
    end)

    it("handles nil", function()
        assert.same({}, issues.parse_deps_value(nil))
    end)

    it("handles empty string", function()
        assert.same({}, issues.parse_deps_value(""))
    end)

    it("trims whitespace", function()
        assert.same({ "0001", "0002" }, issues.parse_deps_value("[ 0001 , 0002 ]"))
    end)
end)

--------------------------------------------------------------------------------
-- parse_frontmatter
--------------------------------------------------------------------------------

describe("parse_frontmatter", function()
    it("returns nil for empty lines", function()
        assert.is_nil(issues.parse_frontmatter({}))
    end)

    it("returns nil for no frontmatter", function()
        assert.is_nil(issues.parse_frontmatter({ "# Title", "", "Content" }))
    end)

    it("parses minimal frontmatter", function()
        local lines = { "---", "status: open", "---", "", "# Title" }
        local fm = issues.parse_frontmatter(lines)
        assert.is_not_nil(fm)
        assert.equals("open", fm.status)
        assert.same({}, fm.deps)
        assert.equals(3, fm.header_end)
    end)

    it("parses full frontmatter", function()
        local lines = {
            "---",
            "id: 0002",
            "status: blocked",
            "deps: [0001, 0003]",
            "created: 2026-03-28",
            "updated: 2026-03-29",
            "---",
            "",
            "# Some issue",
        }
        local fm = issues.parse_frontmatter(lines)
        assert.is_not_nil(fm)
        assert.equals("0002", fm.id)
        assert.equals("blocked", fm.status)
        assert.same({ "0001", "0003" }, fm.deps)
        assert.equals("2026-03-28", fm.created)
        assert.equals("2026-03-29", fm.updated)
        assert.equals(7, fm.header_end)
    end)

    it("parses id without quotes", function()
        local lines = { "---", "id: 0005", "status: open", "---" }
        local fm = issues.parse_frontmatter(lines)
        assert.equals("0005", fm.id)
    end)

    it("id is nil when absent", function()
        local lines = { "---", "status: open", "deps: []", "---" }
        local fm = issues.parse_frontmatter(lines)
        assert.is_nil(fm.id)
    end)

    it("defaults status to open when missing", function()
        local lines = { "---", "deps: []", "---" }
        local fm = issues.parse_frontmatter(lines)
        assert.equals("open", fm.status)
    end)

    it("handles empty deps", function()
        local lines = { "---", "status: done", "deps: []", "---" }
        local fm = issues.parse_frontmatter(lines)
        assert.same({}, fm.deps)
    end)

    it("parses github_issue field", function()
        local lines = { "---", "status: open", "github_issue: 42", "deps: []", "---" }
        local fm = issues.parse_frontmatter(lines)
        assert.equals("42", fm.github_issue)
    end)

    it("github_issue is nil when absent", function()
        local lines = { "---", "status: open", "deps: []", "---" }
        local fm = issues.parse_frontmatter(lines)
        assert.is_nil(fm.github_issue)
    end)
end)

--------------------------------------------------------------------------------
-- extract_title
--------------------------------------------------------------------------------

describe("extract_title", function()
    it("extracts title after frontmatter", function()
        local lines = { "---", "status: open", "---", "", "# My Issue Title" }
        assert.equals("My Issue Title", issues.extract_title(lines, 3))
    end)

    it("returns empty for no heading", function()
        local lines = { "---", "status: open", "---", "", "No heading here" }
        assert.equals("", issues.extract_title(lines, 3))
    end)

    it("skips lines before header_end", function()
        local lines = { "---", "# Not This", "---", "", "# Real Title" }
        assert.equals("Real Title", issues.extract_title(lines, 3))
    end)
end)

--------------------------------------------------------------------------------
-- cycle_status_value
--------------------------------------------------------------------------------

describe("cycle_status_value", function()
    after_each(function()
        issue_vocabulary.reset_for_tests()
    end)

    it("exposes status values from the generated vocabulary", function()
        assert.are.same(issue_vocabulary.default():status_values(), issues.status_values())
    end)

    it("completes status frontmatter values from the vocabulary", function()
        assert.are.same({ "working", "wontfix" }, issues.complete_frontmatter_values("status", "wo"))
    end)

    it("surfaces newly generated statuses without Lua enum edits", function()
        issue_vocabulary.set_default_for_tests(fake_issue_vocab({
            "open",
            "working",
            "blocked",
            "done",
            "wontfix",
            "punt",
            "archived",
        }))

        assert.are.same({ "archived" }, issues.complete_frontmatter_values("status", "ar"))
        assert.equals("archived", issues.status_values()[7])
    end)

    it("cycles open to working", function()
        assert.equals("working", issues.cycle_status_value("open"))
    end)

    it("cycles working to blocked", function()
        assert.equals("blocked", issues.cycle_status_value("working"))
    end)

    it("cycles blocked by first lifecycle successor", function()
        assert.equals("working", issues.cycle_status_value("blocked"))
    end)

    it("cycles done by lifecycle successor", function()
        assert.equals("working", issues.cycle_status_value("done"))
    end)

    it("cycles wontfix by lifecycle successor", function()
        assert.equals("working", issues.cycle_status_value("wontfix"))
    end)

    it("cycles punt by lifecycle successor", function()
        assert.equals("working", issues.cycle_status_value("punt"))
    end)

    it("defaults unknown to open", function()
        assert.equals("open", issues.cycle_status_value("unknown"))
    end)
end)

--------------------------------------------------------------------------------
-- render_issue_template
--------------------------------------------------------------------------------

describe("render_issue_template", function()
    after_each(function()
        issue_vocabulary.reset_for_tests()
    end)

    it("uses the vocabulary default status for every issue template render", function()
        issue_vocabulary.set_default_for_tests(fake_issue_vocab({
            "triage",
            "working",
            "blocked",
            "done",
        }))

        local content = issues.render_issue_template({
            id = "000123",
            title = "Split the task",
            date = "2026-06-25",
        })

        assert.matches("status: triage", content, 1, true)
        assert.is_nil(content:match("{{status}}"))
    end)
end)

--------------------------------------------------------------------------------
-- next_runnable
--------------------------------------------------------------------------------

describe("next_runnable", function()
    it("returns nil for empty list", function()
        assert.is_nil(issues.next_runnable({}))
    end)

    it("returns single open issue with no deps", function()
        local result = issues.next_runnable({
            { id = "0001", status = "open", deps = {} },
        })
        assert.equals("0001", result.id)
    end)

    it("skips done issues", function()
        local result = issues.next_runnable({
            { id = "0001", status = "done", deps = {} },
            { id = "0002", status = "open", deps = {} },
        })
        assert.equals("0002", result.id)
    end)

    it("skips blocked issues", function()
        local result = issues.next_runnable({
            { id = "0001", status = "blocked", deps = {} },
            { id = "0002", status = "open", deps = {} },
        })
        assert.equals("0002", result.id)
    end)

    it("skips working issues", function()
        local result = issues.next_runnable({
            { id = "0001", status = "working", deps = {} },
            { id = "0002", status = "open", deps = {} },
        })
        assert.equals("0002", result.id)
    end)

    it("skips wontfix issues", function()
        local result = issues.next_runnable({
            { id = "0001", status = "wontfix", deps = {} },
            { id = "0002", status = "open", deps = {} },
        })
        assert.equals("0002", result.id)
    end)

    it("skips open issue with unmet dep", function()
        local result = issues.next_runnable({
            { id = "0001", status = "open", deps = { "0002" } },
            { id = "0002", status = "open", deps = {} },
        })
        assert.equals("0002", result.id)
    end)

    it("returns open issue when deps are done", function()
        local result = issues.next_runnable({
            { id = "0001", status = "done", deps = {} },
            { id = "0002", status = "open", deps = { "0001" } },
        })
        assert.equals("0002", result.id)
    end)

    it("handles diamond dependency", function()
        -- 0003 depends on 0001 and 0002; 0001 done, 0002 not done
        local result = issues.next_runnable({
            { id = "0001", status = "done", deps = {} },
            { id = "0002", status = "open", deps = {} },
            { id = "0003", status = "open", deps = { "0001", "0002" } },
        })
        assert.equals("0002", result.id)
    end)

    it("returns nil when all deps unmet (circular)", function()
        local result = issues.next_runnable({
            { id = "0001", status = "open", deps = { "0002" } },
            { id = "0002", status = "open", deps = { "0001" } },
        })
        assert.is_nil(result)
    end)

    it("returns nil when all issues are done", function()
        local result = issues.next_runnable({
            { id = "0001", status = "done", deps = {} },
            { id = "0002", status = "done", deps = {} },
        })
        assert.is_nil(result)
    end)

    it("picks oldest open issue first", function()
        local result = issues.next_runnable({
            { id = "0003", status = "open", deps = {} },
            { id = "0001", status = "open", deps = {} },
            { id = "0002", status = "open", deps = {} },
        })
        assert.equals("0001", result.id)
    end)

    it("advances past current_id", function()
        local all = {
            { id = "0001", status = "open", deps = {} },
            { id = "0002", status = "open", deps = {} },
            { id = "0003", status = "open", deps = {} },
        }
        assert.equals("0002", issues.next_runnable(all, "0001").id)
        assert.equals("0003", issues.next_runnable(all, "0002").id)
    end)

    it("cycles back to first when at end", function()
        local all = {
            { id = "0001", status = "open", deps = {} },
            { id = "0002", status = "open", deps = {} },
        }
        assert.equals("0001", issues.next_runnable(all, "0002").id)
    end)

    it("cycles back when current_id is past all runnable", function()
        local all = {
            { id = "0001", status = "open", deps = {} },
            { id = "0002", status = "done", deps = {} },
        }
        assert.equals("0001", issues.next_runnable(all, "0002").id)
    end)

    it("returns nil with current_id when no runnable", function()
        local all = {
            { id = "0001", status = "done", deps = {} },
        }
        assert.is_nil(issues.next_runnable(all, "0001"))
    end)
end)

--------------------------------------------------------------------------------
-- topo_sort
--------------------------------------------------------------------------------

describe("topo_sort", function()
    it("sorts open before blocked before done", function()
        local sorted = issues.topo_sort({
            { id = "0001", status = "done", deps = {} },
            { id = "0002", status = "blocked", deps = {} },
            { id = "0003", status = "open", deps = {} },
        })
        assert.equals("0003", sorted[1].id) -- open
        assert.equals("0002", sorted[2].id) -- blocked
        assert.equals("0001", sorted[3].id) -- done
    end)

    it("sorts modeled statuses in priority order", function()
        local sorted = issues.topo_sort({
            { id = "0001", status = "wontfix", deps = {} },
            { id = "0002", status = "done", deps = {} },
            { id = "0003", status = "blocked", deps = {} },
            { id = "0004", status = "working", deps = {} },
            { id = "0005", status = "open", deps = {} },
        })
        assert.equals("0005", sorted[1].id) -- open
        assert.equals("0004", sorted[2].id) -- working
        assert.equals("0003", sorted[3].id) -- blocked
        assert.equals("0002", sorted[4].id) -- done
        assert.equals("0001", sorted[5].id) -- wontfix
    end)

    it("sorts by ID within same status", function()
        local sorted = issues.topo_sort({
            { id = "0003", status = "open", deps = {} },
            { id = "0001", status = "open", deps = {} },
            { id = "0002", status = "open", deps = {} },
        })
        assert.equals("0001", sorted[1].id)
        assert.equals("0002", sorted[2].id)
        assert.equals("0003", sorted[3].id)
    end)

    it("handles empty list", function()
        assert.same({}, issues.topo_sort({}))
    end)
end)

--------------------------------------------------------------------------------
-- format_deps
--------------------------------------------------------------------------------

describe("format_deps", function()
    it("formats empty deps", function()
        assert.equals("[]", issues.format_deps({}))
    end)

    it("formats single dep", function()
        assert.equals("[0001]", issues.format_deps({ "0001" }))
    end)

    it("formats multiple deps", function()
        assert.equals("[0001, 0003]", issues.format_deps({ "0001", "0003" }))
    end)

    it("handles nil", function()
        assert.equals("[]", issues.format_deps(nil))
    end)
end)

--------------------------------------------------------------------------------
-- parse_md_link_at_cursor
--------------------------------------------------------------------------------

describe("parse_md_link_at_cursor", function()
    it("returns the link when cursor is inside it", function()
        local line = "see [issue 000067](./000067-foo.md) for details"
        local link = issues.parse_md_link_at_cursor(line, 10)
        assert.is_not_nil(link)
        assert.equals("issue 000067", link.text)
        assert.equals("./000067-foo.md", link.url)
    end)

    it("returns nil when cursor is outside any link", function()
        local line = "see [issue 000067](./000067-foo.md) for details"
        assert.is_nil(issues.parse_md_link_at_cursor(line, 40))
    end)

    it("picks the link under the cursor when there are multiple", function()
        local line = "[a](./a.md) and [b](./b.md)"
        local first = issues.parse_md_link_at_cursor(line, 2)
        assert.equals("./a.md", first.url)
        local second = issues.parse_md_link_at_cursor(line, 18)
        assert.equals("./b.md", second.url)
    end)

    it("matches a link at the very start of the line", function()
        local line = "[issue 000001](./000001-foo.md)"
        local link = issues.parse_md_link_at_cursor(line, 1)
        assert.is_not_nil(link)
        assert.equals("./000001-foo.md", link.url)
    end)

    it("returns nil for nil inputs", function()
        assert.is_nil(issues.parse_md_link_at_cursor(nil, 1))
        assert.is_nil(issues.parse_md_link_at_cursor("[a](b)", nil))
    end)
end)

--------------------------------------------------------------------------------
-- resolve_link_target
--------------------------------------------------------------------------------

describe("resolve_link_target", function()
    it("joins a relative .md link against cur_dir", function()
        local link = { url = "./000067-foo.md" }
        assert.equals("/repo/issues/./000067-foo.md", issues.resolve_link_target(link, "/repo/issues"))
    end)

    it("returns an absolute .md link unchanged", function()
        local link = { url = "/abs/path/000067-foo.md" }
        assert.equals("/abs/path/000067-foo.md", issues.resolve_link_target(link, "/repo/issues"))
    end)

    it("joins a bare relative .md link (no ./ prefix)", function()
        local link = { url = "000067-foo.md" }
        assert.equals("/repo/issues/000067-foo.md", issues.resolve_link_target(link, "/repo/issues"))
    end)

    it("returns nil when link url is not a .md file", function()
        assert.is_nil(issues.resolve_link_target({ url = "https://example.com" }, "/repo/issues"))
        assert.is_nil(issues.resolve_link_target({ url = "./other.txt" }, "/repo/issues"))
    end)

    it("returns nil when link is nil", function()
        assert.is_nil(issues.resolve_link_target(nil, "/repo/issues"))
    end)

    it("returns nil when link has no url field", function()
        assert.is_nil(issues.resolve_link_target({}, "/repo/issues"))
    end)
end)

--------------------------------------------------------------------------------
-- parse_src_url
--------------------------------------------------------------------------------

describe("parse_src_url", function()
    it("extracts path from a src: URL", function()
        assert.equals("backend/app/models/user.rb", issues.parse_src_url("src:/backend/app/models/user.rb"))
    end)

    it("extracts a nested path", function()
        assert.equals("nex-integrations-platform/nexhealth_integrations/sync_runner.py",
            issues.parse_src_url("src:/nex-integrations-platform/nexhealth_integrations/sync_runner.py"))
    end)

    it("returns nil for non-src: URLs", function()
        assert.is_nil(issues.parse_src_url("./000067-foo.md"))
        assert.is_nil(issues.parse_src_url("https://example.com"))
    end)

    it("returns nil for nil input", function()
        assert.is_nil(issues.parse_src_url(nil))
    end)
end)

--------------------------------------------------------------------------------
-- find_parent
--------------------------------------------------------------------------------

describe("find_parent", function()
    it("finds the issue whose deps contains child_id", function()
        local list = {
            { id = "000010", deps = {} },
            { id = "000011", deps = { "000020", "000021" } },
            { id = "000012", deps = { "000022" } },
        }
        local parent = issues.find_parent(list, "000021")
        assert.is_not_nil(parent)
        assert.equals("000011", parent.id)
    end)

    it("returns nil when no parent exists", function()
        local list = {
            { id = "000010", deps = {} },
            { id = "000011", deps = { "000020" } },
        }
        assert.is_nil(issues.find_parent(list, "000099"))
    end)

    it("returns the first matching parent deterministically", function()
        local list = {
            { id = "000010", deps = { "000050" } },
            { id = "000011", deps = { "000050" } },
        }
        local parent = issues.find_parent(list, "000050")
        assert.equals("000010", parent.id)
    end)

    it("handles nil inputs gracefully", function()
        assert.is_nil(issues.find_parent(nil, "000001"))
        assert.is_nil(issues.find_parent({}, nil))
    end)

    it("tolerates issues with missing deps field", function()
        local list = { { id = "000010" }, { id = "000011", deps = { "000020" } } }
        local parent = issues.find_parent(list, "000020")
        assert.equals("000011", parent.id)
    end)
end)

--------------------------------------------------------------------------------
-- repo_label (#142)
--------------------------------------------------------------------------------

describe("repo_label", function()
    it("returns the basename of a git root", function()
        assert.equals("parley.nvim", issues.repo_label("/Users/x/workspace/parley.nvim"))
        assert.equals("brain", issues.repo_label("/Users/x/workspace/brain"))
    end)

    it("strips trailing slashes", function()
        assert.equals("pair", issues.repo_label("/Users/x/workspace/pair/"))
        assert.equals("pair", issues.repo_label("/Users/x/workspace/pair///"))
    end)

    it("falls back to '?' for nil or empty", function()
        assert.equals("?", issues.repo_label(nil))
        assert.equals("?", issues.repo_label(""))
    end)

    it("handles a bare segment with no slashes", function()
        assert.equals("repo", issues.repo_label("repo"))
    end)
end)
