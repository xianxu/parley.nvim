# TODO

## A note taking plugin

I want the ability to quickly take notes. This is not interacting with LLM, but very simple function and I decide to include in Parley. Consider the following:

1. Notes are just markdown files, organized under one root directory.
2. Directory under root is organized in two levels: year/month, e.g. 2025/04, 2025/05, etc.
3. file names in those directory (such as 2025/04) are organized as {date}-some-subject-of-the-file.md, e.g. 30-meeting-with-mike.md. 
4. using directory and file name together, you can determine the date of the note.
5. the plugin would provide the following functionalities and hotkeys.
    1. <C-n>n: create a new note file. The file name would be {date}-some-subject-of-the-file.md. The user would be prompted to input the subject of the file. The file would be created under the appropriate directory. The file would be opened in a new buffer.
	2. <C-n>f: find a note file. The user would be prompted to search for a note based on the subject of the file (part of file name) using telescope fuzzy finder. The file would be opened in a new buffer.


