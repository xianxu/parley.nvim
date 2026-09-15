-- Pure mandatory exclusions. Apply after optional filters and target expansion.
local M={}
local function inside(parent,path)return path==parent or parent=='/' and path:sub(1,1)=='/' or path:sub(1,#parent+1)==parent..'/'end
local function glob(value)
    return (value:gsub('[\\%[%]*?]',{['\\']='\\\\',['[']='[[]',[']']='[]]',['*']='[*]',['?']='[?]'}))
end
local function rg_glob(value)return (value:gsub('([\\%*%?%[%]{}!])','\\%1'))end
function M.apply(command,private,root)
    local out={};for i,value in ipairs(command)do out[i]=value end
    if not private then return out end
    local effective=private
    if root then
        if inside(private,root)then return nil,'traversal target is private recovery storage'end
        if not inside(root,private)then return out end
        effective='.'..(root=='/' and private or private:sub(#root+1))
    end
    local program=out[1]
    if program=='ls'then
        local target=root or out[#out]
        for i=2,#out-1 do
            if out[i]:sub(1,1)=='-' and out[i]:find('R',1,true) and inside(target,private)then
                return nil,'recursive listing overlaps private recovery storage'
            end
        end
    elseif program=='find'then
        table.insert(out,3,'(');table.insert(out,4,'-path');table.insert(out,5,glob(effective))
        table.insert(out,6,'-prune');table.insert(out,7,')');table.insert(out,8,'-o')
        out[#out+1]='-print'
    elseif program=='rg' or program=='grep' or program=='ack'then
        local separator
        for i=2,#out do if out[i]=='--'then separator=i;break end end
        if not separator then return nil,'search is missing its argument boundary'end
        if program=='rg'then
            local pattern=root and '!**/'..rg_glob(effective:sub(3))..'/**' or '!**'..rg_glob(effective)..'/**'
            table.insert(out,separator,'--glob');table.insert(out,separator+1,pattern)
        elseif program=='grep'then
            table.insert(out,separator,'--exclude-dir='..glob(private:match('[^/]+$')))
        else table.insert(out,separator,'--ignore-dir=is:'..private:match('[^/]+$'))end
    else return nil,'unsupported private traversal'end
    return out
end
return M
