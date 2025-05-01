# TODO

## A note taking plugin

I want the ability to quickly take notes. This is not interacting with LLM, but very simple function and I decide to include in Parley. Please implement the following: 

1. Notes are just markdown files, organized under one root directory. Make this root directory configurable.
2. Directory under root is organized in two levels: year/month, e.g. 2025/04, 2025/05, etc. This is uniform.
3. File names in those directory (such as 2025/04) are organized as {date}-some-subject-of-the-file.md, e.g. 30-meeting-with-mike.md. 
4. Using directory and file name together, you can determine the date of the note.
5. The plugin would provide the following functionalities and hotkeys.
    1. <C-n>n: a global hotkey, create a new note file. The file name would be {date}-some-subject-of-the-file.md. The user would be prompted to input the subject of the file. The file would be created under the appropriate directory. The file would be opened in the current window. Spaces in the subject user inputted, would be replaced with dashes.
	2. <C-n>f: find a note file. The user would be prompted to search for a note based on the subject of the file (part of file name) using telescope fuzzy finder. The file would be opened in the current window. This Note Finder, is very similar to Chat Finder, from user interface POV, but keep code separate as I see future diverging needs.

## Note Finder should only search for recent notes

Similar to Chat Finder, the Note Finder should only search for recent notes by default. This is configurable, default to 3 months.


