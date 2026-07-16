
# Issue #90: chat topic inference for child chat

**State:** OPEN
**Labels:** 
**Assignees:** 

## Description

right now, (I think) that child chat's context include big portion of parent chat, up to the location of child chat's inserted. as a result, the inferred child chat topic is often the same as the parent, because of shared context. while this context inheritance is desired for normal question and answers, it interfere with topic generation. 

change the topic generation to only use context in the current file
