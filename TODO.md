# TODO

## Customization for non-chat md files

Allow some customization for any markdown files that is not a chat. 

1. Parley would handle two kinds of files, all markdown based. One is chat transcript as handle previously, they are in that chat_dir. The other is any other markdown file, not in the chat_dir, or following the header convention.

2. In non-chat md file, allow @@ line to refer to some chat file. In non-chat md file, upon detecting "@@ " at the start of a line, bring up chat finder, for user to select which chat file to insert. Once file name is inserted, the line should be formatted as @@/path/to/chat/file: {topic of the chat}. in a single line. 

3. There should also be a mode to insert new chat directly in non-md files. Let's use the syntax: @@+ at start of a line. When this is detected, a new chat file name should be created and inserted at the location, replace the @@+ marker with @@/path/to/new/chat/file. Note, at this point, the new chat file is not yet created. When user opens the file, from this line with <C-g>o, we would notice the chat is not yet available, and at that moment, create it and bring up a new buffer to display that. 

4. Use the title of the chat file for display, behind the file name for clarity of its content, as described before. The subject of the chat will be refreshed every time ^@@:/path/to/chat/file is parsed, in case they are updated.

5. Allow same file jumping behavior, <C-g>o to open the chat file under cursor, as described before.

## A note taking plugin

I want the ability to quickly take notes. This is not interacting with LLM, but very simple function and I decide to include in Parley. Consider the following:

1. Notes are just markdown files, organized under one root directory.
2. Directory under root is organized in two levels: year/month, e.g. 2025/04, 2025/05, etc.
3. file names in those directory (such as 2025/04) are organized as {date}-some-subject-of-the-file.md, e.g. 30-meeting-with-mike.md. 
4. using directory and file name together, you can determine the date of the note.
5. the plugin would provide the following functionalities and hotkeys.
    1. <C-n>n: create a new note file. The file name would be {date}-some-subject-of-the-file.md. The user would be prompted to input the subject of the file. The file would be created under the appropriate directory. The file would be opened in a new buffer.
	2. <C-n>f: find a note file. The user would be prompted to search for a note based on the subject of the file (part of file name) using telescope fuzzy finder. The file would be opened in a new buffer.

## Remove parameter N in ParleyChatRespond

That's from past
