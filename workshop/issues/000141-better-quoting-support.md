---
id: 000141
status: working
deps: []
created: 2026-06-25
updated: 2026-06-25
started: 2026-06-25T18:34:47-07:00
---

# better quoting support

we allow alt+q for user to directly quote in chat buffer and ask follow up questions. here are some improvements I want to make to that. some fresh: 🤖<quoted text>[question] is translated into next turn as question from user:

> quoted text
question

and the original quoted text is decorated as [quoted text] in original location. 

improvements:

1. add a newline between quoted text and question, and also use [quoted text]
> [quoted text]

question

2. allow the * search inside [] to match the whole string including []. this way, when user press * or # inside the anchor, they will jump likely to the referenced text.



## Done when

-

## Spec


## Plan

- [ ]

## Log

### 2026-06-25

