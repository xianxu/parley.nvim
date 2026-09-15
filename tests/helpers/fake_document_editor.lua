-- Stateful native callback double; text is owned here, never by the adapter.
local M={}
function M.new(lines)
    local fake={lines=vim.deepcopy(lines or {''}),tick=1}
    local function offset(_,row)
        if row<0 or row>#fake.lines then return -1 end
        local n=0
        for i=1,row do n=n+#fake.lines[i]+1 end
        return n
    end
    local function text(_,sr,sc,er,ec)
        local result={}
        for row=sr,er do
            result[#result+1]=fake.lines[row+1]:sub(row==sr and sc+1 or 1,row==er and ec or -1)
        end
        return result
    end
    local function set_text(_,sr,sc,er,ec,replacement)
        if fake.fail_before then error('before delivery') end
        local sb,eb=offset(nil,sr)+sc,offset(nil,er)+ec
        local payload=table.concat(replacement,'\n')
        local all=table.concat(fake.lines,'\n')..'\n'
        all=all:sub(1,sb)..payload..all:sub(eb+1)
        fake.lines=vim.split(all:sub(1,-2),'\n',{plain=true})
        fake.tick=fake.tick+1
        if fake.before_delivery then local hook=fake.before_delivery; fake.before_delivery=nil; hook(fake) end
        fake.callbacks.on_bytes('bytes',fake.buf,fake.tick,sr,sc,sb,er-sr,er==sr and ec-sc or ec,eb-sb,
            #replacement-1,#replacement==1 and #payload or #replacement[#replacement],#payload)
        if fake.after_delivery then local hook=fake.after_delivery; fake.after_delivery=nil; hook(fake) end
        if fake.mutate_then_error then error('after mutation') end
    end
    fake.driver={line_count=function() return #fake.lines end,offset=offset,text=text,
        lines=function(_,a,b) local out={}; if b<0 then b=#fake.lines end; for i=a+1,b do out[#out+1]=fake.lines[i] end; return out end,
        set_text=set_text,attach=function(buf,_,callbacks) fake.buf=buf;fake.callbacks=callbacks;return true end,
        detach=function() fake.callbacks.on_detach('detach',fake.buf) end}
    function fake:edit(sr,sc,er,ec,replacement) set_text(self.buf,sr,sc,er,ec,replacement) end
    function fake:set_lines(first,last,replacement)
        if last<0 then last=#self.lines end
        if self.fail_before then error('before delivery') end
        local sb,eb=offset(nil,first),offset(nil,last)
        local next_lines={}
        for i=1,first do next_lines[#next_lines+1]=self.lines[i] end
        for _,line in ipairs(replacement) do next_lines[#next_lines+1]=line end
        for i=last+1,#self.lines do next_lines[#next_lines+1]=self.lines[i] end
        self.lines=#next_lines==0 and {''} or next_lines
        local bytes=0
        for _,line in ipairs(replacement) do bytes=bytes+#line+1 end
        self.tick=self.tick+1
        self.callbacks.on_bytes('bytes',self.buf,self.tick,first,0,sb,last-first,0,eb-sb,#replacement,0,bytes)
        if self.mutate_then_error then error('after mutation') end
    end
    function fake:reload(new_lines)
        self.lines=vim.deepcopy(new_lines);self.tick=self.tick+1;self.callbacks.on_reload('reload',self.buf)
    end
    function fake:changedtick() self.tick=self.tick+1;self.callbacks.on_changedtick('changedtick',self.buf,self.tick) end
    return fake
end
return M
