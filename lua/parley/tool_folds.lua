-- Native folds are a presentation of confirmed document sections. Neovim moves
-- them on ordinary edits; only structural deltas schedule reconciliation.
local M={}
local line_reader=require('parley.line_reader')
local Document=require('parley.document')
local Native=require('parley.fold_native')
local Diff=require('parley.fold_diff')
local valid_target=Native.valid_target
local buffers={}
local setting_foldenable=0
local generation=0
local function invalidate(s)
    generation=generation+1;s.generation=generation
    if vim.api.nvim_buf_is_valid(s.buf) then vim.b[s.buf].parley_fold_generation=generation end
end
local function notify(event) if M._observer then M._observer(event) end end
local restore_window=Native.restore_window
-- The >50k-row paths still delete via the native walk.
local function clear_folds_in_span(buf,win,first_0,last_0,command_limit,remember,current,owner)
    local next_row,done=Native.walk(buf,win,first_0,last_0,command_limit,remember,current,owner)
    M._last_clear_iters=Native.last_iters
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
    -- #264: below the suspension threshold, uncertainty removes no native fold.
    -- Parley owns every fold and Neovim carries folds with their text, so the
    -- old folds stay stable until the confirmed projection is ready; the diff
    -- reconcile then changes only what differs. Clearing here, a turn before
    -- any replacement existed, is what made closed folds blink open.
    local first=math.max(scope.first,s.owned_first or scope.first)
    if not job and scope.last-first<=INTERACTIVE_ROWS then
        s.first=math.min(s.first or first,first)
        s.last=math.max(s.last or scope.last,scope.last)
        s.uncertainty_cleared=true
        return false
    end
    if not job then
        job={first=first,last=scope.last,windows={},index=1}
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
                    window.phase='inventory';window.inventory_row=plan.first;window.existing={}
                    if plan.last-plan.first>INTERACTIVE_ROWS then window.suspended=true end
                end
            elseif window.phase=='inventory' then
                -- Read the native folds without changing any (#264). At most 50k
                -- affected rows keep the single-walk exception; larger scopes page.
                local folds,next_row,done=Native.walk(buf,win,window.inventory_row,plan.last-1,
                    window.suspended and BATCH_GROUPS*2 or nil,nil,current,window,'inventory')
                if not current() or not folds then return end
                vim.list_extend(window.existing,folds)
                window.inventory_row=next_row
                if done then
                    window.batches=Diff.diff(window.existing,plan.ranges,BATCH_GROUPS)
                    window.batch,window.removed,window.created=1,0,0
                    window.phase='reconcile'
                end
            elseif window.phase=='reconcile' then
                -- One batch per slice: its removals and creations cover one or
                -- more whole regions, so no region is unfolded between turns, and
                -- a fold the projection already has is never touched.
                local batch=window.batches[window.batch]
                if batch then
                    -- User fold commands (zf/zd/zE) between slices don't bump
                    -- changedtick; a stale inventory re-plans instead of guessing.
                    for _,fold in ipairs(batch.remove) do
                        if vim.fn.foldlevel(fold.start_0+1)==0 then discard_plan(s,plan);return end
                    end
                    for _,fold in ipairs(batch.remove) do
                        line_reader.record_work(buf,{native_fold_ops=1,fold_groups_visited=1})
                        vim.api.nvim_win_set_cursor(win,{fold.start_0+1,0})
                        vim.cmd('silent! normal! zD')
                        if not current() or not valid_target(buf,win) then return end
                    end
                    for _,range in ipairs(batch.create) do
                        if vim.fn.foldlevel(range.start_0+1)>0 or vim.fn.foldlevel(range.end_0+1)>0 then
                            discard_plan(s,plan);return
                        end
                    end
                    for _,range in ipairs(batch.create) do
                        line_reader.record_work(buf,{native_fold_ops=1,fold_groups_visited=1})
                        vim.cmd(string.format('%d,%dfold',range.start_0+1,range.end_0+1))
                        if not current() or not valid_target(buf,win) then return end
                        if window.opened[range.identity] then
                            line_reader.record_work(buf,{native_fold_ops=1})
                            vim.cmd(string.format('%dfoldopen',range.start_0+1))
                            if not current() or not valid_target(buf,win) then return end
                        end
                    end
                    window.removed=window.removed+#batch.remove
                    window.created=window.created+#batch.create
                    window.batch=window.batch+1
                end
                if window.batch>#window.batches then
                    window.phase='done';s.windows[win]=true
                    notify({phase='reconcile',win=win,ranges=plan.ranges,
                        removed=window.removed,created=window.created})
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
--- The rows a streamed write should fold, and the new `seen` (#290). Pure:
--- `kind(row)` names a row's lexed kind, or nil when the index has none yet.
--- An appended tool block folds from its marker to its last non-blank row. Its
--- first row counts only when the write began it (`first_col` 0): a round's
--- first call is written after the answer's prose, so its first byte continues
--- that prose row, which is never part of the block; with the column unknown,
--- nothing is folded and the reconcile does it. Streamed prose folds each
--- `summary` row from `seen`, the caller's high-water row, on; a continued row
--- is rechecked, which catches a prefix split across writes, and re-folds the
--- row still being streamed (writing into a row deletes a manual fold over it,
--- as nvim_buf_set_text re-inserts the row).
function M.written_ranges(receipt,seen,kind)
    seen=seen or -1
    local ranges={}
    if not receipt.tip or not receipt.first_row then return ranges,seen end
    local first,last=receipt.first_row,receipt.tip.row
    if receipt.kind=='append' then
        if receipt.first_col==nil then return ranges,seen end
        if receipt.first_col>0 then first=first+1 end
        while first<=last and kind(first)=='blank' do first=first+1 end
        while last>first and kind(last)=='blank' do last=last-1 end
        local anchor=first<=last and kind(first)
        if (anchor=='tool_use' or anchor=='tool_result') and kind(last) then ranges[1]={first,last} end
    elseif receipt.kind=='output' then
        for row=math.max(first,seen),last do
            if kind(row)=='summary' then ranges[#ranges+1]={row,row};seen=row end
        end
    end
    return ranges,seen
end
--- The writer's fast path (#290): fold what a streamed write produced in the
--- turn it lands, so it is never shown open while repair catches up. It is not
--- the authority (#193/#200): it folds exactly the range the confirmed
--- projection will, so the reconcile finds a match and leaves it alone, and
--- corrects any disagreement. Rows are classified by the tokens the append
--- already lexed into the shared index (#254: never re-read from the buffer).
--- Returns the new `seen`.
function M.fold_written(buf,receipt,seen)
    if not vim.api.nvim_buf_is_valid(buf) then return seen end
    local s=ensure(buf);if not s then return seen end
    local ranges
    ranges,seen=M.written_ranges(receipt,seen,function(row)
        local span=Document.query(s.doc,row,row+1)[1]
        return span and not span.opaque and span.metadata and span.metadata.token and span.metadata.token.kind or nil
    end)
    if #ranges==0 then return seen end
    for _,win in ipairs(vim.fn.win_findbuf(buf)) do
        if vim.api.nvim_get_option_value('foldmethod',{win=win})=='manual' then
            setting_foldenable=setting_foldenable+1
            local ok,err=pcall(vim.api.nvim_win_call,win,function()
                local view,enabled=vim.fn.winsaveview(),vim.wo.foldenable
                -- `:fold` sets 'foldenable'; restored so the operator's setting holds.
                local created,failure=pcall(function()
                    for _,range in ipairs(ranges) do
                        if vim.fn.foldlevel(range[1]+1)==0 and vim.fn.foldlevel(range[2]+1)==0 then
                            line_reader.record_work(buf,{native_fold_ops=1})
                            vim.cmd(string.format('%d,%dfold',range[1]+1,range[2]+1))
                        end
                    end
                end)
                restore_window(buf,win,enabled,view)
                if not created then error(failure,0) end
            end)
            setting_foldenable=setting_foldenable-1
            if not ok then error(err,0) end
        end
    end
    notify({phase='written',ranges=ranges})
    return seen
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
