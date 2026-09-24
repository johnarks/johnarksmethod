#!/usr/bin/env bash
#
# install.sh — install the JohnArks Method skill pack for Claude Code and/or Codex.
#
# Idempotent: already-installed components are detected and skipped.
#
# Usage:
#   ./install.sh [--project DIR] [--agent claude|codex|both|auto] [--scope project|user]
#
#   --project DIR   Target project directory (default: current directory).
#   --agent         Which agent to set up (default: auto-detect).
#   --scope         "project" installs into the target project (default);
#                   "user" installs Claude Code skills to ~/.claude/skills.
#
# The method requires the project to be a git repository: evidence commits are
# the ground truth the enforcer verifies. If the target is not a git repo, the
# script asks to create one (interactive) or tells the agent to ask the user.
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(pwd)"
AGENT="auto"
SCOPE="project"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT_DIR="$(cd "$2" && pwd)"; shift 2 ;;
    --agent)   AGENT="$2"; shift 2 ;;
    --scope)   SCOPE="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,/^#$/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "Unknown option: $1 (try --help)" >&2; exit 1 ;;
  esac
done

have_claude=false
have_codex=false
case "$AGENT" in
  claude) have_claude=true ;;
  codex)  have_codex=true ;;
  both)   have_claude=true; have_codex=true ;;
  auto)
    if [[ -d "$HOME/.claude" ]] || command -v claude >/dev/null 2>&1; then have_claude=true; fi
    if [[ -d "$HOME/.codex"  ]] || command -v codex  >/dev/null 2>&1; then have_codex=true;  fi
    if ! $have_claude && ! $have_codex; then
      echo "No Claude Code or Codex detected; defaulting to Claude Code layout." >&2
      have_claude=true
    fi
    ;;
  *) echo "Unknown --agent: $AGENT (claude|codex|both|auto)" >&2; exit 1 ;;
esac

INSTALLED=0
SKIPPED=0

# ---------------- git repository gate ----------------
# The method's trust chain bottoms out at git: every "done" must name a real
# commit. Without a repo, evidence cannot be verified.
if ! git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "== git repository =="
  echo "  This folder is not a git repository."
  echo "  The JohnArks Method requires git — evidence commits are the ground"
  echo "  truth the enforcer verifies, and resume-across-sessions needs history."
  if [[ -t 0 ]]; then
    read -r -p "  Create one now with 'git init'? [Y/n] " answer
    case "${answer:-Y}" in
      [Yy]*|"")
        git -C "$PROJECT_DIR" init -q
        echo "  [ok]   git repository created in $PROJECT_DIR"
        INSTALLED=$((INSTALLED+1))
        ;;
      *)
        echo "  [warn] continuing without git — evidence verification and"
        echo "         resume will be degraded. Ask the user to reconsider."
        ;;
    esac
  else
    echo "  [warn] non-interactive shell: could not ask."
    echo "  AGENT: stop and ask the user in chat — 'This folder is not a git"
    echo "  repository. The method needs one to verify work. Create it now?"
    echo "  (Offer to also create a GitHub repo and push.)' Do not proceed"
    echo "  with the build loop until the user decides."
  fi
else
  echo "== git repository =="
  echo "  [skip] $PROJECT_DIR is already a git repository"
  SKIPPED=$((SKIPPED+1))
fi

install_skill_dir() {
  local src="$1" dest_parent="$2"
  local name; name="$(basename "$src")"
  local dest="$dest_parent/$name"
  if [[ -f "$dest/SKILL.md" ]] && cmp -s "$src/SKILL.md" "$dest/SKILL.md"; then
    echo "  [skip] $name — already installed"
    SKIPPED=$((SKIPPED+1))
  else
    mkdir -p "$dest"
    cp -r "$src"/. "$dest"/
    echo "  [ok]   $name"
    INSTALLED=$((INSTALLED+1))
  fi
}

install_skills_to() {
  local dest_parent="$1"
  mkdir -p "$dest_parent"
  for skill in "$REPO_DIR"/skills/*/; do
    [[ -d "$skill" ]] || continue
    install_skill_dir "$skill" "$dest_parent"
  done
}

install_file() {
  # install_file <src> <dest> — idempotent single-file copy
  local src="$1" dest="$2" label="$3"
  mkdir -p "$(dirname "$dest")"
  if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
    echo "  [skip] $label — already installed"
    SKIPPED=$((SKIPPED+1))
  else
    cp "$src" "$dest"
    echo "  [ok]   $label"
    INSTALLED=$((INSTALLED+1))
  fi
}

ROUTING_START="JOHNARKSMETHOD:ROUTING:START"

ensure_routing() {
  local file="$1"
  if [[ -f "$file" ]] && grep -q "$ROUTING_START" "$file"; then
    echo "  [skip] routing block already present in $file"
    SKIPPED=$((SKIPPED+1))
    return
  fi
  {
    echo ""
    cat "$REPO_DIR/templates/agent-routing.md"
  } >> "$file"
  echo "  [ok]   routing block appended to $file"
  INSTALLED=$((INSTALLED+1))
}

# ---------------- method core (always project-level) ----------------
echo "== JohnArks Method core =="
install_file "$REPO_DIR/scripts/jam.py" "$PROJECT_DIR/.jam/bin/jam.py" "enforcer (scripts/jam.py)"
chmod +x "$PROJECT_DIR/.jam/bin/jam.py"
for tpl in "$REPO_DIR"/templates/*.md; do
  [[ -f "$tpl" ]] || continue
  install_file "$tpl" "$PROJECT_DIR/.jam/templates/$(basename "$tpl")" "template $(basename "$tpl")"
done
if [[ ! -f "$PROJECT_DIR/.jam/STATE.json" ]] && command -v python3 >/dev/null 2>&1; then
  ( cd "$PROJECT_DIR" && python3 .jam/bin/jam.py init >/dev/null )
  echo "  [ok]   .jam/ workspace initialized (STATE.json, PRODUCT.md, RESUME.md, DECISIONS.md)"
  INSTALLED=$((INSTALLED+1))
elif [[ -f "$PROJECT_DIR/.jam/STATE.json" ]]; then
  echo "  [skip] .jam/ workspace already initialized"
  SKIPPED=$((SKIPPED+1))
fi

# ---------------- Claude Code ----------------
if $have_claude; then
  echo "== Claude Code =="
  if [[ "$SCOPE" == "user" ]]; then
    DEST="$HOME/.claude/skills"
    echo "-- user-level skills: $DEST"
    install_skills_to "$DEST"
  else
    DEST="$PROJECT_DIR/.claude/skills"
    echo "-- project skills: $DEST"
    install_skills_to "$DEST"

    HOOK_DEST_DIR="$PROJECT_DIR/.claude/hooks"
    install_file "$REPO_DIR/hooks/stop-gate-check.sh" "$HOOK_DEST_DIR/stop-gate-check.sh" "stop hook"
    chmod +x "$HOOK_DEST_DIR/stop-gate-check.sh"
    SETTINGS="$PROJECT_DIR/.claude/settings.json"
    mkdir -p "$(dirname "$SETTINGS")"
    if [[ ! -f "$SETTINGS" ]]; then echo '{}' > "$SETTINGS"; fi
    HOOK_CMD="$HOOK_DEST_DIR/stop-gate-check.sh"
    if grep -q "stop-gate-check.sh" "$SETTINGS"; then
      echo "  [skip] stop hook already wired in $SETTINGS"
      SKIPPED=$((SKIPPED+1))
    elif command -v python3 >/dev/null 2>&1; then
      python3 - "$SETTINGS" "$HOOK_CMD" <<'PYEOF'
import json, sys
path, cmd = sys.argv[1], sys.argv[2]
try:
    with open(path) as f:
        data = json.load(f)
except Exception:
    data = {}
if not isinstance(data, dict):
    data = {}
hooks = data.setdefault("hooks", {})
stop = hooks.setdefault("Stop", [])
entry = {"hooks": [{"command": cmd, "type": "command"}]}
if not any(e.get("hooks", [{}])[0].get("command") == cmd for e in stop):
    stop.append(entry)
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF
      echo "  [ok]   stop hook wired in $SETTINGS"
      INSTALLED=$((INSTALLED+1))
    else
      echo "  [warn] python3 not found — wire the hook manually:"
      echo "         see $REPO_DIR/INSTALL.md"
    fi

    echo "-- project routing: $PROJECT_DIR/CLAUDE.md"
    ensure_routing "$PROJECT_DIR/CLAUDE.md"
  fi
fi

# ---------------- Codex ----------------
if $have_codex; then
  echo "== Codex =="
  DEST="$HOME/.codex/skills"
  echo "-- user-level skills: $DEST"
  install_skills_to "$DEST"
  echo "   Note: Codex has no Stop-hook equivalent; gates are enforced by"
  echo "   orchestrator convention + 'jam.py check' before ending any turn."
  if [[ "$SCOPE" == "project" ]]; then
    echo "-- project routing: $PROJECT_DIR/AGENTS.md"
    ensure_routing "$PROJECT_DIR/AGENTS.md"
  fi
fi

echo ""
echo "Done: $INSTALLED installed/updated, $SKIPPED already present."
echo "Next: the agent confirms setup, then asks: \"What would you like to do?\""
