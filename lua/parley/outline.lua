-- Outline module for Parley.nvim
-- Provides navigation through chat messages and markdown headers

local M = {}

local highlight_structure = require("parley.highlight_structure")
local question_tags = require("parley.question_tags")
local markdown_heading = require("parley.markdown_heading")

local Document = require("parley.document")
local Reader = require("parley.line_reader")
local cursors = setmetatable({}, {__mode="k"})
local function document(buf,config)
  return Document.get(buf) or Document.attach(buf,{patterns=highlight_structure.patterns(config)})
end
local function label(buf,row)
  local result=Reader.for_buffer(buf):chunk({row=row,col=0,max_bytes=4096})
  return result.bytes .. (result.eol and "" or "…"),result.eol
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
  elseif question_tags.parse_tag(line) then
    -- Both delimiters are two characters: `@@my note@@` → `  → my note` (#232;
    -- the old 2,-2 slice left one `@` on each side). Indented like a question:
    -- an annotation is a navigation entry at the conversation's own level, not
    -- a heading above it (operator, 2026-09-12).
    return true, "annotation", "  → " .. question_tags.parse_tag(line)
  -- Match branch references
  elseif line:match("^" .. vim.pesc(config.chat_branch_prefix or "🌿:")) then
    return true, "branch", "🌿 " .. line
  -- Match markdown headings — only for non-chat markdown files
  elseif not opts.is_chat then
    -- The dialect itself lives in markdown_heading (ARCH-DRY) -- this used to
    -- be a third copy of it. The indent ladder is unchanged: 2/4/6 spaces for
    -- levels 1/2/3, which is exactly two spaces per level.
    local level = markdown_heading.level(line)
    if level then
      return true, "heading", ("  "):rep(level) .. line
    end
  end

  -- Not an outline item
  return false, nil, nil
end

-- Expose helpers for testing (follows dispatcher._extract_sse_content convention)
M._is_in_code_block = is_in_code_block
M._is_outline_item = is_outline_item

local function find_nearest_outline_line(target_buf, lnum, config, is_chat)
  local doc=document(target_buf,config)
  local count=Document.size(doc).rows
  local safe=math.max(1,math.min(lnum,count))
  local first,last=math.max(0,safe-6),math.min(count,safe+5)
  local best,distance=nil,6
  for _=1,11 do
    local found=Document.outline(doc,first,last,{is_chat=is_chat,budget_nodes=2048,budget_entries=4096})
    if found.status~="found" then break end
    local row=found.span.start_row+1
    local delta=math.abs(row-safe)
    if delta<distance then best,distance=row,delta end
    first=found.span.end_row
    if first>=last then break end
  end
  return best
end
M._nearest_outline_line=find_nearest_outline_line

local function focus_buffer_line(target_buf, target_name, preferred_windows, lnum, validate)
  local function place_cursor(win)
    if vim.api.nvim_win_get_buf(win)~=target_buf then return false end
    local current=lnum
    if validate then current=validate() end
    if validate and not current then return false end
    vim.api.nvim_win_set_cursor(win, { current, 0 })
    vim.cmd("normal! zz")
    return true
  end
  for _, win in ipairs(preferred_windows or {}) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == target_buf then
      vim.api.nvim_set_current_win(win)
      return place_cursor(win)
    end
  end

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == target_buf then
      vim.api.nvim_set_current_win(win)
      return place_cursor(win)
    end
  end

  if vim.fn.filereadable(target_name) == 1 then
    vim.cmd("edit " .. vim.fn.fnameescape(target_name))
    return place_cursor(0)
  end

  if vim.api.nvim_buf_is_valid(target_buf) then
    vim.cmd("buffer " .. target_buf)
    return place_cursor(0)
  end

  return false
end

local function jump_to_outline_location(selection, config)
  local target_buf = selection.bufnr
  local target_name = selection.name

  if not vim.api.nvim_buf_is_valid(target_buf) or not vim.api.nvim_buf_is_loaded(target_buf) then
    vim.notify("Buffer " .. target_buf .. " is no longer valid - cannot navigate", vim.log.levels.ERROR)
    return false
  end

  local function resolve_location()
    if not vim.api.nvim_buf_is_valid(target_buf) or not vim.api.nvim_buf_is_loaded(target_buf) then return nil end
    local doc=document(target_buf,config)
    local live=selection.identity and Document.lookup(doc,selection.identity)
    local safe_lnum
    if selection.identity then
      -- Identity proves location only. Context can invalidate a surviving row or
      -- reclassify it without replacing its handle.
      local current=live and Document.outline(doc,live.start_row,live.end_row,
        {is_chat=selection.is_chat,budget_nodes=2048,budget_entries=4096})
      if not current or current.status~="found" or current.span.handle~=selection.identity then
        vim.notify("Outline item is no longer eligible or is awaiting repair",vim.log.levels.WARN)
        return nil
      end
      safe_lnum=live.start_row+1
    elseif selection.exact then
      local row=math.max(0,(selection.lnum or 1)-1)
      if row>=Document.size(doc).rows then return nil end
      local current=Document.outline(doc,row,row+1,
        {is_chat=selection.is_chat,budget_nodes=2048,budget_entries=4096})
      if current.status~="found" or current.span.start_row~=row then
        vim.notify("Outline item is no longer eligible or is awaiting repair",vim.log.levels.WARN)
        return nil
      end
      if selection.source_bound then
        local text,complete=label(target_buf,row)
        if not selection.expected_line or not complete or text~=selection.expected_line then
          vim.notify("Outline source changed; reopen the outline",vim.log.levels.WARN)
          return nil
        end
      end
      safe_lnum=row+1
    else
      safe_lnum=find_nearest_outline_line(target_buf,selection.lnum or 1,config,selection.is_chat)
      if not safe_lnum then
        vim.notify("Outline location is unavailable or is awaiting repair",vim.log.levels.WARN)
        return nil
      end
    end
    return safe_lnum
  end
  local safe_lnum=resolve_location()
  if not safe_lnum then return false end
  local focused=focus_buffer_line(target_buf,target_name,selection.windows,safe_lnum,function()
    -- Window/buffer entry can run user autocommands. Check the projection
    -- again after that boundary, immediately before placing the cursor.
    safe_lnum=resolve_location()
    return safe_lnum
  end)
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

-- One page visits at most eight candidates and reads at most 4 KiB per label.
-- The cursor retains only progress and a possible trailing empty question.
function M._build_picker_items(bufnr, config, opts)
  opts=opts or {}
  local doc=document(bufnr,config)
  local tick=vim.api.nvim_buf_get_changedtick(bufnr)
  local saved=opts.cursor and cursors[opts.cursor]
  if opts.cursor and (not saved or saved.doc~=doc or saved.tick~=tick) then
    return {},{status="stale"}
  end
  local state=saved or {doc=doc,tick=tick,next=0,last=Document.size(doc).rows}
  local items={}
  local function pause(status)
    local key={};cursors[key]=state
    return items,{status=status,cursor=key}
  end
  for _=1,8 do
    if #items+(state.pending and 2 or 1)>8 then return pause("more") end
    if state.next>=state.last then return items,{status="ready"} end
    local found=Document.outline(doc,state.next,state.last,{is_chat=opts.is_chat,
      cursor=state.query,budget_nodes=2048,budget_entries=4096})
    state.query=found.status=="budget" and found.cursor or nil
    if found.status=="not_found" then return items,{status="ready"} end
    if found.status~="found" then return pause(found.status) end
    local row=found.span
    state.next=row.end_row
    local metadata=row.metadata or {}
    local token,sem=metadata.token or {},metadata.semantic or {}
    local text,complete=label(bufnr,row.start_row)
    local item={value={lnum=row.start_row+1,identity=row.handle}}
    local tag=token.preface_tag and question_tags.parse_tag(text)
    if token.kind=="user" then
      item.type="question";item.display="  "..text
      if sem.preface_origin then
        local preface=Document.lookup(doc,sem.preface_origin)
        if preface then
          local content=label(bufnr,preface.start_row)
          local attached=question_tags.parse_tag(content) or content:sub(3)
          if attached=="_" then item=nil
          else item.display="  "..attached;item.value.tag_lnum=preface.start_row+1 end
        end
      end
    elseif token.preface_tag then
      if sem.preface or tag=="_" then item=nil
      else item.type="annotation";item.display="  → "..(tag or text:sub(3)) end
    elseif token.kind=="branch" then item.type="branch";item.display="🌿 "..text
    elseif token.heading_level and token.heading_level<=markdown_heading.MAX_LEVEL then
      item.type="heading";item.display=string.rep("  ",token.heading_level)..text
    else item=nil end
    if item then
      if state.pending then items[#items+1]=state.pending;state.pending=nil end
      local empty=item.type=="question" and complete and text:sub(#config.chat_user_prefix+1):match("^%s*$")
      if empty then state.pending=item else items[#items+1]=item end
    end
  end
  return pause("more")
end

local function load_live_items(buf,config,opts,done)
  local items,cursor={},nil
  local unsubscribe
  local pump,stopped=nil,false
  local doc=document(buf,config)
  local function stop()
    stopped=true
    if pump then pump:close() end
    if unsubscribe then unsubscribe() end
  end
  local function step()
    if stopped then return end
    if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf)
      or Document.get(buf)~=doc then stop();return end
    local page,result=M._build_picker_items(buf,config,{is_chat=opts.is_chat,cursor=cursor})
    if result.status=="stale" then items,cursor={},nil
    else vim.list_extend(items,page);cursor=result.cursor end
    if result.status=="ready" then
      stop()
      done(items);return
    end
    return result.status~="opaque"
  end
  pump=require("parley.deferred_work").new(step)
  unsubscribe=Document.subscribe(doc,function(event)
    if event.kind=="detach" then stop()
    elseif not stopped then pump:request() end
  end)
  pump:request()
end
M._load_live_items=load_live_items

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

  -- Keep every branch at a source line, in parser (left-to-right) order.
  local branch_at_line = {}
  for _, branch in ipairs(parsed.branches) do
    branch_at_line[branch.line] = branch_at_line[branch.line] or {}
    table.insert(branch_at_line[branch.line], branch)
  end

  -- Code block memo — the SAME helper the buffer paths use. This third copy is
  -- the one #218 originally missed: the tree picker still exhibited the bug
  -- after the other two were fixed (BR-1).
  local code_memo = highlight_structure.code_block_memo(
    file_lines, highlight_structure.patterns(config), true)

  local user_prefix = config.chat_user_prefix
  for i = header_end + 1, #file_lines do
    local branches = branch_at_line[i]

    -- Classify once. A question containing inline branches still owns a
    -- question row, so its preface can label it independently of those links.
    local is_item, item_type, formatted_line =
      is_outline_item(nil, i, config, code_memo, file_lines, { is_chat = true })
    if is_item and item_type ~= "branch" and (not branches or item_type == "question") then
      table.insert(items, {
        display = indent .. formatted_line,
        value = { lnum = i, file = abs_path },
        type = item_type,
      })
    end
    if branches then
      for _, branch in ipairs(branches) do
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
      end
    end
  end

  items = question_tags.apply_outline(items, file_lines, config, header_end)
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

  -- A live confirmed row supplies identity; an unopened disk item supplies
  -- only a file/row/content location, never a nearest-item substitution.
  local live_buf=require('parley.helper').buffer_for(abs_path)
  local doc=live_buf and Document.get(live_buf)
  for _,item in ipairs(items) do
    local entry=item.value
    if not entry.child_path then
      local expected=file_lines[entry.lnum] or ""
      entry.source_bound=true
      entry.expected_line=#expected<=4096 and expected or nil
      if doc and entry.expected_line and entry.lnum<=Document.size(doc).rows then
        local row=entry.lnum-1
        local found=Document.outline(doc,row,row+1,{is_chat=true,budget_nodes=2048,budget_entries=4096})
        if found.status=="found" and found.span.start_row==row then
          local text,complete=label(live_buf,row)
          if complete and text==expected then entry.identity=found.span.handle end
        end
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
      value = { lnum = 1, file = abs_path, file_start = true },
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
    load_live_items(current_bufnr, config, { is_chat = false }, function(items)
    local keybindings_key = require("parley.keybinding_registry").keys_for("help", parley.config)
    float_picker.open({
      title = "Outline",
      items = items,
      initial_index = question_tags.initial_index(items, buf_name, vim.api.nvim_win_get_cursor(0)[1]),
      anchor = "top",
      on_select = function(item)
        if not vim.api.nvim_buf_is_valid(current_bufnr) then return end
        jump_to_outline_location({
          bufnr = current_bufnr,
          name = buf_name,
          windows = target_windows,
          lnum = item.value.lnum,
          identity = item.value.identity,
          is_chat = false,
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
    end)
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
      load_live_items(current_bufnr,config,{is_chat=true},function(live_items)
        require("parley.float_picker").open({title="Outline",items=live_items,anchor="top",
          on_select=function(item)
            jump_to_outline_location({bufnr=current_bufnr,name=buf_name,windows=target_windows,
              lnum=item.value.lnum,identity=item.value.identity,is_chat=true},config)
          end})
      end)
      return
    end

    local keybindings_key = require("parley.keybinding_registry").keys_for("help", parley.config)
    float_picker.open({
      title = "🌳 Chat Tree Outline",
      items = items,
      anchor = "top",
      initial_index = sel_index or question_tags.initial_index(items, buf_name, vim.api.nvim_win_get_cursor(0)[1]),
      on_select = function(item)
        local entry = item.value
        if entry.child_path or entry.file_start then
          local path=entry.child_path or entry.file
          if vim.fn.filereadable(path) ~= 1 then
            vim.notify("Cannot open outline file: " .. path, vim.log.levels.WARN)
            return
          end
          local child_buf = vim.fn.bufadd(path)
          vim.fn.bufload(child_buf)
          -- File entries select a path, independently of semantic row eligibility.
          focus_buffer_line(child_buf, path, target_windows, 1)
          return
        end
        do
          local target_file = entry.file or buf_name
          local target_buf = vim.fn.bufadd(target_file)
          vim.fn.bufload(target_buf)
          jump_to_outline_location({
            bufnr = target_buf,
            name = target_file,
            windows = target_windows,
            lnum = entry.lnum,
            identity = entry.identity,
            source_bound = entry.source_bound,
            expected_line = entry.expected_line,
            exact = true,
            is_chat = true,
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
