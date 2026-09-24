# Start here — the prompts to copy

## Set up the JohnArks Method in a project

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

**What happens.** The agent installs the 7 skills, the `jam.py` enforcer,
the stop hook, and the project routing block (confirming anything already
installed instead of duplicating it). If the folder isn't a git repository,
the agent **stops and asks you** before creating one, and offers to set up
a GitHub repo too. Then it verifies everything works and asks:
**"What would you like to do?"** — your answer starts discovery.

## Resume in a new session, platform, or model

Your session died, tokens ran out, or you're switching from Claude Code to
Codex (or to whatever comes next). Open the project folder and paste:

```text
Resume the JohnArks Method in this project. Run
python3 .jam/bin/jam.py resume, fix any findings it reports, then continue
the build loop from the current checkpoint. Do not re-run discovery or
re-ask settled questions.
```

## Update the method in a project that already uses it

```text
Update the JohnArks Method in this project from
https://github.com/johnarks/johnarksmethod. Re-run the installer, confirm
what changed, and run python3 .jam/bin/jam.py check to verify the project
state is still clean.
```

## What you'll be asked to do, ever

1. **Describe what you want**, in ordinary language.
2. **Confirm or correct one summary** of what will be built.
3. **Approve each checkpoint plan** and **review finished checkpoints** as a user.
4. **Do things only you can do** — sign in somewhere, approve access, or say whether something feels right.

If an agent asks you which library to use or whether to keep going, it is
not following the method. Point it at the routing block in `CLAUDE.md` /
`AGENTS.md`.
