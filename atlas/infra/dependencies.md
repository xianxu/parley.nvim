# External dependencies

`lua/parley/deps.lua` owns external-tool metadata and display-only install advice.
Its pure `advice(id, host)` and `packages(host, selection)` projections share the
same host/manager policy. The registry groups tools as managed, platform or
advisory; curl additionally retains required severity. Executable alternatives
such as ImageMagick's `magick` and `convert` share one package entry.

`deps_probe.lua` is the thin local observation boundary. It reads uname,
executable availability, and the managed version record. It delegates binary
precedence to `cliproxy.discover_binary`: configured path, managed download,
then PATH. Only the selected managed binary inherits the recorded version.
Discovery computes paths without creating directories; `cliproxy.download`
creates the install directory at its write boundary.

`:checkhealth parley` enumerates this registry, including without setup. It
reports source/version, missing-tool advice, and non-applicable platform tools.
It performs no service probes, package-manager commands, credential reads or
subprocess launches. Existing setup and lualine diagnostics remain separate.

Clipboard and shrink recipes reference dependency ids and obtain advice at
selection time. Their shared `argv_recipe` still owns selection and configured
argv validation. Clipboard missing-tool notices reset at setup, while each paste
rechecks availability so later installation recovers immediately. Shrink retains
its existing configure-owned resolution cache. Exporter's pandoc error and
CLIProxyAPI's missing-binary guidance also derive from the registry.

For #247, `deps.packages({sysname='Darwin', manager='brew'}, 'default')` supplies
ripgrep as the additional formula dependency. Neovim remains the host runtime;
CLIProxyAPI remains Parley-managed. Alternate converters and pandoc are optional;
`'all'` projects the available advisory packages for explicit installation advice.
Formula generation and parity verification belong to #247.

The dependency specs cover host policy, executable/version changes and read-only
health reporting. `tests/arch/dependency_registry_spec.lua` prevents builtin
recipes or package-install command literals from creating a second advice source.
