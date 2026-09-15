-- Frozen finite replacement geometry derived only from an already-read source
-- span. Location is not write authority: callers capture every gap before IO,
-- then resolve its own grant before each patch. Protected source is never part
-- of a replacement grant, even when cancellation interrupts preparation.
local M={}
local annotation=require('parley.annotation')
local parser=require('parley.chat_parser')
local lexical=require('parley.highlight_structure')

local function integer(value)
    return type(value)=='number' and value>=0 and value%1==0
end
local function point(row,col,byte) return {row=row,col=col,byte=byte} end
local function line(value)
    assert(type(value)=='string' and not value:find('\n',1,true),'expected a source line without newline')
end

local function keep(out,first_byte,offset,row,text,first,last,kind)
    out.protected[#out.protected+1]={first_offset=offset+first,end_offset=offset+last,
        first=point(row,first,first_byte+offset+first),
        last=point(row,last,first_byte+offset+last),kind=kind,raw=text:sub(first+1,last)}
end
local function gap(out,previous,previous_offset,finish,finish_offset,text)
    out.gaps[#out.gaps+1]={first=point(previous.row,previous.col,previous.byte),
        last=point(finish.row,finish.col,finish.byte),first_offset=previous_offset,
        end_offset=finish_offset,text=text}
end

-- `lines` is exactly [first_row,last_row), not the whole chat. Each row has
-- its canonical trailing LF, INCLUDING the final physical buffer row, matching
-- Document/Editor byte accounting. Thus a suffix at row==line_count is the
-- canonical EOF boundary, not a valid nvim_buf_set_text row: the editor adapter
-- must normalize that boundary when compiling patches, never delete question
-- bytes to manufacture an EOF position. All offsets are half-open byte offsets
-- relative to first_byte; UTF-8 columns are bytes too.
function M.prepare(opts,config)
    assert(type(config)=='table','annotation config required')
    assert(type(opts)=='table' and type(opts.lines)=='table','source span required')
    assert(integer(opts.first_row) and integer(opts.first_byte),'exact source origin required')
    assert(type(opts.header_lines)=='table' and #opts.header_lines>0,'answer header required')
    for _,value in ipairs(opts.header_lines) do line(value) end
    local shell='\n'..table.concat(opts.header_lines,'\n')..'\n\n'
    local out={protected={},gaps={},shell={text=shell,stream_offset=#shell-1,
        stream_row=opts.first_row+#opts.header_lines+1,stream_col=0}}
    local branch=lexical.patterns(config).branch_prefix
    local offset=0
    for i,text in ipairs(opts.lines) do
        line(text)
        local row=opts.first_row+i-1
        if annotation.is_annotation(text,config) then
            keep(out,opts.first_byte,offset,row,text,0,#text,'line')
        else
            for _,link in ipairs(parser.extract_inline_branch_links(text,branch)) do
                keep(out,opts.first_byte,offset,row,text,link.col_start-1,link.col_end,'inline')
            end
        end
        offset=offset+#text+1
    end
    local first=point(opts.first_row,0,opts.first_byte)
    local last=point(opts.first_row+#opts.lines,0,opts.first_byte+offset)
    out.target={first_row=opts.first_row,last_row=last.row,first_byte=opts.first_byte,last_byte=last.byte}
    out.suffix=last
    local previous,previous_offset=first,0
    for i,span in ipairs(out.protected) do
        gap(out,previous,previous_offset,span.first,span.first_offset,i==1 and shell or '\n')
        previous,previous_offset=span.last,span.end_offset
    end
    gap(out,previous,previous_offset,last,offset,#out.protected==0 and shell or '\n')
    return out
end

return M
