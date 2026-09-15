-- Native folds are a presentation of confirmed document sections. Neovim moves
-- them on ordinary edits; only structural deltas schedule reconciliation.
local M={}
local line_reader=require('parley.line_reader')
local Document=require('parley.document')
local buffers={}
local function valid_target(buf,win)
    return vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_win_is_valid(win)
        and vim.api.nvim_win_get_buf(win)==buf
end
local function notify(event) if M._observer then M._observer(event) end end
local function clear_folds_in_span(buf, win, first_0, last_0)
    -- Reset first: an early return must not leave a previous call's count
    -- readable as if it described this one.
    M._last_clear_iters = nil
    if not valid_target(buf, win) then return end
    if first_0 == nil or last_0 == nil or last_0 < first_0 then return end
    vim.api.nvim_win_call(win, function()
        local line_count = vim.api.nvim_buf_line_count(buf)
        local last_row = math.min(last_0 + 1, line_count)
        local first_row = math.max(first_0 + 1, 1)
        if first_row > last_row then return end
        -- Cursor excursions also change topline/skipcol with an attached UI.
        -- Preserve only this fold walk's view, so intentional follow movement
        -- inside with_exchange_update's mutation remains effective.
        local view = vim.fn.winsaveview()
        local foldenable = vim.api.nvim_get_option_value("foldenable", { win = win })
        -- Walk fold-to-fold, not row-to-row, in ONE Lua→VimL crossing.
        -- chat_respond wraps every streamed chunk in with_exchange_update, so
        -- this is a per-chunk cost and it must not scale with exchange length:
        -- probing every row costs O(span) (3.7ms from Lua, 1.2ms natively, on a
        -- 600-row exchange), while `zj` jumps straight to the next fold start,
        -- making it O(number of folds present). zD deletes nested folds at the
        -- cursor too. If zj cannot move there is no further fold below, so stop.
        -- s:guard bounds the loop absolutely: `zD` refuses under a non-manual
        -- 'foldmethod' (E350), which would otherwise leave foldlevel unchanged
        -- and spin here forever. Bounding by the span means the worst case
        -- degrades to the row-walk cost rather than hanging the editor.
        -- 'foldenable' must be on for this walk: with it off, zj does not
        -- navigate and zD does not delete, so the loop silently no-ops and a
        -- stale fold survives the reconcile that exists to remove it —
        -- including one anchored on a question, the exact reported symptom.
        -- Reachable from a user's `set nofoldenable`, `zi`, or parley's own
        -- chat_toggle_tool_folds. Saved and restored so the operator's setting
        -- is not changed underneath them.
        local ok, err = pcall(vim.api.nvim_exec2, string.format([[
            setlocal foldenable
            execute %d
            let s:guard = 0
            let s:groups = 0
            let s:ops = 0
            let s:limit = %d
            while line('.') <= %d && s:guard < s:limit
              let s:guard += 1
              if foldlevel(line('.')) > 0
                let s:groups += 1
                let s:ops += 1
                silent! normal! zD
                if foldlevel(line('.')) > 0
                  break
                endif
              else
                let s:before = line('.')
                let s:ops += 1
                silent! normal! zj
                if line('.') == s:before
                  break
                endif
              endif
            endwhile
            let b:parley_fold_clear_iters = s:guard
            let b:parley_fold_clear_work = [s:groups, s:ops]
        ]], first_row, (last_row - first_row + 2) * 2, last_row), {})
        -- Restore both even if the walk fails; its temporary editor state must
        -- not become the reader's new position or folding preference.
        vim.api.nvim_set_option_value("foldenable", foldenable, { win = win })
        vim.fn.winrestview(view)
        if not ok then error(err, 0) end
        -- Loop iterations, exposed so a test can assert this walks folds rather
        -- than rows without timing anything. A wall-clock assertion measures the
        -- machine as much as the algorithm.
        M._last_clear_iters = vim.b[buf].parley_fold_clear_iters
        -- Count the existing native walk, including unsuccessful commands.
        -- Nested folds deleted together by zD constitute one outer group.
        local work = vim.b[buf].parley_fold_clear_work
        line_reader.record_work(buf, { fold_groups_visited = work[1], native_fold_ops = work[2] })
    end)
end


function M.foldtext()
    local start_line = vim.fn.getline(vim.v.foldstart)
    local line_count = vim.v.foldend - vim.v.foldstart + 1
    -- Derived from the configured prefixes, not hardcoded: these were the last
    -- hand-maintained copy of the marker vocabulary, so a customised
    -- chat_tool_use_prefix (etc.) silently fell through to the preview branch —
    -- the same branch that rendered "💬: q (4 lines)" and made #200 look like
    -- ordinary text instead of a corrupt fold.
    local patterns = require("parley.highlight_structure").patterns(require("parley.config"))

    local tool_use = patterns.tool_use_prefix
    local tool_result = patterns.tool_result_prefix
    if start_line:match(patterns.tool_use_pattern) then
        local name = start_line:match(patterns.tool_use_pattern .. "%s*(%S+)") or "tool"
        return string.format("%s %s (%d lines) ", tool_use:gsub(":$", ""), name, line_count)
    elseif start_line:match(patterns.tool_result_pattern) then
        local name = start_line:match(patterns.tool_result_pattern .. "%s*(%S+)") or "result"
        local is_error = start_line:match("error=true") and " error" or ""
        return string.format("%s %s%s (%d lines) ",
            tool_result:gsub(":$", ""), name, is_error, line_count)
    elseif start_line:match(patterns.reasoning_pattern) then
        return patterns.reasoning_prefix:gsub(":$", "") .. " thinking (" .. line_count .. " lines) "
    elseif start_line:match(patterns.summary_pattern) then
        return patterns.summary_prefix:gsub(":$", "") .. " summary (" .. line_count .. " lines) "
    end

    -- Reached only when a fold is anchored on something Parley never folds.
    -- That is the #200 signature, so say so rather than rendering it as if it
    -- were ordinary content.
    local preview = start_line:sub(1, 60)
    if #start_line > 60 then preview = preview .. "..." end
    return "⚠ unexpected fold: " .. preview .. " (" .. line_count .. " lines) "
end

local function configure(win)
    vim.api.nvim_set_option_value('foldmethod','manual',{win=win})
    vim.api.nvim_set_option_value('foldtext',"v:lua.require('parley.tool_folds').foldtext()",{win=win})
    vim.api.nvim_set_option_value('foldcolumn','1',{win=win})
    vim.api.nvim_set_option_value('foldminlines',0,{win=win})
end
local function mark(s,first,last)
    s.first=math.min(s.first or first,first)
    s.last=math.max(s.last or last,last)
    s.plan=nil
end
local function apply(buf,s,plan)
    if not Document.validate_projection(s.doc,plan.certificate) then return false end
    for _,win in ipairs(vim.fn.win_findbuf(buf)) do
        if valid_target(buf,win) then
            if not Document.validate_projection(s.doc,plan.certificate) then return false end
            configure(win)
            vim.api.nvim_win_call(win,function()
                local view=vim.fn.winsaveview()
                local enabled=vim.wo.foldenable
                vim.wo.foldenable=true
                local opened={}
                for _,range in ipairs(plan.ranges) do
                    opened[range.identity]=vim.fn.foldlevel(range.start_0+1)>0
                        and vim.fn.foldclosed(range.start_0+1)==-1
                end
                local ok,err=pcall(function()
                    clear_folds_in_span(buf,win,plan.first,plan.last-1)
                    for _,range in ipairs(plan.ranges) do
                        line_reader.record_work(buf,{native_fold_ops=1})
                        vim.cmd(string.format('%d,%dfold',range.start_0+1,range.end_0+1))
                        if opened[range.identity] then
                            line_reader.record_work(buf,{native_fold_ops=1})
                            vim.cmd(string.format('%dfoldopen',range.start_0+1))
                        end
                    end
                end)
                vim.wo.foldenable=enabled
                vim.fn.winrestview(view)
                if not ok then error(err,0) end
            end)
            s.windows[win]=true
            notify({phase='reconcile',win=win,ranges=plan.ranges})
        end
    end
    return true
end
-- One bounded query page per step. Destructive native work begins only after
-- every desired range is confirmed and its local projection proof still holds.
function M.step(buf)
    local s=buffers[buf]
    if not s or s.first==nil then return 'idle' end
    local size=Document.size(s.doc).rows
    local plan=s.plan
    if not plan then
        local first=math.min(s.first,math.max(0,size-1))
        local last=math.min(math.max(first,s.last-1),math.max(0,size-1))
        local earliest=Document.next_exchange(s.doc,0,size)
        if earliest.status=='opaque' or earliest.status=='budget' then return 'pending' end
        local owned=earliest.span and earliest.span.start_row or s.owned_first
        if owned==nil then s.first,s.last=nil,nil;return 'idle' end
        s.owned_first=math.min(s.owned_first or owned,owned)
        first=math.max(first,s.owned_first)
        if last<first then s.first,s.last=nil,nil;return 'idle' end
        local a=Document.exchange(s.doc,first)
        local z=Document.exchange(s.doc,last)
        if a.status=='opaque' or z.status=='opaque' then return 'pending' end
        if a.status=='budget' or z.status=='budget' then return 'pending' end
        -- Prefix/header edits can precede the first exchange. Clearing this
        -- confirmed prefix is safe only after the full requested scope settles.
        plan={first=a.status=='ready' and a.first or first,
            last=z.status=='ready' and z.last or math.min(size,last+1),ranges={}}
        s.plan=plan
    end
    local result=Document.folds(s.doc,plan.first,plan.last,{cursor=plan.cursor})
    if result.status=='opaque' then s.plan=nil;return 'pending' end
    if result.status=='stale' then s.plan=nil;return 'more' end
    for _,range in ipairs(result.ranges or {}) do plan.ranges[#plan.ranges+1]=range end
    plan.cursor=result.cursor
    if result.status=='budget' then return 'more' end
    if result.status~='ready' then s.plan=nil;return 'pending' end
    plan.certificate=result.certificate
    if not apply(buf,s,plan) then s.plan=nil;return 'more' end
    s.first,s.last,s.plan=nil,nil,nil
    return 'idle'
end
local function schedule(buf,s)
    if not s.work then
        s.work=require('parley.deferred_work').new(function()
            return buffers[buf]==s and M.step(buf)=='more'
        end)
    end
    s.work:request()
end
local function ensure(buf)
    local hit=buffers[buf];if hit then return hit end
    local doc=Document.get(buf) or Document.attach(buf,{
        patterns=require('parley.highlight_structure').patterns(require('parley.config'))})
    if not doc then return nil end
    local s={doc=doc,windows={}};buffers[buf]=s
    s.unsubscribe=Document.subscribe(doc,function(event)
        if event.kind=='detach' then
            if s.work then s.work:close() end
            buffers[buf]=nil;return
        end
        if event.kind=='reload' then
            if s.work then s.work:cancel() end
            s.owned_first=nil;mark(s,0,Document.size(doc).rows)
        elseif event.kind=='edit' then
            if s.owned_first then
                if event.old_last_row<=s.owned_first then
                    s.owned_first=s.owned_first+event.last_row-event.old_last_row
                elseif event.first_row<=s.owned_first then s.owned_first=event.first_row end
            end
            -- Native coordinates of queued work move with every edit, even
            -- one that needs no structural repair of its own.
            if s.first then
                local delta=event.last_row-event.old_last_row
                if event.old_last_row<=s.first then s.first=s.first+delta;s.last=s.last+delta
                elseif event.first_row<s.last then s.last=math.max(event.last_row,s.last+delta) end
                if delta~=0 then s.plan=nil end
            end
            if event.semantic_changed then mark(s,event.first_row,event.last_row) end
        elseif event.kind=='repair' then
            for _,delta in ipairs(event.result.deltas or {}) do
                local row=Document.lookup(doc,delta.handle)
                if row then mark(s,row.start_row,row.end_row) end
            end
        end
        if s.first~=nil then schedule(buf,s) end
    end)
    mark(s,0,Document.size(doc).rows)
    return s
end
-- Deterministic test/explicit maintenance seam; ordinary callbacks use step.
function M.flush(buf,limit)
    for _=1,limit or 10000 do
        local status=M.step(buf)
        if status~='more' then return status end
    end
    return 'more'
end
function M.hydrate_window(buf,win)
    if not valid_target(buf,win) then return false end
    local s=ensure(buf);if not s then return false end
    if s.windows[win] then return false end
    configure(win);mark(s,0,Document.size(s.doc).rows);schedule(buf,s);return true
end
function M.apply_folds(buf,win)
    if not vim.api.nvim_buf_is_valid(buf) then return false end
    local s=ensure(buf);if not s then return false end
    if win and valid_target(buf,win) then configure(win) end
    mark(s,0,Document.size(s.doc).rows);schedule(buf,s);return true
end
-- Legacy streaming brackets no longer clear/reparse a mutable layout model.
-- The document observer handles both successful and partially failing edits.
function M.prepare_exchange_update(buf)
    ensure(buf)
    return vim.fn.win_findbuf(buf)
end
function M.finalize_exchange_update(buf)
    local s=buffers[buf];if s and s.first~=nil then schedule(buf,s) end
end
function M.with_exchange_update(buf,_,_exchange,mutate)
    ensure(buf)
    return mutate()
end
function M.setup(buf)
    if not vim.api.nvim_buf_is_valid(buf) then return end
    local s=ensure(buf);if not s then return end
    if s.setup then return end
    s.setup=true
    local group=vim.api.nvim_create_augroup('ParleyToolFolds'..buf,{clear=true})
    vim.api.nvim_create_autocmd({'BufWinEnter','WinEnter'},{group=group,callback=function(args)
        if args.buf==buf then M.hydrate_window(buf,vim.api.nvim_get_current_win()) end
    end})
    vim.api.nvim_create_autocmd('WinClosed',{group=group,callback=function(args)
        s.windows[tonumber(args.match)]=nil
    end})
    for _,win in ipairs(vim.fn.win_findbuf(buf)) do if valid_target(buf,win) then configure(win) end end
    schedule(buf,s)
end
return M
