-- Pure argv planning: each builtin traversal runs against one pinned target.
local M={exec_marker='PARLEY_SCOPED_EXEC\n'}
local function copy(value)local out={};for i,v in ipairs(value)do out[i]=v end;return out end
function M.plan(command,private)
    if type(command)~='table' then return nil,'invalid scoped command'end
    local program=command[1]
    local positions={}
    if program=='find'then positions={2}
    elseif program=='ls'then positions={#command}
    elseif program=='rg' or program=='grep' or program=='ack'then
        local separator
        for i=2,#command do if command[i]=='--'then separator=i;break end end
        if not separator then return nil,'missing scoped search separator'end
        for i=separator+2,#command do positions[#positions+1]=i end
    else return nil,'unsupported scoped process'end
    if #positions==0 or #positions>32 then return nil,'scoped target capacity'end
    local plans={}
    for _,position in ipairs(positions)do
        local path=command[position]
        if type(path)~='string' or path:sub(1,1)~='/' or #path>4096 then return nil,'invalid scoped target'end
        local argv=copy(command)
        if program=='rg' or program=='grep' or program=='ack'then
            for i=#argv,positions[1],-1 do table.remove(argv,i)end
            argv[#argv+1]='.'
        else argv[position]='.'end
        -- A find prune target is below the pinned directory; keep that exclusion
        -- effective after replacing its original absolute traversal operand.
        if program=='rg' and private and private:sub(1,#path+1)==path..'/'then
            local function escaped(value)return (value:gsub('([%*%?%[%]{}!])','\\%1'))end
            local original='!**'..escaped(private)..'/**'
            for i=3,#argv do
                if argv[i-1]=='--glob' and argv[i]==original then
                    argv[i]='!**/'..escaped(private:sub(#path+2))..'/**'
                end
            end
        end
        if program=='find'then
            for i=3,#argv do
                if argv[i-1]=='-path' and argv[i]:sub(1,#path+1)==path..'/'then
                    argv[i]='.'..argv[i]:sub(#path+1)
                end
            end
        end
        plans[#plans+1]={path=path,command=argv,target_position=(program=='find' and 2 or #argv)}
    end
    return plans
end
function M.join_code(prior,current)
    if prior==nil then return current end
    if prior>=2 or current>=2 then return math.max(prior,current)end
    return math.min(prior,current)
end
function M.restore(text,path,program,maximum)
    maximum=maximum or 1048576
    local out,used,offset={},0,1
    while offset<=#text do
        local ending=text:find('\n',offset,true)
        local line=text:sub(offset,ending and ending-1 or #text)
        local rendered=line
        if program=='ls'then
            rendered=line:gsub('/dev/fd/%d+$',function()return path end)
        else
            local tail=line:match('^/dev/fd/%d+(.*)$')
            if tail then rendered=path..tail
            elseif line=='.'then rendered=path
            elseif line:sub(1,2)=='./' or line:sub(1,2)=='.:'then rendered=path..line:sub(2)end
        end
        if ending then rendered=rendered..'\n'end
        local remaining=math.max(0,maximum-used)
        if #rendered>remaining then out[#out+1]=rendered:sub(1,remaining);return table.concat(out),true end
        out[#out+1]=rendered;used=used+#rendered
        offset=ending and ending+1 or #text+1
    end
    return table.concat(out),false
end
return M
