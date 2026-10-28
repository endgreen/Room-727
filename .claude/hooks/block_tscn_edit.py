#!/usr/bin/env python3
"""PreToolUse hook — block direct .tscn file edits.

Prevents Edit/Write on .tscn files. Scene modifications must go through
MCP tools (godot_add_node, godot_update_property, godot_save_scene).
"""

import json
import sys


def main():
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, EOFError):
        sys.exit(0)

    tool_name = data.get("tool_name", "")
    tool_input = data.get("tool_input", {})

    if tool_name not in ("Edit", "Write"):
        sys.exit(0)

    file_path = tool_input.get("file_path", "")

    if not file_path.endswith(".tscn"):
        sys.exit(0)

    # Block .tscn edits
    msg = (
        "BLOQUE : Ne pas editer les fichiers .tscn directement. "
        "Utiliser godot_add_node / godot_update_property + godot_save_scene a la place. "
        "Voir CLAUDE.md 'Regle fondamentale : fichiers vs API Godot'."
    )
    output = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "additionalContext": msg,
        }
    }
    json.dump(output, sys.stdout)
    sys.exit(2)


if __name__ == "__main__":
    main()
