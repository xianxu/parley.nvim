local ok, S = pcall(require, "parley.document.sequence")

local function rows(n, offset)
    local out = {}
    for i = 1, n do out[i] = { rows = 1, bytes = i % 9 + 1, metadata = { id = i + (offset or 0) } } end
    return out
end

describe("document sequence", function()
    it("provides the pure sequence module", function() assert.is_true(ok) end)
    if not ok then return end

    it("indexes projections independently and rejects stale projection cursors", function()
        local values = rows(1600)
        for _, v in ipairs(values) do v.metadata.token = { kind = "text" } end
        local seq = S.new(values, {
            channel_names = { 'row' }, channels = function() return { row = true } end,
            projection_summary = function(m) return { marked = m.marked == true } end,
            combine_projection = function(a,b) return { marked = a.marked or b.marked } end,
            empty_projection = { marked = false },
        })
        local h = S.at(seq, 100).handle
        local text = S.range_certificate(seq, 0, 1600)
        local syntax = S.range_certificate(seq, 0, 1600, { kind = "syntax" })
        local proof = S.range_certificate(seq, 0, 1600, { kind = "projection" })
        local fact = S.fact_certificate(seq,{first=S.bof(seq),last=S.eof(seq),channels={'row'}})
        local result = S.find(seq, 0, 1600, { projection = true, max_nodes = 512, max_entries = 600,
            matches = function() return false end })
        assert.equals("budget", result.status)
        assert.is_table(result.cursor)
        assert.is_true(S.project_many(seq, { { handle = h, metadata = { token = { kind = "text" }, marked = true } } }))
        assert.is_true(S.validate_certificate(seq,text))
        assert.is_true(S.validate_certificate(seq,syntax,{kind="syntax"}))
        assert.is_true(S.validate_certificate(seq,fact,{kind="fact"}))
        assert.is_false(S.validate_certificate(seq,proof,{kind="projection"}))
        assert.equals("stale", S.find(seq,0,1600,{projection=true,cursor=result.cursor}).status)
        local found = S.find(seq,0,1600,{projection=true,
            may_match=function(summary) return summary.marked end,
            matches=function(m) return m.marked end})
        assert.equals("found", found.status)
        assert.equals(h, found.span.handle)
        local payload_proof=S.range_certificate(seq,0,1600,{kind="projection"})
        local metadata=S.at(seq,100).metadata
        metadata.token.bytes=60
        assert.is_true(S.update_text(seq,h,{bytes=61,metadata=metadata}))
        assert.is_true(S.validate_certificate(seq,payload_proof,{kind="projection"}))
        metadata.note="new semantic meaning without changed summary"
        assert.is_true(S.project_many(seq,{{handle=h,metadata=metadata}}))
        assert.is_false(S.validate_certificate(seq,payload_proof,{kind="projection"}))
        assert.is_false(S.validate_certificate(seq,text,{kind="projection"}))
    end)

    it("splices against an independent seeded flat reference and proves membership", function()
        local flat, seed, next_id = rows(300), 4312, 301
        local seq = S.new(flat)
        local retired = {}
        local function random(n) seed = seed * 48271 % 2147483647; return seed % n end
        for _ = 1, 500 do
            local first = random(#flat + 1)
            local count = math.min(random(12), #flat - first)
            for _, span in ipairs(S.query(seq, first, first + count)) do retired[#retired + 1] = span.handle end
            local add = rows(random(8), next_id)
            next_id = next_id + #add
            S.splice(seq, first, first + count, add)
            for _ = 1, count do table.remove(flat, first + 1) end
            for i = #add, 1, -1 do table.insert(flat, first + 1, add[i]) end
            local actual, byte = S.query(seq, 0, #flat), 0
            assert.equals(#flat, #actual)
            for i, span in ipairs(actual) do
                assert.same(flat[i].metadata, span.metadata)
                assert.equals(byte, span.start_byte)
                assert.equals(i - 1, S.rank(seq, span.handle).row)
                byte = byte + flat[i].bytes
            end
            assert.same({ rows = #flat, bytes = byte }, S.size(seq))
        end
        for _, handle in ipairs(retired) do assert.is_nil(S.rank(seq, handle)) end
    end)

    it("keeps huge paste/delete and narrow queries bounded", function()
        local seq = S.new(rows(50000))
        local survivor = S.at(seq, 49999).handle
        S.stats(seq, true)
        S.splice(seq, 2, 49998, {{ rows = 1000000, bytes = 8000000, opaque = true }})
        local work = S.stats(seq, true)
        assert.is_true(work.entries_copied < 1024)
        assert.is_true(work.nodes_visited < 256)
        assert.equals(1000003, S.rank(seq, survivor).row)
        local hit = S.query(seq, 500, 501)
        assert.equals(1, #hit)
        assert.equals(500, hit[1].start_row)
        assert.is_nil(hit[1].start_byte)
        assert.is_true(S.stats(seq).nodes_visited < 128)
        S.splice(seq, 500, 501, rows(1), { start_byte = 4000, end_byte = 4008 })
        assert.equals(1, S.at(seq, 500).rows)
        assert.equals(1000004, S.size(seq).rows)
    end)

    it("does not expose input or stored metadata and rejects foreign handles", function()
        local input = rows(2)
        local seq = S.new(input)
        input[1].metadata.id = -1
        local span = S.at(seq, 0)
        span.metadata.id = -2
        assert.equals(1, S.at(seq, 0).metadata.id)
        assert.is_nil(S.rank(S.new(rows(2)), span.handle))
        local eof = S.eof(seq)
        S.splice(seq, 2, 2, rows(3))
        assert.equals(5, S.rank(seq, eof).row)
    end)

    it("validates local certificates across disjoint changes but not replacement or edge insertion", function()
        local seq = S.new(rows(500))
        local cert = S.range_certificate(seq, 200, 220)
        S.splice(seq, 2, 3, rows(5))
        local valid, range = S.validate_certificate(seq, cert)
        assert.is_true(valid)
        assert.equals(204, range.first_row)
        S.splice(seq, 210, 211, {{rows=1,bytes=4,metadata={id=900}}})
        assert.is_false(S.validate_certificate(seq, cert))
        cert = S.range_certificate(seq, 100, 120)
        S.splice(seq, 100, 100, rows(1))
        assert.is_false(S.validate_certificate(seq, cert))
    end)

    it("uses conservative summaries and resumes budgeted searches after unrelated edits", function()
        local seq = S.new(rows(2000), {
            empty_summary = { max = 0 },
            summarize = function(m) return { max = m.id } end,
            combine = function(a,b) return { max = math.max(a.max,b.max) } end,
        })
        local opts = {
            may_match = function(summary) return summary.max >= 1900 end,
            matches = function(m) return m.id == 1900 end,
            max_nodes = 128, max_entries = 8,
        }
        opts.max_nodes,opts.max_entries=512,1024
        opts.may_match=function() return true end
        local result = S.find(seq, 100, 2000, opts)
        assert.equals("budget", result.status)
        S.splice(seq, 10, 10, rows(1))
        local slices = 1
        while result.status == "budget" do
            opts.cursor = result.cursor
            result = S.find(seq, 1800, 2000, opts)
            assert.is_true(result.work.nodes_visited <= 512)
            assert.is_true(result.work.entries_visited <= 1024)
            slices = slices + 1
            assert.is_true(slices < 100)
        end
        assert.equals("found", result.status)
        assert.equals(1900, result.span.metadata.id)
        assert.equals(1900, result.span.start_row)
        assert.equals("not_found", S.find(seq,0,100,{
            may_match=opts.may_match,matches=opts.matches,max_nodes=512,max_entries=1024,
        }).status)
        S.splice(seq,1900,1900,{{rows=100,bytes=500,opaque=true}})
        assert.equals("opaque", S.find(seq,1800,2100,{
            may_match=opts.may_match,matches=opts.matches,max_nodes=512,max_entries=1024,
        }).status)
    end)

    it("combines cached range summaries without exposing the backing values", function()
        local seq=S.new(rows(50000),{
            empty_summary={total=0},summarize=function(m) return {total=m.id} end,
            combine=function(a,b) return {total=a.total+b.total} end,
        })
        S.stats(seq,true)
        local summary=S.summary(seq,100,49900)
        assert.equals((101+49900)*49800/2,summary.summary.total)
        assert.is_true(S.stats(seq).nodes_visited<128)
        summary.summary.total=-1
        assert.equals((101+49900)*49800/2,S.summary(seq,100,49900).summary.total)
        local handle=S.at(seq,200).handle
        local cert=S.range_certificate(seq,190,210)
        assert.is_true(S.update(seq,handle,{id=99999}))
        assert.is_false(S.validate_certificate(seq,cert))
        assert.equals(99999,S.at(seq,200).metadata.id)
    end)

    it("counts all find navigation and reports insufficient budgets without doing hidden work", function()
        local seq=S.new(rows(5000))
        S.stats(seq,true)
        local result=S.find(seq,100,4900,{max_nodes=1,max_entries=1,matches=function() return false end})
        assert.equals("budget",result.status)
        assert.is_table(result.required)
        assert.is_true(S.stats(seq).nodes_visited<=1)
        assert.is_true(S.stats(seq).entries_visited<=1)
        S.stats(seq,true)
        result=S.find(seq,100,4900,{max_nodes=512,max_entries=1024,matches=function() return false end})
        local work=S.stats(seq)
        assert.equals(work.nodes_visited,result.work.nodes_visited)
        assert.equals(work.entries_visited,result.work.entries_visited)
        assert.is_true(work.nodes_visited<=512)
        assert.is_true(work.entries_visited<=1024)
    end)

    it("preserves provenance values nested in copied metadata", function()
        local seq=S.new(rows(3))
        local origin=S.at(seq,0).handle
        local finish=S.eof(seq)
        S.update(seq,S.at(seq,1).handle,{origin=origin,nested={finish=finish}})
        local metadata=S.at(seq,1).metadata
        assert.equals(origin,metadata.origin)
        assert.equals(0,S.rank(seq,metadata.origin).row)
        assert.equals(3,S.rank(seq,metadata.nested.finish).row)
        local other=S.new({{rows=1,bytes=0,metadata=metadata}})
        assert.equals(origin,S.at(other,0).metadata.origin)
        assert.is_nil(S.rank(other,origin))
    end)

    it("matches seeded opaque range edits with independent per-row byte sizes", function()
        local bytes,seed={},771
        for i=1,1000 do bytes[i]=i%7 end
        local function sum(first,last) local n=0; for i=first,last do n=n+bytes[i] end; return n end
        local function random(n) seed=seed*48271%2147483647; return seed%n end
        local seq=S.new({{rows=#bytes,bytes=sum(1,#bytes),opaque=true}})
        for _=1,400 do
            local first=random(#bytes+1)
            local last=math.min(#bytes,first+random(20))
            local n=random(10)
            local added,spans={},{}
            for i=1,n do added[i]=random(12) end
            if n>0 then
                local total=0; for _,b in ipairs(added) do total=total+b end
                spans[1]={rows=n,bytes=total,opaque=true}
            end
            S.splice(seq,first,last,spans,{start_byte=sum(1,first),end_byte=sum(1,last)})
            for _=first+1,last do table.remove(bytes,first+1) end
            for i=#added,1,-1 do table.insert(bytes,first+1,added[i]) end
            assert.same({rows=#bytes,bytes=sum(1,#bytes)},S.size(seq))
            for _,span in ipairs(S.query(seq,0,#bytes)) do
                assert.equals(sum(1,span.start_row),span.start_byte)
                assert.equals(sum(span.start_row+1,span.end_row),span.bytes)
            end
        end
    end)

    it("resumes reverse scans, rejects stale cursors, and accounts for complete work", function()
        local seq=S.new(rows(5000))
        local opts={reverse=true,max_nodes=512,max_entries=1024,matches=function(m) return m.id==150 end}
        local result
        for _=1,30 do
            S.stats(seq,true)
            result=S.find(seq,100,4900,opts)
            local work=S.stats(seq)
            assert.equals(work.nodes_visited,result.work.nodes_visited)
            assert.equals(work.entries_visited,result.work.entries_visited)
            assert.is_true(work.nodes_visited<=512)
            assert.is_true(work.entries_visited<=1024)
            if result.status~="budget" then break end
            opts.cursor=result.cursor
        end
        assert.equals("found",result.status)
        assert.equals(149,result.span.start_row)
        opts.cursor=nil
        result=S.find(seq,100,4900,opts)
        S.splice(seq,4000,4001,rows(1))
        opts.cursor=result.cursor
        assert.equals("stale",S.find(seq,100,4900,opts).status)
    end)

    it("checks empty and deleted certificate endpoints and bounded input failures", function()
        local seq=S.new(rows(5))
        local cert=S.range_certificate(seq,2,2)
        assert.is_true(S.validate_certificate(seq,cert))
        S.splice(seq,2,2,rows(1))
        assert.is_false(S.validate_certificate(seq,cert))
        cert=S.range_certificate(seq,1,4)
        S.splice(seq,0,6,{})
        assert.is_false(S.validate_certificate(seq,cert))
        assert.equals("not_found",S.find(seq,0,0).status)
        seq=S.new({{rows=100,bytes=1000,opaque=true}})
        assert.is_nil(S.range_certificate(seq,1,2))
        assert.has_error(function() S.splice(seq,1,2,{}) end)
        assert.same({rows=100,bytes=1000},S.size(seq))
        assert.has_error(function() S.splice(seq,0,0,{{rows=1,bytes=-1}}) end)
        assert.same({rows=100,bytes=1000},S.size(seq))
    end)

    it("budgets certificate overhead and resumes searches ending inside opaque spans", function()
        local seq=S.new(rows(2000))
        S.splice(seq,2000,2000,{{rows=1000,bytes=9000,opaque=true}})
        local bound=S.navigation_budget(seq)
        S.stats(seq,true)
        S.range_certificate(seq,5,1900)
        assert.is_true(S.stats(seq).nodes_visited<=bound.nodes)
        assert.is_true(S.stats(seq).entries_visited<=bound.entries)
        local opts={matches=function() return false end}
        local result=S.find(seq,5,2200,opts)
        assert.equals("budget",result.status)
        assert.is_not_nil(result.cursor)
        for _=1,20 do
            opts.cursor=result.cursor
            result=S.find(seq,5,2200,opts)
            if result.status~="budget" then break end
        end
        assert.equals("opaque",result.status)
        assert.equals(2000,result.span.start_row)
        assert.equals(2200,result.span.end_row)
    end)

    it("publishes metadata batches atomically and preserves all row handles", function()
        local seq=S.new(rows(500))
        local a,b=S.at(seq,2).handle,S.at(seq,400).handle
        local foreign=S.at(S.new(rows(1)),0).handle
        assert.is_false(S.update_many(seq,{{handle=a,metadata={id=999}},{handle=foreign,metadata={id=888}}}))
        assert.equals(3,S.at(seq,2).metadata.id)
        assert.has_error(function()
            S.update_many(seq,{{handle=a,metadata={id=999}},{handle=b,metadata={invalid=function() end}}})
        end)
        assert.equals(3,S.at(seq,2).metadata.id)
        assert.is_true(S.update_many(seq,{{handle=a,metadata={id=999}},{handle=b,metadata={id=888}}}))
        assert.equals(a,S.at(seq,2).handle)
        assert.equals(b,S.at(seq,400).handle)
        assert.equals(999,S.at(seq,2).metadata.id)
        assert.equals(888,S.at(seq,400).metadata.id)
        assert.equals(400,S.rank(seq,b).row)
        S.update(seq,a,nil)
        assert.is_nil(S.at(seq,2).metadata)
    end)

    it("keeps live rank and summaries intact when batch summary calculation fails", function()
        local fail=false
        local seq=S.new(rows(500),{
            empty_summary={max=0},summarize=function(m) return {max=m.id} end,
            combine=function(a,b) if fail then error("summary failure") end; return {max=math.max(a.max,b.max)} end,
        })
        local a,b=S.at(seq,2).handle,S.at(seq,400).handle
        fail=true
        local success,err=pcall(function() S.update_many(seq,{{handle=a,metadata={id=999}},{handle=b,metadata={id=888}}}) end)
        assert.is_false(success)
        assert.matches("summary failure",err)
        fail=false
        assert.equals(2,S.rank(seq,a).row)
        assert.equals(400,S.rank(seq,b).row)
        assert.equals(3,S.at(seq,2).metadata.id)
        assert.equals(500,S.summary(seq,0,500).summary.max)
    end)

    it("publishes semantic projections without weakening lexical revision proofs", function()
        local seq=S.new({{rows=1,bytes=5,metadata={token={kind='text'},semantic_stamp=1}}},{
            empty_summary={stamp=0},summarize=function(m) return {stamp=m.semantic_stamp} end,
            combine=function(a,b) return {stamp=math.max(a.stamp,b.stamp)} end,
        })
        local h=S.at(seq,0).handle
        local cert=S.range_certificate(seq,0,1)
        assert.is_true(S.project_many(seq,{{handle=h,metadata={token={kind='text'},semantic_stamp=1,semantic={role='answer'}}}}))
        assert.is_true(S.validate_certificate(seq,cert))
        assert.equals('answer',S.at(seq,0).metadata.semantic.role)
        assert.is_false(S.project_many(seq,{{handle=h,metadata={token={kind='user'},semantic_stamp=1}}}))
        assert.is_false(S.project_many(seq,{{handle=h,metadata={token={kind='text'},semantic_stamp=2}}}))
        assert.is_true(S.validate_certificate(seq,cert))
        S.update(seq,h,{token={kind='text'},semantic_stamp=1})
        assert.is_false(S.validate_certificate(seq,cert))
    end)
    it("separates syntax certificates from same-row text snapshots",function()
        local seq=S.new({{rows=1,bytes=5,metadata={token={kind='text',bytes=4,blank=false}}}})
        local h=S.at(seq,0).handle
        for _,length in ipairs({5,12}) do
            local text=S.range_certificate(seq,0,1)
            local syntax=S.range_certificate(seq,0,1,{kind='syntax'})
            local ok,result=S.update_text(seq,h,{bytes=length,metadata={token={kind='text',bytes=length-1,blank=false}}})
            assert.is_true(ok); assert.is_true(result.same_syntax_proven)
            assert.equals(h,S.at(seq,0).handle)
            assert.equals(length,S.size(seq).bytes)
            assert.is_false(S.validate_certificate(seq,text))
            assert.is_true(S.validate_certificate(seq,syntax,{kind='syntax'}))
            assert.is_false(S.validate_certificate(seq,syntax))
        end
    end)
    it("invalidates syntax when any meaningful lexical field changes",function()
        local seq=S.new({{rows=1,bytes=5,metadata={token={kind='text',blank=false,preface_tag=false}}}})
        local h=S.at(seq,0).handle
        local syntax=S.range_certificate(seq,0,1,{kind='syntax'})
        local text=S.range_certificate(seq,0,1)
        local ok,result=S.update_text(seq,h,{bytes=5,metadata={token={kind='text',blank=false,preface_tag=true}}})
        assert.is_true(ok); assert.is_false(result.same_syntax_proven)
        assert.is_false(S.validate_certificate(seq,syntax,{kind='syntax'}))
        assert.is_false(S.validate_certificate(seq,text))
    end)
    it("refuses opaque, foreign, and malformed text updates atomically",function()
        local seq=S.new({{rows=1,bytes=5,metadata={token={kind='text'}}},{rows=2,bytes=8,opaque=true}})
        local h=S.at(seq,0).handle
        local opaque=S.at(seq,1).handle
        local foreign=S.at(S.new(rows(1)),0).handle
        assert.is_false(S.update_text(seq,opaque,{bytes=8,metadata={token={kind='text'}}}))
        assert.is_false(S.update_text(seq,foreign,{bytes=2,metadata={token={kind='text'}}}))
        assert.has_error(function() S.update_text(seq,h,{bytes=-1,metadata={token={kind='text'}}}) end)
        assert.has_error(function() S.update_text(seq,h,{bytes=7,metadata={token={kind='text'},bad=function() end}}) end)
        assert.has_error(function() S.update_text(seq,h,{bytes=7,metadata={}}) end)
        assert.equals(5,S.at(seq,0).bytes)
        assert.equals(h,S.at(seq,0).handle)
    end)
    it("keeps projection publication revision-neutral for both certificate kinds",function()
        local seq=S.new({{rows=1,bytes=5,metadata={token={kind='text'}}}})
        local h=S.at(seq,0).handle
        local text=S.range_certificate(seq,0,1)
        local syntax=S.range_certificate(seq,0,1,{kind='syntax'})
        assert.is_true(S.project_many(seq,{{handle=h,metadata={token={kind='text'},semantic={role='answer'}}}}))
        assert.is_true(S.validate_certificate(seq,text))
        assert.is_true(S.validate_certificate(seq,syntax,{kind='syntax'}))
        S.update(seq,h,{token={kind='text'}})
        assert.is_false(S.validate_certificate(seq,syntax,{kind='syntax'}))
    end)

    it("resumes explicitly syntax-scoped searches across payload edits",function()
        local values={}
        for i=1,1500 do values[i]={rows=1,bytes=5,metadata={token={kind=i==1500 and 'user' or 'text'}}} end
        local seq=S.new(values)
        local predicate=function(m) return m.token.kind=='user' end
        local syntax=S.find(seq,0,1500,{matches=predicate,certificate_kind='syntax'})
        local text=S.find(seq,0,1500,{matches=predicate})
        assert.equals('budget',syntax.status)
        assert.equals('budget',text.status)
        S.update_text(seq,S.at(seq,1).handle,{bytes=12,metadata={token={kind='text'}}})
        assert.equals('stale',S.find(seq,0,1500,{matches=predicate,cursor=text.cursor}).status)
        for _=1,20 do
            syntax=S.find(seq,0,1500,{matches=predicate,certificate_kind='syntax',cursor=syntax.cursor})
            if syntax.status~='budget' then break end
        end
        assert.equals('found',syntax.status)
        assert.equals(1499,syntax.span.start_row)
    end)
    it("bounds text updates and syntax validation independently of document size",function()
        for _,n in ipairs({1000,10000,50000}) do
            local values={}
            for i=1,n do values[i]={rows=1,bytes=5,metadata={token={kind='text',blank=false}}} end
            local seq=S.new(values)
            local h=S.at(seq,math.floor(n/2)).handle
            local cert=S.range_certificate(seq,0,n,{kind='syntax'})
            S.stats(seq,true)
            local ok,result=S.update_text(seq,h,{bytes=11,metadata={token={kind='text',blank=false}}})
            assert.is_true(ok); assert.is_true(result.same_syntax_proven)
            assert.is_true(S.validate_certificate(seq,cert,{kind='syntax'}))
            local work=S.stats(seq)
            assert.is_true(work.entries_copied<=128)
            assert.is_true(work.nodes_visited<200)
            assert.is_true(work.metadata_values_compared<20)
        end
    end)
    it("does not preserve syntax when an indexed non-token summary changes",function()
        local seq=S.new({{rows=1,bytes=5,metadata={token={kind='text'},flag=1}}},{
            empty_summary=0,summarize=function(m) return m.flag end,combine=math.max})
        local h=S.at(seq,0).handle
        local cert=S.range_certificate(seq,0,1,{kind='syntax'})
        local ok,result=S.update_text(seq,h,{bytes=5,metadata={token={kind='text'},flag=2}})
        assert.is_true(ok); assert.is_false(result.same_syntax_proven)
        assert.is_false(S.validate_certificate(seq,cert,{kind='syntax'}))
    end)

    it("keeps selective fact proofs across irrelevant row insertion and deletion",function()
        local function span(kind) return {rows=1,bytes=2,metadata={token={kind=kind}}} end
        local seq=S.new({span('text'),span('text'),span('user')},{channel_names={'user'},
            channels=function(m) return m.token.kind=='user' and {'user'} or {} end})
        local witness=S.at(seq,2).handle
        local cert=S.fact_certificate(seq,{first=S.bof(seq),last=witness,end_inclusive=true,channels={'user'}})
        S.splice(seq,0,1,{span('text'),span('text')})
        assert.equals(0,S.rank(seq,S.bof(seq)).row)
        assert.is_true(S.validate_certificate(seq,cert,{kind='fact'}))
        S.splice(seq,0,2,{})
        assert.is_true(S.validate_certificate(seq,cert,{kind='fact'}))
        assert.is_false(S.validate_certificate(seq,cert))
        local valid,range=S.validate_certificate(seq,cert,{kind='fact'})
        assert.is_true(valid); assert.equals(0,range.first_row); assert.equals(2,range.last_row)
    end)
    it("rejects equal-count matching replacement without hashes",function()
        local function span(kind) return {rows=1,bytes=2,metadata={token={kind=kind}}} end
        local seq=S.new({span('text'),span('user'),span('text')},{channel_names={'user'},
            channels=function(m) return m.token.kind=='user' and {user=true} or {} end})
        local cert=S.fact_certificate(seq,{first=S.bof(seq),last=S.eof(seq),channels={'user'}})
        S.splice(seq,1,2,{span('user')})
        assert.is_false(S.validate_certificate(seq,cert,{kind='fact'}))
    end)
    it("does not treat unread spans as ready negative facts",function()
        local seq=S.new({{rows=100,bytes=200,opaque=true}},{channel_names={'user'},channels=function() return {} end})
        assert.is_nil(S.fact_certificate(seq,{first=S.bof(seq),last=S.eof(seq),channels={'user'}}))
        local cursorproof=S.fact_certificate(seq,{first=S.bof(seq),last=S.eof(seq),channels={'user'},allow_opaque=true})
        assert.is_true(S.validate_certificate(seq,cursorproof,{kind='fact'}))
        S.splice(seq,0,1,{{rows=1,bytes=2,metadata={token={kind='text'}}}},{start_byte=0,end_byte=2})
        assert.is_false(S.validate_certificate(seq,cursorproof,{kind='fact'}))
    end)

    it("resumes selective searches when an irrelevant cursor row is deleted",function()
        local values={}
        for i=1,2000 do values[i]={rows=1,bytes=2,metadata={token={kind=i==2000 and 'user' or 'text'}}} end
        local seq=S.new(values,{channel_names={'user'},channels=function(m) return m.token.kind=='user' and {'user'} or {} end})
        local opts={certificate_kind='fact',fact={first=S.bof(seq),last=S.eof(seq),channels={'user'}},
            matches=function(m) return m.token.kind=='user' end}
        local result=S.find(seq,0,2000,opts)
        assert.equals('budget',result.status)
        -- Remove every potential early cursor row without touching the witness.
        S.splice(seq,0,1000,{})
        opts.cursor=result.cursor
        for _=1,20 do
            result=S.find(seq,0,1000,opts)
            if result.status~='budget' then break end
            opts.cursor=result.cursor
        end
        assert.equals('found',result.status)
        assert.equals(999,result.span.start_row)
    end)
    it("bounds selective validation and accounts for channel copies at scale",function()
        for _,n in ipairs({1000,10000,50000}) do
            local values={}
            for i=1,n do values[i]={rows=1,bytes=2,metadata={token={kind=i==n and 'user' or 'text'}}} end
            local seq=S.new(values,{channel_names={'user','row'},channels=function(m)
                return {row=true,user=m.token.kind=='user'} end})
            local cert=S.fact_certificate(seq,{first=S.bof(seq),last=S.eof(seq),channels={'user'}})
            S.splice(seq,1,2,{})
            S.stats(seq,true)
            assert.is_true(S.validate_certificate(seq,cert,{kind='fact'}))
            local work=S.stats(seq)
            assert.is_true(work.nodes_visited<10)
            assert.is_true(work.entries_visited<10)
            assert.is_true(work.channel_values_visited<=2)
        end
    end)

    it("keeps fact channel caches correct through text updates and rejects projection drift",function()
        local seq=S.new({{rows=1,bytes=2,metadata={token={kind='text'},marker=false}}},{
            channel_names={'user'},channels=function(m) return {user=m.marker==true} end})
        local h=S.at(seq,0).handle
        local proof=S.fact_certificate(seq,{first=S.bof(seq),last=S.eof(seq),channels={'user'}})
        assert.is_false(S.project_many(seq,{{handle=h,metadata={token={kind='text'},marker=true}}}))
        assert.is_true(S.validate_certificate(seq,proof,{kind='fact'}))
        local ok,result=S.update_text(seq,h,{bytes=5,metadata={token={kind='text'},marker=true}})
        assert.is_true(ok); assert.is_false(result.same_syntax_proven)
        assert.is_false(S.validate_certificate(seq,proof,{kind='fact'}))
        local totals=S.channel_summary(seq,0,1,{'user'})
        assert.equals(1,totals.channels.user.count)
        totals.channels.user.count=999
        assert.equals(1,S.channel_summary(seq,0,1,{'user'}).channels.user.count)
        assert.has_error(function() S.channel_summary(seq,0,1,{'typo'}) end)
        assert.is_false(S.update_text(seq,S.bof(seq),{bytes=5,metadata={token={kind='text'}}}))
    end)
    it("resumes opaque selective scans within complete navigation budgets",function()
        local seq=S.new(rows(1500),{channel_names={'user'},channels=function() return {} end})
        S.splice(seq,1500,1500,{{rows=100,bytes=200,opaque=true}})
        local opts={certificate_kind='fact',fact={first=S.bof(seq),last=S.eof(seq),channels={'user'}},
            matches=function() return false end,max_nodes=512,max_entries=1024}
        local result
        for _=1,20 do
            S.stats(seq,true)
            result=S.find(seq,0,1550,opts)
            local actual=S.stats(seq)
            assert.equals(actual.nodes_visited,result.work.nodes_visited)
            assert.equals(actual.channel_values_visited,result.work.channel_values_visited)
            assert.is_true(actual.nodes_visited<=512)
            assert.is_true(actual.entries_visited<=1024)
            if result.status~='budget' then break end
            assert.is_not_nil(result.cursor); opts.cursor=result.cursor
        end
        assert.equals('opaque',result.status)
        assert.equals(1500,result.span.start_row)
    end)

    it("reclaims detached document storage with active JIT traces and retained certificates",function()
        -- Run a fresh LuaJIT VM: earlier Plenary assertions alter hot traces and
        -- can hide the retention defect. Do not flush traces before measuring.
        local source=[=[
            jit.opt.start('hotloop=1','hotexit=1')
            local S=require('parley.document.sequence')
            local G=require('parley.document.grammar')
            collectgarbage('collect')
            local baseline=collectgarbage('count')
            local _,token=G.lex_step(G.lex_start(),'ordinary body',true,{bytes=64})
            local values={}
            for i=1,50000 do values[i]={rows=1,bytes=14,metadata={token=token}} end
            local seq=S.new(values,{summarize=function(m) return G.summary(m.token) end,
                combine=G.combine,empty_summary=G.empty_summary(),channel_names=G.CHANNELS,
                channels=function(m) return G.channels(m.token) end})
            values=nil
            local certificate=S.range_certificate(seq,0,50000)
            collectgarbage('collect')
            local attached=collectgarbage('count')
            S.splice(seq,0,50000,{{rows=1,bytes=1,opaque=true}})
            collectgarbage('collect'); collectgarbage('collect')
            print(vim.json.encode({retained=collectgarbage('count')-baseline,
                allocated=attached-baseline,valid=S.validate_certificate(seq,certificate)}))
        ]=]
        local path=vim.fn.tempname()..'.lua'
        vim.fn.writefile(vim.split(source,'\n',{plain=true}),path)
        local output=vim.fn.system({vim.v.progpath,'--headless','--noplugin','-u','NONE','-i','NONE',
            '--cmd','set rtp^='..vim.fn.fnameescape(vim.fn.getcwd()),
            '-c','luafile '..vim.fn.fnameescape(path),'-c','qa!'})
        local status=vim.v.shell_error
        vim.fn.delete(path)
        assert.equals(0,status,output)
        local result=vim.json.decode(output)
        assert.is_false(result.valid)
        -- A pinned tree keeps tens of MiB; allocator/JIT bookkeeping may keep
        -- a few MiB. The coarse ratio avoids platform-sensitive byte equality.
        assert.is_true(result.retained<result.allocated*0.3+2048,
            'detached tree retained '..math.floor(result.retained)..' KiB')
    end)

    it("bounds live and detached rank traversal before consuming index work", function()
        local seq=S.new(rows(5000))
        local live=S.at(seq,4999).handle
        local detached=S.at(seq,100).handle
        S.stats(seq,true)
        local value,reason=S.rank(seq,live,{nodes=0,entries=1})
        assert.is_nil(value); assert.equals("budget",reason)
        assert.equals(0,S.stats(seq).nodes_visited)
        assert.equals(1,S.stats(seq).entries_visited)
        S.splice(seq,0,4999,{})
        S.stats(seq,true)
        value,reason=S.rank(seq,detached,{nodes=1,entries=1})
        assert.is_nil(value); assert.equals("budget",reason)
        assert.equals(1,S.stats(seq).nodes_visited)
        assert.equals(1,S.stats(seq).entries_visited)
        assert.is_nil(S.rank(seq,detached,{nodes=100,entries=1}))
        assert.equals(0,S.rank(seq,live,{nodes=100,entries=1}).row)
        S.stats(seq,true)
        value,reason=S.rank(seq,live,{nodes=100,entries=0})
        assert.is_nil(value); assert.equals("budget",reason)
        assert.equals(0,S.stats(seq).nodes_visited)
        assert.equals(0,S.stats(seq).entries_visited)
    end)

end)
