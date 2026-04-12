# Pitch Deck: Collaborative AI Harness

**Status:** Draft v1
**Date:** 2026-04-11
**Purpose:** Seed-stage funding pitch deck outline

---

## Slide 1: Ariadne

**[Collaborative AI Harness]**

*"Life takes 42 shots."*

One-liner: "AI runs the loops. Humans steer. AI learns. ⟳""

---

## Slide 2: Problem

**AI is powerful but unsustainable to use well.**

- Real problems don't get solved in one shot: human language is imprecise, domain understanding is patchy, market conditions change. They shift as you build and learn new potentials and new constraints. This is an iterative process. 
- Effective AI use requires **multi-shot to convergence** — narrowing infinite possibilities to a concrete outcome. It's a search problem with a stochastic machine. 
- The hard part: at each step, the still infinite remaining choices all look **plausible**. Think AlphaZero — it works because it learns a board evaluation function through self-play. In knowledge work, there often aren't and won't be enough training examples, to guide the search. We take the position that **the human is the evaluation function**. Our job merely is to make this setup sustainable.
- Today's tools, the structure of the agentic loop, and epidemic knowledge are in separate plane, not co-designable. This needs to change. 

---

## Slide 3: The Faster Horse Problem

**Most people are building a faster horse**

- Ford: "If I asked customers what they want, they'd say a faster horse."
- Today's AI tools are horse carriages with a motor strapped on. Copilot autocompletes in your IDE. A chatbot sits in your doc editor. The new capability is forced into the old shape.
- Human-executes-step-by-step, with AI whispering suggestions, is not the car. It's the faster horse.

---

## Slide 4: Insight

**LLMs are a new stochastic OS. New applications layer needs to be built**

- Every platform shift spawns a new application paradigm. GUI → WYSIWYG. Mobile → apps. Internet → SaaS.
- LLMs are the next platform — a stochastic OS that can execute cognitive tasks, **plausibly**. The application layer race starts now.
- The native app looks fundamentally different:
  - AI runs the process loops, humans steer
  - The human role is managerial: providing structure (how loops work) and content (judgment, context, choices)
  - Workflows evolve through use — living structures, not static templates
  - And a natural way for human to define what is **correct**, not only **plausible**

---

## Slide 5: Solution

**A knowledge OS where AI runs the loops and humans steer.**

- **Multi-shot convergence** as the core primitive. Every task is a loop: AI proposes → human evaluates → AI narrows → human steers. Sustainable across sessions, days, weeks.
- **Living skills.** Workflow patterns that evolve through usage. The system develops institutional knowledge about how *you* solve problems. 
- **Human as evaluation function.** Structured checkpoints where human judgment is most leveraged — not "approve/reject a wall of text."
- **Human as architect.** Human understands the underlying agentic loop, and evolve them explicitly, not just letting AI to evolve the structure alone.
- **Persistent, editable state.** Full history is transparent, editable, replayable. Go back, change a decision, re-converge from that point.

---

## Slide 6: How It Works

*(Visual diagram needed. Convey the following:)*

**The convergence loop:**

```
Human sets direction
    → AI executes loop (proposes, uses tools, explores)
        → System surfaces structured checkpoint
            → Human evaluates, steers, provides context
                → AI narrows and continues
                    → ... until convergence
```

**Skills evolve:** Each loop run feeds back into the skill. What the user modifies, skips, or repeats reshapes future runs. The harness molds to the user over time.

**Not just individual — organizational.** Team-level skills capture how *this team* works. New members inherit evolved workflows. This changes how companies are structured.

---

## Slide 7: Demo / The Dogfood Story

**We're building the company using the product.**

- The founder uses an early version of the harness daily to do real work — architecture, planning, coding, decision-making.
- Every milestone of the company is built through multi-shot AI convergence loops.
- This is the proof: if the harness can't accelerate building its own company, the thesis is wrong. 

*(Include concrete example: "Here's how I used the harness to [specific task] — what would have taken X days took Y hours, with better outcomes because...")*

---

## Slide 8: Why Now

- **Capability just arrived.** LLMs can now reliably execute multi-step cognitive tasks as evidently in coding agents' capabilities. Two years ago they couldn't. The stochastic OS just booted up.
- **Tool use is maturing.** Models call tools, execute code, interact with APIs — they're "loop executors" now, not just text generators.
- **The economics are already there.** If an AI loop can do the work, it's cheaper than a human. The question was never cost — it was capability. Capability just arrived.
- **The window is open.** The industry is in its "faster horse" phase. Once someone demonstrates the native paradigm, the shift will be obvious in hindsight.

---

## Slide 9: Market

- **Wedge:** Programmers and technical founders. They feel the pain most, can evaluate the product, and software is the most mature domain for AI tool use.
- **Expansion:** All knowledge work — consulting, legal, product, operations. Any domain where complex multi-step work requires iterative refinement and human judgment.
- **This is not a tool market — it's a platform shift.** We won't capture the whole market, but a slice would have handsome reward.

---

## Slide 10: Business Model

- **Phase 1: Dogfood.** Build a boodstrap in nvim with the capabilities, but rough on interactions. If multi-shot AI convergence can't accelerate building its own company, the thesis is wrong.
- **Phase 2: The Product.** Build a product with the bootstrap, same capabilities, multiple different interfaces to meet where users are. This will be a SaaS of intelligent workflow.
- **Moat: process knowledge lock-in.** The longer you use it, the more your skills evolve to fit you. Switching means losing institutional knowledge. This compounds.

---

## Slide 11: Team

- **[Founder Name]** — Engineering leadership at Meta, Twitter, Microsoft. Builder and manager at scale.
- Dual perspective that produces the insight: deep understanding of both the technical capability of AI *and* the organizational processes it replaces — and the technical details of *how* to replace them. What visibility and safeguards are needed. How to create virtuous loops where human oversight improves AI execution, which earns more autonomy.
- Already building and using the harness daily. Not theorizing — operating.

---

## Slide 12: The Ask

- Raising $1M seed round.
- Use of funds: keying founding team.
- Goal: demonstrate the paradigm with paying dev teams within 1 year.

---

## Competitive Positioning

**vs. OpenClaw** (open-source AI agent, 247K GitHub stars):
OpenClaw is a task executor — "do this for me." It automates well-defined tasks (send email, run test, manage files). The collaborative AI harness solves a different problem: convergence on ill-defined outcomes when you *don't* know exactly what you want. OpenClaw is the faster horse. We're building the car.

**vs. Copilots (GitHub Copilot, Cursor, etc.):**
Code-level assistants bolted onto existing IDE workflows. They help humans execute faster. We restructure the loop so AI executes and humans steer.

**vs. Agent frameworks (LangChain, CrewAI, etc.):**
Infrastructure for developers building AI apps. We're building the end-user application — the cockpit — not the plumbing.

**vs. Claude Code / Codex CLI:**
Operate at the code plane. We operate at the decision and convergence plane — a higher knowledge level.

---

## Key Thesis Summary

1. LLMs are a new stochastic OS
2. Frontier lab handles AI intelligence — we make it work in knowledge economy, sustainably
3. The native application layer for this OS hasn't been built
4. We're building it: a knowledge OS with living, evolving workflows
5. This changes not just productivity but how organizations are structured
6. Start with dev teams, expand to all knowledge work, become the platform
