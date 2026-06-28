#!/bin/bash
# install.sh — copies statusline-command.sh to ~/.claude/ and wires it into settings.json

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

cp "$REPO_DIR/statusline-command.sh" "$CLAUDE_DIR/statusline-command.sh"
chmod +x "$CLAUDE_DIR/statusline-command.sh"
echo "  ✓ statusline-command.sh → $CLAUDE_DIR/"

# Ensure settings.json has the statusLine entry
SETTINGS="$CLAUDE_DIR/settings.json"
if [ -f "$SETTINGS" ]; then
  if ! grep -q "statusLine" "$SETTINGS"; then
    python3 -c "
import json, sys
with open('$SETTINGS') as f: s = json.load(f)
s['statusLine'] = {'type': 'command', 'command': 'bash $CLAUDE_DIR/statusline-command.sh'}
with open('$SETTINGS', 'w') as f: json.dump(s, f, indent=2)
print('  ✓ settings.json patched')
"
  else
    echo "  ~ settings.json already has statusLine"
  fi
fi

echo ""
echo "Done. Restart Claude Code to apply."
