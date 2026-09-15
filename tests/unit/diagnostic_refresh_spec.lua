local diagnostic_refresh = require("parley.diagnostic_refresh")

describe('streaming diagnostic primitives',function()
    it('indexes split diagnostic candidates without changing semantic token equality',function()
        local G=require('parley.document.grammar')
        local cursor=G.lex_start()
        cursor=G.lex_step(cursor,'x2026-04-18T00:00:',false,{bytes=4096})
        local _,token=G.lex_step(cursor,'00Z [^a]',true,{bytes=4096})
        assert.is_true(token.diagnostic_utc_candidate)
        assert.is_true(token.diagnostic_reference_candidate)
        local _,plain=G.lex_step(G.lex_start(),'plain',true,{bytes=4096})
        assert.is_true(G.same_token(plain,token))
    end)
    it('matches UTC tokens split at every byte boundary',function()
        local timezone=require('parley.timezone_diagnostics')
        assert.is_function(timezone.scan_chunk)
        local text='x2026-04-18T00:00:00Zy'
        local opts={to_local=function()return {year=2026,month=4,day=18,hour=0,min=0,sec=0}end}
        for split=1,#text-1 do
            local a,carry=timezone.scan_chunk(text:sub(1,split),0,'',opts)
            local b=timezone.scan_chunk(text:sub(split+1),split,carry,opts)
            assert.equals(1,#a+#b);local found=a[1] or b[1]
            assert.equals(1,found.col);assert.equals(21,found.end_col)
        end
    end)
    it('derives footnotes through a byte reader without whole-line materialization',function()
        local define=require('parley.define')
        assert.is_function(define.read_diagnostic_definition)
        assert.is_function(define.read_diagnostic_references)
        local function source(line)return {length=#line,byte=function(i)return i>=1 and i<=#line and line:sub(i,i) or '' end}end
        local definition=define.read_diagnostic_definition(source('[^acos]: "Advertising Cost of Sales". Ratio.'))
        local references=define.read_diagnostic_references(source('Use Advertising Cost of Sales[^acos].'),{definition})
        local result=define.materialize_diagnostic(references[1])
        assert.equals(4,result.col);assert.equals('Advertising Cost of Sales',result.term)
        assert.equals('Ratio.',result.definition)
    end)
    it('matches legacy structured, slug and fallback anchor semantics',function()
        local define=require('parley.define')
        local function source(line)return {length=#line,byte=function(i)return i>=1 and i<=#line and line:sub(i,i) or '' end}end
        for _,term in ipairs({'ASIN','Advertising Cost of Sales','serverless functions'}) do
            for _,suffix in ipairs({'',' ',']',"')",' ” ',']  )'}) do
                for _,definition in ipairs({'plain definition','"'..term..'".  A   definition.','`'..term..'` A definition'}) do
                    local text='Earlier '..term..' then '..term..suffix..'[^serverless-functions].'
                    local line='[^serverless-functions]: '..definition
                    local parsed=define.read_diagnostic_definition(source(line))
                    local actual={}
                    for _,record in ipairs(define.read_diagnostic_references(source(text),{parsed})) do
                        local d=define.materialize_diagnostic(record);d.lnum=0;d.end_lnum=0;actual[#actual+1]=d
                    end
                    assert.same(define.footnote_diagnostics({text,line}),actual)
                end
            end
        end
    end)
end)

describe('indexed diagnostic refresh',function()
    it('publishes split timestamps and footnotes from bounded candidate reads',function()
        assert.is_function(diagnostic_refresh.drain)
        local b=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_buf_set_lines(b,0,-1,false,{string.rep('x',4090)..' 2026-04-18T00:00:00Z ASIN[^a]',
            'plain','[^a]: old','[^a]: "ASIN". Correct definition.'})
        local Document=require('parley.document')
        Document.drain(Document.attach(b,{schedule=false}),1000)
        diagnostic_refresh.refresh(b,{schedule=false})
        assert.equals('idle',diagnostic_refresh.drain(b,10000).status)
        local t=vim.diagnostic.get(b,{namespace=require('parley.timezone_diagnostics').diag_namespace()})
        local f=vim.diagnostic.get(b,{namespace=require('parley.skill_render').diag_namespace()})
        assert.equals(1,#t);assert.equals(1,#f);assert.equals('ASIN — Correct definition.',f[1].message)
        vim.api.nvim_buf_delete(b,{force=true})
    end)
    it('preserves long definitions and bounds parser work while skipping unrelated typing',function()
        local b=vim.api.nvim_create_buf(false,true)
        local body=string.rep('long definition ',6000)
        vim.api.nvim_buf_set_lines(b,0,-1,false,{'ASIN[^a]','ordinary body','[^a]: '..body})
        local Document=require('parley.document');local Reader=require('parley.line_reader')
        Document.drain(Document.attach(b,{schedule=false}),10000)
        local max_read,max_work,publications=0,0,0
        local observer=Reader.set_observer(b,function(event)
            max_read=math.max(max_read,event.bytes_read or 0)
            max_work=math.max(max_work,event.diagnostic_bytes_processed or 0)
            if event.operation=='diagnostic_publication' then publications=publications+1 end
        end)
        diagnostic_refresh.refresh(b,{schedule=false})
        assert.equals('idle',diagnostic_refresh.drain(b,10000).status)
        local found=vim.diagnostic.get(b,{namespace=require('parley.skill_render').diag_namespace()})
        assert.equals('ASIN — '..body:sub(1,-2),found[1].message)
        assert.is_true(max_read<=4096);assert.is_true(max_work<=4096)
        local before=publications
        vim.api.nvim_buf_set_text(b,1,2,1,3,{'X'})
        diagnostic_refresh.refresh(b)
        assert.equals('idle',diagnostic_refresh.drain(b,100).status)
        assert.equals(before,publications)
        Reader.clear_observer(b,observer);vim.api.nvim_buf_delete(b,{force=true})
    end)
    it('handles first-definition movement, duplicate removal and unrelated skill diagnostics',function()
        local b=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_buf_set_lines(b,0,-1,false,{'ASIN[^a]','[^a]: one','hidden ASIN[^a]','[^a]: two'})
        local Document=require('parley.document');Document.drain(Document.attach(b,{schedule=false}),1000)
        local ns=require('parley.skill_render').diag_namespace()
        vim.diagnostic.set(ns,b,{{lnum=0,col=0,message='other',source='parley-edit'}})
        diagnostic_refresh.refresh(b,{schedule=false});diagnostic_refresh.drain(b,10000)
        local found=vim.diagnostic.get(b,{namespace=ns});assert.equals(2,#found)
        assert.equals('ASIN — two',found[2].message)
        vim.api.nvim_buf_set_lines(b,1,2,false,{'ordinary'})
        diagnostic_refresh.drain(b,10000)
        found=vim.diagnostic.get(b,{namespace=ns});assert.equals(3,#found)
        vim.api.nvim_buf_set_lines(b,3,4,false,{})
        diagnostic_refresh.drain(b,10000)
        found=vim.diagnostic.get(b,{namespace=ns});assert.equals(1,#found);assert.equals('other',found[1].message)
        vim.api.nvim_buf_delete(b,{force=true})
    end)
    it('invalidates diagnostic projection proofs but preserves semantic syntax on new candidates',function()
        local S=require('parley.document.sequence');local G=require('parley.document.grammar')
        local P=require('parley.document.projection')
        local function token(text)local _,t=G.lex_step(G.lex_start(),text,true,{bytes=4096});return t end
        local a=token('plain')
        local metadata={token=a,confirmed=true,semantic={}}
        local seq=S.new({{rows=1,bytes=6,metadata=metadata}},{empty_summary=G.empty_summary(),summarize=function(m)return G.summary(m.token)end,
            combine=G.combine,empty_projection=P.empty(),projection_summary=P.summary,combine_projection=P.combine})
        local syntax=S.range_certificate(seq,0,1,{kind='syntax'})
        local projection=S.range_certificate(seq,0,1,{kind='projection'})
        metadata.token=token('plain [^a]')
        local success,result=S.update_text(seq,S.at(seq,0).handle,{bytes=11,metadata=metadata})
        assert.is_true(success);assert.is_true(result.same_syntax_proven)
        assert.is_true(S.validate_certificate(seq,syntax,{kind='syntax'}))
        assert.is_false(S.validate_certificate(seq,projection,{kind='projection'}))
    end)
    it('lets native timers run before candidate diagnostics finish parsing',function()
        local b=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_buf_set_lines(b,0,-1,false,{'ASIN[^a]','[^a]: '..string.rep('long definition ',6000)})
        local Document=require('parley.document');Document.drain(Document.attach(b,{schedule=false}),10000)
        diagnostic_refresh.refresh(b)
        local observed
        vim.defer_fn(function()
            observed=#vim.diagnostic.get(b,{namespace=require('parley.skill_render').diag_namespace()})
        end,2)
        assert.is_true(vim.wait(500,function()return observed~=nil end,1))
        diagnostic_refresh.clear(b);vim.api.nvim_buf_delete(b,{force=true})
        assert.equals(0,observed)
    end)
    it('reports derivation errors without endlessly restarting the same job',function()
        local b=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_buf_set_lines(b,0,-1,false,{'2026-04-18T00:00:00Z'})
        local Document=require('parley.document');Document.drain(Document.attach(b,{schedule=false}),1000)
        diagnostic_refresh.refresh(b,{schedule=false,to_local=function()error('conversion failed')end})
        local result=diagnostic_refresh.drain(b,100)
        assert.equals('error',result.status);assert.matches('conversion failed',result.reason)
        assert.equals('error',diagnostic_refresh.step(b).status)
        vim.api.nvim_buf_delete(b,{force=true})
    end)
    it('retires arbitrary deleted candidates and cancels pending work on reload',function()
        local path=vim.fn.tempname();vim.fn.writefile({'ASIN[^a]','[^a]: '..string.rep('word ',2000)},path)
        vim.cmd('edit '..vim.fn.fnameescape(path));local b=vim.api.nvim_get_current_buf()
        local Document=require('parley.document');Document.drain(Document.attach(b,{schedule=false}),1000)
        diagnostic_refresh.refresh(b,{schedule=false});diagnostic_refresh.step(b)
        vim.fn.writefile({'fresh 2026-04-18T00:00:00Z'},path);vim.cmd('edit!')
        -- Native edit! may detach the old attachment before loading the same buffer.
        -- The lifecycle refresh creates a new job; the old pending source cannot publish.
        diagnostic_refresh.refresh(b,{schedule=false})
        assert.equals('idle',diagnostic_refresh.drain(b,10000).status)
        assert.equals(0,#vim.diagnostic.get(b,{namespace=require('parley.skill_render').diag_namespace()}))
        assert.equals(1,#vim.diagnostic.get(b,{namespace=require('parley.timezone_diagnostics').diag_namespace()}))
        vim.api.nvim_buf_set_lines(b,0,-1,false,{})
        assert.equals('idle',diagnostic_refresh.drain(b,1000).status)
        assert.equals(0,#vim.diagnostic.get(b,{namespace=require('parley.timezone_diagnostics').diag_namespace()}))
        vim.api.nvim_buf_delete(b,{force=true});vim.fn.delete(path)
    end)
end)

describe("diagnostic refresh", function()
    it("refreshes timezone before footnotes synchronously", function()
        local calls = {}
        local refresh = diagnostic_refresh._new({
            is_valid = function(buf) return buf == 7 end,
            timezone = { refresh_buffer = function() table.insert(calls, "timezone") end },
            footnotes = { refresh_footnote_diagnostics = function() table.insert(calls, "footnote") end },
        })

        refresh.refresh(7)
        assert.are.same({ "timezone", "footnote" }, calls)
    end)

    it("does nothing for an invalid buffer", function()
        local calls = 0
        local refresh = diagnostic_refresh._new({
            is_valid = function() return false end,
            timezone = { refresh_buffer = function() calls = calls + 1 end },
            footnotes = { refresh_footnote_diagnostics = function() calls = calls + 1 end },
        })
        refresh.refresh(99)
        refresh.clear(99)
        assert.equals(0, calls)
    end)

    it("clears timezone and only footnote-owned decorations", function()
        local calls = {}
        local refresh = diagnostic_refresh._new({
            is_valid = function() return true end,
            timezone = { clear = function() table.insert(calls, "timezone") end },
            footnotes = { clear_footnote_diagnostics = function() table.insert(calls, "footnote") end },
        })
        refresh.clear(3)
        assert.are.same({ "timezone", "footnote" }, calls)
    end)
end)
