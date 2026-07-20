#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
SOURCE_APP="$PROJECT_DIR/build/Claude Island.app"
INSTALL_ROOT="$HOME/Applications"
TARGET_APP="$INSTALL_ROOT/Claude Island.app"

"$SCRIPT_DIR/build-app.sh" >/dev/null
mkdir -p "$INSTALL_ROOT"

if pgrep -x ClaudeIsland >/dev/null; then
  pkill -x ClaudeIsland
  for _ in {1..20}; do
    pgrep -x ClaudeIsland >/dev/null || break
    sleep 0.1
  done
fi

if [[ -e "$TARGET_APP" ]]; then
  TRASH_TARGET="$HOME/.Trash/Claude Island-$(date +%Y%m%d-%H%M%S).app"
  mv "$TARGET_APP" "$TRASH_TARGET"
fi

ditto "$SOURCE_APP" "$TARGET_APP"
open "$TARGET_APP"
echo "$TARGET_APP"
