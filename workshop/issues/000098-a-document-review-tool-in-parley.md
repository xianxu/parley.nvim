---
id: 000098
status: open
deps: []
created: 2026-04-11
updated: 2026-04-11
---

# a document review tool in parley

center around markdown files, and use special syntax to allow users to comment on a document. e.g. maybe with syntax like: ㊷[I found this too offending]

then create get agent to update the draft based on those notes, their goal is to remove those ㊷[comments] while incorporating the comment into their update. 

This would result in a series of edit_file tool call. 

We need some good system prompts. For example, comments assumed to be local, but can also be global, depending on the comment itself. 

I can also see agent decide to address some aspect of comment, and ask more questions for a command, thus creating a loop. In that case, I suspect it can look something like: 

㊷[I found this too offending]<can you be more specific?>

And then we can have binding for user to add more context, e.g. maybe the quick fix. and user is supposed to then replace that to.

㊷[I found this too offending]<can you be more specific?>[referring to the joke about Asian people]

So basically fix to quick fix is if you have odd number of those sections. do create coloring for <> for markdown.

There would be some key binding to check if there are any remaining things. 

keybindings:

<C-d>i: insert a ㊷[comment], cursor inside [] and in insert mode.
<C-d>r: trigger agent rewrite based on feedback in ㊷[comment]. 
<C-d>v: validation, e.g. are there user comment left unaddressed replaced or with <follow up questions>. there are two states here. after <C-d>r, in normal situation, all comments are addressed, or <follow up question asksed>. however, if this didn't happen, I guess we will just keep trying to submit to agent.

this needs tool call, basically agent both need to provide what to edit, and also tool calls (edit_file) to actually change the current file.

## Done when

-

## Plan

- [ ]

## Log

### 2026-04-11

