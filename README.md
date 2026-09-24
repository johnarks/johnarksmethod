# JohnArks Method

**A build method for people who don't write code — and can't review the code an AI wrote for them.**

You describe what you want. An AI agent asks focused questions, then builds it in small checkpoints. Every checkpoint passes five enforced gates — behavior tests, visual review, two independent adversarial code reviews, your approval, and an independent audit. Every "done" is proven by a real git commit plus a passing verification command. Never by the agent's word.

If the session dies, you switch from Claude Code to Codex, or a new model comes out next year: one resume command picks up exactly where you left off, with all context intact.

## Why this exists

AI coding agents are powerful and unreliable in the same breath. They hallucinate — confidently describing work they never did. They lose context — a fresh session starts from zero. They can't be supervised by someone who doesn't program, because "does this look right?" is not a question a non-developer can answer about code.

The JohnArks Method is built on a single insight: **don't trust the agent — verify the work.** It wraps the agent in machinery that makes good work provable and bad work impossible to hide:

- **Small checkpoints, ordered by complexity.** You review a *sequence* of small steps, not a mountain of code.
- **Five gates per checkpoint.** Tests that fail before the feature exists. A visual reviewer that compares screenshots against the design. Two adversarial reviewers, isolated from each other, that must *both* approve the code. Your approval. Then an independent auditor that re-derives what happened from the repo alone and rejects the record if it doesn't match.
- **Git as ground truth.** Every finished checkpoint ends in a commit. The enforcer script verifies each "done" names a real commit containing the real files. An agent cannot claim work happened without pointing at the commit — a fabricated claim fails the check mechanically.
- **Executable evidence, not prose.** Each checkpoint declares a verify command. Done means the command exited 0, with its output archived. Not "the agent said it's fine."
- **Resume anywhere.** Product intent, plan, checkpoint state, decision history, and a fresh resume brief live in the project's `.jam/` directory and in git. A new agent on a new platform runs one command and continues — no re-asking, no re-doing.

## What it is, concretely

Seven agent skills plus a small Python enforcer (`scripts/jam.py`, stdlib only):

| Skill | Role |
|---|---|
| `orchestrator` | Runs everything. The only skill you ever invoke. Discovery → plan → gated build loop → final review. |
| `checkpoint-planner` | Splits work into small ordered checkpoints, each tracing to product requirements and declaring its verify command. |
| `test-planner` | Defines "proven": behavior test cases from the user's perspective, edges included, failing first. |
| `prototype-builder` | Clickable HTML prototype as the visual reference when no design exists yet. |
| `ui-reviewer` | Vision-based comparison of implementation vs. reference in matching states. Zero blockers to pass. |
| `adversarial-review` | Two isolated reviewers vs. the architecture doc. Both must approve. |
| `design-planner` | Writes the opinionated architecture/design doc the reviewers enforce. |

The **trust chain**: worker → dual reviewers → you → scribe → independent auditor → enforcer script → git. Any single liar is caught by the next layer, and you never have to inspect any of it.

## Who it's for

- **Non-developers directing AI-built software** — founders, operators, anyone with an idea and no interest in reading code. The method is your stand-in reviewer.
- **Long-lived projects** — apps built over weeks and months, where sessions die, tokens run out, and context must survive.
- **Platform switchers** — start on Claude Code, continue on Codex, move to whatever comes next. The project state is plain files in git, not locked in one harness.
- **The skeptical** — if you've been burned by an agent that said "done" and wasn't, this is the machinery that makes "done" mean something.

## Who it's not for

- Trivial edits and one-off questions (the routing block says so explicitly — judgment applies).
- Teams that already run rigorous human code review on every change; the gates would be redundant.
- Anyone who wants the agent to "just do it" with no checkpoints — the method will fight you, by design.

## Setup — one prompt

Open your project folder with your AI agent and paste:

```text
Set up the JohnArks Method in this project using
https://github.com/johnarks/johnarksmethod. Install all skills and
supporting files, wire up the quality gates, and confirm everything is
working — if anything is already installed, confirm that instead of
reinstalling it. If this folder is not a git repository yet, stop and ask
me to create one before continuing. When setup is confirmed, ask me what
I'd like to do.
```

What happens: the agent installs everything (idempotent — already-present components are confirmed, not duplicated), ensures the folder is a git repository (it will **ask you** before creating one, and offer to set up a GitHub repo), verifies the enforcer and gates, then asks **"What would you like to do?"** Your answer starts discovery — focused questions, one at a time, then a summary you confirm before anything is planned or built.

Full agent runbook: [`INSTALL.md`](INSTALL.md). Copy-paste prompts for setup, resume, and upgrades: [`START-HERE.md`](START-HERE.md).

## The loop, in brief

1. **Discovery.** "What would you like to do?" → questions → product intent (`PRODUCT.md`) with requirement IDs → you confirm the summary.
2. **Planning.** App-state check, checkpoint plan (you approve the sequence), test plan.
3. **Build loop.** For each checkpoint: tests first (must fail) → implement → tests green → Gate 1 behavior → Gate 2 UI review → Gate 3 dual adversarial review → Gate 4 your approval → Gate 5 independent audit → commit with evidence.
4. **Final review.** Drift check (built vs. intended), you test as a user, feedback becomes new checkpoints.

The stop hook (Claude Code) or the enforcer-before-every-turn rule (Codex) guarantees the session cannot end with open gates or an unverified record.

## Switching sessions or platforms

```text
Resume the JohnArks Method in this project. Run
python3 .jam/bin/jam.py resume, fix any findings it reports, then continue
the build loop from the current checkpoint. Do not re-run discovery or
re-ask settled questions.
```

## Lineage

The JohnArks Method combines two ideas:

- **Helix loop** (Shopify's engineering workflow, reconstructed from their [helix writeup](https://shopify.engineering/helix)): checkpoints with behavior tests, visual review, and dual independent adversarial reviewers, enforced by a stop hook. The per-checkpoint quality engine.
- **Arks Method** (multi-agent coordination): product intent as durable first-class state, repository-over-chat recovery, executable verification, and the principle that workers are disposable. The memory and continuity engine.

What's deliberately left out: the heavy multi-agent coordination machinery (task branches, leases, heartbeats). This method is strict where it matters — verification and evidence — and light everywhere else.

## License

MIT.
