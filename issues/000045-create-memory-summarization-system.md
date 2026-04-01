---
id: 000045
status: open
deps: []
created: 2026-03-31
updated: 2026-03-31
---

# create memory summarization system

All the chats are in local drive, it's very easy to create memory summarization, so parley becomes person. Chats have tags, so we can even summarized for each [tag] and overall. 

Memory system would map from a chat file, to a summary, 📝, maybe we can just grep lines starting with 📝 for some glaces of what is discussed. For chats without such lines, we will need to do a round to ask LLM to summarize. and in those case, maybe have a front matter field called summary: ...

Then all the lines of summary: in front matter; and all the 📝 liens form memory of a person's interaction. organized by tags in the file. 

Then, those memory can be constructed into system prompt, e.g. with prompt "compress this into a Claude/OpenAI-ready token-optimized prompt to encode user preference"

The generated additional "preference prompt" would be appended to system prompt, based on the tags of a chat. 

We are into how do we organize system_prompt territory. The current structure is simple, just a string. but in the future, there should be:

1. "structural prompt": e.g. as LLM to generate 🧠:, 📝: lines.
2. "user preference": e.g. what user may initially put in. 
3. "discovered user preference": based on above memory mechanism.

I guess another interesting aspect is that once we have tool use, then user can ask about past chat "what did I tell you about XXX", and we can use `ack XXX` to find the context in chats, or notes, then ask agent to summarize. 

## Done when

-

## Plan

- [ ]

## Log

### 2026-03-31

