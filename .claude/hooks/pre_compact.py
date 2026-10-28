#!/usr/bin/env python3
"""PreCompact hook — save project state before context compaction.

Writes a state snapshot to .claude/pre_compact_state.json.
The compact_context.py (SessionStart/compact) reads it back and injects it.
"""
import json
import subprocess
import sys
from pathlib import Path


def main():
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, EOFError):
        sys.exit(0)

    cwd = Path.cwd()
    if not (cwd / "project.godot").is_file():
        sys.exit(0)

    state = {"trigger": data.get("trigger", "unknown")}

    # Project stage
    indicators = {
        "GAME_PLAN.md": "planning",
        "GAME_SEQUENCE.yaml": "sequence defined",
        "deliverables": "deliverables set",
        "CHECKPOINT.md": "checkpoint exists",
    }
    stages = [label for artifact, label in indicators.items() if (cwd / artifact).exists()]
    if stages:
        state["stages"] = stages

    # CHECKPOINT.md summary (first 800 chars)
    checkpoint = cwd / "CHECKPOINT.md"
    if checkpoint.is_file():
        try:
            state["checkpoint_summary"] = checkpoint.read_text(encoding="utf-8")[:800].strip()
        except Exception:
            pass

    # GAME_PLAN.md header (first 3 non-empty lines)
    game_plan = cwd / "GAME_PLAN.md"
    if game_plan.is_file():
        try:
            text = game_plan.read_text(encoding="utf-8")
            lines = [line for line in text.splitlines() if line.strip()][:3]
            state["game_plan_header"] = "\n".join(lines)
        except Exception:
            pass

    # Recent git commits
    try:
        result = subprocess.run(
            ["git", "log", "--oneline", "-3"],
            capture_output=True, text=True, timeout=3, cwd=str(cwd)
        )
        if result.returncode == 0 and result.stdout.strip():
            state["recent_commits"] = result.stdout.strip()
    except Exception:
        pass

    # Save state file
    state_file = cwd / ".claude" / "pre_compact_state.json"
    try:
        state_file.parent.mkdir(parents=True, exist_ok=True)
        state_file.write_text(json.dumps(state, indent=2, ensure_ascii=False))
    except Exception:
        pass

    sys.exit(0)


if __name__ == "__main__":
    main()
