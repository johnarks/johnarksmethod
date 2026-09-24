#!/usr/bin/env bash
#
# johnarksmethod stop hook — "a claim is not done because you said so"
#
# Claude Code runs this on the Stop event. It runs the JAM enforcer
# (scripts/jam.py check). If the enforcer reports findings — open gates,
# stale resume brief, unverifiable evidence commits, malformed state —
# the hook exits 2, which tells Claude Code to block the stop and feed
# the message back to the agent so it keeps working.
#
# State dir: .jam/ (project root). Enforcer: .jam/bin/jam.py.
# The hook receives the project dir via CLAUDE_PROJECT_DIR; falls back to PWD.

set -u

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
JAM_DIR="$PROJECT_DIR/.jam"
ENFORCER="$JAM_DIR/bin/jam.py"

# No method state yet (setup ran but no work started, or loop finished and
# the project was archived): nothing to enforce, allow the stop.
if [ ! -f "$JAM_DIR/STATE.json" ]; then
  exit 0
fi

if [ ! -f "$ENFORCER" ]; then
  echo "jam stop hook: enforcer not found at $ENFORCER; allowing stop (state cannot be verified)." >&2
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "jam stop hook: python3 not found; cannot verify state. Allowing stop." >&2
  exit 0
fi

cd "$PROJECT_DIR" || exit 0

# 1. Record integrity: malformed state, unverifiable evidence, stale resume.
OUTPUT="$(python3 "$ENFORCER" check 2>&1)"
if [ "$?" -ne 0 ]; then
  echo "JAM STOP HOOK: cannot stop — the enforcer reports problems:"
  echo "$OUTPUT"
  echo "Fix the findings above, then stop again."
  exit 2
fi

# 2. Open gates on the current checkpoint.
GATE_OUTPUT="$(python3 "$ENFORCER" gates 2>&1)"
if [ "$?" -ne 0 ]; then
  # Exit 2 = block the stop. The output tells the agent what to fix.
  echo "JAM STOP HOOK: cannot stop — open gates:"
  echo "$GATE_OUTPUT"
  echo "Finish the open gates, then stop again."
  exit 2
fi

exit 0
