#!/usr/bin/env python3
"""Read YAML from stdin, emit JSON to stdout. Used by parley's raw input
feature to parse a `yaml {"type":"request"}` fence into a Lua table.

Exits 0 on success, non-zero on parse error (with the error on stderr).
Requires PyYAML; failure prints a clear hint.
"""
import json
import sys


def main():
    try:
        import yaml  # type: ignore
    except ImportError:
        print(
            "yaml_to_json: PyYAML is not installed. "
            "Install with: pip install pyyaml (or your package manager).",
            file=sys.stderr,
        )
        sys.exit(2)

    try:
        data = yaml.safe_load(sys.stdin)
    except yaml.YAMLError as exc:
        print(f"yaml_to_json: parse error: {exc}", file=sys.stderr)
        sys.exit(1)

    json.dump(data, sys.stdout)


if __name__ == "__main__":
    main()
