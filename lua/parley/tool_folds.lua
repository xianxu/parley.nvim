-- Native folds are a presentation of confirmed document sections. Neovim moves
-- them on ordinary edits; only structural deltas schedule reconciliation.
local M={}
local line_reader=require('parley.line_reader')
local Document=require('parley.document')
local buffers={}
local setting_foldenable=0
local generation=0
local function invalidate(s)
    generation=generation+1;s.generation=generation
    if vim.api.nvim_buf_is_valid(s.buf) then vim.b[s.buf].parley_fold_generation=generation end
end
local function valid_target(buf,win)
    return vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_win_is_valid(win)
        and vim.api.nvim_win_get_buf(win)==buf
end
local function notify(event) if M._observer then M._observer(event) end end
-- A slice owns temporary editor state even after it loses publication authority.
-- Cleanup targets the captured window, never whichever window a callback selects.
local function restore_window(buf,win,enabled,view,owner)
    if not valid_target(buf,win) then return end
    local ok,err=true,nil
    -- Retirement may run inside an option callback. Once it restores the
    -- operator preference, nested slices must not reinstate temporary suspension.
    if not (owner and owner.released_preference) then
        ok,err=pcall(vim.api.nvim_set_option_value,'foldenable',enabled,{win=win})
    end
    if valid_target(buf,win) then
        local restored,failure=pcall(vim.api.nvim_win_call,win,function()vim.fn.winrestview(view)end)
        if not restored and ok then ok,err=false,failure end
    end
    if not ok then error(err,0) end
end

local function clear_folds_in_span(buf, win, first_0, last_0, command_limit, remember, current, owner)
    -- Reset first: an early return must not leave a previous call's count
    -- readable as if it described this one.
    M._last_clear_iters = nil
    if not valid_target(buf, win) then return end
    if first_0 == nil or last_0 == nil or last_0 < first_0 then return end
    local next_row,done
    local tick=vim.api.nvim_buf_get_changedtick(buf)
    local owner_generation=vim.b[buf].parley_fold_generation or 0
    local function live()
        return valid_target(buf,win) and vim.api.nvim_buf_get_changedtick(buf)==tick
            and (vim.b[buf].parley_fold_generation or 0)==owner_generation and (not current or current())
    end
    vim.api.nvim_win_call(win, function()
        if not live() then return end
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
        local command = string.format([[
            let s:owner_buf = %d
            let s:owner_win = %d
            let s:owner_tick = %d
            let s:owner_generation = %d
            setlocal foldenable
            if bufnr() == s:owner_buf && win_getid() == s:owner_win && b:changedtick == s:owner_tick && get(b:, 'parley_fold_generation', 0) == s:owner_generation
            execute %d
            let s:guard = 0
            let s:states = []
            let s:groups = 0
            let s:ops = 0
            let s:limit = %d
            while line('.') <= %d && s:guard < s:limit && s:ops + 2 < s:limit
              if bufnr() != s:owner_buf || win_getid() != s:owner_win || b:changedtick != s:owner_tick || get(b:, 'parley_fold_generation', 0) != s:owner_generation | break | endif
              let s:guard += 1
              let s:level = foldlevel(line('.'))
              if bufnr() != s:owner_buf || win_getid() != s:owner_win || b:changedtick != s:owner_tick || get(b:, 'parley_fold_generation', 0) != s:owner_generation | break | endif
              if s:level > 0
                let s:groups += 1
                let s:ops += 1
                let s:was_open = foldclosed(line('.')) == -1
                if bufnr() != s:owner_buf || win_getid() != s:owner_win || b:changedtick != s:owner_tick || get(b:, 'parley_fold_generation', 0) != s:owner_generation | break | endif
                if s:was_open
                  silent! normal! zc
                  if bufnr() != s:owner_buf || win_getid() != s:owner_win || b:changedtick != s:owner_tick || get(b:, 'parley_fold_generation', 0) != s:owner_generation | break | endif
                  let s:ops += 1
                endif
                call add(s:states, [foldclosed(line('.')) - 1, s:was_open])
                if bufnr() != s:owner_buf || win_getid() != s:owner_win || b:changedtick != s:owner_tick || get(b:, 'parley_fold_generation', 0) != s:owner_generation | break | endif
                silent! normal! zD
                if bufnr() != s:owner_buf || win_getid() != s:owner_win || b:changedtick != s:owner_tick || get(b:, 'parley_fold_generation', 0) != s:owner_generation | break | endif
                if foldlevel(line('.')) > 0
                  break
                endif
              else
                let s:before = line('.')
                let s:ops += 1
                silent! normal! zj
                if bufnr() != s:owner_buf || win_getid() != s:owner_win || b:changedtick != s:owner_tick || get(b:, 'parley_fold_generation', 0) != s:owner_generation | break | endif
                if line('.') == s:before
                  break
                endif
              endif
            endwhile
            let b:parley_fold_clear_states = s:states
            let b:parley_fold_clear_iters = s:guard
            let b:parley_fold_clear_work = [s:groups, s:ops]
            let b:parley_fold_clear_next = line('.')
            let b:parley_fold_clear_done = (s:guard < s:limit && s:ops + 2 < s:limit) || line('.') > %d
            endif
        ]], buf, win, tick, owner_generation, first_row, command_limit or (last_row - first_row + 2) * 2, last_row, last_row)
        local ok, err = pcall(vim.api.nvim_exec2, command, {})
        -- Restore both even if the walk fails; its temporary editor state must
        -- not become the reader's new position or folding preference.
        restore_window(buf,win,foldenable,view,owner)
        if not ok then error(err, 0) end
        if not live() then return end
        -- Loop iterations, exposed so a test can assert this walks folds rather
        -- than rows without timing anything. A wall-clock assertion measures the
        -- machine as much as the algorithm.
        M._last_clear_iters = vim.b[buf].parley_fold_clear_iters
        -- Count the existing native walk, including unsuccessful commands.
        -- Nested folds deleted together by zD constitute one outer group.
        local work = vim.b[buf].parley_fold_clear_work
        line_reader.record_work(buf, { fold_groups_visited = work[1], native_fold_ops = work[2] })
        if remember then
            for _,entry in ipairs(vim.b[buf].parley_fold_clear_states or {}) do remember(entry[1],entry[2]==1) end
        end
        next_row=vim.b[buf].parley_fold_clear_next-1
        done=vim.b[buf].parley_fold_clear_done==1
    end)
    return next_row,done
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

local function configure(win,current)
    for _,option in ipairs({{'foldmethod','manual'},
        {'foldtext',"v:lua.require('parley.tool_folds').foldtext()"},{'foldcolumn','1'},{'foldminlines',0}}) do
        if current and not current() then return false end
        vim.api.nvim_set_option_value(option[1],option[2],{win=win})
    end
    return not current or current()
end
local BATCH_GROUPS=64
local INTERACTIVE_ROWS=50000
local function release_window(buf,window)
    local suspended=window.suspended;window.suspended=false
    if suspended then window.released_preference=true end
    if suspended and valid_target(buf,window.win) then
        if vim.api.nvim_get_option_value('foldenable',{win=window.win})~=window.enabled then
            setting_foldenable=setting_foldenable+1
            local ok,err=pcall(vim.api.nvim_set_option_value,'foldenable',window.enabled,{win=window.win})
            setting_foldenable=setting_foldenable-1
            if not ok then error(err,0) end
        end
    end
    window.suspended=false
end
local function release_windows(buf,windows)
    local failure
    for _,window in ipairs(windows or {}) do
        local ok,err=pcall(release_window,buf,window)
        if not ok and not failure then failure=err end
    end
    if failure then error(failure,0) end
end
local function configure_target(buf,s,win)
    return configure(win,function()return buffers[buf]==s and valid_target(buf,win)end)
end
-- Open hints belong to live fold markers. Retire deleted/non-fold identities
-- in scheduled slices, including when repeated edits abort reconstruction.
local function prune_hints(s)
    local scan=s.hint_scan
    if not scan then return false end
    if not scan.windows then
        scan.windows={};scan.index=0
        for _,map in pairs(s.opened) do scan.windows[#scan.windows+1]=map end
    end
    local visited=0
    while visited<BATCH_GROUPS do
        if not scan.map then
            scan.index=scan.index+1
            local map=scan.windows[scan.index]
            if not map then s.hint_scan=nil;return false end
            scan.map,scan.key=map,next(map)
        end
        local key=scan.key
        if not key then scan.map=nil else
            scan.key=next(scan.map,key)
            local row=Document.lookup(s.doc,key)
            if not row or row.metadata and row.metadata.confirmed
                and not require('parley.document.projection').summary(row.metadata).fold_start then
                scan.map[key]=nil
            end
            visited=visited+1
        end
    end
    return true
end
local function discard_uncertainty(s,expected)
    local job=s.uncertainty
    if expected and job~=expected then return end
    s.uncertainty=nil
    release_windows(s.buf,job and job.windows)
end
local function clear_uncertainty(s)
    local scope=Document.uncertain_range(s.doc)
    if not scope then discard_uncertainty(s);return false end
    if s.uncertainty_cleared then return false end
    local job=s.uncertainty
    if not job then
        job={first=math.max(scope.first,s.owned_first or scope.first),last=scope.last,windows={},index=1}
        for _,win in ipairs(vim.fn.win_findbuf(s.buf)) do
            job.windows[#job.windows+1]={win=win,row=job.first,
                enabled=vim.api.nvim_get_option_value('foldenable',{win=win}),
                suspended=job.last-job.first>INTERACTIVE_ROWS}
        end
        s.uncertainty=job
        -- Recreation must include every removed suffix fold once context returns.
        s.first=math.min(s.first or job.first,job.first)
        s.last=math.max(s.last or job.last,job.last)
    end
    local tick=vim.api.nvim_buf_get_changedtick(s.buf)
    local owner_generation=s.generation
    local function current()
        return buffers[s.buf]==s and s.generation==owner_generation and s.uncertainty==job and vim.api.nvim_buf_is_valid(s.buf)
            and vim.api.nvim_buf_get_changedtick(s.buf)==tick
    end
    local window=job.windows[job.index]
    if not window then
        s.uncertainty_cleared=true;discard_uncertainty(s,job);return true
    end
    if valid_target(s.buf,window.win) then
        s.opened[window.win]=s.opened[window.win] or {}
        setting_foldenable=setting_foldenable+1
        local ok,next_row,done=pcall(clear_folds_in_span,s.buf,window.win,window.row,job.last-1,
            BATCH_GROUPS*2,function(row,opened)
                if not current() then return end
                local found=Document.query(s.doc,row,row+1)[1]
                if found then s.opened[window.win][found.handle]=opened end
            end,current,window)
        setting_foldenable=setting_foldenable-1
        if not ok then discard_uncertainty(s,job);error(next_row,0) end
        if not current() then return true end
        window.row=next_row
        if window.suspended and not done then
            setting_foldenable=setting_foldenable+1
            local disabled,err=pcall(vim.api.nvim_set_option_value,'foldenable',false,{win=window.win})
            setting_foldenable=setting_foldenable-1
            if not disabled then discard_uncertainty(s,job);error(err,0) end
            if not current() then return true end
        end
        if not done then return true end
    end
    release_window(s.buf,window)
    if not current() then return true end
    job.index=job.index+1
    return true
end
local function discard_plan(s,expected)
    local plan=s.plan
    if expected and plan~=expected then return end
    s.plan=nil
    release_windows(s.buf,plan and plan.windows)
end
local function mark(s,first,last)
    invalidate(s)
    s.first=math.min(s.first or first,first)
    s.last=math.max(s.last or last,last)
    discard_plan(s)
end
local function apply(buf,s,plan)
    local tick=vim.api.nvim_buf_get_changedtick(buf)
    local function current()
        return buffers[buf]==s and s.plan==plan and vim.api.nvim_buf_is_valid(buf)
            and vim.api.nvim_buf_get_changedtick(buf)==tick
    end
    if not Document.validate_projection(s.doc,plan.certificate) then discard_plan(s,plan);return 'more' end
    if not plan.windows then
        local windows={}
        for _,win in ipairs(vim.fn.win_findbuf(buf)) do
            if valid_target(buf,win) then
                if not configure(win,current) then discard_plan(s,plan);return 'more' end
                s.opened[win]=s.opened[win] or {}
                windows[#windows+1]={win=win,phase='capture',index=1,opened=s.opened[win],
                    enabled=vim.api.nvim_get_option_value('foldenable',{win=win})}
            end
        end
        plan.windows=windows;plan.window=1
    end
    local window=plan.windows[plan.window]
    if not window then return 'idle' end
    local win=window.win
    if not valid_target(buf,win) then
        release_window(buf,window);plan.window=plan.window+1;return 'more'
    end
    -- Each slice restores its entry view, preserving scrolling between slices.
    setting_foldenable=setting_foldenable+1
    local ok,err=pcall(vim.api.nvim_win_call,win,function()
        if not current() or not valid_target(buf,win) then return end
        local view=vim.fn.winsaveview()
        local enabled=vim.wo.foldenable
        local success,failure=pcall(function()
            vim.wo.foldenable=true
            if not current() or not valid_target(buf,win) then return end
            if window.phase=='capture' then
                local last=math.min(#plan.ranges,window.index+BATCH_GROUPS-1)
                for index=window.index,last do
                    local range=plan.ranges[index]
                    line_reader.record_work(buf,{fold_groups_visited=1})
                    local level=vim.fn.foldlevel(range.start_0+1)
                    if not current() or not valid_target(buf,win) then return end
                    if level>0 then
                        local opened=vim.fn.foldclosed(range.start_0+1)==-1
                        if not current() or not valid_target(buf,win) then return end
                        window.opened[range.identity]=opened
                    end
                end
                window.index=last+1
                if window.index>#plan.ranges then
                    window.phase='clear';window.clear_row=plan.first
                    if plan.last-plan.first>INTERACTIVE_ROWS then window.suspended=true end
                end
            elseif window.phase=='clear' then
                -- At most 50k affected rows retain the measured native-clear
                -- exception. Larger scopes visit bounded fold groups per slice.
                local next_row,done=clear_folds_in_span(buf,win,window.clear_row,plan.last-1,
                    window.suspended and BATCH_GROUPS*2 or nil,nil,current,window)
                if not current() then return end
                window.clear_row=next_row
                if done then window.phase='create';window.index=1 end
            elseif window.phase=='create' then
                local last=math.min(#plan.ranges,window.index+BATCH_GROUPS-1)
                for index=window.index,last do
                    local range=plan.ranges[index]
                    line_reader.record_work(buf,{native_fold_ops=1,fold_groups_visited=1})
                    vim.cmd(string.format('%d,%dfold',range.start_0+1,range.end_0+1))
                    if not current() or not valid_target(buf,win) then return end
                    if window.opened[range.identity] then
                        line_reader.record_work(buf,{native_fold_ops=1})
                        vim.cmd(string.format('%dfoldopen',range.start_0+1))
                        if not current() or not valid_target(buf,win) then return end
                    end
                end
                window.index=last+1
                if window.index>#plan.ranges then
                    window.phase='done';s.windows[win]=true
                    notify({phase='reconcile',win=win,ranges=plan.ranges})
                end
            end
        end)
        -- Superseded work restores its entry preference; only a live job may
        -- leave folds suspended between slices of a large reconciliation.
        local restore_enabled=enabled
        if current() and window.suspended then restore_enabled=false end
        restore_window(buf,win,restore_enabled,view,window)
        if not success then error(failure,0) end
    end)
    setting_foldenable=setting_foldenable-1
    if not ok then discard_plan(s,plan);error(err,0) end
    if not current() then discard_plan(s,plan);return 'more' end
    if window.phase=='done' then
        release_window(buf,window)
        if not current() then discard_plan(s,plan);return 'more' end
        s.opened[win]=nil;plan.window=plan.window+1
    end
    return plan.window>#plan.windows and 'idle' or 'more'
end
-- One bounded query page per step. Destructive native work begins only after
-- every desired range is confirmed and its local projection proof still holds.
function M.step(buf)
    local s=buffers[buf]
    if not s then return 'idle' end
    if prune_hints(s) then return 'more' end
    if clear_uncertainty(s) then return 'more' end
    if buffers[buf]~=s then return 'idle' end
    if s.first==nil then return 'idle' end
    local size=Document.size(s.doc).rows
    local plan=s.plan
    if plan and plan.certificate then
        local status=apply(buf,s,plan)
        if status=='idle' and s.plan==plan and buffers[buf]==s then s.first,s.last,s.plan=nil,nil,nil end
        return status
    end
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
    if result.status=='opaque' then discard_plan(s);return 'pending' end
    if result.status=='stale' then discard_plan(s);return 'more' end
    for _,range in ipairs(result.ranges or {}) do plan.ranges[#plan.ranges+1]=range end
    plan.cursor=result.cursor
    if result.status=='budget' then return 'more' end
    if result.status~='ready' then discard_plan(s);return 'pending' end
    plan.certificate=result.certificate
    return 'more'
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
    local s={buf=buf,doc=doc,windows={},opened={}};buffers[buf]=s
    s.unsubscribe=Document.subscribe(doc,function(event)
        if event.kind=='detach' then
            invalidate(s)
            discard_uncertainty(s)
            discard_plan(s)
            if s.work then s.work:close() end
            if s.group then vim.api.nvim_del_augroup_by_id(s.group);s.group=nil end
            if s.unsubscribe then s.unsubscribe();s.unsubscribe=nil end
            s.doc=nil;s.work=nil
            buffers[buf]=nil
            if vim.api.nvim_buf_is_valid(buf) then vim.b[buf].parley_fold_generation=nil end
            return
        end
        if event.kind=='reload' then
            discard_uncertainty(s);s.uncertainty_cleared=nil;s.hint_scan=nil;s.opened={}
            if s.work then s.work:cancel() end
            s.owned_first=nil;mark(s,0,Document.size(doc).rows)
        elseif event.kind=='edit' then
            s.hint_scan=s.hint_scan or {}
            discard_uncertainty(s);s.uncertainty_cleared=nil
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
                if delta~=0 then discard_plan(s) end
            end
            if event.semantic_changed and not event.deferred_fragment then mark(s,event.first_row,event.last_row) end
        elseif event.kind=='repair' then
            for _,delta in ipairs(not event.result.reused_suffix and event.result.deltas or {}) do
                local row=Document.lookup(doc,delta.handle)
                if row then mark(s,row.start_row,row.end_row) end
            end
        end
        if s.first~=nil or event.kind=='edit' and event.semantic_changed then schedule(buf,s) end
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
    if not configure_target(buf,s,win) then
        if buffers[buf]==s then schedule(buf,s) end
        return false
    end
    mark(s,0,Document.size(s.doc).rows);schedule(buf,s);return true
end
function M.apply_folds(buf,win)
    if not vim.api.nvim_buf_is_valid(buf) then return false end
    local s=ensure(buf);if not s then return false end
    local configured=not win or not valid_target(buf,win) or configure_target(buf,s,win)
    if buffers[buf]~=s then return false end
    mark(s,0,Document.size(s.doc).rows);schedule(buf,s);return configured
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
    s.group=group
    vim.api.nvim_create_autocmd({'BufWinEnter','WinEnter'},{group=group,callback=function(args)
        if args.buf==buf then M.hydrate_window(buf,vim.api.nvim_get_current_win()) end
    end})
    vim.api.nvim_create_autocmd('OptionSet',{group=group,pattern='foldenable',callback=function()
        if setting_foldenable>0 then return end
        local win=vim.api.nvim_get_current_win()
        for _,job in ipairs({s.plan or {},s.uncertainty or {}}) do
            for _,window in ipairs(job.windows or {}) do
                if window.win==win and window.suspended then
                    window.enabled=vim.api.nvim_get_option_value('foldenable',{win=win})
                end
            end
        end
    end})
    vim.api.nvim_create_autocmd('WinClosed',{group=group,callback=function(args)
        s.windows[tonumber(args.match)]=nil;s.opened[tonumber(args.match)]=nil
    end})
    for _,win in ipairs(vim.fn.win_findbuf(buf)) do
        if buffers[buf]~=s then return end
        if valid_target(buf,win) then
            configure_target(buf,s,win)
        end
    end
    if buffers[buf]==s then schedule(buf,s) end
end
return M
