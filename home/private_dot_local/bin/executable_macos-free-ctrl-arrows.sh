#!/bin/sh
# Release Ctrl+Up / Ctrl+Down from macOS window management.
#
# Symbolic hotkey 32 claims Ctrl+Up for Mission Control and 33 claims Ctrl+Down
# for Application windows (App Exposé). The WindowServer consumes both before any
# application - or even a session event tap - sees them, so vim never receives
# the <C-Up>/<C-Down> mapped to paragraph jumps in
# config/nvim/lua/lee/remap.lua. Ctrl+Left/Right were already released the same
# way (ids 79-82). Same effect as unticking them in
# System Settings > Keyboard > Keyboard Shortcuts.
#
# Idempotent: only rewrites preferences and re-activates when one is still on.
# Driven from Hammerspoon (system_hotkeys.lua) so it survives OS updates.
set -eu

/usr/bin/python3 - <<'PY'
import plistlib
import subprocess
import sys

DOMAIN = "com.apple.symbolichotkeys"
# 32 = Mission Control (Ctrl+Up), 33 = Application windows (Ctrl+Down).
IDS = ("32", "33")
ACTIVATE = (
    "/System/Library/PrivateFrameworks/SystemAdministration.framework"
    "/Resources/activateSettings"
)


def export():
    out = subprocess.run(
        ["defaults", "export", DOMAIN, "-"], capture_output=True, check=True
    ).stdout
    return plistlib.loads(out)


def is_off(entry):
    # Only a real boolean counts. `defaults ... -dict-add` stores old-style
    # plist values as strings (the existing 79-82 entries hold "false" rather
    # than a boolean), so any string is treated as needing normalisation.
    if not isinstance(entry, dict):
        return False
    return entry.get("enabled", True) is False


prefs = export()
hotkeys = prefs.setdefault("AppleSymbolicHotKeys", {})
pending = [i for i in IDS if not is_off(hotkeys.get(i))]

if not pending:
    print("Ctrl+Up / Ctrl+Down already released")
    sys.exit(0)

# A missing entry means "still at the macOS default", which is enabled; add it
# as an explicit, correctly-typed boolean.
for i in pending:
    hotkeys.setdefault(i, {})["enabled"] = False

subprocess.run(["defaults", "import", DOMAIN, "-"], input=plistlib.dumps(prefs), check=True)
# Re-read the preferences into the running session. Without this the change
# would only take effect at the next login.
subprocess.run([ACTIVATE, "-u"], check=True)
print("released Ctrl+Up / Ctrl+Down (disabled symbolic hotkeys %s)" % ", ".join(pending))
PY
