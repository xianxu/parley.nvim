local ok,Deferred=pcall(require,'parley.deferred_work')

describe('deferred work',function()
    it('provides a coalesced timer owner',function()assert.is_true(ok)end)
    if not ok then return end
    it('lets native timers run before repeated slices complete',function()
        local slices,observed=0,nil
        local work=Deferred.new(function()slices=slices+1;return slices<100 end)
        for _=1,20 do work:request() end
        vim.defer_fn(function()observed=slices end,2)
        assert.is_true(vim.wait(500,function()return observed~=nil end,1))
        work:close()
        assert.is_true(observed<100)
        assert.is_true(slices<20,'requests should coalesce')
    end)
    it('cancels pending work and can be requested again',function()
        local slices=0
        local work=Deferred.new(function()slices=slices+1 end)
        work:request();work:cancel()
        vim.wait(10,function()return false end,1)
        assert.equals(0,slices)
        work:request()
        assert.is_true(vim.wait(100,function()return slices==1 end,1))
        work:close();work:request()
        vim.wait(10,function()return false end,1)
        assert.equals(1,slices)
    end)
    it('does not resurrect when cancelled inside its callback',function()
        local slices=0
        local work
        work=Deferred.new(function()slices=slices+1;work:cancel();return true end)
        work:request()
        assert.is_true(vim.wait(100,function()return slices==1 end,1))
        vim.wait(10,function()return false end,1)
        assert.equals(1,slices)
        work:close()
    end)
    it('closes its only timer and ignores already queued stale callbacks',function()
        local original=vim.defer_fn
        local timers={}
        vim.defer_fn=function(fn,delay)
            assert.equals(1,delay)
            local timer={fn=fn,closed=false}
            function timer:is_closing()return self.closed end
            function timer:stop()self.stopped=true end
            function timer:close()self.closed=true end
            timers[#timers+1]=timer;return timer
        end
        local success,err=pcall(function()
            local slices=0
            local work=Deferred.new(function()slices=slices+1;return true end)
            work:request();work:request();assert.equals(1,#timers)
            work:cancel();assert.is_true(timers[1].closed)
            work:request();timers[1].fn();assert.equals(0,slices)
            work:close();assert.is_true(timers[2].closed)
            timers[2].fn();work:request();assert.equals(0,slices);assert.equals(2,#timers)
        end)
        vim.defer_fn=original
        assert.is_true(success,err)
    end)
end)
