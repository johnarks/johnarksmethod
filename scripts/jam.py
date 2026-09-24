#!/usr/bin/env python3
"""
jam.py — the JohnArks Method enforcer.

A claim is not done because an agent said so. It is done when:
  1. the checkpoint's verify command exits 0,
  2. every applicable gate is recorded passed/skipped in STATE.json,
  3. a real git commit exists containing the work.

Commands:
  init            scaffold .jam/ (STATE.json, PRODUCT.md, RESUME.md, DECISIONS.md)
  check           validate everything; exit 0 = clean, 1 = findings (listed)
  resume          print the recovery brief for a fresh agent, then run check
  verify <cp-id>  run the checkpoint's verify command, report PASS/FAIL
  gates           exit 1 if the current checkpoint has any open gate

Stdlib only. No network. Exit codes are the contract.
"""

import json
import os
import subprocess
import sys

METHOD = "johnarksmethod"
METHOD_VERSION = "1.0"

VALID_STATUS = {"planned", "in_progress", "done"}
VALID_GATES = {"pending", "passed", "skipped", "failed"}
GATE_NAMES = ("behavior", "ui", "adversarial", "human", "audit")
VALID_PHASES = {"discovery", "planning", "execution", "complete"}


def project_root():
    """Walk up from cwd to find .jam/, else use cwd."""
    d = os.path.abspath(os.getcwd())
    while True:
        if os.path.isdir(os.path.join(d, ".jam")):
            return d
        parent = os.path.dirname(d)
        if parent == d:
            return os.getcwd()
        d = parent


def jam_dir(root):
    return os.path.join(root, ".jam")


def run(cmd, cwd):
    return subprocess.run(
        cmd, cwd=cwd, shell=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
    )


def git_ok(root, rev):
    """True if rev names a real commit in this repo."""
    if not os.path.isdir(os.path.join(root, ".git")):
        return None  # no git repo: unknown, not false
    r = run("git cat-file -e " + rev + "^{commit}", root)
    return r.returncode == 0


def load_state(root):
    path = os.path.join(jam_dir(root), "STATE.json")
    try:
        with open(path) as f:
            return json.load(f), None
    except FileNotFoundError:
        return None, "missing .jam/STATE.json (run: python3 .jam/bin/jam.py init)"
    except json.JSONDecodeError as e:
        return None, "STATE.json does not parse: %s" % e


def check_state(root):
    findings = []
    state, err = load_state(root)
    if err:
        return [err]
    for key in ("method", "project", "phase", "current_checkpoint", "checkpoints"):
        if key not in state:
            findings.append("STATE.json missing required key: %s" % key)
    if state.get("method") != METHOD:
        findings.append("STATE.json method is %r, expected %r"
                        % (state.get("method"), METHOD))
    if state.get("phase") not in VALID_PHASES:
        findings.append("unknown phase: %r" % state.get("phase"))
    cps = state.get("checkpoints", {})
    if not isinstance(cps, dict):
        findings.append("checkpoints is not an object")
        return findings
    cur = state.get("current_checkpoint")
    if cur and cur not in cps:
        findings.append("current_checkpoint %r not in checkpoints" % cur)
    for cp_id, cp in cps.items():
        status = cp.get("status")
        if status not in VALID_STATUS:
            findings.append("%s: bad status %r" % (cp_id, status))
            continue
        gates = cp.get("gates", {})
        for g in GATE_NAMES:
            if gates.get(g) not in VALID_GATES:
                findings.append("%s: gate %r has bad value %r"
                                % (cp_id, g, gates.get(g)))
        if status == "done":
            bad = [g for g in GATE_NAMES
                   if gates.get(g) not in ("passed", "skipped")]
            if bad:
                findings.append("%s: marked done but gates not passed: %s"
                                % (cp_id, ", ".join(bad)))
            if gates.get("ui") == "skipped" and not cp.get("ui_skipped_reason"):
                findings.append("%s: ui gate skipped without a recorded reason"
                                % cp_id)
            commit = cp.get("evidence_commit")
            if not commit:
                findings.append("%s: done but no evidence_commit recorded"
                                % cp_id)
            else:
                ok = git_ok(root, commit)
                if ok is False:
                    findings.append(
                        "%s: evidence_commit %s is not a real commit"
                        % (cp_id, commit[:12]))
                elif ok is None:
                    findings.append(
                        "%s: cannot verify evidence_commit — not a git repo"
                        % cp_id)
            if not cp.get("verify"):
                findings.append("%s: done but no verify command recorded"
                                % cp_id)
    if state.get("phase") == "execution" and not state.get("product_accepted"):
        findings.append("phase is execution but product_accepted is not true")
    # Freshness: RESUME.md must name the current checkpoint.
    resume_path = os.path.join(jam_dir(root), "RESUME.md")
    if not os.path.isfile(resume_path):
        findings.append("missing .jam/RESUME.md")
    elif cur:
        with open(resume_path) as f:
            if cur not in f.read():
                findings.append(
                    "RESUME.md does not mention current checkpoint %r — stale"
                    % cur)
    for name in ("PRODUCT.md", "DECISIONS.md"):
        if not os.path.isfile(os.path.join(jam_dir(root), name)):
            findings.append("missing .jam/%s" % name)
    return findings


def cmd_init(root):
    jd = jam_dir(root)
    os.makedirs(os.path.join(jd, "evidence"), exist_ok=True)
    tpl = os.path.join(root, ".jam", "templates")
    # Templates ship inside the repo; fall back to embedded minimal ones.
    def put(name, content):
        path = os.path.join(jd, name)
        if not os.path.exists(path):
            with open(path, "w") as f:
                f.write(content)
            print("created .jam/%s" % name)
        else:
            print("exists  .jam/%s" % name)

    put("STATE.json", json.dumps({
        "method": METHOD,
        "method_version": METHOD_VERSION,
        "project": os.path.basename(root),
        "phase": "discovery",
        "product_accepted": False,
        "current_checkpoint": None,
        "checkpoints": {},
    }, indent=2) + "\n")
    put("PRODUCT.md", "# Product intent\n\n"
        "_Draft during discovery. The human confirms a summary of this file\n"
        "before phase leaves discovery. Requirements use FR-### ids; every\n"
        "checkpoint traces to at least one._\n\n"
        "## Vision\n\n## Goals\n\n## Non-goals\n\n## Users\n\n"
        "## Requirements\n\n- FR-001: _..._\n\n## Constraints\n\n"
        "## Success criteria\n\n## Open questions\n")
    put("RESUME.md", "# Resume brief\n\n"
        "_Kept current at every checkpoint completion. A fresh agent reads\n"
        "this file first, then runs `python3 .jam/bin/jam.py resume`._\n\n"
        "## What this project is\n\n## Where we are\n\n"
        "## Next step\n\n## Blocked on\n\n## Key decisions (pointers)\n")
    put("DECISIONS.md", "# Decision log\n\n"
        "_One entry per decision: what, why, alternatives rejected,\n"
        "checkpoint. Missing fields invalidate state._\n")
    print("init done.")


def cmd_check(root):
    findings = check_state(root)
    if findings:
        print("JAM CHECK: %d finding(s)" % len(findings))
        for f in findings:
            print("  - " + f)
        return 1
    print("JAM CHECK: clean")
    return 0


def cmd_resume(root):
    state, err = load_state(root)
    print("=== JAM resume brief ===")
    if err:
        print("state: " + err)
        return 1
    print("project : %s" % state.get("project"))
    print("phase   : %s (product_accepted=%s)"
          % (state.get("phase"), state.get("product_accepted")))
    cps = state.get("checkpoints", {})
    done = [c for c, v in cps.items() if v.get("status") == "done"]
    prog = [c for c, v in cps.items() if v.get("status") == "in_progress"]
    print("done    : %s" % (", ".join(sorted(done)) or "none"))
    print("in-prog : %s" % (", ".join(sorted(prog)) or "none"))
    cur = state.get("current_checkpoint")
    if cur and cur in cps:
        gates = cps[cur].get("gates", {})
        open_g = [g for g in GATE_NAMES if gates.get(g) == "pending"]
        print("current : %s — %s" % (cur, cps[cur].get("title", "")))
        print("open    : %s" % (", ".join(open_g) or "none — advance"))
    print("next    : continue the build loop at the current checkpoint; "
          "do not start new work until open gates pass.")
    print("======================")
    return cmd_check(root)


def cmd_verify(root, cp_id):
    state, err = load_state(root)
    if err:
        print(err)
        return 1
    cp = state.get("checkpoints", {}).get(cp_id)
    if not cp:
        print("unknown checkpoint: %s" % cp_id)
        return 1
    cmd = cp.get("verify")
    if not cmd:
        print("%s has no verify command recorded" % cp_id)
        return 1
    print("running verify for %s: %s" % (cp_id, cmd))
    r = run(cmd, root)
    out = r.stdout.strip().splitlines()
    tail = "\n".join(out[-25:])
    if tail:
        print("--- output (tail) ---")
        print(tail)
    if r.returncode == 0:
        print("VERIFY PASS: %s" % cp_id)
        return 0
    print("VERIFY FAIL: %s (exit %d)" % (cp_id, r.returncode))
    return 1


def cmd_gates(root):
    """Exit 1 if the current checkpoint has any open (pending/failed) gate."""
    state, err = load_state(root)
    if err:
        print(err)
        return 1
    cur = state.get("current_checkpoint")
    cps = state.get("checkpoints", {})
    if not cur or cur not in cps:
        print("no current checkpoint — nothing to enforce")
        return 0
    cp = cps[cur]
    if cp.get("status") == "done":
        print("current checkpoint %s is done — gates closed" % cur)
        return 0
    gates = cp.get("gates", {})
    open_g = [g for g in GATE_NAMES if gates.get(g) in ("pending", "failed")]
    if not open_g:
        print("current checkpoint %s: all gates closed" % cur)
        return 0
    print("current checkpoint %s has open gates: %s"
          % (cur, ", ".join(open_g)))
    return 1


def main(argv):
    root = project_root()
    if len(argv) < 2:
        print(__doc__.strip().splitlines()[0])
        print("usage: jam.py {init|check|resume|verify <cp-id>}")
        return 2
    cmd = argv[1]
    if cmd == "init":
        cmd_init(root)
        return 0
    if cmd == "check":
        return cmd_check(root)
    if cmd == "resume":
        return cmd_resume(root)
    if cmd == "verify":
        if len(argv) < 3:
            print("usage: jam.py verify <cp-id>")
            return 2
        return cmd_verify(root, argv[2])
    if cmd == "gates":
        return cmd_gates(root)
    print("unknown command: %s" % cmd)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
