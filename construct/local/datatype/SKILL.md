---
name: xx-datatype
description: "Use when the user is requesting an artifact (capture, save, record, create) AND the substance to preserve is conversational context they've already produced. Skip when the user is stating facts, asking questions, or asking the agent to generate substance from scratch. Also trigger when editing markdown with known frontmatter type:"
---

# Datatype

Create and edit *typed data artifacts* — markdown files whose shape is declared by a prototype in `construct/datatype/`. Datatypes are pluggable: adding one means writing a new prototype file, not changing this skill. (Skill name is `datatype` to keep the meta-concept distinctive; artifacts produced by it are still called *data* and live under `data/`.)

## When to use

This skill is the primary way the agent captures conversational substance into a durable, structured file. It activates on three triggers, in priority order:

1. **Conversational capture or authoring** (the common case). Use judgment in three steps. Don't pattern-match a verb-noun grammar — read the turn as a whole.

   **Step 1 — classify the user's turn.** Conversational turns fall into three exhaustive buckets:

   - **Stating a fact or sharing context.** *"We're going to France this summer."* *"I had a meeting with Alice."* *"The launch is next Tuesday."* The user is describing reality, not asking for it to be preserved. Don't trigger.
   - **Asking a question.** *"How do I plan a trip?"* *"What's the right way to track this?"* Information is being requested, not deposited. Don't trigger.
   - **Requesting an artifact.** *"Let's capture this trip."* *"Save these meeting notes."* *"Create a product for ariadne."* The user wants something to land in a file. Proceed.

   The verb is a hint, not the determining factor. *"Remember this list"* requests an artifact; *"I'll remember to email her later"* states a fact. *"Capture the moment"* sounds capture-shaped but might be a metaphor inside a wider sentence. Read the whole turn, not the keywords.

   **Step 2 — is the request durable capture of existing substance, or generative work?** Not every artifact request is datatype-dispatch territory. This skill captures conversational substance the user has *already produced* (described items, decisions, listed names, prior context). It does NOT generate substance from thin air.

   - *"Save the contractors we just listed"* — substance present (the listing) → capture.
   - *"Capture this trip we've been planning"* — substance present (the prior conversation) → capture.
   - *"Plan a trip to France for me"* — no substance, request is generative → fall through to general agent behavior; not this skill's job.
   - *"Create a function that does X"* — generative request on a non-datatype noun → fall through.

   If the user is asking the agent to *produce* the substance, it's coding / research / brainstorming territory. The dispatcher takes over only when there is existing substance worth preserving.

   **Step 3 — which datatype fits?** Semantically match the user's artifact against the available prototypes' descriptions. Each prototype's `description:` field starts with "Use when…" and IS the matching surface. See [Type lookup](#type-lookup) for enumeration; matching uses `name` + `description` only. Three sub-cases:

   - **Single clear fit** → apply that prototype. State the destination in your response so the user can redirect if you guessed wrong.
   - **Multiple comparable fits** → present 2–3 candidates with a one-line context each (drawn from their descriptions), ask which.
   - **No fit, but the request is capture-shaped** → offer either (a) route to `type.md` (the meta-prototype) to design a new type, or (b) write a freestanding markdown file under the user's chosen location, untyped.

   **Updates to existing instances** (*"add Florence to our summer trip"*, *"update the contractors list"*) fold naturally into Step 3 — the artifact reference identifies the parent's type via semantic match, the dispatcher then routes to its §7 update flow (below) rather than creating a new file. No separate trigger logic needed.

   When the user is just sharing context, treat it as conversation. Do not proactively offer to capture unless the user has signaled the intent.

2. **Slash invocation:** `/xx-datatype <type> [path]` — explicit, used when the user already knows the type and wants no inference. Bypasses the three-step judgment.

3. **Edit-time application:** when opening a markdown file whose frontmatter has `type: <X>` and `<X>.md` exists in a known prototype location, follow that prototype's authoring instructions for the edit.

If the conversational trigger is unclear (the user said "remember this" with no clear referent), list the available types and ask which fits — but only after you've reached Step 3 and found no clear semantic match. Don't ask preemptively; use judgment first.

## Type lookup

**Naming convention:** a prototype's filename (without `.md`) is the type name. `meeting-notes.md` defines `type: meeting-notes`. Filename and the prototype's own `type:` frontmatter field must agree.

Prototypes live in two places. Lookup precedence is local-first:

1. `<repo>/datatype/<name>.md` — project-local override.
2. `<repo>/construct/datatype/<name>.md` — shared, symlinked from ariadne.

Local fully shadows shared (no merging). If `<name>.md` is not found in either, list the available types from both directories and ask the user, or offer to create a new one (which routes to applying `type.md` — the meta-prototype).

To enumerate available types: list `*.md` files in both directories, dedupe by filename (local wins). For type *selection* (matching the user's request to a type), read only each prototype's frontmatter block — `name` and `description` are sufficient — not the body. The body is loaded only after a type is chosen, when applying it. This mirrors how skills themselves load: descriptions are eager, bodies are on-demand. A reasonable extractor: `awk '/^---$/{c++; next} c==1' <file>`, or any tool that stops at the second `---`.

## The dispatcher's universal responsibilities

These belong to *this* skill, not to per-type prototypes. Every prototype assumes them.

### 1. Distill the conversation

Before asking the user for input, scan the relevant chat context for:
- Field values mentioned explicitly (dates, names, places, IDs).
- Lists or items the user has been enumerating.
- Decisions, action items, commitments, or steps performed.
- Surrounding context that tells you what *kind* of thing is being captured.

Pre-fill the artifact with what you found. Then ask only for what's still missing or ambiguous.

Don't make the user re-state things they just said.

### 2. Discover where files live

At the start of a capture, learn the existing folder structure: run `find memory/ -type d` if a `memory/` directory exists at the repo root, otherwise `find . -type d -not -path './.git/*'` against the repo root. (The rest of this skill calls that location the **base** — `memory/` or repo-root, whichever applied.)

Directory names carry **categorical meaning** — `memory/life/family-travel/` says different things from `memory/work/travel/`. Respect existing conventions in the repo. Don't invent a parallel structure.

Decision tree for the destination:

1. **User gave an explicit path** (e.g., "save it under `memory/life/family-travel`") → use it. Create intermediate directories if needed.
2. **A clearly fitting existing directory exists** → use it. State the choice in your response so the user can redirect if you guessed wrong.
3. **Multiple plausible directories exist** → propose the top 1–2 candidates with one-line rationale each, ask which.
4. **No fitting directory** → propose a new path that follows the existing naming scheme. Don't speculatively create deep nests.

Filename guidance is per-prototype (each prototype's authoring instructions specify the convention).

### 3. Apply the prototype

**The prototype is a specification, not a template.** Read it as a document describing what an instance should contain — do not copy it verbatim and do not carry its meta-sections into the instance.

A prototype's body has the following meta-sections: lede, **Frontmatter shape**, **Body skeleton**, **Authoring instructions**, **Search recipes** (recommended), **Rules** (optional). None of these sections appear in the instance.

To produce an instance:
- **Frontmatter** — read the prototype's *Frontmatter shape* table; emit only the fields it lists (with the values you've gathered or asked for). Don't carry over the prototype's own frontmatter (`type: <protoname>`, etc. — instead, the instance's `type:` is the prototype's name).
- **Body** — read the prototype's *Body skeleton* section; the structure described there *is* the instance's body. Emit those sections in the order given. Skip optional sections that have no content (per the no-padding rule).
- **Behavior** — follow the prototype's *Authoring instructions* during the application process (which fields to ask for vs. infer, default location hints, filename convention). These are guidance for *you* (the dispatcher); they are not content for the instance.

Special case: applying `type.md` (the meta-prototype) produces a new prototype, whose body skeleton happens to be those same four meta-sections. The convention is consistent — instance shape always tracks prototype's *Body skeleton* section — it's just that for the meta-prototype, that skeleton is the prototype-shape itself.

The prototype is the contract. The dispatcher executes it; it doesn't ship the contract along with the result.

### 4. Confirm before writing

Before writing the file:
- Show the user the **destination path** and the **filename**.
- For non-trivial artifacts, show a brief preview of the frontmatter and section list.
- Wait for confirmation, but don't ceremonially confirm trivial cases. If the user said "save these meeting notes from the call with Alice today" and everything is unambiguous, just write it and report the path.

### 5. Editing existing instances

When invoked against an existing typed file (the user pointed at it explicitly, or opened it for editing):
1. Read the file's `type:` frontmatter field.
2. Look up the prototype.
3. Apply the prototype's authoring instructions to the edit — specifically, the parts about what belongs in which section, what shape fields take, what to ask vs. infer.
4. Make the edit. Update `last-reviewed`, `last-run`, or similar staleness markers if the prototype declares them.

### 6. Search and listing — use `rg`

There is no index. Finding instances is `rg` against the working tree. When the user asks to find, list, or filter typed artifacts, consult the prototype's **Search recipes** section first — it has worked-out queries for the common cases. Build new queries when the user's filter is unusual, but stay within the same conventions:

- `rg -l "^type: <name>"` — find files of a type.
- Pipe through `xargs rg -l <pattern>` to narrow.
- Frontmatter fields are anchored with `^` (e.g., `^date: 2026-04`).
- Frontmatter list values use inline form (`attendees: [alice, bob]`), so a name match relies on word-boundary anchors: `attendees:.*\balice\b`.

When emitting a new instance, follow the same conventions so future searches stay sharp.

### 7. Update an existing instance from conversational context

The user often references an existing artifact obliquely — "let's add Florence to our summer trip", "update the contractors list with this new plumber", "log the action items from today onto the Q2 roadmap notes". This is a capture intent, but the destination is an *existing* file, not a new one.

Recognize and route to update rather than create:

1. **Detect implicit reference.** Phrases like *"our X"*, *"the X we discussed"*, *"add to the X"*, *"update the X"*, *"log this onto …"*, or any specific noun phrase the user treats as already known. If unsure whether they mean an existing file or a new one, ask once.
2. **Find the file.** Search by topic — `find <base> -type f -name '*.md'` then grep candidates for the user's referenced phrase, or look in the directory the type's prototype suggests as default. If multiple candidates match, list the top 2–3 with their paths and ask which.
3. **Treat as an edit, not a rewrite.** Append, splice into the right section, or modify a specific field — whichever fits the user's intent. Don't reflow or reorder the rest of the file.
4. **Preserve provenance.** If the prototype declares timestamp fields (`last-reviewed`, `last-run`, `updated`), bump them. Otherwise no metadata change is needed.
5. **Confirm the destination once** before writing — show the path and a short summary of the change. The bar is lower than for a new file because the user already named the destination, but a one-line confirm avoids editing the wrong file when multiple candidates exist.

If no existing file matches what the user referenced, fall through to creating a new one (Step 4) — but say so explicitly: "I didn't find an existing X, so I'll create one." Don't silently switch modes.

## Adding a new type

**Check before designing.** Type proliferation is the failure mode — five overlapping prototypes that each capture 90% of the same thing. Before routing to the meta-prototype:

1. List existing types (both shared and project-local).
2. Identify the closest match by purpose, time-shape, and granularity.
3. State the delta to the user: *"`travel-plan` already covers trips with itinerary and bookings — what does the new type need that `travel-plan` doesn't?"* Be specific about the closest match's coverage so the user can answer concretely.
4. Resolve to one of three outcomes:
   - **Use the existing type as-is.** The user's case fits; skip new-type creation.
   - **Extend the existing prototype.** A small addition (one new field, one new optional section) is better than a fork. Edit the prototype directly and apply.
   - **Create a new type.** The delta is large enough that overloading the existing one would hurt both. Proceed to the brainstorm.

Only after that triage: route to the meta-prototype — apply `type.md` to design a new prototype via `superpowers-brainstorming`. That brainstorm produces a new file under `construct/datatype/` (shared) or `<repo>/datatype/` (project-local), and from then on it's available like any other type.

Do not skip the brainstorm step for new types. The frontmatter / body / instructions trinity is non-obvious to design, and getting it wrong upfront makes the prototype useless.

## Rules

- **Conversation > ceremony.** The trigger is usually a casual phrase, not a slash command. Don't insist on the slash form.
- **Distill, don't transcribe.** Capture the substance of the chat, not the dialogue.
- **Be concise.** Human will read what you generate, do not add fluffs.
- **Local overrides shadow shared completely.** No field-level merging.
- **Frontmatter is for queryable, stable, externally-referenced fields.** Free-form prose stays in the body.
- **Don't pad empty sections.** If a section has nothing in it, omit it. `(none)` is noise.
- **Never silently overwrite.** Two cases, two responses:
  - *Unintended collision while creating a new file* — ask: append, version (`-v2`), or rename.
  - *Intentional update of an existing file* (Step 6 above) — fine to modify in place after a one-line confirm of the path and the change.
- **Filenames respect the prototype's convention.** If the prototype specifies `<date>-<slug>.md`, use that. Don't second-guess.
- **Greppable frontmatter.** Lists go inline (`[alice, bob]`), dates are ISO, scalar values stay on one line. The `rg` toolchain depends on it.
- **Surface unknowns explicitly.** If a required field can't be determined, write `TBD` or `<unknown>` rather than fabricating, and call it out in the response so the user can fill in.
- **Never auto-commit data artifacts.** Write the file and stop — leave it as an uncommitted change in the working tree so the user can `git status` / `git diff` and review what was captured. The user commits these on their own schedule. This is intentionally different from the coding/issue workflow in `AGENTS.md` (which has issue-sync auto-pushing): data artifacts are personal capture, not shared engineering state, and the user wants to eyeball them before they enter history. Same goes for updates to existing instances (Step 7) — modify in place and stop, do not commit.
