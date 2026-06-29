local M = {}

M.dir_keys = {
    "repo_chat_dir",
    "repo_note_dir",
    "issues_dir",
    "vision_dir",
    "history_dir",
}

function M.relative_dirs(config)
    config = config or {}
    local dirs = {}
    for _, key in ipairs(M.dir_keys) do
        if config[key] then
            table.insert(dirs, config[key])
        end
    end
    return dirs
end

return M
