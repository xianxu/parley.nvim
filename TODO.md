# TODO

@@~/Library/Mobile Documents/com~apple~CloudDocs/parley/2025-04-27.19-08-22.820.md: tech: LLM integration

## Customization for non-chat md files

Allow some customization for any markdown files that is not a chat. 

1. Parley would handle two kinds of files, all markdown based. One is chat transcript as handle previously, they are in that chat_dir. The other is any other markdown file, not in the chat_dir, or following the header convention.

2. In non-chat md file, allow @@ line to refer to some chat file in a similar way as how @@ in chat file is handled. That is, line starting with @@ should be highlighted, and <C-g>o to open the chat file.

3. Implement a function to insert a chat file from an interface same as Chat Finder. This should be bounded to the same <C-g>f, just that upon selecting in non-chat file, instead of opening the file from Chat Finder, insert the file path at current cursor location, in the format of @@/path/to/chat/file. Currently <C-g>f is bound only in chat window, thus won't generate conflict.
@@

4. Implement a function to create a new chat file, and insert the newly created file name as the current cursor location. in this mode, file's generated but not opened automatically. Bind this locally to non-md files as <C-g>n. This won't conflict with the search functionality <C-g>n in chat window, as that's locally bound to chat file.

4. Use the title of the chat file for display, behind the file name for clarity of its content, as described before. The subject of the chat will be refreshed every time ^@@:/path/to/chat/file is parsed, in case they are updated. Do this as part of the highlight process.

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


