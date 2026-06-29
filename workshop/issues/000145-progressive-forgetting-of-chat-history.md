---
id: 000145
status: open
deps: []
created: 2026-06-26
updated: 2026-06-26
---

# Progressive forgetting of chat history

parley already have chat_memory.max_full_exchanges, after which I believe we would use in-chat summary for that turn. I'm thinking that tool call request/result might be less valuable, than the text summarization of those tool call results, thus thinking it might worth to create a multi-tier trimming process, first not sending tool call result, then not sending full exchange etc.

on the other hand, I'm also less sure, as this algorithm will destroy the prefix caching. existing max_full_exchanges mechanism already do so and cached read cost is 10% of otherwise. 

further, different providers have different cache semantics. I remember claude requires explicit marking of what to cache, while it's automatic for chatgpt. 

needs some discussion.

## Done when

-

## Spec


## Plan

- [ ]

## Log

### 2026-06-26

