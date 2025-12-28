#!/bin/bash

# OpenLoop Setup Script for OpenCode
# This script installs the OpenLoop plugin and commands
# Usage: curl -fsSL https://raw.githubusercontent.com/square-key-labs/opencode-loop/main/setup.sh | bash
#    or: ./setup.sh

main() {
    set -e

    # Colors
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'

    OPENCODE_DIR="${HOME}/.opencode"
    REPO_URL="https://raw.githubusercontent.com/square-key-labs/opencode-loop/main"

    echo -e "${BLUE}"
    echo "═══════════════════════════════════════════════════════════"
    echo "           OpenLoop Setup for OpenCode"
    echo "═══════════════════════════════════════════════════════════"
    echo -e "${NC}"

    # Check/install bun
    if ! command -v bun &> /dev/null; then
        echo -e "${YELLOW}Installing bun...${NC}"
        curl -fsSL https://bun.sh/install | bash
        export PATH="$HOME/.bun/bin:$PATH"
    fi
    echo -e "${GREEN}✓ Bun available${NC}"

    # Create directories
    mkdir -p "${OPENCODE_DIR}/plugin" "${OPENCODE_DIR}/command"
    echo -e "${GREEN}✓ Directories created${NC}"

    # Download files from repo
    echo -e "${BLUE}Downloading files...${NC}"
    curl -fsSL "${REPO_URL}/plugin/open-loop.ts" -o "${OPENCODE_DIR}/plugin/open-loop.ts"
    curl -fsSL "${REPO_URL}/command/loop.md" -o "${OPENCODE_DIR}/command/loop.md"
    curl -fsSL "${REPO_URL}/command/cancel-loop.md" -o "${OPENCODE_DIR}/command/cancel-loop.md"
    curl -fsSL "${REPO_URL}/command/loop-status.md" -o "${OPENCODE_DIR}/command/loop-status.md"
    echo -e "${GREEN}✓ Files downloaded${NC}"

    # Setup package.json
    if [ -f "${OPENCODE_DIR}/package.json" ] && command -v jq &> /dev/null; then
        jq -s '.[0] * .[1]' "${OPENCODE_DIR}/package.json" <(curl -fsSL "${REPO_URL}/package.json") > "${OPENCODE_DIR}/package.json.tmp"
        mv "${OPENCODE_DIR}/package.json.tmp" "${OPENCODE_DIR}/package.json"
    else
        curl -fsSL "${REPO_URL}/package.json" -o "${OPENCODE_DIR}/package.json"
    fi
    echo -e "${GREEN}✓ package.json configured${NC}"

    # Install deps
    cd "${OPENCODE_DIR}" && bun install
    echo -e "${GREEN}✓ Dependencies installed${NC}"

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}           OpenLoop Installation Complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "Commands:"
    echo -e "  ${YELLOW}/loop <task>${NC}        - Start loop"
    echo -e "  ${YELLOW}/cancel-loop${NC}        - Cancel loop"
    echo -e "  ${YELLOW}/loop-status${NC}        - Check status"
    echo ""
    echo -e "${GREEN}Restart OpenCode to load the plugin.${NC}"
}

# Run main function - this ensures entire script is downloaded before execution
main
