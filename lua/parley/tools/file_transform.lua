-- PURE: bounded file transformations shared by compatibility and async IO.
local M={}
local function integer(n)return type(n)=='number' and n>=0 and n<math.huge and n%1==0 end
local function lines(bytes)
    local out={};for line in (bytes..'\n'):gmatch('([^\n]*)\n')do out[#out+1]=line end
    if bytes:sub(-1)=='\n' then table.remove(out)end
    return out
end

function M.validate(name,input,maximum)
    if name=='write_file'then
        if type(input.content)~='string'then return 'missing or invalid required field: content'end
        if #input.content>(maximum or 1048576)then return 'file transformation exceeds size limit'end
    elseif name=='propose_edits'then
        if type(input.edits)~='table'then return 'missing or invalid required field: edits'end
        if #input.edits==0 then return 'no edits provided'end
    elseif name=='edit_file'then
        if input.insert_line~=nil and input.insert_text~=nil then
            if type(input.insert_line)~='number' or not integer(math.abs(input.insert_line))
                or type(input.insert_text)~='string'then return 'invalid insert fields'end
        else
            if input.old_string==nil then return 'provide either (old_string + new_string) for replacement or (insert_line + insert_text) for insertion'end
            if type(input.old_string)~='string' or input.old_string==''then return 'missing or invalid required field: old_string'end
            if type(input.new_string)~='string'then return 'missing or invalid required field: new_string'end
        end
    end
end

function M.transform(name,input,content,path,maximum)
    maximum=maximum or 1048576
    local error=M.validate(name,input,maximum);if error then return nil,error end
    if input.insert_line~=nil and select(2,content:gsub('\n',''))>32768 then return nil,'line transformation capacity exceeded'end
    if name=='write_file' then
        return input.content,'Written '..#input.content..' bytes to '..path
    end
    if name=='propose_edits'then
        if #input.edits>128 or #content*#input.edits>8388608 then return nil,'edit work capacity exceeded'end
        local bound=#content
        for _,edit in ipairs(input.edits)do
            if type(edit)~='table' or type(edit.new_string)~='string'then return nil,'invalid edit'end
            bound=bound+#edit.new_string
            if bound>maximum then return nil,'file transformation exceeds size limit'end
        end
        local changed=require('parley.skill_edits').compute_edits(content,input.edits)
        return changed.ok and changed.content or nil,changed.msg..(changed.ok and ' to '..path or '')
    end
    if input.insert_line~=nil and input.insert_text~=nil then
        if #content+#input.insert_text+2>maximum then return nil,'file transformation exceeds size limit'end
        local old,added=lines(content),lines(input.insert_text)
        local at=math.max(0,math.min(input.insert_line,#old));local out={}
        for i=1,at do out[#out+1]=old[i]end
        for _,line in ipairs(added)do out[#out+1]=line end
        for i=at+1,#old do out[#out+1]=old[i]end
        return table.concat(out,'\n')..(content:sub(-1)=='\n' and '\n' or ''),
            'Inserted '..#added..' line(s) after line '..at..' in '..path
    end
    local old,new=input.old_string,input.new_string
    local first=content:find(old,1,true)
    if not first then return nil,'old_string not found in '..path end
    if not input.replace_all and content:find(old,first+1,true)then
        return nil,'old_string is not unique in '..path..'. Use replace_all=true to replace all occurrences.'
    end
    local escaped=old:gsub('([%(%)%.%%%+%-%*%?%[%]%^%$])','%%%1')
    local count=1
    if input.replace_all then count=select(2,content:gsub(escaped,''))end
    if #content+count*(#new-#old)>maximum then return nil,'file transformation exceeds size limit'end
    local changed
    if input.replace_all then changed=content:gsub(escaped,(new:gsub('%%','%%%%')))
    else changed=content:sub(1,first-1)..new..content:sub(first+#old)end
    return changed,'Replaced '..count..' occurrence(s) in '..path
end

function M.numbered_read(input,content,maximum_lines)
    if content==''then return ''end
    if select(2,content:gsub('\n',''))>(maximum_lines or 32768)then return nil,'line transformation capacity exceeded'end
    local start=input.offset or input.line_start or 1
    if not integer(start) or start<1 or input.line_end and not integer(input.line_end)then return nil,'invalid line range'end
    local limit=input.limit or (input.line_end and input.line_end-start+1)
    if not integer(start) or start<1 or limit and not integer(limit)then return nil,'invalid line range'end
    local source=lines(content);local out={}
    for index,line in ipairs(source)do
        if index>=start and (not limit or #out<limit)then out[#out+1]=string.format('%5d  %s',index,line)end
    end
    return table.concat(out,'\n'),nil,{truncated=#out<#source,offset=start,limit=limit}
end
return M
