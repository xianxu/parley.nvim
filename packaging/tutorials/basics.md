---
topic: 2. A Bit More Basics
file: basics.md
tags:
---

@@More Basics@@
# A Bit More Basics

You can use Parley as a collection of conversations, and branch a conversation
when you want to drill in. Let's practice with this chat.

> In you are new to VIM, remember the check what mode you are in at button left
> corner. In ./welcome.md, we covered NORMAL, INSERT, COMMAND modes.

## About these filenames

This lesson is `basics.md`; the first lesson is `welcome.md`. These tutorial
files have stable names so they are easy to recognize and refer to.
Ordinary new chats use a time stamp followed by a topic slug as file name.

## 1. Find your chats

Chat Finder helps you search past conversations.

1. Press `option+f`
2. Use Up/Down arrow key to select. You can also select using mouse.
3. Or type `Welco` to filter down based on file name.
4. Press `return` to open the file. Mouse double click also works. 
5. Then open Chat Finder (`option+f`) again, select `Basics` to return to here.

## 2. Create a chat

Use `option+n` to create a new Parley conversation. Parley autosaves your edits
about a second after you leave INSERT mode. You can always save using `:w`
command in NORMAL mode.

@@Navigate with outline@@
## 3. Navigate with the outline

It is easier to explore a long conversation with `outline`. In chats it lists 
questions, linked branches, and named outline markers. 

1. Press option+t to open outline.
2. Select the marker "→Try it", press `return` or double click with mouse.
3. Send the question below it with `option+return` and wait for the answer.
4. Open the outline again to find your question or return to another section.

@@How to Tag@@

You can take with @@tag@@ at start of a line to create a short cut in the
outline. Those tags help you navigate. A particular kind of tag right before
a question: @@_@@ hides the question from outline.

Try to use `option+t` outline to navigate around.

@@Exploring with branches@@
## 4. Explore a side question with a branch 🌿:

A branch 🌿: is a separate chat linked to the current one. Use it when answers
raise more questions and you want to explore them without losing your place in 
the main thread. This is a core Parley function.

After sending the rainbow question below, try this:

1. Read the answer, and find where you have more questions. Or just take the
   side questions AI *should* suggest. 
2. Select the text where you have question, or just select the AI suggested
   side question.
3. Press `option+i`. Parley creates and opens a linked chat with selected text
   as part of questions. If no text is selected, the linked chat is inserted in
   the next line. 
4. The child opens ready for your question with previous selected text quoted.
5. Send with `option+return`. You can keep asking questions in that branch, 
   or further branching out from that branch.
6. Press `option+t` to open the outline, and you can come back here by selecting
   "→Exploring with branches". 

The main chat keeps a branch link marked with a leaf. Put the cursor on that
link and press `option+o` to open the child again. In the child chat, a back
link to parent chat is automatically inserted when a branch is created.

Continue with [3. Advanced](advanced.md) for project folders, local tools,
transcript context, and pasting images. Remember alternatively, `option+o`
over ./advanced.md opens it as well.

@@Try it@@

Place the cursor on the question below and press `option+return`. You can replace
it with a subject you are curious about: this is your editable conversation. 
`option+return` on a question already with answer, like the following one, will
ask AI to answer that single question again, replacing existing answer.

New to Vim? Open [4. VIM Basics](vim-basics.md) for navigation, undo, search,
and everyday editing. In Normal mode, put the cursor on the link and press
`option+o`.

💬: How does a rainbow form? Give me a short explanation and suggest two
interesting side questions I could explore in a separate chat.

🤖:[gpt-5.6-terra*]

### Plan
- Explain the three key optical steps concisely: refraction, reflection, and color separation.
- Suggest two focused questions that build naturally from the explanation.

A rainbow forms when sunlight enters water droplets in the air. The light **bends** as it enters, **reflects** off the droplet’s inner surface, and bends again as it leaves. These bends separate white sunlight into its component colors, creating the familiar arc when the Sun is behind you and rain is in front of you.

Two side questions:
1. Why do rainbows appear as arcs, and can you ever reach the end of one?
2. How do double rainbows form, and why are their colors reversed?

📝: you asked about how rainbows form and requested two side questions, I answered with the roles of refraction, internal reflection, and dispersion, plus questions about color order and double rainbows

💬: what determines the width of each color band in a rainbow? is it always fixed proportion? for example how big is the red band vs yellow band. 

🤖:[gpt-5.6-terra*]
The color-band widths are **not fixed proportions** in a strict sense.

For the primary rainbow, each color exits raindrops at a slightly different angle because water bends different wavelengths by different amounts:

- **Red** is seen at about **42°** from the antisolar point.
- **Violet** is seen at about **40°**.
- So the entire visible primary rainbow is roughly **2° wide** in angular radius.

The bands do not have sharp physical boundaries. Sunlight contains a continuous spectrum, but our eyes and brain divide it into named colors—red, orange, yellow, and so on. That means asking for “the width of yellow” requires choosing an arbitrary wavelength range for yellow.

A useful approximation is that colors are distributed unevenly across the rainbow because water’s refractive index changes unevenly with wavelength. **Blue and violet tend to be spread over a somewhat larger angular range per unit of wavelength than red**, but the apparent widths also depend on:

- the size distribution of raindrops (small drops blur colors),
- the Sun’s apparent size,
- overlapping light from neighboring wavelengths,
- atmospheric haze and your visual perception.

So: the **red-to-violet angular span is fairly stable** for ordinary water droplets, but the perceived width of each named color band is not universally fixed.

📝: you asked what determines rainbow color-band widths and whether their proportions are fixed; I explained that wavelength-dependent refraction sets a roughly 2° red-to-violet span, while individual named bands have non-fixed, perception- and conditions-dependent widths.

💬:


