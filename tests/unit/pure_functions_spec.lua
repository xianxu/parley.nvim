-- Unit tests for pure functions in lua/parley/init.lua
--
-- These functions are completely pure (no vim.*, no I/O, no side effects)
-- and were previously untested.

local tmp_dir = "/tmp/parley-test-pure-functions-" .. os.time()

-- Bootstrap parley
local parley = require("parley")
parley.setup({
    chat_dir = tmp_dir,
    state_dir = tmp_dir .. "/state",
    providers = {},
    api_keys = {},
})

-- Helper to create a minimal parsed_chat structure for find_exchange_at_line
local function parsed_chat_with_exchanges(exchanges)
    return { exchanges = exchanges }
end

local function exchange(q_start, q_end, a_start, a_end)
    local ex = {
        question = {
            line_start = q_start,
            line_end = q_end
        }
    }
    if a_start and a_end then
        ex.answer = {
            line_start = a_start,
            line_end = a_end
        }
    end
    return ex
end

describe("find_exchange_at_line", function()
    it("returns (index, 'question') when line is in question range", function()
        local pc = parsed_chat_with_exchanges({
            exchange(10, 15, 20, 25)
        })
        
        local idx, kind = parley.find_exchange_at_line(pc, 12)
        assert.equals(1, idx)
        assert.equals("question", kind)
    end)

    it("returns (index, 'answer') when line is in answer range", function()
        local pc = parsed_chat_with_exchanges({
            exchange(10, 15, 20, 25)
        })
        
        local idx, kind = parley.find_exchange_at_line(pc, 22)
        assert.equals(1, idx)
        assert.equals("answer", kind)
    end)

    it("returns (nil, nil) when line is in gap between exchanges", function()
        local pc = parsed_chat_with_exchanges({
            exchange(10, 15, 20, 25),
            exchange(30, 35, 40, 45)
        })
        
        local idx, kind = parley.find_exchange_at_line(pc, 27)
        assert.is_nil(idx)
        assert.is_nil(kind)
    end)

    it("returns (nil, nil) when line is before all exchanges", function()
        local pc = parsed_chat_with_exchanges({
            exchange(10, 15, 20, 25)
        })
        
        local idx, kind = parley.find_exchange_at_line(pc, 5)
        assert.is_nil(idx)
        assert.is_nil(kind)
    end)

    it("returns (nil, nil) when line is after all exchanges", function()
        local pc = parsed_chat_with_exchanges({
            exchange(10, 15, 20, 25)
        })
        
        local idx, kind = parley.find_exchange_at_line(pc, 30)
        assert.is_nil(idx)
        assert.is_nil(kind)
    end)

    it("finds correct index in multi-exchange chat (not always first)", function()
        local pc = parsed_chat_with_exchanges({
            exchange(10, 15, 20, 25),
            exchange(30, 35, 40, 45),
            exchange(50, 55, 60, 65)
        })
        
        local idx, kind = parley.find_exchange_at_line(pc, 42)
        assert.equals(2, idx)
        assert.equals("answer", kind)
    end)

    it("returns (nil, nil) when line is after question in exchange with no answer", function()
        local pc = parsed_chat_with_exchanges({
            exchange(10, 15) -- No answer
        })
        
        local idx, kind = parley.find_exchange_at_line(pc, 17)
        assert.is_nil(idx)
        assert.is_nil(kind)
    end)

    it("includes line at exact question boundary (line_start)", function()
        local pc = parsed_chat_with_exchanges({
            exchange(10, 15, 20, 25)
        })
        
        local idx, kind = parley.find_exchange_at_line(pc, 10)
        assert.equals(1, idx)
        assert.equals("question", kind)
    end)

    it("includes line at exact question boundary (line_end)", function()
        local pc = parsed_chat_with_exchanges({
            exchange(10, 15, 20, 25)
        })
        
        local idx, kind = parley.find_exchange_at_line(pc, 15)
        assert.equals(1, idx)
        assert.equals("question", kind)
    end)

    it("includes line at exact answer boundary (line_start)", function()
        local pc = parsed_chat_with_exchanges({
            exchange(10, 15, 20, 25)
        })
        
        local idx, kind = parley.find_exchange_at_line(pc, 20)
        assert.equals(1, idx)
        assert.equals("answer", kind)
    end)

    it("includes line at exact answer boundary (line_end)", function()
        local pc = parsed_chat_with_exchanges({
            exchange(10, 15, 20, 25)
        })
        
        local idx, kind = parley.find_exchange_at_line(pc, 25)
        assert.equals(1, idx)
        assert.equals("answer", kind)
    end)
end)

describe("simple_markdown_to_html", function()
    it("escapes HTML special characters", function()
        local html = parley.simple_markdown_to_html("A & B < C > D")
        assert.is_true(html:find("&amp;") ~= nil)
        assert.is_true(html:find("&lt;") ~= nil)
        assert.is_true(html:find("&gt;") ~= nil)
    end)

    it("converts fenced code block with language to <pre><code> with class", function()
        local md = "```lua\nprint('hello')\n```"
        local html = parley.simple_markdown_to_html(md)
        assert.is_true(html:find('<code class="language%-lua">') ~= nil)
        assert.is_true(html:find("print%('hello'%)") ~= nil)
    end)

    it("converts fenced code block without language to <pre><code>", function()
        local md = "```\ncode here\n```"
        local html = parley.simple_markdown_to_html(md)
        assert.is_true(html:find("<code") ~= nil)
        assert.is_true(html:find("code here") ~= nil)
        assert.is_true(html:find("<div class=\"code%-block\">") ~= nil)
    end)

    it("converts inline code to <code> with inline-code class", function()
        local md = "Use `print()` function"
        local html = parley.simple_markdown_to_html(md)
        assert.is_true(html:find('<code class="inline%-code">print%(%)') ~= nil)
    end)

    it("converts # H1 to <h1> with main-header class", function()
        local md = "# Main Title"
        local html = parley.simple_markdown_to_html(md)
        assert.is_true(html:find('<h1 class="main%-header">Main Title</h1>') ~= nil)
    end)

    it("converts ## H2 to <h2> with section-header class", function()
        local md = "## Section"
        local html = parley.simple_markdown_to_html(md)
        assert.is_true(html:find('<h2 class="section%-header">Section</h2>') ~= nil)
    end)

    it("converts ### H3 to <h3> with sub-header class", function()
        local md = "### Subsection"
        local html = parley.simple_markdown_to_html(md)
        assert.is_true(html:find('<h3 class="sub%-header">Subsection</h3>') ~= nil)
    end)

    it("converts **bold** to <strong> with bold-text class", function()
        local md = "This is **bold** text"
        local html = parley.simple_markdown_to_html(md)
        assert.is_true(html:find('<strong class="bold%-text">bold</strong>') ~= nil)
    end)

    it("converts __bold__ to <strong> with bold-text class", function()
        local md = "This is __bold__ text"
        local html = parley.simple_markdown_to_html(md)
        assert.is_true(html:find('<strong class="bold%-text">bold</strong>') ~= nil)
    end)

    it("converts *italic* to <em> with italic-text class", function()
        local md = "This is *italic* text"
        local html = parley.simple_markdown_to_html(md)
        assert.is_true(html:find('<em class="italic%-text">italic</em>') ~= nil)
    end)

    it("converts _italic_ to <em> with italic-text class", function()
        local md = "This is _italic_ text"
        local html = parley.simple_markdown_to_html(md)
        assert.is_true(html:find('<em class="italic%-text">italic</em>') ~= nil)
    end)

    it("converts - list item to <li> with list-item class", function()
        local md = "\n- First item\n- Second item"
        local html = parley.simple_markdown_to_html(md)
        assert.is_true(html:find('<li class="list%-item">First item</li>') ~= nil)
        assert.is_true(html:find('<li class="list%-item">Second item</li>') ~= nil)
    end)

    it("wraps list items in <ul> with bullet-list class", function()
        local md = "\n- Item"
        local html = parley.simple_markdown_to_html(md)
        assert.is_true(html:find('<ul class="bullet%-list">') ~= nil)
    end)

    it("converts > blockquote to <blockquote> with quote class", function()
        local md = "\n> This is a quote"
        local html = parley.simple_markdown_to_html(md)
        assert.is_true(html:find('<blockquote class="quote">') ~= nil)
        assert.is_true(html:find('This is a quote') ~= nil)
    end)

    it("wraps content in paragraph tags", function()
        local md = "Simple text"
        local html = parley.simple_markdown_to_html(md)
        assert.is_true(html:find('<p class="paragraph">') ~= nil)
        assert.is_true(html:find('</p>') ~= nil)
    end)

    it("splits multiple paragraphs on double newlines", function()
        local md = "First paragraph\n\nSecond paragraph"
        local html = parley.simple_markdown_to_html(md)
        -- Should have closing and opening p tags
        local _, count = html:gsub("</p>", "")
        assert.is_true(count >= 2) -- At least 2 closing p tags
    end)
end)
