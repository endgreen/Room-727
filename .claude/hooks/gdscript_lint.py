#!/usr/bin/env python3
"""Hook: PostToolUse (mcp__godot__godot_write_script)
Basic GDScript lint after writing a script via MCP.
Checks for common mistakes that Godot would silently swallow.
"""

import json
import re
import sys


def lint_gdscript(content: str, path: str) -> list[str]:
    """Return a list of warnings for the given GDScript content."""
    warnings = []
    lines = content.split("\n")

    # 1. Missing extends
    has_extends = any(line.strip().startswith("extends") for line in lines)
    if not has_extends and len(lines) > 3:
        warnings.append(f"[{path}] Missing 'extends' declaration")

    # 2. await in _process or _physics_process (forbidden in @tool)
    in_process = False
    for i, line in enumerate(lines, 1):
        stripped = line.strip()
        if re.match(r"^func\s+_(process|physics_process)", stripped):
            in_process = True
        elif re.match(r"^func\s+", stripped):
            in_process = False
        elif in_process and "await" in stripped:
            warnings.append(
                f"[{path}:{i}] 'await' inside _process/_physics_process — "
                "will crash in @tool scripts"
            )

    # 3. print() instead of GolemCapture.game_log()
    print_count = sum(
        1
        for line in lines
        if re.search(r"\bprint\s*\(", line.strip())
        and not line.strip().startswith("#")
    )
    if print_count > 0:
        warnings.append(
            f"[{path}] {print_count} print() call(s) found — "
            "consider GolemCapture.game_log() for MCP-visible output"
        )

    # 4. Duplicate signal declarations
    signals = []
    for i, line in enumerate(lines, 1):
        match = re.match(r"^signal\s+(\w+)", line.strip())
        if match:
            sig_name = match.group(1)
            if sig_name in signals:
                warnings.append(
                    f"[{path}:{i}] Duplicate signal declaration: '{sig_name}'"
                )
            signals.append(sig_name)

    # 5. connect() in _process (should be in _ready)
    in_process = False
    for i, line in enumerate(lines, 1):
        stripped = line.strip()
        if re.match(r"^func\s+_(process|physics_process)", stripped):
            in_process = True
        elif re.match(r"^func\s+", stripped):
            in_process = False
        elif in_process and ".connect(" in stripped:
            warnings.append(
                f"[{path}:{i}] .connect() inside _process — "
                "will create duplicate connections every frame. Move to _ready()"
            )

    # 6. Unreachable code after return
    for i, line in enumerate(lines, 1):
        if line.strip() == "return" or re.match(r"^\s+return\b", line):
            # Check next non-empty line at same or deeper indent
            indent = len(line) - len(line.lstrip())
            for j in range(i, min(i + 3, len(lines))):
                next_line = lines[j]
                if next_line.strip() and not next_line.strip().startswith("#"):
                    next_indent = len(next_line) - len(next_line.lstrip())
                    if next_indent > indent:
                        warnings.append(
                            f"[{path}:{j + 1}] Possible unreachable code after return"
                        )
                    break

    # 7. Camera2D position modification (should use offset for shake)
    is_camera_script = "extends Camera2D" in content or "Camera2D" in path.lower()
    if is_camera_script:
        for i, line in enumerate(lines, 1):
            stripped = line.strip()
            # Detect direct position assignment (not offset)
            if re.search(r"\bposition\s*=", stripped) and "offset" not in stripped:
                # Ignore initial position setup in _ready
                if "_ready" not in "\n".join(lines[max(0, i - 10) : i]):
                    warnings.append(
                        f"[{path}:{i}] Camera2D position modified directly — "
                        "use 'offset' for screenshake to preserve camera framing"
                    )

    # 8. Dangerous := with Variant sources
    for i, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.startswith("#"):
            continue
        if ":=" not in stripped:
            continue
        # Get the right-hand side after :=
        rhs_match = re.search(r":=\s*(.+)", stripped)
        if not rhs_match:
            continue
        rhs = rhs_match.group(1)
        if (
            ".duplicate(" in rhs
            or ".get(" in rhs
            or (" if " in rhs and " else " in rhs)
            or re.match(r"^\s*[\[\{]", rhs)
            or re.search(r"[=!<>]=", rhs)
            or re.match(r"^\s*\w+\s*[<>]\s*\w+", rhs)
        ):
            warnings.append(
                f"[{path}:{i}] ':=' avec source Variant détecté. "
                "Utiliser ': Type =' à la place pour éviter un crash parser."
            )

    # 9. Camera2D without anchor_mode consideration
    if is_camera_script:
        has_anchor_mode = any("anchor_mode" in line for line in lines)
        has_position_center = any(
            re.search(r"position\s*=.*\d+.*\d+", line) for line in lines
        )
        if not has_anchor_mode and not has_position_center:
            warnings.append(
                f"[{path}] Camera2D script without anchor_mode or position setup — "
                "consider ANCHOR_MODE_FIXED_TOP_LEFT for fixed 2D games, "
                "or position at viewport center for DRAG_CENTER mode"
            )

    return warnings


def main():
    data = json.load(sys.stdin)
    tool_input = data.get("tool_input", {})

    # Extract script path and content from tool input
    path = tool_input.get("path", "unknown.gd")
    content = tool_input.get("content", "")

    if not content:
        sys.exit(0)

    # Skip non-GDScript files (e.g. .gdshader triggers false positives)
    if not path.endswith(".gd"):
        sys.exit(0)

    warnings = lint_gdscript(content, path)

    if not warnings:
        sys.exit(0)

    # Report warnings back to Claude
    msg = "GDScript lint warnings:\n" + "\n".join(f"  ⚠ {w}" for w in warnings)
    output = {
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": msg,
        }
    }
    json.dump(output, sys.stdout)


if __name__ == "__main__":
    main()
