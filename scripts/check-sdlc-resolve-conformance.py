#!/usr/bin/env python3
"""Opt-in, offline conformance of the resolver fake to installed sdlc.

Only the consumed files/path/kind/milestone projection and failure vs success
are compared. This does not certify the complete resolver grammar or discovery.
No repository writes occur outside the automatically removed scratch directory.
"""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


LUA_CHECK = r'''
vim.opt.runtimepath:append(vim.env.PARLEY_CONFORMANCE_ROOT)
local artifact = require("parley.artifact_ref")
local fixture = vim.json.decode(table.concat(vim.fn.readfile(vim.env.PARLEY_CONFORMANCE_FIXTURE), "\n"))
for _, case in ipairs(fixture.cases) do
    for _, command in ipairs({ fixture.sdlc, fixture.fake }) do
        vim.env.PARLEY_FAKE_SDLC_MODE = case.failure and "fail" or nil
        local done, files, err = false, nil, nil
        artifact.run_resolve(case.ref, { cwd = fixture.repo, sdlc_cmd = command }, function(result, failure)
            files, err, done = result, failure, true
        end)
        assert(vim.wait(10000, function() return done end), "resolver timed out: " .. case.ref)
        if case.failure then
            assert(files == nil and type(err) == "string" and #err > 0, "missing ref must fail: " .. case.ref)
        else
            assert(err == nil, tostring(err))
            assert(vim.deep_equal(case.files, files), case.ref .. " consumed projection differs for " .. command
                .. "\nexpected " .. vim.inspect(case.files) .. "\nactual " .. vim.inspect(files))
        end
        local action = artifact.dispatch_resolve_result(case.ref, files, err, {
            notify = function() end, open = function() end, picker = function() end,
        })
        assert(action == case.action, case.ref .. " dispatch differs: " .. action)
    end
    print("PASS: real/fake production run_resolve + parse + dispatch: " .. case.ref)
end
'''


def run(argv, **kwargs):
    return subprocess.run(argv, text=True, capture_output=True, timeout=30, **kwargs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdlc", default="sdlc", help="installed resolver executable")
    parser.add_argument("--fake", type=Path, help="alternate fake executable (for negative checks)")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    sdlc = shutil.which(args.sdlc)
    nvim = shutil.which("nvim")
    if not sdlc or not nvim:
        parser.error("installed sdlc and nvim are required for this opt-in check")
    fake = (args.fake or root / "tests/fixtures/fake_sdlc").resolve()
    vocabulary = root / "construct/generated/vocabulary/issue.json"
    discovery = json.loads(vocabulary.read_text())["discovery"]
    with tempfile.TemporaryDirectory(prefix="parley-resolve-conformance-", dir=os.environ.get("TMPDIR") or "/tmp") as scratch:
        scratch = Path(scratch).resolve()
        repo, state = scratch / "repo", scratch / "fake-state"
        repo.mkdir()
        state.mkdir()
        env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
        env.update(HOME=str(scratch / "home"), XDG_CONFIG_HOME=str(scratch / "config"),
                   XDG_DATA_HOME=str(scratch / "data"), XDG_CACHE_HOME=str(scratch / "cache"),
                   XDG_STATE_HOME=str(scratch / "state"), GIT_CONFIG_NOSYSTEM="1",
                   PARLEY_FAKE_SDLC_STATE=str(state), PARLEY_CONFORMANCE_ROOT=str(root))
        (scratch / "home").mkdir()
        initialized = run(["git", "init", "--quiet", str(repo)], env=env)
        assert initialized.returncode == 0, initialized.stderr
        copied = repo / "construct/generated/vocabulary/issue.json"
        copied.parent.mkdir(parents=True)
        shutil.copyfile(vocabulary, copied)

        def artifact(folder, name, kind, milestone=None):
            path = repo / discovery[folder] / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(f"---\nid: {name[:6]}\nstatus: open\n---\n# Resolver fixture\n")
            result = {"path": str(path), "kind": kind}
            if milestone:
                result["milestone"] = milestone
            return result

        sole = artifact("home", "000001-sole.md", "issue")
        issue = artifact("home", "000002-family.md", "issue")
        plan = artifact("plans", "000002-family-plan.md", "plan")
        review = artifact("plans", "000002-family-m1-review.md", "review", "M1")
        cases = [
            {"ref": "#1", "files": [sole], "action": "open"},
            {"ref": "#2", "files": [issue, plan, review], "action": "picker"},
            {"ref": "#2 M1", "files": [review], "action": "open"},
            {"ref": "gh#42", "files": [], "action": "external"},
            {"ref": "#999", "failure": True, "action": "error"},
            {"ref": "#2 M9", "failure": True, "action": "error"},
        ]
        # Seed from independently authored expectations, never from real stdout.
        (state / "resolve.json").write_text(json.dumps({case["ref"]: {"files": case["files"]}
                                                       for case in cases if not case.get("failure")}))
        # Check real and fake failure exit status explicitly, before Lua consumes
        # the same argv through production run_resolve's default vim.system seam.
        for case in cases:
            for command in (sdlc, str(fake)):
                env["PARLEY_FAKE_SDLC_MODE"] = "fail" if case.get("failure") else ""
                result = run([command, "resolve", "--json", case["ref"]], cwd=repo, env=env)
                assert (result.returncode != 0) == bool(case.get("failure")), (
                    f"{command} {case['ref']}: unexpected exit {result.returncode}: {result.stderr}")
        fixture = scratch / "fixture.json"
        fixture.write_text(json.dumps({"repo": str(repo), "sdlc": sdlc, "fake": str(fake), "cases": cases}))
        env["PARLEY_CONFORMANCE_FIXTURE"] = str(fixture)
        lua = scratch / "check.lua"
        lua.write_text("local ok, err = pcall(function()\n" + LUA_CHECK + "\nend)\n"
                       "if not ok then io.stderr:write(tostring(err) .. '\\n'); vim.cmd('cquit 1') end\nvim.cmd('qa!')\n")
        checked = run([nvim, "--headless", "--noplugin", "-n", "-i", "NONE", "-u", "NONE", "-l", str(lua)],
                      cwd=repo, env=env)
        print(checked.stdout, end="")
        print(checked.stderr, end="" if checked.stderr.endswith("\n") else "\n")
        assert checked.returncode == 0, "resolver conformance failed"
        requests = [json.loads(line) for line in (state / "requests.jsonl").read_text().splitlines()]
        expected = [["resolve", "--json", case["ref"]] for case in cases]
        assert requests == expected + expected, "fake received unexpected resolver argv"
        print("sdlc resolver conformance passed (6 cases; offline temporary Git repository)")


if __name__ == "__main__":
    main()
