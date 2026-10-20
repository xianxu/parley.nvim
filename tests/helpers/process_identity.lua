-- A process's identity that survives reparenting (#402): its start time. A pid
-- alone can be reused by an unrelated process once the original exits, so a
-- signal sent later is guarded by pid and start time together. Read in-process
-- (no `ps`, which sandboxes deny), and safe in a libuv callback (no vim.fn).
local M = {}

local ffi = require("ffi")
local darwin = ffi.os == "OSX"

if darwin then
    pcall(ffi.cdef, [[
        typedef struct {
            uint32_t pbi_flags, pbi_status, pbi_xstatus, pbi_pid, pbi_ppid;
            uint32_t pbi_uid, pbi_gid, pbi_ruid, pbi_rgid, pbi_svuid, pbi_svgid, rfu_1;
            char pbi_comm[16]; char pbi_name[32];
            uint32_t pbi_nfiles, pbi_pgid, pbi_pjobc, e_tdev, e_tpgid; int32_t pbi_nice;
            uint64_t pbi_start_tvsec, pbi_start_tvusec;
        } parley_proc_bsdinfo;
        int proc_pidinfo(int pid, int flavor, uint64_t arg, void *buffer, int buffersize);
    ]])
end

local PROC_PIDTBSDINFO = 3

--- The start time of `pid` as an opaque string, or nil when no such process
--- exists or the platform can't say.
--- @param pid integer
--- @return string|nil
function M.start_time(pid)
    if type(pid) ~= "number" or pid <= 0 then return nil end
    if darwin then
        local info = ffi.new("parley_proc_bsdinfo")
        if ffi.C.proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, info, ffi.sizeof(info)) ~= ffi.sizeof(info) then return nil end
        return ("%d.%06d"):format(tonumber(info.pbi_start_tvsec), tonumber(info.pbi_start_tvusec))
    end
    -- Linux: field 22 of /proc/<pid>/stat, counted after the parenthesized name.
    local file = io.open("/proc/" .. pid .. "/stat", "r")
    if not file then return nil end
    local stat = file:read("*a")
    file:close()
    local rest = stat and stat:match("%)%s+(.*)$")
    if not rest then return nil end
    local fields = {}
    for field in rest:gmatch("%S+") do fields[#fields + 1] = field end
    return fields[20] -- field 22 overall; the name and pid precede `rest`
end

return M
