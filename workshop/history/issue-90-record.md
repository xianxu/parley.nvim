# Issue #90: Chat topic inference for child chat

## Problem
Child chat topic generation includes ancestor (parent) messages in context, causing inferred topics to mirror the parent chat topic.

## Root Cause
In `chat_respond.lua`, ancestor messages are injected into `messages` at lines 754-763. Later at line 1040, `topic_msgs = vim.deepcopy(messages)` copies the full message array including ancestors for topic generation.

## Fix
1. [x] Track `ancestor_msg_count` after ancestor injection
2. [x] When building `topic_msgs` for topic generation, skip ancestor messages (indices 2 through `ancestor_msg_count + 1`)
3. [x] Test: all existing tests pass, lint clean (pre-existing warning in outline.lua only)

## Files Changed
- `lua/parley/chat_respond.lua` — track ancestor count, filter topic messages
