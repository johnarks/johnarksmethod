<!-- JOHNARKSMETHOD:ROUTING:START -->
## JohnArks Method — default build workflow for this project

This project uses the **JohnArks Method** skill pack: discovery first, then
small checkpoints with five enforced gates per checkpoint (behavior tests →
UI review → adversarial code review → human approval → independent audit).
Every "done" is proven by a git commit plus a passing verify command — never
by an agent's word.

**Routing rule:** when the user asks for feature work — a new feature, a
migration, or a substantial refactor — handle it with the **`orchestrator`**
skill. Do not build it as a single unreviewed pass.

**Starting / resuming:**
- If `.jam/STATE.json` exists, run `python3 .jam/bin/jam.py resume` first
  and fix any findings before new work. Never build on a broken record.
- If it doesn't exist, run `python3 .jam/bin/jam.py init`, then discovery:
  ask "What would you like to do?", one question at a time, confirm the
  product-intent summary with the human before planning.

**Non-negotiables while the loop runs:**
- A checkpoint is done only when every gate that applies to it passes.
  A failed gate blocks: fix and re-run, never skip.
- Each checkpoint traces to product requirement IDs (`FR-###`) and declares
  a `verify` command. Gate 1 runs it; exit 0 is the pass criterion.
- Keep working state in the project's `.jam/` directory (`STATE.json`,
  `PRODUCT.md`, `RESUME.md`, `DECISIONS.md`, `checkpoints.json`,
  `evidence/`). Update it at every gate transition.
- Gate 5 (audit): a scribe writes the record; a fresh auditor with no
  access to the scribe's notes re-derives the outcome from git + files +
  test output. Mismatch blocks.
- Read `.jam/learnings.md` before starting any checkpoint; append new
  human feedback to it after every human review.
- Commit every finished checkpoint: `jam(cp-<id>): <short title>`,
  including `.jam/` state and `.jam/evidence/<id>/`.
- This project must be a git repository. If it isn't, stop and ask the
  human to create one before continuing — evidence commits are the
  ground truth the enforcer verifies.
- Small, one-off questions and trivial edits do not need the loop —
  use judgment.
<!-- JOHNARKSMETHOD:ROUTING:END -->
