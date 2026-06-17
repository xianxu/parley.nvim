---
id: 000133
status: working
deps: []
created: 2026-06-17
updated: 2026-06-17
---

# parley review parity with fix/docflow skill in ariadne

I'm thinking about improving document review tool, to be more on parity of coding agent, such that parley can be used more independently. This continues my search of the equilibrium of where AI can help human. 

Specifically, the following implements:

1/ bind the alt+o to the skill open, for easier access. 

2/ last used skill should be selected by default. 

3/ review tool support free form instruction, those instruction would be review location neutral, e.g. give me some ideas, or expand based on the sketches and make it a document etc. or, we may add selection of different stages of review. think the overall process of constructing a document,sometimes we lack some good material, only have vague ideas; other times there is stage we have material, need some organization and structuring; sometimes we want to do some tuning of tone; sometimes we want copy edit and spell check across. One possible improvement would be that upon triggering review tool, it is presented with a menu to select which one of the review is requested, each would just respond to some specific prompting. then the "free form" prompt can be an escape: let's chat about what review you want. 

4/ when there's no markers, general review can be performed. 

5/ generally, check the ../ariadne/construct/local/fix skill, there are various aspect that can be borrowed. for example, in terms of editing, when to consider portion of the document as more settled (from top to bottom). Auto commit as part of each back and forth etc. 

6/ the `review` tool is the initial trigger, we should have faster shortcut to faster ping pong. potentially the alt+return, essentially same as `pair` and `parley`'s chat mode. imagine if we are in a "review process" already (initially manually triggered with the `review` tool) alt+return would trigger the next round. or maybe, alt+return would pop up a dialog with some menu for user to confirm what review's submitted. this is the same menu mentioned in point 3/ in terms of "overall process of constructing a document". and the menu item selected would be sticky, so that next alt+return would have that selected. 

7/ now think this through, review modes would roughly the following (aka the menu)
    7.1/ developmental (we call it brainstorming)
    7.2/ line editing 
    7.3/ copy editing
    7.4/ proof reading
    7.5/ review of fact (fresh context 2nd agent review)
    7.6/ free form

8/ and below that menu, we have space to type in anything. so if 7.1/ is selected while user also typed in text, it's fine, both are sent as instruction. this edit box blow the menu should be a normal buffer really with good editing experience.

9/ alt+return would trigger also the quickfix that contains items needing user attention.

## Done when

-

## Spec


## Plan

- [ ]

## Log

### 2026-06-17

