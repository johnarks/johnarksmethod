# INSTALL.md — agent bootstrap

> **If you are an AI agent and a user gave you this repo link with
> instructions to "set up the JohnArks Method in this project," this file
> is your runbook.** Follow it top to bottom, then report back.

## What you're installing

Seven skills (`skills/*/SKILL.md`), the JAM enforcer (`scripts/jam.py`),
one stop hook (`hooks/stop-gate-check.sh`), method templates
(`templates/`), and a project routing block (`templates/agent-routing.md`).
The user only ever invokes one skill — **`orchestrator`** — which runs the
other six.

## Steps

### 1. Get the repo

```bash
git clone https://github.com/johnarks/johnarksmethod.git
cd johnarksmethod
```

If the user gave you a local path instead of the link, `cd` there.

### 2. Run the installer

From the project the user wants set up (or pass `--project`):

```bash
./install.sh --project /path/to/their/project --agent auto
```

- `--agent auto` (default) detects Claude Code and Codex. Use `--agent
  claude`, `codex`, or `both` to be explicit.
- `--scope project` (default) installs into the target project.
  `--scope user` installs Claude Code skills to `~/.claude/skills`.
- **The script is idempotent.** Re-running it detects what's already
  present and skips it — so "confirm if they've already been installed" is
  answered by the `[skip]` lines. Surface those to the user.

The script also installs the method core into the project: `.jam/bin/jam.py`
(the enforcer), `.jam/templates/`, and initializes `.jam/` (`STATE.json`,
`PRODUCT.md`, `RESUME.md`, `DECISIONS.md`) if not present.

### 3. The git repository gate (MANDATORY — do not skip)

The method's trust chain bottoms out at **git**: every "done" must name a
real commit, and the enforcer verifies those commits exist. If the project
folder is **not** a git repository:

1. **Stop and ask the user in chat** — do not silently proceed:
   > "This folder isn't a git repository yet. The JohnArks Method needs
   > one — it's how work gets verified and how a future session resumes.
   > Should I create one now?"
2. If yes: `git init`, plus an initial commit of the current files if the
   folder is non-empty.
3. Then offer: "Want me to also create a GitHub repository and push this
   up, so the project is backed up and shareable?" If yes, create it
   (public or private — ask) with `gh repo create` and push.
4. If the user declines git entirely: warn plainly that evidence
   verification and resume-across-sessions will be degraded, record their
   decision in chat, and continue — the loop still runs, but `jam.py check`
   will flag every evidence claim as unverifiable.

The installer prints this same instruction when it runs non-interactively.
**Never start the build loop on a no-git project without the user's
explicit decision.**

### 4. Verify, then confirm to the user

1. **Skills present:** 7 expected (`orchestrator`, `checkpoint-planner`,
   `test-planner`, `prototype-builder`, `ui-reviewer`,
   `adversarial-review`, `design-planner`).
2. **Enforcer works:** `cd` to the project and run
   `python3 .jam/bin/jam.py check` — expect `JAM CHECK: clean` on a fresh
   install. Also confirm `python3 .jam/bin/jam.py resume` prints a brief.
3. **Hook (Claude Code):** the hook is copied and wired in
   `.claude/settings.json`. Its two checks: `jam.py check` must be clean
   and `jam.py gates` must show no open gates, or stopping is blocked.
4. **Routing:** the `JOHNARKSMETHOD:ROUTING:START` marker exists in the
   project's `CLAUDE.md` and/or `AGENTS.md`.
5. **Git:** the project is a git repo, or the user explicitly declined one
   (say which).

### 5. Ask the entry question

Report what's installed, what was already there (quote the `[skip]`
lines), which agent(s) were set up, and the git situation. Then ask the
user, exactly:

> **What would you like to do?**

Do not start building anything until they answer. Their answer begins
**discovery** (orchestrator skill, section 1): one question at a time,
then a product-intent summary they confirm before any planning.

## Codex caveat

Codex has no Stop-hook equivalent. Gates are enforced by orchestrator
convention plus a hard rule: run `python3 .jam/bin/jam.py check` before
ending **any** turn, and keep working while it reports findings. The
enforcer is the backstop the hook would have been.

## Resume (switching sessions, platforms, or models)

Paste into the new session with the project folder open:

```text
Resume the JohnArks Method in this project. Run
python3 .jam/bin/jam.py resume, fix any findings it reports, then continue
the build loop from the current checkpoint. Do not re-run discovery or
re-ask settled questions.
```

## Manual install (no script)

```bash
# Method core
mkdir -p <project>/.jam/bin <project>/.jam/templates
cp scripts/jam.py <project>/.jam/bin/ && chmod +x <project>/.jam/bin/jam.py
cp templates/*.md <project>/.jam/templates/
cd <project> && python3 .jam/bin/jam.py init

# Claude Code, project-level
mkdir -p <project>/.claude/skills <project>/.claude/hooks
cp -r skills/* <project>/.claude/skills/
cp hooks/stop-gate-check.sh <project>/.claude/hooks/ && chmod +x <project>/.claude/hooks/stop-gate-check.sh
# merge hook into <project>/.claude/settings.json (see repo hooks/stop-gate-check.sh header)
cat templates/agent-routing.md >> <project>/CLAUDE.md

# Codex (user-level skills + project routing)
mkdir -p ~/.codex/skills
cp -r skills/* ~/.codex/skills/
cat templates/agent-routing.md >> <project>/AGENTS.md
```

## For agents with no skills system at all

The skills are plain Markdown. Read `skills/orchestrator/SKILL.md` and
follow it directly — it references the other six by role, and
`scripts/jam.py` is plain Python with no dependencies.
