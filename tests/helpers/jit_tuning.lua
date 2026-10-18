-- Harness-only VM effects; the allocator/version rule is shared with the editor.
local policy = require("parley.jit_tuning")
local M = { OPTIONS = { "sizemcode=1024", "maxmcode=8192" } }

function M.options(version, arch, os)
    if arch == "arm64" and os == "OSX" and policy.has_mcode_fix(version) then return M.OPTIONS end
end

function M.apply(runtime)
    runtime = runtime or jit
    if not runtime then return end
    if policy.requires_interpreter(runtime.version, runtime.arch, runtime.os) then
        runtime.off()
        return
    end
    local options = M.options(runtime.version, runtime.arch, runtime.os)
    if options then runtime.opt.start(unpack(options)) end
    return options
end

return M
