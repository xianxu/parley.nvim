-- Explicit recovery UI and confirmed-save lifecycle. Snapshot files never enter
-- chat discovery or provider input; inspection uses a scratch buffer only.
local D=require('parley.document')
local Store=require('parley.answer_recovery')
local RR=require('parley.response_recovery')
local M={}
local parley
local entries={}
local order=0
local retries=setmetatable({},{__mode='k'})
local function fail(reason)return {ok=false,reason=tostring(reason)}end
local function notice(reason)vim.notify('Parley recovery: '..tostring(reason),vim.log.levels.WARN)end
local function report(job,result,phase)
    local reason=result.cleanup_error or (not result.ok and result.reason)
    local e=entries[job]
    local key=tostring(phase or 'publication')..tostring(reason)
    if reason and (not e or e.reported~=key)then
        if e then e.reported=key end
        notice(reason)
    end
    return result
end
local function timestamp(path)
    local name=vim.fn.fnamemodify(path,':t')
    return require('parley.chat_slug').parse_filename(name) or 'legacy:'..name
end
local function open_store(create)
    if not parley then return nil,'recovery setup required'end
    local directory=require('parley.recovery_paths').directory(parley.config.state_dir)
    return Store.open({directory=directory,create=create})
end
local function slice(lines,first,last)
    local result={};for i=first,last do result[#result+1]=lines[i] or ''end
    return table.concat(result,'\n')
end
local function geometry(lines,parsed,index,offset)
    local exchange=parsed.exchanges[index]
    if not exchange or not exchange.question or not exchange.answer then return nil end
    local q=exchange.question;local last=exchange.answer.line_end
    local footer=require('parley.chat_respond')._trailing_footnote_boundary(lines,q.line_end)
    if footer then last=math.min(last,footer)end
    local previous=parsed.exchanges[index-1]
    local predecessor=''
    if previous and previous.question then
        predecessor=slice(lines,previous.preface and previous.preface.line_start or previous.question.line_start,
            previous.answer and previous.answer.line_end or previous.question.line_end)
    end
    offset=offset or 0
    return {question=slice(lines,exchange.preface and exchange.preface.line_start or q.line_start,q.line_end),
        predecessor=predecessor,region={first={row=q.line_end-1+offset,col=#lines[q.line_end]},
            last={row=last-1+offset,col=#lines[last]}},bytes='\n'..slice(lines,q.line_end+1,last),
        question_row=q.line_start-1+offset}
end
local function association(path,root,value)
    return {timestamp=timestamp(path),path=path,root=root,question=vim.fn.sha256(value.question),
        predecessor=vim.fn.sha256(value.predecessor)}
end
local function same_chat(a,b)return a.timestamp==b.timestamp and a.root==b.root end
local function same_source(a,b)return same_chat(a,b) and a.question==b.question and a.predecessor==b.predecessor end
local function materialize(buf,lines,path,root)
    lines=lines or vim.api.nvim_buf_get_lines(buf,0,-1,false)
    local parsed=parley.parse_chat(lines,parley.chat_parser.find_header_end(lines))
    local result={}
    for index in ipairs(parsed.exchanges)do
        local value=geometry(lines,parsed,index)
        if value then
            value.association=association(path,root,value);value.replacement={bytes=value.bytes};value.target=value
            result[#result+1]=value
        end
    end
    return result
end
local function root_for(buf)return require('parley.neighborhood').policy_for_buf(buf).write_root end
local function current_region(doc,entity,buf)
    local marker=D.lookup(doc,entity);if not marker then return nil,'missing exchange'end
    local extent=D.exchange(doc,marker.start_row)
    if extent.status~='ready' or extent.identity~=entity then return nil,'exchange is not confirmed'end
    local first=vim.api.nvim_buf_get_offset(buf,extent.first)
    local finish=math.min(extent.last+1,D.size(doc).rows)
    local last=vim.api.nvim_buf_get_offset(buf,finish)
    if first<0 or last<first or last-first>16*1024*1024 then return nil,'recovery region limit'end
    -- This is one explicit answer materialization at settlement, never a stream
    -- chunk/typing scan. New prompts lie outside this indexed exchange extent.
    local lines=vim.api.nvim_buf_get_lines(buf,extent.first,finish,false)
    local parsed=parley.parse_chat(lines,0)
    local value=geometry(lines,parsed,1,extent.first)
    return value and value.region or nil,'answer is not available'
end
function M.setup(value)
    parley=value
    local group=vim.api.nvim_create_augroup('ParleyAnswerRecovery',{clear=true})
    vim.api.nvim_create_autocmd('BufWritePost',{group=group,callback=function(args)M.saved(args.buf)end})
    vim.api.nvim_create_autocmd('BufWipeout',{group=group,callback=function(args)
        local copy={};for job,e in pairs(entries)do if e.buf==args.buf then copy[#copy+1]=job end end
        for _,job in ipairs(copy)do M.release(job)end
    end})
end
function M.start(doc,spec)
    local function admitted()
        if D.get(spec.buf)~=doc then return false end
        if not spec.ctx then return true end
        local snapshot=D.snapshot(doc);local grant=snapshot.grants[spec.ctx.grant]
        return snapshot.epoch==spec.ctx.epoch and grant and grant.status=='valid'
            and grant.entity==spec.ctx.entity and grant.generation==spec.ctx.generation
            and (not spec.ctx.cancelled or not spec.ctx.cancelled())
    end
    if not admitted()then return nil,'replacement ownership changed'end
    local storage,err=open_store();if not storage then return nil,err end
    local value=geometry(spec.lines,spec.parsed,spec.index)
    if not value then return nil,'no previous answer'end
    local entity=spec.entity or D.exchange(doc,spec.region.first.row).identity
    if not entity then return nil,'exchange is not confirmed'end
    local target,why=current_region(doc,entity,spec.buf);if not target then return nil,why end
    local a=association(spec.path,spec.root,value)
    local key
    local retry=retries[doc] and retries[doc][entity]
    if retry and retry.epoch==D.snapshot(doc).epoch and (retry.proof
        and D.validate_revision(doc,retry.proof).status=='valid'
        or not retry.proof and retry.tick==vim.api.nvim_buf_get_changedtick(spec.buf))then
        key=retry.key;a=vim.deepcopy(retry.association)
    end
    for job,e in pairs(entries)do
        if e.doc==doc and e.entity==entity then key=e.key;a=vim.deepcopy(e.association)
            if RR.snapshot(job).status~='captured' then M.release(job)end
            break
        end
    end
    if not key then
        local records,list_error=Store.list(storage);if not records then return nil,list_error end
        local matching={};for _,record in ipairs(records)do if same_source(a,record.association)then matching[#matching+1]=record end end
        if #matching>1 then return nil,'ambiguous retained recovery snapshots'end
        if #matching==1 then
            local candidates=materialize(spec.buf,spec.lines,spec.path,spec.root)
            local resolved=Store.resolve(storage,matching[1].id,candidates)
            if not resolved.ok or resolved.target.question_row~=value.question_row then return nil,'retained recovery requires inspection or explicit restore'end
            key=matching[1].key;a=vim.deepcopy(matching[1].association)
        end
    end
    key=key or vim.fn.sha256(vim.json.encode({a.timestamp,a.root,D.snapshot(doc).epoch,entity}))
    -- Preserve fixed User capacity. Eviction drops volatile automatic association
    -- only; it never deletes the durable original or weakens fresh-target proof.
    if D.user_guard_stats(doc).live>=48 then
        local oldest
        for job,e in pairs(entries)do
            if e.doc==doc and RR.snapshot(job).status=='settled' and (not oldest or e.order<entries[oldest].order)then oldest=job end
        end
        if oldest then M.release(oldest)end
    end
    if not admitted()then return nil,'replacement ownership changed'end
    local job,reason=RR.capture(doc,{buf=spec.buf,store=storage,key=key,association=a,region=target,annotations=spec.annotations,
        on_release=function(retired)
            local e=entries[retired];entries[retired]=nil
            if e and e.pending then e.pending:cancel()end
        end})
    if not job then return nil,reason end
    order=order+1;entries[job]={buf=spec.buf,doc=doc,entity=entity,key=key,association=a,order=order,store=storage}
    return job
end
function M.publish(job,ctx)
    local result=RR.publish(job,ctx)
    -- The preparation owner reports refusal; successful publication can still
    -- carry a failed predecessor cleanup that would otherwise be invisible.
    if result.ok then report(job,result)end
    return result
end
-- Async completion keeps its grant until semantic repair can certify the answer.
-- A User proof fences question/answer bytes through repair, permitting disjoint
-- edits while rejecting edit/undo ABA. Numeric offsets are used only to capture
-- this proof synchronously from the current grant, never after a yield.
function M.settle(job,ctx,done)
    local function refuse(result)
        if not done then return result end
        -- Async callers always receive the same cancellation interface, even
        -- when refusal completes inline before they can retain the handle.
        local handle={cancel=function(_,resolved)if resolved then resolved()end end}
        done(result)
        return handle
    end
    local e=entries[job]
    if not e then
        return refuse(fail('recovery job released'))
    end
    if type(ctx)~='table'then return refuse(fail('replacement ownership changed'))end
    local fence
    local function attempt()
        local region,err=current_region(e.doc,e.entity,e.buf)
        if not region then return fail(err)end
        if fence then
            local proof=D.resolve_user(e.doc,fence)
            local bound=proof and proof.regions[1]
            local function before(a,b)return a.row<b.row or a.row==b.row and a.col<=b.col end
            if not bound or not before(bound.first,region.first) or not before(region.last,bound.last)then
                return fail('replacement escaped settlement evidence')
            end
        end
        return RR.settle(job,ctx,region)
    end
    if not done then return report(job,attempt())end
    local snapshot=D.snapshot(e.doc)
    local epoch=snapshot.epoch
    local grant=snapshot.grants[ctx.grant]
    local marker=D.lookup(e.doc,e.entity)
    local function position(offset)
        -- O(log rows) native offset lookup also works while semantic rows are
        -- opaque; it reads no text and supplies no post-yield write authority.
        local low,high=0,vim.api.nvim_buf_line_count(e.buf)
        while low+1<high do
            local mid=math.floor((low+high)/2)
            if vim.api.nvim_buf_get_offset(e.buf,mid)<=offset then low=mid else high=mid end
        end
        return {row=low,col=offset-vim.api.nvim_buf_get_offset(e.buf,low)}
    end
    local why
    if marker and grant and grant.status~='revoked' and grant.entity==e.entity
        and grant.generation==ctx.generation and epoch==ctx.epoch then
        fence,why=D.capture_user(e.doc,{operation='answer-recovery-pending-settlement',regions={{
            first={row=marker.start_row,col=0},last=position(grant.last)}}})
    end
    if not fence then
        local result=fail(why or 'replacement ownership changed');report(job,result);return refuse(result)
    end
    local handle,work,finished={},nil,false
    local function finish(result)
        if finished then return end
        finished=true;if work then work:close();work=nil end
        D.cancel_user(e.doc,fence);fence=nil
        if e.pending==handle then e.pending=nil end
        local callback=done;done=nil
        report(job,result);callback(result)
    end
    function handle.cancel(_,resolved)
        finish(fail('replacement settlement cancelled'))
        if resolved then resolved()end
    end
    work=require('parley.deferred_work').new(function()
        if entries[job]~=e or D.get(e.buf)~=e.doc or D.snapshot(e.doc).epoch~=epoch
            or not vim.api.nvim_buf_is_valid(e.buf) or not D.resolve_user(e.doc,fence)
            or ctx.cancelled and ctx.cancelled()then
            finish(fail('replacement changed before settlement'));return false
        end
        local result=attempt()
        if result.reason=='exchange is not confirmed'then D.repair_step(e.doc);return true end
        finish(result);return false
    end)
    e.pending=handle;work:request();return handle
end
function M.release(job)RR.release(job);entries[job]=nil end
function M.finish(job,outcome)
    local e=entries[job]
    if outcome~='success' and e then
        -- Retain identity only, never a write grant or store. Reload/detach drop
        -- the entire epoch; intervening human edits refuse automatic retry.
        if D.get(e.buf)==e.doc and RR.snapshot(job).id then
            local retained=retries[e.doc]
            if not retained then
                retained={};retries[e.doc]=retained
                local doc,buf=e.doc,e.buf;local off
                off=D.subscribe(doc,function(event)
                    if event.kind=='reload' or event.kind=='detach'then retries[doc]=nil;off()
                    elseif event.kind=='repair'then
                        for entity,r in pairs(retained)do
                            if not r.proof and r.tick==vim.api.nvim_buf_get_changedtick(buf)then
                                local proof=D.capture_revision(doc,entity,'context')
                                if proof.status=='ready'then r.proof=proof.token end
                            end
                        end
                    end
                end)
            end
            if vim.tbl_count(retained)>=48 then
                local oldest;for entity,r in pairs(retained)do if not oldest or r.order<retained[oldest].order then oldest=entity end end
                retained[oldest]=nil
            end
            local proof=D.capture_revision(e.doc,e.entity,'context')
            retained[e.entity]={proof=proof.status=='ready' and proof.token or nil,key=e.key,association=vim.deepcopy(e.association),order=e.order,
                epoch=D.snapshot(e.doc).epoch,tick=vim.api.nvim_buf_get_changedtick(e.buf)}
        end
        M.release(job)
    elseif e and RR.snapshot(job).status~='settled'then
        -- Completion may succeed while human edits make settlement unavailable.
        -- Keep the durable copy, but no stale host ownership or fresh authority.
        M.release(job)
    end
end
function M.inspect_record(id)local storage,err=open_store();if not storage then return nil,err end;return Store.inspect(storage,id)end
function M.list(buf)
    buf=buf or vim.api.nvim_get_current_buf()
    local storage,err=open_store();if not storage then return nil,err end
    local records,why=Store.list(storage);if not records then return nil,why end
    local a={timestamp=timestamp(vim.api.nvim_buf_get_name(buf)),root=root_for(buf)}
    local out={};for _,record in ipairs(records)do if same_chat(record.association,a)then out[#out+1]=record end end
    return out
end
function M.saved(buf)
    local list={};for job,e in pairs(entries)do if e.buf==buf and RR.snapshot(job).status=='settled'then list[#list+1]=job end end
    if #list==0 then return end
    local path=vim.api.nvim_buf_get_name(buf)
    local stat=(vim.uv or vim.loop).fs_stat(path)
    if not stat or stat.size>256*1024*1024 then return end
    local ok,lines=pcall(vim.fn.readfile,path);if not ok then notice(lines);return end
    for _,job in ipairs(list)do
        local e=entries[job]
        if e then
            local result=RR.saved(job,{read=function()
                local candidates=materialize(buf,lines,path,e.association.root);local match
                for _,candidate in ipairs(candidates)do
                    if same_source(candidate.association,e.association)then
                        if match then return nil,'ambiguous saved exchange'end;match=candidate
                    end
                end
                return match and match.bytes or nil,'saved exchange not found'
            end})
            report(job,result,'save')
            if result.ok then M.release(job)end
        end
    end
end
function M.snapshot(job)return RR.snapshot(job)end
local function scratch(record,title)
    local buf=vim.api.nvim_create_buf(false,true)
    require('parley.buffer_edit').replace_all_lines(buf,vim.split(record.bytes,'\n',{plain=true}))
    vim.bo[buf].buftype='nofile';vim.bo[buf].bufhidden='wipe';vim.bo[buf].swapfile=false
    vim.api.nvim_set_current_buf(buf);vim.bo[buf].modifiable=false
    vim.b[buf].parley_recovery_id=record.id;vim.b[buf].parley_recovery_title=title
    return buf
end
local function pick(buf,done)
    local records,err=M.list(buf);if not records then notice(err);return end
    if #records==0 then notice('no recovery snapshots for this chat');return end
    local allowed={};for _,record in ipairs(records)do allowed[record]=true end
    vim.ui.select(records,{prompt='Answer recovery:',format_item=function(record)
        return record.association.timestamp..' '..record.id:sub(1,8)
    end},function(record)if record and allowed[record]then done(record)end end)
end
function M.inspect(buf)
    buf=buf or vim.api.nvim_get_current_buf()
    pick(buf,function(item)local record,err=M.inspect_record(item.id);if record then scratch(record,'Original answer')else notice(err)end end)
end
local function discard_snapshot(storage,id,kind)
    local result=Store.cleanup(storage,id,{kind=kind or 'discard'})
    if result.ok then
        local done={};for job in pairs(entries)do if RR.snapshot(job).id==id then done[#done+1]=job end end
        for _,job in ipairs(done)do M.release(job)end
    end
    return result
end
-- Called only after the file deletion owner confirms success, never on buffer
-- unload. Recheck absence here too; an error or a recreated file retains copies.
function M.deleted(path)
    if type(path)~='string' or path==''then return fail('deleted chat path required')end
    local uv=vim.uv or vim.loop
    local present,why=uv.fs_lstat(path)
    if present or not tostring(why):find('ENOENT',1,true)then return fail('chat deletion is not confirmed')end
    local storage,err,status=open_store(false)
    if not storage then return status=='absent' and {ok=true} or fail(err)end
    local records,list_error=Store.list(storage);if not records then return fail(list_error)end
    local function canonical(value)return vim.fn.resolve(vim.fn.fnamemodify(value,':p'))end
    local exact={};local key=canonical(path)
    for _,record in ipairs(records)do if canonical(record.association.path)==key then exact[#exact+1]=record end end
    local selected=exact
    if #selected==0 then
        local policy,policy_error=require('parley.neighborhood').policy_for_path(path,parley.config,
            require('parley.chat_dirs').get_chat_roots())
        if not policy then return fail(policy_error)end
        local sources={};selected={}
        for _,record in ipairs(records)do
            local a=record.association
            if a.timestamp==timestamp(path) and a.root==policy.write_root then
                sources[canonical(a.path)]=true;selected[#selected+1]=record
            end
        end
        local count=0;for _ in pairs(sources)do count=count+1 end
        if count>1 then return fail('ambiguous renamed chat recovery association')end
        for source in pairs(sources)do
            -- The existing resolver knows slug variants and configured roots.
            -- Any still-existing resolution means this deletion cannot identify
            -- the retained chat uniquely; never choose its ordinal tie-break.
            local ok,resolved=pcall(parley.resolve_chat_path,source,vim.fn.fnamemodify(path,':h'))
            if not ok then return fail('chat association resolution failed')end
            local source_stat,source_error=uv.fs_lstat(source)
            local resolved_stat,resolved_error
            if resolved then resolved_stat,resolved_error=uv.fs_lstat(resolved)end
            if source_stat or not tostring(source_error):find('ENOENT',1,true)
                or resolved and (resolved_stat or not tostring(resolved_error):find('ENOENT',1,true))then
                return fail('another associated chat still exists')
            end
        end
    end
    local count,failure=0
    for _,record in ipairs(selected)do
        local recreated,recheck=uv.fs_lstat(path)
        if recreated or not tostring(recheck):find('ENOENT',1,true)then return fail('chat deletion evidence changed')end
        local result=discard_snapshot(storage,record.id,'chat_deleted')
        if result.ok then count=count+1 else failure=result.reason end
    end
    return failure and {ok=false,reason=failure,removed=count} or {ok=true,removed=count}
end
function M.discard(buf)
    buf=buf or vim.api.nvim_get_current_buf();local storage,err=open_store();if not storage then notice(err);return end
    pick(buf,function(item)
        vim.ui.input({prompt='Discard this recovery snapshot permanently? Type yes: '},function(answer)
            if answer~='yes'then return end
            local result=discard_snapshot(storage,item.id)
            if not result.ok then notice(result.reason);return end
        end)
    end)
end
local function restore_intent(buf,captured_row)
    buf=buf or vim.api.nvim_get_current_buf()
    local doc=D.get(buf);local storage,err=open_store()
    if not doc or not storage then notice(err or 'chat document unavailable');return end
    local records,list_error=M.list(buf)
    if not records then notice(list_error);return end
    local path=vim.api.nvim_buf_get_name(buf)
    local tick=vim.api.nvim_buf_get_changedtick(buf)
    local candidates=materialize(buf,nil,path,root_for(buf))
    local selected;local row=captured_row or vim.api.nvim_win_get_cursor(0)[1]-1
    for _,candidate in ipairs(candidates)do
        if row>=candidate.question_row and row<=candidate.region.last.row then selected=candidate end
    end
    local guarded={}
    local function release()for _,candidate in ipairs(guarded)do D.cancel_user(doc,candidate.guard)end end
    for _,candidate in ipairs(candidates)do
        local needed=candidate==selected
        for _,record in ipairs(records)do
            if same_source(record.association,candidate.association) and record.replacement.bytes==candidate.bytes then needed=true;break end
        end
        if needed then
            candidate.guard=D.capture_user(doc,{operation='recovery-picker-target',regions={candidate.region}})
            if not candidate.guard then release();notice('too many matching recovery targets; select fewer snapshots');return end
            guarded[#guarded+1]=candidate
        end
    end
    if vim.api.nvim_buf_get_changedtick(buf)~=tick then release();notice('chat changed while capturing recovery targets');return end
    local function apply_target(item,target)
        local result=Store.restore(storage,item.id,{validate=function()
            if D.get(buf)~=doc or not D.resolve_user(doc,target.guard)then return nil,'selected answer changed'end
            return target.guard
        end,apply=function(token,bytes)
            local applied=D.apply_user(doc,token,{patches={{region=1,text=bytes}}})
            return {ok=applied.status=='applied',reason=applied.reason or applied.status}
        end})
        release();if not result.ok then notice(result.reason)end
    end
    return {release=release,choose=function(item)
        local runtime
        for job,e in pairs(entries)do if e.doc==doc and RR.snapshot(job).id==item.id then runtime=job;break end end
        if runtime and RR.snapshot(runtime).status=='settled' then
            local restored=RR.restore(runtime)
            if restored.ok then release();return end
        end
        local resolved=Store.resolve(storage,item.id,candidates)
        if resolved.ok and not runtime then apply_target(item,resolved.target);return end
        if not selected or not D.resolve_user(doc,selected.guard)then release();notice('select an unchanged answer to restore into');return end
        -- Preview exactly the captured target bytes. Returning focus elsewhere
        -- cannot change the saved target/guard used by confirmation.
        scratch({id=item.id,bytes=selected.bytes},'Current answer to replace')
        vim.ui.input({prompt='Replace the previewed answer with its recovery snapshot? Type yes: '},function(answer)
            if answer=='yes'then apply_target(item,selected)else release()end
        end)
    end}
end
function M.restore(buf)
    buf=buf or vim.api.nvim_get_current_buf()
    local intent=restore_intent(buf);if not intent then return end
    local records,err=M.list(buf)
    if not records or #records==0 then intent.release();notice(err or 'no recovery snapshots');return end
    local allowed={};for _,item in ipairs(records)do allowed[item]=true end
    vim.ui.select(records,{prompt='Restore answer snapshot:',format_item=function(item)return item.id:sub(1,8)end},function(item)
        if item and allowed[item]then intent.choose(item)else intent.release()end
    end)
end
function M.export(id)
    local record,err=M.inspect_record(id);if not record then return nil,err end
    return {filename=id..'.md',bytes=record.bytes,annotations=record.annotations,association=record.association}
end
function M.open(buf)
    buf=buf or vim.api.nvim_get_current_buf()
    local intent=restore_intent(buf);if not intent then return end
    local records,err=M.list(buf)
    if not records or #records==0 then intent.release();notice(err or 'no recovery snapshots');return end
    local allowed={};for _,record in ipairs(records)do allowed[record]=true end
    vim.ui.select(records,{prompt='Answer recovery:',format_item=function(record)return record.id:sub(1,8)end},function(item)
        if not item or not allowed[item]then intent.release();return end
        vim.ui.select({'Inspect / export','Restore','Discard'}, {prompt='Recovery action:'},function(action)
            if action=='Restore'then intent.choose(item);return end
            intent.release()
            if action=='Inspect / export'then
                local record,why=M.inspect_record(item.id);if record then scratch(record,'Original answer')else notice(why)end
            elseif action=='Discard'then
                local storage,why=open_store();if not storage then notice(why);return end
                vim.ui.input({prompt='Discard this recovery snapshot permanently? Type yes: '},function(answer)
                    if answer~='yes'then return end
                    local result=discard_snapshot(storage,item.id)
                    if not result.ok then notice(result.reason)end
                end)
            end
        end)
    end)
end
return M
