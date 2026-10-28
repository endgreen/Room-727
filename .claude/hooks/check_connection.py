#!/usr/bin/env python3
"""Hook: PreToolUse (mcp__godot__.*)
Check if Godot is listening before sending any MCP tool call.
Prevents 10s timeout hangs when Godot isn't running.
Cross-platform: works on macOS, Linux, and Windows.
"""

import json
import os
import socket
import sys
import time

CACHE_FILE = os.path.join(os.environ.get("TEMP", os.environ.get("TMPDIR", "/tmp")), "golem_port_check_cache")
CACHE_TTL = 10  # seconds — avoid TCP storm on rapid MCP calls


def is_recently_confirmed() -> bool:
    """Return True if a recent probe already confirmed the port is open."""
    try:
        if os.path.exists(CACHE_FILE):
            mtime = os.path.getmtime(CACHE_FILE)
            if time.time() - mtime < CACHE_TTL:
                return True
    except OSError:
        pass
    return False


def mark_confirmed() -> None:
    """Touch the cache file to record a successful probe."""
    try:
        with open(CACHE_FILE, "w") as f:
            f.write("")
    except OSError:
        pass


def is_port_listening(host: str, port: int) -> bool:
    """Check if a port is listening without leaving a persistent connection."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(0.5)
    try:
        result = sock.connect_ex((host, port))
        return result == 0
    except OSError:
        return False
    finally:
        sock.close()


def main():
    port = int(os.environ.get("GOLEM_PORT", "3571"))
    host = "127.0.0.1"

    # Skip probe if recently confirmed — prevents TCP storm
    if is_recently_confirmed():
        sys.exit(0)

    if is_port_listening(host, port):
        mark_confirmed()
        sys.exit(0)

    # Nothing listening — block the tool call
    output = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "additionalContext": f"Godot is not listening on port {port}. Start Godot with the Golem MCP plugin enabled, then retry.",
        }
    }
    json.dump(output, sys.stdout)
    sys.exit(2)


if __name__ == "__main__":
    main()
