# Integrate MCP and tool calling

Right now, Parley talks to a chatbot (Claude, ChatGPT, Gemini) through some version of their chat completion API, and uses a neovim buffer to store the conversation history. It uses some Unicode markers at beginning of line to indicate the conversation turns. It operates under the principle, that the transcript file (a markdown file) contains the full state of the conversation, and from that file, we can reconstruct what to send to the chat completion API, without needing to store any other state.

The markers used are as follows:

💬: user input
🤖: assistant response (Claude/ChatGPT/Gemini)
🧠: model thought (optional)
📝: summary of the exchange

The structure of a file is like the following. 

💬: user types in their question
some other text from user
yet another line

🤖:[Claude-Sonnet]

🧠: model thought (optional)

Claude responds with an answer
another line of answer

📝: you asked some question, and I answered with something, something.

💬: user types in a follow-up question

Note markers: 🧠: 📝: are inserted by assistant acting according to my prompt. Parley has a mechanism so that when the answer gets long, then the summary line is used to summarize the one question and answer, to prevent conversation bloat. In a parley transcript file, you would expect blocks of text, starting with those four markers repeated: 💬:, 🤖:, 🧠:, 📝:, and repeat.  

===

The task here is to incorporate MCP (Model Context Protocol) and chat agents tool calling ability into Parley, with Parley acting as the glue layer, that 1) talk to local MCP server to get registered tools; 2) send this as tools that assistant can use; 3) parse out assistant's tool use proposal; 4) locally execute such proposals through local MCP; 5) send back tool response as part of the current exchange. 

To accomplish this, we will need to take the following steps to start.

1) extend the file marker structure, to include tool call proposals from the model. Let's use ❓: to indicate one tool call proposal. 
  1) there might be multiple ❓: segments in an answer. you should print all those tool	call proposals in the answer before stopping to wait for user input. Each proposal in a new line.
  2) ❓ is part of assistant response block.
  3) when there's ❓ in assistant response that still requires human response, instead of displaying 💬: as a palace for user to input next question, we now expect user to input choices regarding the tool call proposals. Let's bind the following keys: 
    1) yA: yes to all tool call proposals and remember this choice for future calls in this session for the corresponding tool.
	2) ya: yes to all tool call proposals, but do not remember this choice for future calls in this session.
	3) yo: yes to one tool call under cursor, but do not remember this choice for future calls in this session.
	4) yO: yes to one tool	call under cursor, and remember this choice for future calls in this session for the corresponding tool.
	5) only wait user input when there's at least one ❓ tool call proposal that user hasn't made a choice yet, either in this turn, or asked to always allow a tool call in previous tool proposals.
	6) ya and yo will affect the current proposal line under cursor.
	7) yA and yO will affect all proposal	lines in the current answer.
  4) Record user's choices right after the ❓: marker, with ❓:	[yA|ya|yo|yO] to indicate user's choice. This is needed to follow Parley's principle that the transcript file contains the full state of the conversation.
  5) When there's no ❓ in an answer, we go back to the original behavior of waiting for user input at 💬:.
  6) when there's ❓ in an answer and user has made choices for all tools, we automatically execute the tool calls, and insert the tool call results into the transcript file, right after the corresponding ❓: proposal. The format of the tool call result is as follows:
     1) 🛠️: [Tool-Name][tool-call-id]
     2) Tool call result text
  7) after all tool call result are inserted, Parley automatically sends the whole exchange (user question, assistant response with tool call proposals, tool call results) back to the chat completion API, so that the model can see the tool call results in the context, and continue to generate the rest of the answer. This answer should be appended to the current assistant response block, not starting one with a new 🤖: marker.
  8) tool proposal (❓: lines) should be encoded as role="assistant" with "tool_calls" attribute and list of calls proposed.
  9) tool responses (🛠️:) should be encoded as role="tool" in the chat completion API calls, so that the model can see the tool responses in the context.

  The following is an example, but verify if this works with OpenAI's ChatGPT chat completion API. 

```
[
  {"role":"user","content":"Find usages of loginWithToken in the repo."},
  {"role":"assistant","tool_calls":[
    {"id":"call_1","type":"function","function":{"name":"repo_search","arguments":"{\"query\":\"loginWithToken\"}"}}
  ]},
  {"role":"tool","tool_call_id":"call_1","name":"repo_search","content":"{\"matches\":[{\"file\":\"auth.ts\",\"line\":42}, ... ]}"}
]
```

2) at this stage, please mock out the local MCP server's response. 
  1) provide a mock MCP server's tool definition, say web_search, we can assume web_search uses curl to search web.
  2) provide a conversion between MCP's tool definition and OpenAI's function calling definition. Also provide conversion for Anthropic's tool calling definition, as I will test with ChatGPT and Claude first.
  3) provide a mock MCP server's response to a tool call web_search for now for testing the interaction with ChatGPT and Claude.

When you completed this step, I expect the following would work. Note the response from ChatGPT is not precise, you should check out what they return. Note the 🧠: 📝: lines are missing for simplification as they are part of prompting, and might be missing anyway depending on prompting.

===

💬: can you find the latest stock price of google and microsoft?

🤖:[Claude-Sonnet]

Should, I need to search the web.

❓: `{"id":"call_1","type":"function","function":{"name":"web_search","arguments":"{\"query\":\"google stock price\"}"}}`
❓: `{"id":"call_2","type":"function","function":{"name":"web_search","arguments":"{\"query\":\"microsoft stock price\"}"}}`

>> Please choose (yA/ya/yo/yO): 

===

💬: can you find the latest stock price of google and microsoft?

🤖:[Claude-Sonnet]

Should, I need to search the web.

❓:[yA] `{"id":"call_1","type":"function","function":{"name":"repo_search","arguments":"{\"query\":\"google stock price\"}"}}`

🛠️: [repo_search][call_1]

`{"matches":[{"google stock GOOGL price is $911 as of today" ... ]}`

❓:[yA] `{"id":"call_2","type":"function","function":{"name":"web_search","arguments":"{\"query\":\"microsoft stock price\"}"}}`
🛠️: [repo_search][call_2]

`{"matches":[{"microsoft stock MSFT price is $544 as of today" ... ]}`

Ok, I found the price of GOOGL is $911 and MSFT is $544 as of today. Do you want something else?

💬: 

===

Notice the new 💬: at the end, indicating a completion of last turn, which has 2 tools calls, and 2 chat completion calls. Note the transcript has the full state, so later on, if user continue to ask other questions, from what's in the transcript, we can construct what to send to the chat completion API, without needing to call the MCP server again, or waiting for user response, as user's choice and MCP response are coded in the transcript itself.

Now go ahead to implement this part of the feature. Do not implement actual MCP server interaction yet, just mock out the MCP server response for now. I'll import some MCP client integration later. Right now just focus on handling this extended turn structure, with tool call proposals, user choices, tool call results, and multiple chat completion calls in one turn.
