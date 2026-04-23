---
name: xx-skill-gen
description: "Use when the user wants to create a new skill from scratch by providing a name and description. Invoked as /xx-skill-gen <new-skill-name>."
---

# Skill Generator

Generate a new skill scaffold by gathering requirements and optionally brainstorming the design.

## Usage

```
/xx-skill-gen <new-skill-name>
```

## Process

1. **Parse the skill name** from the argument. If no name is provided, ask the user for one.

2. **Ask for initial description** — Ask the user:
   > "What should this skill do? Give me a brief description of its purpose, when it should trigger, and what behavior it should produce."

   Wait for the user's response before proceeding.

3. **Assess clarity** — After receiving the description, evaluate whether the requirements are clear enough to generate a skill directly:
   - **Clear enough**: The user described specific triggering conditions, expected behavior, and there are no open questions about scope or design.
   - **Ambiguous**: The description is vague, covers multiple concerns, has unclear scope, or you have questions about how it should work.

4. **If ambiguous** — Invoke the `superpowers-brainstorming` skill to collaboratively explore intent, requirements, and design before generating the skill. The brainstorming output becomes the spec for the skill.

5. **If clear** — Proceed directly to skill generation.

6. **Generate the skill** — Create the skill directory and SKILL.md:
   - Directory: `.claude/skills/<new-skill-name>/`
   - File: `.claude/skills/<new-skill-name>/SKILL.md`
   - Follow the SKILL.md structure from `superpowers-writing-skills`:
     - YAML frontmatter with `name` and `description` (description starts with "Use when...")
     - Overview section
     - When to Use section
     - Core process/pattern section
     - Common Mistakes section (if applicable)

7. **Present the generated skill** to the user for review and approval.

## Key Rules

- **Always ask for description first** — never generate a skill from just a name
- **Default to brainstorming** — when in doubt about clarity, invoke brainstorming rather than guessing
- **Follow writing-skills conventions** — the generated SKILL.md must follow all conventions from `superpowers-writing-skills` (CSO, frontmatter format, token efficiency)
- **One skill at a time** — generate, review, then move on
