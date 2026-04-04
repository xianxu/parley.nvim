# Vision Exports

## CSV Export

Generates a CSV spreadsheet with columns: `namespace, name, type, size, quarter, depends_on`.

- `depends_on` values joined with `; ` separator
- CSV-escapes fields containing commas or quotes
- Output via `:ParleyVisionExportCsv [path]` or `<C-j>ec`

## DOT Graph Export

Generates Graphviz DOT format for dependency visualization.

- Node width mapped from size: S=1.0, M=1.5, L=2.2, XL=3.0
- Node color mapped from type: tech=`#a0d8ef` (blue), business=`#ffe0b2` (orange)
- Edges follow `depends_on` relationships
- Optional `--root=node` filters to subgraph (ancestors + descendants)
- Output via `:ParleyVisionExportDot [path] [--root=id]` or `<C-j>ed`
- Render with: `dot -Tsvg output.dot -o output.svg`

## Validation

`:ParleyVisionValidate` (`<C-j>V`) checks:

- All initiatives have names
- No duplicate IDs within or across files
- All `depends_on` references resolve (no dangling refs)
- No ambiguous prefix matches
- No circular dependencies

Errors shown in quickfix list.
