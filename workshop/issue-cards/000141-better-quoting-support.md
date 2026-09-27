---
id: '000141'
status: done
started: 2026-06-25T18:34:47-07:00
created: 2026-06-25
updated: 2026-06-25
estimate_hours: 1.5
actual_hours: 1.5
---

# better quoting support

## Problem

we allow alt+q for user to directly quote in chat buffer and ask follow up questions. here are some improvements I want to make to that. some fresh: 🤖<quoted text>[question] is translated into next turn as question from user:

> quoted text
question

and the original quoted text is decorated as [quoted text] in original location. 

improvements:

1. add a newline between quoted text and question, and also use [quoted text]
> [quoted text]

question

2. allow the * search inside [] to match the whole string including []. this way, when user press * or # inside the anchor, they will jump likely to the referenced text.
