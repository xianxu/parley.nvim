# Vision Exports

## CSV Export

Generates a CSV spreadsheet with columns: `namespace, project, type, size, need_by, depends_on`.

- `depends_on` values joined with `; ` separator
- CSV-escapes fields containing commas or quotes
- Output via `:ParleyVisionExportCsv [path]` or `<C-j>ec`
- Defaults to `roadmap.csv` at repo root when no path given

## DOT Graph Export

Generates Graphviz DOT format for dependency visualization.

- Node width scales linearly with size in months (1.5 + months × 0.4 inches); T-shirt sizes use legacy fixed widths as fallback
- Completion shown as striped fill (done color / base color ratio) — tech=blue, business=orange
- Label includes size in months and completion percentage when > 0%
- Edges follow `depends_on` relationships
- Optional `--root=node` filters to subgraph (ancestors + descendants)
- Optional `--quarter=25Q3` filters to projects with non-zero charge in that quarter
- Output via `:ParleyVisionExportDot [path] [--root=id]` or `<C-j>ed`
- Defaults to `roadmap.dot` at repo root when no path given
- Render with: `dot -Tsvg output.dot -o output.svg`

## Validation

`:ParleyVisionValidate` (`<C-j>v`) checks:

- All items are either projects or persons (with names)
- No duplicate project IDs within or across files
- All `depends_on` references resolve (no dangling refs)
- No ambiguous prefix matches
- No circular dependencies
- Person `capacity` format valid (e.g. `11w`)
- Project `size` format valid (`3m` or S/M/L/XL)
- `completion` in range 0-100
- `start_by` / `need_by` format valid (`25Q3` or `25M6`)
- Warning when `need_by` is before `start_by`

Errors shown in quickfix list with file/line locations. Circular dependency errors produce one quickfix entry per node in the cycle, each pointing to the specific `depends_on` line. Quickfix is cleared when validation passes.

Modified vision YAML buffers are auto-saved before validation runs.

## Allocation Report

`:ParleyVisionAllocation [--quarter=25Q3]` shows a per-namespace breakdown of team capacity vs project demand.

- Groups persons and projects by namespace (YAML filename)
- Calculates quarterly charge per project based on size, completion, start_by/need_by range
- Shows capacity (sum of person weeks), demand (sum of project charges converted to weeks), and balance
- Over-committed teams flagged with warning
- Opens in a scratch buffer
- Quarter auto-detected from latest quarterly folder if not specified

## Goto Reference

`<C-j>o` jumps to the initiative definition of the `depends_on` ref under the cursor. Works with both multiline and inline list syntax, and handles cross-file jumps.
