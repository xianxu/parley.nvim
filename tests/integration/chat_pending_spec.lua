local Pending=require('parley.chat_pending')
local function fake_runtime()
    local now = 0
    local queue = {}
    local timers = {}
    local next_timer = 0

    local scheduler = {}
    scheduler.enqueue = function(callback)
        table.insert(queue, callback)
    end
    local function register(delay, repeating, callback)
        next_timer = next_timer + 1
        local timer = {
            due = now + delay,
            interval = repeating and delay or nil,
            callback = callback,
            closed = false,
        }
        timers[next_timer] = timer
        return function()
            if timer.closed then
                return
            end
            timer.closed = true
        end
    end
    scheduler.after = function(delay, callback)
        return register(delay, false, callback)
    end
    scheduler.every = function(delay, callback)
        return register(delay, true, callback)
    end

    local runtime = {
        clock = { now_ms = function() return now end },
        scheduler = scheduler,
    }
    function runtime:drain()
        while #queue > 0 do
            local callback = table.remove(queue, 1)
            callback()
        end
    end
    function runtime:advance(milliseconds)
        now = now + milliseconds
        local again = true
        while again do
            again = false
            for _, timer in pairs(timers) do
                if not timer.closed and timer.due <= now then
                    if timer.interval then
                        timer.due = timer.due + timer.interval
                    else
                        timer.closed = true
                    end
                    timer.callback()
                    again = true
                end
            end
        end
    end
    function runtime:fire_earliest_timer_early()
        local earliest
        for _, timer in pairs(timers) do
            if not timer.closed and (not earliest or timer.due < earliest.due) then
                earliest = timer
            end
        end
        assert(earliest, "expected an open timer")
        if earliest.interval then
            earliest.due = earliest.due + earliest.interval
        else
            earliest.closed = true
        end
        earliest.callback()
    end
    function runtime:open_timer_count()
        local count = 0
        for _, timer in pairs(timers) do
            if not timer.closed then
                count = count + 1
            end
        end
        return count
    end
    return runtime
end

local buffers={}
local function fixture()
    local buf=vim.api.nvim_create_buf(false,true);buffers[#buffers+1]=buf
    vim.api.nvim_buf_set_lines(buf,0,-1,false,{'🤖: first','body','🤖: second','body'})
    return buf
end
local function start(buf,runtime,generation,row,extra)
    local opts={buf=buf,generation=generation,entity='entity'..generation,agent='agent'..generation,
        alive=function()return true end,resolve_tip=function()return {row=row,col=0}end,
        scheduler=runtime.scheduler,clock=runtime.clock,choose_verb_index=function()return 1 end}
    for k,v in pairs(extra or {})do opts[k]=v end
    return Pending.start(opts)
end
local function marks(buf)
    return vim.api.nvim_buf_get_extmarks(buf,vim.api.nvim_get_namespaces().parley_chat_pending,0,-1,{details=true})
end
describe('generation-scoped pending presentation',function()
    after_each(function()
        Pending.cancel_all()
        for _,buf in ipairs(buffers)do if vim.api.nvim_buf_is_valid(buf)then vim.api.nvim_buf_delete(buf,{force=true})end end
        buffers={}
    end)
    it('shows two independent pending writers and cancelling one leaves the other active',function()
        local buf=fixture();local rt=fake_runtime()
        local a=start(buf,rt,1,0);local b=start(buf,rt,2,2)
        rt:drain();rt:advance(1000);rt:drain()
        assert.equals(2,#marks(buf));assert.equals(2,Pending.identity(buf).count)
        local version=Pending.identity(buf).version;assert.equals(version,Pending.identity(buf).version)
        a:cancel();assert.equals(1,#marks(buf));assert.is_false(Pending.is_active(buf,1));assert.is_true(Pending.is_active(buf,2))
        assert.is_not_equal(version,Pending.identity(buf).version);b:complete()
        assert.is_false(Pending.is_active(buf));assert.equals(0,rt:open_timer_count())
    end)
    it('hides synchronously after committed bytes and never owns an emitter or completion callback',function()
        local buf=fixture();local rt=fake_runtime();local called=false
        local s=start(buf,rt,1,0,{emit_content=function()called=true end})
        rt:drain();rt:advance(1000);rt:drain();assert.equals(1,#marks(buf))
        assert.is_nil(s.content);assert.is_nil(s.before_write)
        vim.api.nvim_buf_set_text(buf,1,0,1,0,{'committed '})
        s:written(1,10);assert.equals(0,#marks(buf));assert.equals(1,s.anchor_line)
        assert.equals('committed body',vim.api.nvim_buf_get_lines(buf,1,2,false)[1])
        s:complete(function()called=true end)
        assert.is_false(called);assert.is_true(s.finished);assert.equals(0,rt:open_timer_count())
    end)
    it('renders typed progress without adding buffer characters or waiting for minimum visibility',function()
        local buf=fixture();local rt=fake_runtime();local s=start(buf,rt,1,0)
        local before=vim.api.nvim_buf_get_lines(buf,0,-1,false)
        rt:drain();rt:advance(1000);rt:drain()
        s:progress({kind='reasoning',text='thinking',message='Reasoning...'});s:activity();rt:drain()
        assert.equals('Reasoning: thinking',marks(buf)[1][4].virt_lines[1][1][1])
        assert.same(before,vim.api.nvim_buf_get_lines(buf,0,-1,false));s:complete();assert.equals(0,#marks(buf))
    end)
    it('retires all timers and owned autocmds on detach',function()
        local buf=fixture();local rt=fake_runtime();local a=start(buf,rt,1,0);start(buf,rt,2,2)
        rt:drain();vim.api.nvim_buf_delete(buf,{force=true});rt:advance(20000);rt:drain()
        assert.is_true(a.finished);assert.is_false(Pending.is_active(buf));assert.equals(0,rt:open_timer_count())
        local ok,list=pcall(vim.api.nvim_get_autocmds,{group='ParleyChatPending'..buf})
        assert.is_true(not ok or #list==0)
    end)
    it('still reveals after a long main-loop delay and rearms early timer delivery',function()
        local buf=fixture();local rt=fake_runtime();local s=start(buf,rt,1,0)
        rt:fire_earliest_timer_early();rt:drain();assert.equals(0,#marks(buf))
        rt:advance(20000);rt:drain();assert.equals(1,#marks(buf));s:complete()
    end)
    it('does not restart a frame timer after its tip becomes unavailable',function()
        local buf=fixture();local rt=fake_runtime()
        local s=start(buf,rt,1,0,{resolve_tip=function()return nil end})
        rt:advance(1000);rt:drain()
        assert.is_true(s.finished);assert.equals(0,rt:open_timer_count());assert.is_false(Pending.is_active(buf))
    end)
    it('releases registry ownership when timer creation fails during startup',function()
        local buf=fixture();local rt=fake_runtime()
        local original=rt.scheduler.after;local count=0
        rt.scheduler.after=function(...)
            count=count+1;if count==2 then error('timer unavailable')end;return original(...)
        end
        assert.has_error(function()start(buf,rt,1,0)end)
        assert.is_false(Pending.is_active(buf));assert.equals(0,rt:open_timer_count())
    end)
    it('retires immediately when the shared document detaches before buffer deletion',function()
        local buf=fixture();local rt=fake_runtime()
        local D=require('parley.document');local doc=D.attach(buf,{schedule=false})
        local s=start(buf,rt,1,0);rt:advance(1000);rt:drain()
        D.detach(doc)
        assert.is_true(s.finished);assert.equals(0,rt:open_timer_count());assert.equals(0,#marks(buf))
    end)
    it('refuses duplicate identities and more than four presentation sessions',function()
        local buf=fixture();local rt=fake_runtime()
        for i=1,4 do start(buf,rt,i,0)end
        assert.has_error(function()start(buf,rt,1,0)end)
        assert.has_error(function()start(buf,rt,5,0)end)
    end)
    it('uses current resolved tips and retires only the generation whose liveness expired',function()
        local buf=fixture();local rt=fake_runtime();local alive=true;local row=0
        local a=start(buf,rt,1,0,{alive=function()return alive end,resolve_tip=function()return {row=row,col=0}end})
        start(buf,rt,2,2);rt:drain();row=1;rt:advance(1000);rt:drain()
        assert.equals(1,marks(buf)[1][2]);alive=false;rt:advance(120);rt:drain()
        assert.is_true(a.finished);assert.is_true(Pending.is_active(buf,2))
    end)
end)
