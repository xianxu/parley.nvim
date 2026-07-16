
# Issue #86: system prompt should be editable outside config

**State:** OPEN
**Labels:** 
**Assignees:** 

## Description

Right now, system prompt is not editable outside configuration system. we should make them editable. we start with defaults from configuration file, but then should allow cloning them and updating them. updated system prompt are stored and overrides prompts with same name. 

we should also allow addition, deletion of custom system prompts. note that system prompts come from two different sources, one in parley.defaults and one from user edits, so when user delete edits of existing system prompts in parley.defaults, they merely delete their customization, not the base prompt. in UI we should have some distinction among those built-in that you can't delete, and things you can. 
