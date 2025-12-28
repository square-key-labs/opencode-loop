#!/bin/bash

# OpenLoop Uninstall Script for OpenCode
# This script removes the OpenLoop plugin and commands
# Usage: ./uninstall.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# OpenCode config directory
OPENCODE_DIR="${HOME}/.opencode"

echo -e "${BLUE}"
echo "═══════════════════════════════════════════════════════════"
echo "           OpenLoop Uninstaller for OpenCode"
echo "═══════════════════════════════════════════════════════════"
echo -e "${NC}"

# Confirm uninstall
confirm_uninstall() {
    echo -e "${YELLOW}This will remove:${NC}"
    echo "  - ${OPENCODE_DIR}/plugin/open-loop.ts"
    echo "  - ${OPENCODE_DIR}/command/loop.md"
    echo "  - ${OPENCODE_DIR}/command/cancel-loop.md"
    echo "  - ${OPENCODE_DIR}/command/loop-status.md"
    echo ""
    read -p "Are you sure you want to uninstall OpenLoop? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Uninstall cancelled.${NC}"
        exit 0
    fi
}

# Remove plugin
remove_plugin() {
    echo -e "${BLUE}Removing OpenLoop plugin...${NC}"
    if [ -f "${OPENCODE_DIR}/plugin/open-loop.ts" ]; then
        rm -f "${OPENCODE_DIR}/plugin/open-loop.ts"
        echo -e "${GREEN}✓ Plugin removed${NC}"
    else
        echo -e "${YELLOW}⚠ Plugin file not found (already removed?)${NC}"
    fi
}

# Remove commands
remove_commands() {
    echo -e "${BLUE}Removing slash commands...${NC}"
    
    local removed=0
    
    if [ -f "${OPENCODE_DIR}/command/loop.md" ]; then
        rm -f "${OPENCODE_DIR}/command/loop.md"
        ((removed++))
    fi
    
    if [ -f "${OPENCODE_DIR}/command/cancel-loop.md" ]; then
        rm -f "${OPENCODE_DIR}/command/cancel-loop.md"
        ((removed++))
    fi
    
    if [ -f "${OPENCODE_DIR}/command/loop-status.md" ]; then
        rm -f "${OPENCODE_DIR}/command/loop-status.md"
        ((removed++))
    fi
    
    if [ $removed -gt 0 ]; then
        echo -e "${GREEN}✓ Removed ${removed} command file(s)${NC}"
    else
        echo -e "${YELLOW}⚠ No command files found (already removed?)${NC}"
    fi
}

# Remove state file if exists
remove_state() {
    echo -e "${BLUE}Cleaning up state files...${NC}"
    
    # Find and remove state files in common locations
    find "${HOME}" -name "open-loop.state.json" -path "*/.opencode/*" 2>/dev/null | while read -r statefile; do
        rm -f "$statefile"
        echo -e "${GREEN}✓ Removed state file: ${statefile}${NC}"
    done
    
    echo -e "${GREEN}✓ State cleanup complete${NC}"
}

# Cleanup empty directories
cleanup_dirs() {
    echo -e "${BLUE}Cleaning up empty directories...${NC}"
    
    # Remove plugin dir if empty
    if [ -d "${OPENCODE_DIR}/plugin" ] && [ -z "$(ls -A ${OPENCODE_DIR}/plugin 2>/dev/null)" ]; then
        rmdir "${OPENCODE_DIR}/plugin"
        echo -e "${GREEN}✓ Removed empty plugin directory${NC}"
    fi
    
    # Remove command dir if empty
    if [ -d "${OPENCODE_DIR}/command" ] && [ -z "$(ls -A ${OPENCODE_DIR}/command 2>/dev/null)" ]; then
        rmdir "${OPENCODE_DIR}/command"
        echo -e "${GREEN}✓ Removed empty command directory${NC}"
    fi
}

# Main uninstall
main() {
    confirm_uninstall
    remove_plugin
    remove_commands
    remove_state
    cleanup_dirs
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}           OpenLoop Uninstall Complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Note:${NC} The @opencode-ai/plugin dependency was not removed."
    echo -e "      If you want to remove it, run:"
    echo -e "      ${BLUE}cd ~/.opencode && bun remove @opencode-ai/plugin${NC}"
    echo ""
    echo -e "${GREEN}Restart OpenCode to apply changes.${NC}"
    echo ""
}

# Run main
main
