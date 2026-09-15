-- Stateful async producer: declarations, bytes and cleanup are independently driven.
local M={}
function M.new()
    local fake={preparations={},requests={},cancellations={},finalizations={}}
    fake.adapters={
        prepare=function(ctx,callbacks)
            local item={ctx=ctx,callbacks=callbacks};fake.preparations[#fake.preparations+1]=item;return item
        end,
        request=function(ctx,callbacks)
            local item={ctx=ctx,callbacks=callbacks};fake.requests[#fake.requests+1]=item;return item
        end,
        finalize=function(ctx,done)fake.finalizations[#fake.finalizations+1]=ctx;done('applied')end,
        cancel_operation=function(ctx,resolved)
            fake.cancellations[#fake.cancellations+1]={ctx=ctx,resolved=resolved}
        end,
    }
    function fake:prepare(index,input)
        local item=self.preparations[index or 1]
        item.callbacks.prepared(input or item.ctx.input);item.callbacks.resolved()
    end
    function fake:output(index,bytes,seq)return self.requests[index].callbacks.output(bytes,seq)end
    function fake:complete(index)
        local cb=self.requests[index].callbacks;cb.complete();cb.resolved()
    end
    return fake
end
return M
