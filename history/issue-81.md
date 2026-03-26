# Issue #81: a tree of chat

**State:** OPEN
**Labels:** 
**Assignees:** 

## Description

THIS IS NOT A CODING TASK, READ IN FULL, THEN DESIGN THIS PRODUCT AREA FIRST, IMPROVE WHAT I OUTLINED BELOW FIRST. WE MAY IMPLEMENT IN THIS TICKET OR CREATE ANOTHER TO DO SO. 

I had this idea that a complex chat will need to be a tree, with different branch of directions to explore. but I couldn't figure out a good and lightweight way to describe a tree in an otherwise flat file. using indention will be too subtle and hard to track. 

now I think we can try the following ideas, of using file link syntax @@chat_file@@. basically 

1. allow @@chat_file@@ in chat file. this points to children chat. 
2. add a way from child chat file to parent one. maybe with syntax of first non-empty line after front matter to be: @@parent_chat@@
3. context is managed as:

main chat:

💬: 1
🤖: 1
💬: 2
🤖: 2
@@child1@@
@@child2@@
💬: 3
🤖: 3
@@child3@@
💬: 4
🤖: 4

Child3 chat:
💬: 1
🤖: 1
💬: 2
🤖: 2

The main chat transcript is submitted to llm as: 💬/🤖 1, 2, 3, 4, essentially ignoring child 1, 2, 3 side chain. 

child 3's submission (context) include 💬/🤖 1, 2, 3, + child3: 💬/🤖 1 then 💬 2, if the cursor is on 💬 2 in child3. 

For now, I'll just rely on manual edit to construct such a tree structure, I envision typical workflow as going in one chat. once that chain is too involved into some minor detail, I can back track to some question in the middle, move all question and answers behind it, into a new chat, to clean up the main thread. then, I can continue. This pattern is essentially: chat and prune. 

4. Create a mechanism to prune, e.g. <C-g>P to prune all exchange (leaving last empty question) after and include the cursored exchange into a new chat file, then insert that chat file as a reference at the current cursor location as @@new-sub-chat@@. 

5. The prune function should regenerate topic based on the pruned content using LLM. 

This will allow what I view as a chat-assisted exploration of a topic, but allowing going into various rabbit holes, then coming back, without putting too much information for future human, and LLM to read about. I guess less an issue for LLM, more an issue for future human to learn about the topic being discussed, as it will feel too disjointed. Then this tree of chat idea is a form of context limiting for future humans. Almost, we are writing a book at the assistant of LLM, human asking guiding questions, and a sub chat, can be viewed as the decision to form a "chapter" in the book. 

6. we need to update related functions in parley to be aware of this tree of chat. For example, outline should show the jump point, and allow jump to those files. They may even pull in directly topics in those files and display questions from sub files with an indent in the outline view. Indention should not be too messy in the context of outline. maybe we don't directly display the questions in sub chat, only do so when we hit return on the subchat file in outline view. then we expand that subchat, so on and so forth. If I hit return on a question within a subchat, then we can jump directly there. we need some design and test here.  

7. Deleting a chat should only delete a single chat in a tree. This might leave dangled chat references, which is OK.

8. Move a chat to a different chat_root though, we should move a whole tree of chat to that location. 

9. investigate and give me a plan around other core concepts that needs updating with the introduction of tree of chats. 
