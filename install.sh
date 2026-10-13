#!/bin/bash
# install.sh — copies statusline-command.sh to ~/.claude/ and wires it into settings.json
#
# Works on macOS/Linux (native bash) and on Windows via Git Bash / MSYS.
# On Windows, `bash` on PATH often resolves to the WSL interop shim
# (C:\Windows\System32\bash.exe) instead of Git Bash, which cannot resolve
# Windows-style paths. We work around that by pinning the statusLine command
# to the absolute path of the bash currently running this installer.

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

cp "$REPO_DIR/statusline-command.sh" "$CLAUDE_DIR/statusline-command.sh"
chmod +x "$CLAUDE_DIR/statusline-command.sh"
echo "  ✓ statusline-command.sh → $CLAUDE_DIR/"

# --- Windows (Git Bash/MSYS) detection -------------------------------------
IS_WINDOWS=0
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) IS_WINDOWS=1 ;;
esac

if [ "$IS_WINDOWS" = "1" ]; then
  # $BASH is the POSIX-style path of the bash binary actually running this
  # script (e.g. "/usr/bin/bash" inside Git Bash's own mount namespace).
  # cmd.exe — what Claude Code uses to spawn the statusLine command — can't
  # resolve POSIX paths, and a bare `bash` on PATH often hits the WSL
  # interop shim (C:\Windows\System32\bash.exe) instead of Git Bash, which
  # in turn can't resolve Windows-style paths. Convert to a real Windows
  # path once here so neither side has to guess.
  BASH_RAW="$(cygpath -m "${BASH:-$(command -v bash)}")"
  # $BASH resolves to the raw MSYS binary (.../Git/usr/bin/bash.exe), which
  # is non-login/non-interactive when launched directly by cmd.exe and so
  # skips Git's profile scripts — leaving PATH without even basic coreutils
  # (dirname, cat, jq, ...). Git/bin/bash.exe is a wrapper that sets up that
  # environment properly; prefer it when it exists alongside usr/bin/bash.exe.
  GIT_ROOT="${BASH_RAW%/usr/bin/bash.exe}"
  if [ -f "$GIT_ROOT/bin/bash.exe" ]; then
    BASH_EXE="$GIT_ROOT/bin/bash.exe"
  else
    BASH_EXE="$BASH_RAW"
  fi
  STATUSLINE_SCRIPT="$(cygpath -m "$CLAUDE_DIR/statusline-command.sh")"
  STATUSLINE_CMD="\"$BASH_EXE\" \"$STATUSLINE_SCRIPT\""

  # jq is required by the script but isn't bundled on Windows. Vendor a
  # local copy next to the script so it works regardless of PATH/winget
  # refresh timing, if we can find one already installed on the system.
  if ! command -v jq >/dev/null 2>&1 && [ ! -f "$CLAUDE_DIR/jq.exe" ]; then
    JQ_CANDIDATE="$(find "$LOCALAPPDATA/Microsoft/WinGet/Packages" -maxdepth 1 -iname 'jqlang.jq_*' 2>/dev/null | head -1)/jq.exe"
    if [ -f "$JQ_CANDIDATE" ]; then
      cp "$JQ_CANDIDATE" "$CLAUDE_DIR/jq.exe"
      echo "  ✓ jq.exe → $CLAUDE_DIR/ (vendored from winget install)"
    else
      echo "  ! jq not found. Install it (e.g. 'winget install jqlang.jq') then re-run this script."
    fi
  fi
else
  STATUSLINE_CMD="bash $CLAUDE_DIR/statusline-command.sh"
fi

# Wire (or re-wire) the statusLine entry in settings.json
SETTINGS="$CLAUDE_DIR/settings.json"
if [ -f "$SETTINGS" ]; then
  # Windows' python3 (e.g. the Windows Store build) doesn't understand
  # Git Bash's POSIX-style paths, so pass it a real Windows path.
  SETTINGS_PY="$SETTINGS"
  [ "$IS_WINDOWS" = "1" ] && SETTINGS_PY="$(cygpath -m "$SETTINGS")"
  python3 -c "
import json
with open('$SETTINGS_PY') as f: s = json.load(f)
had = 'statusLine' in s
s['statusLine'] = {'type': 'command', 'command': '''$STATUSLINE_CMD'''}
with open('$SETTINGS_PY', 'w') as f: json.dump(s, f, indent=2)
print('  ~ settings.json statusLine updated' if had else '  ✓ settings.json patched')
"
else
  echo "  ! $SETTINGS not found — add statusLine manually:"
  echo "    { \"statusLine\": { \"type\": \"command\", \"command\": \"$STATUSLINE_CMD\" } }"
fi

echo ""
echo "Done. Restart Claude Code to apply."
