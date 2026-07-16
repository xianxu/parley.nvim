local finder_scan = require("parley.finder_scan")
local issue_vocabulary = require("parley.issue_vocabulary")
local issues = require("parley.issues")

local M = {}
local INVALID = finder_scan.FAILURE_KIND.invalid_adapter_result

local function failure(kind)
    return { kind = "failure", failure_kind = kind or INVALID }
end

local function copy_list(values)
    local result = {}
    for _, value in ipairs(values or {}) do
        result[#result + 1] = value
    end
    return result
end

local function valid_input(input)
    if type(input) ~= "table"
        or type(input.path) ~= "string"
        or type(input.name) ~= "string"
        or type(input.mtime) ~= "number"
        or type(input.lines) ~= "table"
        or type(input.archived) ~= "boolean"
        or (input.repo_name ~= nil and type(input.repo_name) ~= "string")
        or type(input.identity) ~= "table"
        or type(input.identity.key) ~= "string"
        or type(input.identity.source) ~= "table" then
        return false
    end
    for _, line in ipairs(input.lines) do
        if type(line) ~= "string" then
            return false
        end
    end
    return true
end

M.adapt = function(input)
    if not valid_input(input) then
        return failure()
    end

    local id, slug = input.name:match("^(%d+)%-(.+)%.md$")
    if not id then
        return { kind = "skip" }
    end

    local parsed, frontmatter = pcall(issues.parse_frontmatter, input.lines)
    if not parsed then
        return failure(finder_scan.FAILURE_KIND.parse)
    end
    local titled, title = pcall(
        issues.extract_title,
        input.lines,
        frontmatter and frontmatter.header_end or 0
    )
    if not titled then
        return failure(finder_scan.FAILURE_KIND.parse)
    end

    return {
        kind = "record",
        value = {
            id = id,
            slug = slug,
            title = title,
            status = frontmatter and frontmatter.status or "open",
            deps = copy_list(frontmatter and frontmatter.deps),
            created = frontmatter and frontmatter.created or "",
            updated = frontmatter and frontmatter.updated or "",
            github_issue = frontmatter and frontmatter.github_issue or nil,
            path = input.path,
            mtime = input.mtime,
            archived = input.archived,
            repo_name = input.repo_name,
            identity = input.identity,
        },
    }
end

M.materialize = function(records, options)
    options = options or {}
    local archived = options.archived == true
    local filtered = {}
    for _, record in ipairs(finder_scan.deduplicate(records or {})) do
        if (record.archived == true) == archived then
            filtered[#filtered + 1] = record
        end
    end

    local vocabulary = issue_vocabulary.default()
    return finder_scan.sort(filtered, function(left, right)
        if archived and left.mtime ~= right.mtime then
            return left.mtime < right.mtime
        end
        if not archived then
            local left_rank = vocabulary:sort_rank(left.status)
            local right_rank = vocabulary:sort_rank(right.status)
            if left_rank ~= right_rank then
                return left_rank < right_rank
            end
        end
        if left.id ~= right.id then
            return left.id < right.id
        end
        return left.path < right.path
    end)
end

return M
