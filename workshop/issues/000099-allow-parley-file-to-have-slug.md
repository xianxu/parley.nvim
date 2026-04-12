---
id: 000099
status: open
deps: []
created: 2026-04-11
updated: 2026-04-11
---

# allow parley file to have slug

right now parley chat files are named by time they are created. this makes creation of chat fast. however, it also makes finding a chat hard in shell, outside chat finder. one way to address this is to put topic as slug at end of the file name. 

One issue is that when parley chat is created, topic is not set yet. So this updated file name scheme, need to work in two ways, both without any slug, or with slug inserted. think this way, the slug is only useful for user of shell to know what a file is about before opening the file. 

And due to the asynchronicity of chat creation, likely this needs to be designed as file renaming operation. i.e. when parley has a subject, an optional step is to rename it when subject is available. if subject later change, we will change the file name as well. 

Going down this path, then we need to update other parts of parley dealing with chat file, as the slug might potentially be outdated. so each file read of file.md, previously we just check file.md, but this need to be changed to try to find file*.md for parley chat files.

## Done when

-

## Spec


## Plan

- [ ]

## Log

### 2026-04-11

