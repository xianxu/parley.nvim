# Vision Exports

## CSV Export

Generates a CSV spreadsheet with columns: `namespace, project, type, size, need_by, depends_on`.

- `depends_on` values joined with `; ` separator
- CSV-escapes fields containing commas or quotes
- Output via `:ParleyVisionExportCsv [path]` or `<C-j>ec`
- Defaults to `roadmap.csv` at repo root when no path given

## DOT Graph Export

Generates Graphviz DOT format for dependency visualization.

- Node width mapped from size: S=1.0, M=1.5, L=2.2, XL=3.0
- Node color mapped from type: tech=`#a0d8ef` (blue), business=`#ffe0b2` (orange)
- Edges follow `depends_on` relationships
- Optional `--root=node` filters to subgraph (ancestors + descendants)
- Output via `:ParleyVisionExportDot [path] [--root=id]` or `<C-j>ed`
- Defaults to `roadmap.dot` at repo root when no path given
- Render with: `dot -Tsvg output.dot -o output.svg`

## Validation

`:ParleyVisionValidate` (`<C-j>v`) checks:

- All initiatives have names
- No duplicate IDs within or across files
- All `depends_on` references resolve (no dangling refs)
- No ambiguous prefix matches
- No circular dependencies

Errors shown in quickfix list with file/line locations. Circular dependency errors produce one quickfix entry per node in the cycle, each pointing to the specific `depends_on` line. Quickfix is cleared when validation passes.

Modified vision YAML buffers are auto-saved before validation runs.

## Goto Reference

`<C-j>o` jumps to the initiative definition of the `depends_on` ref under the cursor. Works with both multiline and inline list syntax, and handles cross-file jumps.
