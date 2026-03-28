
# Issue #91: bug fixes in chat tree

**State:** OPEN
**Labels:** 
**Assignees:** 

## Description

1/ relative file doesn't seem to work well. for example, relative parent link is correctly color-coded, but shows warning icon ⚠️. ⚠️ should be used only when the target file doesn't exist yet. in this case the file exist, and parley doesn't have issue jumping to it with <C-g>o. 
2/ same thing happened for chat branch points in parent file. 
