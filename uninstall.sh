#!/bin/bash

# OpenLoop Uninstall Script for OpenCode
# Usage: ./uninstall.sh

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

OPENCODE_DIR="${HOME}/.opencode"

echo -e "${BLUE}"
echo "═══════════════════════════════════════════════════════════"
echo "           OpenLoop Uninstaller for OpenCode"
echo "═══════════════════════════════════════════════════════════"
echo -e "${NC}"

# Confirm
echo -e "${YELLOW}This will remove OpenLoop files from ~/.opencode${NC}"
if [ -t 0 ]; then
    read -p "Continue? (y/N) " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && echo -e "${YELLOW}Cancelled.${NC}" && exit 0
else
    echo -e "${YELLOW}Running in non-interactive mode (piped). Proceeding...${NC}"
fi

# Remove files
echo -e "${BLUE}Removing files...${NC}"
rm -f "${OPENCODE_DIR}/plugin/open-loop.ts"
rm -f "${OPENCODE_DIR}/command/loop.md"
rm -f "${OPENCODE_DIR}/command/cancel-loop.md"
rm -f "${OPENCODE_DIR}/command/loop-status.md"
echo -e "${GREEN}✓ Files removed${NC}"

# Clean up state files
find "${HOME}" -name "open-loop.state.json" -path "*/.opencode/*" -delete 2>/dev/null || true
echo -e "${GREEN}✓ State files cleaned${NC}"

# Remove empty dirs
rmdir "${OPENCODE_DIR}/plugin" 2>/dev/null || true
rmdir "${OPENCODE_DIR}/command" 2>/dev/null || true

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}           OpenLoop Uninstalled!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Restart OpenCode to apply changes.${NC}"
