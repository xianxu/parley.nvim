#!/usr/bin/env python3
"""Reject personal configuration markers in the portable starter sources."""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
FILES = ("packaging/starter-config/init.lua", "lua/parley/starter_config.lua")
PERSONAL = re.compile(
    r"/Users/|/home/[^/\s]+/|Mobile Documents|com~apple~CloudDocs|~/blogs"
    r"|(?:OPENAI|ANTHROPIC|GOOGLEAI)_API_KEY|GITHUB_TOKEN"
    r"|require\s*\(?\s*['\"](?:core|helpers)\."
    r"|[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}"
)


def main(paths):
    failures = []
    for path in paths:
        for number, line in enumerate(path.read_text().splitlines(), 1):
            if PERSONAL.search(line):
                failures.append(f"{path}:{number}: personal configuration marker")
    if failures:
        print("\n".join(failures), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main([pathlib.Path(p) for p in sys.argv[1:]] or [ROOT / p for p in FILES]))
