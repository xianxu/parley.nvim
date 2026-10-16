-- The chat tree as request context (#233): a submission sees the tree in
-- depth-first pre-order, cut at the exchange being submitted. That is the
-- ancestor path plus every subtree to its left, so an aside a `<M-i>` branch
-- opened is part of every later question's context, in the order the operator
-- read it. Nothing to the right of the cut is included.
--
-- `path_up` and `linearize` take their IO as dependencies (`load`, `resolve`)
-- and are tested with hand-built parses; `io_deps` is the editor's IO.
local M = {}

local MAX_DEPTH = 20

--- The path from the topmost reachable ancestor down to the current file.
--- A parent is on the path only if it lists the child among its branches,
--- which also gives the branch's position. A parent that does not link back,
--- a cycle or the depth cap ends the path there.
--- @param file string absolute path of the current file
--- @param parsed table the current file's parse
--- @param deps { load: fun(abs: string): table|nil, resolve: fun(ref: string, dir: string): string }
--- @return table[] path: { file, parsed, stop_branch? } root first; the last is the current file
function M.path_up(file, parsed, deps)
    local path = { { file = file, parsed = parsed } }
    local seen = { [file] = true }
    local child_file, child = file, parsed
    for _ = 1, MAX_DEPTH do
        if not child.parent_link then break end
        local parent_file = deps.resolve(child.parent_link.path, vim.fn.fnamemodify(child_file, ":h"))
        if seen[parent_file] then break end
        local parent = deps.load(parent_file)
        if not parent then break end
        local parent_dir = vim.fn.fnamemodify(parent_file, ":h")
        local stop
        for index, branch in ipairs(parent.branches or {}) do
            if deps.resolve(branch.path, parent_dir) == child_file then
                stop = index
                break
            end
        end
        if not stop then break end
        table.insert(path, 1, { file = parent_file, parsed = parent, stop_branch = stop })
        seen[parent_file] = true
        child_file, child = parent_file, parent
    end
    return path
end

--- Linearize the tree along `path`, cut at exchange `cut` of the last file.
--- Each file emits its exchanges in order. After exchange k (k = 0 is before
--- the first question), every branch with `after_exchange == k` is emitted as a
--- whole subtree, in line order, until the path's branch (descend) or the cut.
--- The cut exchange is the last item; branches hanging off it are after the cut.
--- @param path table[] from path_up
--- @param cut integer the current file's exchange being submitted
--- @param deps { load, resolve } as for path_up
--- An item from a subtree hanging off the current file carries `anchor`: the
--- current file's exchange it hangs after (0 = before the first question) and
--- the row of its branch reference, so a request that leaves that exchange out
--- can leave its asides out too. Every item from a subtree is `off_path`: an
--- aside, or a chat nested under one, rather than a file on the path (#352).
--- @return table[] items: { exchange, file, current, anchor?, off_path? }
function M.linearize(path, cut, deps)
    local items, seen = {}, {}
    for _, node in ipairs(path) do seen[node.file] = true end
    local emit

    local function subtree(branch, from_file, depth, anchor)
        if depth > MAX_DEPTH then return end
        local file = deps.resolve(branch.path, vim.fn.fnamemodify(from_file, ":h"))
        if seen[file] then return end
        seen[file] = true
        local parsed = deps.load(file)
        if parsed then emit(file, parsed, false, nil, depth, anchor, true) end
    end

    -- `stop` is { branch = i } (descend at the path's branch) or { cut = n }.
    emit = function(file, parsed, current, stop, depth, anchor, off_path)
        local exchanges, branches = parsed.exchanges or {}, parsed.branches or {}
        for k = 0, #exchanges do
            if k >= 1 then
                items[#items + 1] = { exchange = exchanges[k], file = file, current = current, anchor = anchor,
                    off_path = off_path }
                if stop and stop.cut == k then return end
            end
            for index, branch in ipairs(branches) do
                if branch.after_exchange == k then
                    if stop and stop.branch == index then return end
                    subtree(branch, file, depth + 1, anchor or (current and { exchange = k, line = branch.line }) or nil)
                end
            end
        end
    end

    for i, node in ipairs(path) do
        local last = i == #path
        emit(node.file, node.parsed, last, last and { cut = cut } or { branch = node.stop_branch }, 0)
    end
    return items
end

--- The root of `file`'s tree: the first file of its path_up. A file that
--- cannot be loaded is its own root. Every command that acts on a whole tree
--- starts here (#349), so the tree is the one the request context sees.
--- @param file string absolute, resolved path
--- @param deps { load, resolve } as for path_up
--- @return string root
function M.root(file, deps)
    local parsed = deps.load(file)
    if not parsed then return file end
    return M.path_up(file, parsed, deps)[1].file
end

--- Every file of the tree under `root`, in depth-first pre-order: a file, then
--- each of its branches in line order. A file reached twice is listed once; an
--- unloadable file is skipped with its subtree; depth is capped.
--- @param root string absolute, resolved path
--- @param deps { load, resolve } as for path_up
--- @return table[] files: { file, parsed }
function M.files(root, deps)
    local out, seen = {}, {}
    local function visit(file, depth)
        if depth > MAX_DEPTH or seen[file] then return end
        seen[file] = true
        local parsed = deps.load(file)
        if not parsed then return end
        out[#out + 1] = { file = file, parsed = parsed }
        local dir = vim.fn.fnamemodify(file, ":h")
        for _, branch in ipairs(parsed.branches or {}) do visit(deps.resolve(branch.path, dir), depth + 1) end
    end
    visit(root, 0)
    return out
end

--- The files' saved state: commands that act on the files themselves (delete,
--- move, export, the outline, which renders from disk) see the tree as it is
--- on disk, not as an unsaved buffer has it.
function M.disk_deps()
    local parley = require("parley")
    return {
        resolve = function(ref, dir) return parley.resolve_chat_path(ref, dir) end,
        load = function(file)
            if vim.fn.filereadable(file) == 0 then return nil end
            local lines = vim.fn.readfile(file)
            local header_end = parley.chat_parser.find_header_end(lines)
            return header_end and parley.parse_chat(lines, header_end) or nil
        end,
    }
end

--- The editor's IO: files are read from their loaded buffer when there is one
--- (ahead of the disk while an answer streams or edits are unsaved), and an
--- exchange still being regenerated contributes its previous answer.
function M.io_deps()
    local parley = require("parley")
    return {
        resolve = function(ref, dir) return parley.resolve_chat_path(ref, dir) end,
        load = function(file)
            local lines, buf = parley.helpers.chat_lines(file)
            if not lines then
                parley.logger.debug("chat_tree: not readable: " .. file)
                return nil
            end
            local header_end = parley.chat_parser.find_header_end(lines)
            if not header_end then return nil end
            local parsed = parley.parse_chat(lines, header_end)
            local doc = buf and require("parley.document").get(buf)
            if doc then
                parsed = require("parley.previous_answer").substitute(parsed,
                    require("parley.document").previous_answers(doc), nil)
            end
            return parsed
        end,
    }
end

return M
