-- Outline module for Parley.nvim
-- Provides navigation through chat messages and markdown headers

local M = {}

local highlight_structure = require("parley.highlight_structure")

-- Code-block memo for a buffer. Delegates to highlight_structure so the fence
-- grammar and the #218 partition containment have ONE definition — outline used
-- to carry three independent copies of this loop, and the close review found the
-- bug still live in the one that had been missed.
--
-- `config` is REQUIRED: patterns() without it uses default prefixes, which
-- silently disables containment for anyone who set chat_user_prefix.
local function build_code_block_memo(bufnr, config)
  local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  return highlight_structure.code_block_memo(
    all_lines, highlight_structure.patterns(config), true)
end

local function is_in_code_block(_bufnr, line_number, memo)
  return memo[line_number] or false
end

local function is_outline_item(bufnr, line_number, config, code_block_memo, all_lines, opts)
  opts = opts or {}
  -- Get the line content (use pre-fetched lines if available)
  local line = all_lines and all_lines[line_number]
    or vim.api.nvim_buf_get_lines(bufnr, line_number - 1, line_number, false)[1] or ""

  -- Skip lines in code blocks
  if is_in_code_block(bufnr, line_number, code_block_memo) then
    return false, nil, nil
  end

  -- Check different types of outline items
  local user_prefix = config.chat_user_prefix

  -- Match questions (using configured user prefix)
  if line:match("^" .. vim.pesc(user_prefix)) then
    return true, "question", "  " .. line
  -- Match annotations
  elseif line:match("^@@.+@@$") then
    return true, "annotation", "→ " .. string.sub(line, 2, -2)
  -- Match branch references
  elseif line:match("^" .. vim.pesc(config.chat_branch_prefix or "🌿:")) then
    return true, "branch", "🌿 " .. line
  -- Match markdown headings — only for non-chat markdown files
  elseif not opts.is_chat then
    if line:match("^### ") then
      return true, "heading", "      " .. line
    elseif line:match("^## ") then
      return true, "heading", "    " .. line
    elseif line:match("^# ") then
      return true, "heading", "  " .. line
    end
  end

  -- Not an outline item
  return false, nil, nil
end

-- Expose helpers for testing (follows dispatcher._extract_sse_content convention)
M._is_in_code_block = is_in_code_block
M._is_outline_item = is_outline_item

local function find_nearest_outline_line(target_buf, lnum, config)
  local line_count = vim.api.nvim_buf_line_count(target_buf)
  local safe_lnum = math.min(lnum, line_count)
  local all_lines = vim.api.nvim_buf_get_lines(target_buf, 0, -1, false)
  local code_block_memo = build_code_block_memo(target_buf, config)
  local is_valid_line = is_outline_item(target_buf, safe_lnum, config, code_block_memo, all_lines)

  if is_valid_line then
    return safe_lnum
  end

  for offset = 1, 5 do
    local previous_lnum = safe_lnum - offset
    if previous_lnum > 0 then
      local previous_is_item = is_outline_item(target_buf, previous_lnum, config, code_block_memo, all_lines)
      if previous_is_item then
        return previous_lnum
      end
    end

    local next_lnum = safe_lnum + offset
    if next_lnum <= line_count then
      local next_is_item = is_outline_item(target_buf, next_lnum, config, code_block_memo, all_lines)
      if next_is_item then
        return next_lnum
      end
    end
  end

  return safe_lnum
end

local function focus_buffer_line(target_buf, target_name, preferred_windows, lnum)
  for _, win in ipairs(preferred_windows or {}) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == target_buf then
      vim.api.nvim_set_current_win(win)
      vim.api.nvim_win_set_cursor(win, { lnum, 0 })
      vim.cmd("normal! zz")
      return true
    end
  end

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == target_buf then
      vim.api.nvim_set_current_win(win)
      vim.api.nvim_win_set_cursor(win, { lnum, 0 })
      vim.cmd("normal! zz")
      return true
    end
  end

  local function safe_set_cursor(safe_lnum)
    local line_count = vim.api.nvim_buf_line_count(vim.api.nvim_get_current_buf())
    local clamped = math.max(1, math.min(safe_lnum, line_count))
    vim.api.nvim_win_set_cursor(0, { clamped, 0 })
    vim.cmd("normal! zz")
  end

  if vim.fn.filereadable(target_name) == 1 then
    vim.cmd("edit " .. vim.fn.fnameescape(target_name))
    safe_set_cursor(lnum)
    return true
  end

  if vim.api.nvim_buf_is_valid(target_buf) then
    vim.cmd("buffer " .. target_buf)
    safe_set_cursor(lnum)
    return true
  end

  return false
end

local function jump_to_outline_location(selection, config)
  local target_buf = selection.bufnr
  local target_name = selection.name

  if not vim.api.nvim_buf_is_valid(target_buf) then
    vim.notify("Buffer " .. target_buf .. " is no longer valid - cannot navigate", vim.log.levels.ERROR)
    return false
  end

  local safe_lnum = find_nearest_outline_line(target_buf, selection.lnum or 1, config)
  local focused = focus_buffer_line(target_buf, target_name, selection.windows, safe_lnum)
  if not focused then
    vim.notify("Could not navigate to outline selection", vim.log.levels.WARN)
    return false
  end

  local hl_buf = vim.api.nvim_get_current_buf()
  local line_count = vim.api.nvim_buf_line_count(hl_buf)
  if safe_lnum >= 1 and safe_lnum <= line_count then
    local ns_id = vim.api.nvim_create_namespace("ParleyOutline")
    vim.api.nvim_buf_clear_namespace(hl_buf, ns_id, 0, -1)
    vim.api.nvim_buf_add_highlight(hl_buf, ns_id, "DiffAdd", safe_lnum - 1, 0, -1)
    vim.defer_fn(function()
      if vim.api.nvim_buf_is_valid(hl_buf) then
        vim.api.nvim_buf_clear_namespace(hl_buf, ns_id, 0, -1)
      end
    end, 1000)
  end

  return true, safe_lnum
end

M._jump_to_outline_location = jump_to_outline_location

-- Build the list of picker items from a buffer. Exposed for testing.
-- Returns items in document order: { display: string, value: { lnum: number } }
function M._build_picker_items(bufnr, config, opts)
  local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local code_block_memo = build_code_block_memo(bufnr, config)
  local items = {}
  for i = 1, #all_lines do
    local is_item, item_type, formatted_line = is_outline_item(bufnr, i, config, code_block_memo, all_lines, opts)
    if is_item then
      table.insert(items, { display = formatted_line, value = { lnum = i }, type = item_type })
    end
  end
  -- Drop trailing empty question (the placeholder prompt for the user to continue)
  if #items > 0 then
    local last = items[#items]
    if last.type == "question" then
      local line = all_lines[last.value.lnum] or ""
      local after_prefix = line:sub(#config.chat_user_prefix + 1)
      if after_prefix:match("^%s*$") then
        table.remove(items)
      end
    end
  end
  return items
end

--------------------------------------------------------------------------------
-- Tree-aware outline: recursively build outline items across 🌿: linked files
--------------------------------------------------------------------------------

-- Walk parent_link chain to find the tree root file path.
-- Returns absolute path of root.
local function find_tree_root(file_path, config, depth)
  depth = depth or 0
  if depth > 20 then return file_path end

  local abs_path = require("parley.helper").abs_path(file_path)
  if vim.fn.filereadable(abs_path) == 0 then return abs_path end

  local lines = vim.fn.readfile(abs_path)
  local chat_parser = require("parley.chat_parser")
  local header_end = chat_parser.find_header_end(lines)
  if not header_end then return abs_path end

  local parsed = chat_parser.parse_chat(lines, header_end, config)
  if not parsed.parent_link then return abs_path end

  local parent_dir = vim.fn.fnamemodify(abs_path, ":h")
  -- THE resolver (#224). #225 C3 merged this module's private resolver with
  -- chat_respond's byte-identical copy — correctly by ARCH-DRY, and onto the
  -- NAIVE one. A renamed parent then made find_tree_root return the CHILD as
  -- tree root, so <M-t> never reached the parent. A DRY consolidation has to
  -- pick the more-correct implementation as the survivor.
  local parent_abs = require("parley").resolve_chat_path(parsed.parent_link.path, parent_dir)
  if vim.fn.filereadable(parent_abs) == 0 then return abs_path end

  return find_tree_root(parent_abs, config, depth + 1)
end

-- Build outline items for a single file at a given depth.
-- Returns array of { display, value: { lnum, file, child_path? } }
-- child_path is set on 🌿: items — the resolved absolute path of the child file.
local function build_file_outline_items(file_path, config, depth)
  local abs_path = require("parley.helper").abs_path(file_path)
  if vim.fn.filereadable(abs_path) == 0 then return {} end

  local file_lines = vim.fn.readfile(abs_path)
  local chat_parser = require("parley.chat_parser")
  local header_end = chat_parser.find_header_end(file_lines)
  if not header_end then return {} end

  local parsed = chat_parser.parse_chat(file_lines, header_end, config)
  local indent = string.rep("  ", depth)
  local items = {}
  local file_dir = vim.fn.fnamemodify(abs_path, ":h")

  -- Map line_number -> branch for interleaving
  local branch_at_line = {}
  for _, branch in ipairs(parsed.branches) do
    branch_at_line[branch.line] = branch
  end

  -- Code block memo — the SAME helper the buffer paths use. This third copy is
  -- the one #218 originally missed: the tree picker still exhibited the bug
  -- after the other two were fixed (BR-1).
  local code_memo = highlight_structure.code_block_memo(
    file_lines, highlight_structure.patterns(config), true)

  local user_prefix = config.chat_user_prefix
  for i = header_end + 1, #file_lines do
    local line = file_lines[i]
    local branch = branch_at_line[i]

    if branch then
      -- Resolved ONCE. Under prefix identity each resolve is a glob per chat
      -- root, so the old shape paid double on every untopiced branch — on a
      -- keystroke path (ARCH-CONSTRAINTS, ARCH-DRY).
      local child_abs = require("parley").resolve_chat_path(branch.path, file_dir)
      local topic = branch.topic
      if topic == "" then
        topic = require("parley").get_chat_topic(child_abs) or branch.path
      end
      local branch_indent = branch.inline and (indent .. "    ") or (indent .. "  ")
      table.insert(items, {
        display = branch_indent .. "🌿 " .. topic,
        value = { lnum = branch.line, file = abs_path, child_path = child_abs, inline = branch.inline },
      })
    elseif not code_memo[i] then
      if line:match("^" .. vim.pesc(user_prefix)) then
        table.insert(items, {
          display = indent .. "  " .. line,
          value = { lnum = i, file = abs_path },
          type = "question",
        })
      end
    end
  end

  -- Drop trailing empty question (the placeholder prompt for the user to continue)
  if #items > 0 then
    local last = items[#items]
    if last.type == "question" then
      local line = file_lines[last.value.lnum] or ""
      local after_prefix = line:sub(#user_prefix + 1)
      if after_prefix:match("^%s*$") then
        table.remove(items)
      end
    end
  end

  return items
end

-- Build tree outline with expand/collapse state.
-- expanded_set: table of abs_path -> true for files whose children should be shown
-- Returns flat item list with proper interleaving and indentation.
-- Test seam (#224): the UPWARD walk. `_build_tree_outline_items` builds
-- downward from the path it is handed, so a test that drives it can never see
-- a broken parent lookup — which is how the <M-t> claim shipped unbacked.
M._find_tree_root = find_tree_root

function M._build_tree_outline_items(root_path, config, expanded_set, depth, visited)
  depth = depth or 0
  visited = visited or {}
  -- nil expanded_set = expand all; do NOT default to {}

  local abs_path = require("parley.helper").abs_path(root_path)
  if visited[abs_path] then return {} end
  visited[abs_path] = true

  -- Get the topic for the root-level header
  local items = {}
  if depth == 0 then
    local parley = require("parley")
    local topic = parley.get_chat_topic(abs_path) or vim.fn.fnamemodify(abs_path, ":t")
    table.insert(items, {
      display = "📋 " .. topic,
      value = { lnum = 1, file = abs_path },
    })
  end

  -- Build this file's items
  local file_items = build_file_outline_items(abs_path, config, depth)

  for _, item in ipairs(file_items) do
    table.insert(items, item)
    -- If this is a branch item and it's expanded (nil = expand all), recurse
    if item.value.child_path and (not expanded_set or expanded_set[item.value.child_path]) then
      local child_depth = item.value.inline and (depth + 2) or (depth + 1)
      local child_items = M._build_tree_outline_items(
        item.value.child_path, config, expanded_set, child_depth, visited
      )
      for _, ci in ipairs(child_items) do
        table.insert(items, ci)
      end
    end
  end

  return items
end

-- Create a floating picker to navigate questions and headings in the current buffer
function M.question_picker(config)
  local float_picker = require("parley.float_picker")

  -- Get the current buffer and filename
  local current_bufnr = vim.api.nvim_get_current_buf()
  local buf_name = vim.api.nvim_buf_get_name(current_bufnr)

  -- Ensure buffer is saved to disk to reflect latest changes
  local modified = vim.api.nvim_buf_get_option(current_bufnr, 'modified')
  if modified then
    vim.cmd('silent! write')
  end

  -- Capture windows showing the target buffer before the picker opens
  local target_windows = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == current_bufnr then
      table.insert(target_windows, win)
    end
  end

  local parley = require("parley")
  local is_chat = not parley.not_chat(current_bufnr, buf_name)

  if not is_chat then
    -- Non-chat: use flat outline (include markdown headings)
    local items = M._build_picker_items(current_bufnr, config, { is_chat = false })
    local keybindings_key = require("parley.keybinding_registry").key_for("help", parley.config)
    float_picker.open({
      title = "Outline",
      items = items,
      anchor = "top",
      on_select = function(item)
        if not vim.api.nvim_buf_is_valid(current_bufnr) then return end
        jump_to_outline_location({
          bufnr = current_bufnr,
          name = buf_name,
          windows = target_windows,
          lnum = item.value.lnum,
        }, config)
      end,
      mappings = {
        {
          key = keybindings_key,
          fn = function(_, _)
            vim.schedule(function()
              parley.cmd.KeyBindings()
            end)
          end,
        },
      },
    })
    return
  end

  -- Chat file: build tree outline with expand/collapse
  local root = find_tree_root(buf_name, config)
  -- Start fully expanded (nil = expand all); toggling a branch sets it to a table
  local expanded_set = nil

  -- Recursive picker: opens, handles expand/collapse, reopens on toggle
  local function open_tree_picker(sel_index)
    local items = M._build_tree_outline_items(root, config, expanded_set)
    if #items == 0 then
      items = M._build_picker_items(current_bufnr, config, { is_chat = true })
    end

    local keybindings_key = require("parley.keybinding_registry").key_for("help", parley.config)
    float_picker.open({
      title = "🌳 Chat Tree Outline",
      items = items,
      anchor = "top",
      initial_index = sel_index or 1,
      on_select = function(item)
        local entry = item.value
        do
          local target_file = entry.file or buf_name
          local target_buf = vim.fn.bufnr(target_file)
          jump_to_outline_location({
            bufnr = target_buf ~= -1 and target_buf or current_bufnr,
            name = target_file,
            windows = target_windows,
            lnum = entry.lnum,
          }, config)
        end
      end,
      mappings = {
        {
          key = keybindings_key,
          fn = function(_, _)
            vim.schedule(function()
              parley.cmd.KeyBindings()
            end)
          end,
        },
      },
    })
  end

  open_tree_picker()
end

return M
