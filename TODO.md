# TODO

## Customization for non-chat md files

Allow some customization for any md file that's not a chat. 

1. Parley would handle two kinds of files, all markdown based. One is chat transcript as handle previously, they are in that chat_dir. The other is any other md file. 

2. In non-chat md file, allow @@ line to refer to some chat file. In non-chat md file, upon detecting "@@ " at the start of a line, bring up chat finder, for user to select which chat file name to insert. Once file name is inserted, it should be of format @@/path/to/chat/file: {topic of the chat}. in a single line.

3. There should also a mode to insert new chat directly. Let's use the syntax: @@+ at start of a line. When this is detected, a new chat file name should be created and inserted at the location, replace the @@+ marker with @@/path/to/new/chat/file:, and user can input the topic of the chat in that line. Note, the new chat file is not yet created. When user opens the file, from this line with <C-g>o, we would notice the chat is not yet available, and at that moment, create it and bring up a new buffer to display that. 

4. Use the title of the chat file for display, behind the file name for clarity of its content. 

5. Allow same file jumping behavior, <C-g>o to open the chat file under cursor.

## Chat finder handling large amount of files

As user uses more of parley, the number of chat files will grow to the point it's harder for the user to find information. Let's create a feature to handle that.

Chat finder should by default only allow search of recently created files. The recency should be configurable, default to three months. The age of the chat file should be the last access time. 

Chat finder should have a switch to allow search of all files. Use <C-g>h to do that switch. Make this keybinding configurable.

## A note taking plugin

I want the ability to quickly take notes. Consider the following:

1. notes are just markdown files, organized under one root directory.
2. directory under root is organized in two levels: year/month, e.g. 2025/04, 2025/05, etc.
3. file names in those directory (such as 2025/04) are organized as {date}-some-subject-of-the-file.md, e.g. 30-meeting-with-mike.md. 
4. using directory and file name together, you can determine the date of the note.
5. the plugin would provide the following functionalities and hotkeys.
    1. <C-n>n: create a new note file. The file name would be {date}-some-subject-of-the-file.md. The user would be prompted to input the subject of the file. The file would be created under the appropriate directory. The file would be opened in a new buffer.
	2. <C-n>f: find a note file. The user would be prompted to search for a note based on the subject of the file (part of file name) using telescope fuzzy finder. The file would be opened in a new buffer.

## Remove parameter N in ParleyChatRespond

That's from past
