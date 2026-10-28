#!/usr/bin/env python3
"""SessionStart hook — re-inject Golem MCP context after compaction.

Checks for project indicators and outputs critical reminders so Claude
doesn't lose context during long sessions.
"""

import json
import sys
from pathlib import Path


def main():
    # Read hook input from stdin
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, EOFError):
        sys.exit(0)

    # Only trigger on compaction events
    session_type = data.get("type", "")
    if session_type != "compact":
        sys.exit(0)

    cwd = Path.cwd()

    # Detect Godot + Golem project
    has_golem = (cwd / "addons" / "golem-mcp").is_dir()
    has_godot = (cwd / "project.godot").is_file()

    if not has_godot:
        sys.exit(0)

    parts = []

    # Determine project stage from existing artifacts
    stage_indicators = {
        "GAME_PLAN.md": "planning",
        "GAME_SEQUENCE.yaml": "sequence defined",
        "deliverables": "deliverables set",
        "CHECKPOINT.md": "checkpoint exists",
    }
    stages = [
        label
        for artifact, label in stage_indicators.items()
        if (cwd / artifact).exists()
    ]

    if stages:
        parts.append(f"Project stage: {', '.join(stages)}")

    # Read checkpoint summary if available
    checkpoint = cwd / "CHECKPOINT.md"
    if checkpoint.is_file():
        try:
            text = checkpoint.read_text(encoding="utf-8")
            # Extract first 500 chars as context
            summary = text[:500].strip()
            if summary:
                parts.append(f"CHECKPOINT.md (truncated):\n{summary}")
        except Exception:
            pass

    if has_golem:
        parts.append("Golem MCP plugin detected in addons/.")

    # Read pre-compact state if saved by pre_compact.py
    pre_compact_state = cwd / ".claude" / "pre_compact_state.json"
    if pre_compact_state.is_file():
        try:
            state = json.loads(pre_compact_state.read_text(encoding="utf-8"))
            if "game_plan_header" in state:
                parts.append(f"GAME_PLAN.md header:\n{state['game_plan_header']}")
            if "recent_commits" in state:
                parts.append(f"Recent commits:\n{state['recent_commits']}")
            pre_compact_state.unlink(missing_ok=True)
        except Exception:
            pass

    # Critical reminders
    parts.append(
        "REMINDERS (post-compaction):\n"
        "- Ne pas editer les .tscn directement — utiliser les outils MCP Godot "
        "(godot_add_node / godot_update_property + godot_save_scene)\n"
        "- Consulter _golem/references/gdscript_pitfalls.md AVANT toute ecriture GDScript\n"
        "- Consulter _golem/recipes/INDEX.md AVANT d'implementer toute mecanique\n"
        "- := interdit sur sources Variant (Array, Dict, ternaire, .duplicate())\n"
        "- Root node = \".\", pas son nom. Enfants directs = \"Player\", pas \"Main/Player\"\n"
        "- Viewport origin (0,0) = coin haut-gauche. Centre = viewport_size / 2\n"
        "- Collision: layer = 'je suis', mask = 'je detecte'. Valeur = bitmask, pas numero de layer"
    )

    message = "\n\n".join(parts)

    output = {
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": message,
        }
    }
    json.dump(output, sys.stdout)
    sys.exit(0)


if __name__ == "__main__":
    main()
