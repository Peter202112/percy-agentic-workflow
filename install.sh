#!/bin/bash
set -euo pipefail

# Percy Agentic Workflow — Installer
# Copies agents, commands, skills, and documentation to the target Percy monorepo.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-.}"  # Default to current directory

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    echo "Percy Agentic Workflow Installer"
    echo ""
    echo "Usage: $0 [options] [target-directory]"
    echo ""
    echo "Options:"
    echo "  --all          Install everything (workflow + API + Web + gated skills)"
    echo "  --workflow      Just the orchestration workflow (research → PM → design → build)"
    echo "  --web           Just percy-web review agents + commands"
    echo "  --api           Just percy-api review agents + commands"
    echo "  --skills        Just the gated workflow skills (orchestrator, QA, local)"
    echo "  --dry-run       Preview what would be installed"
    echo "  --help          Show this help"
    echo ""
    echo "target-directory defaults to current directory."
}

DRY_RUN=false
INSTALL_WORKFLOW=false
INSTALL_WEB=false
INSTALL_API=false
INSTALL_SKILLS=false
INSTALL_ALL=false

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --all) INSTALL_ALL=true; shift ;;
        --workflow) INSTALL_WORKFLOW=true; shift ;;
        --web) INSTALL_WEB=true; shift ;;
        --api) INSTALL_API=true; shift ;;
        --skills) INSTALL_SKILLS=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help) usage; exit 0 ;;
        *) TARGET="$1"; shift ;;
    esac
done

# If nothing selected, install all
if ! $INSTALL_WORKFLOW && ! $INSTALL_WEB && ! $INSTALL_API && ! $INSTALL_SKILLS && ! $INSTALL_ALL; then
    INSTALL_ALL=true
fi

if $INSTALL_ALL; then
    INSTALL_WORKFLOW=true
    INSTALL_WEB=true
    INSTALL_API=true
    INSTALL_SKILLS=true
fi

TARGET="$(cd "$TARGET" && pwd)"

echo -e "${BLUE}Percy Agentic Workflow Installer${NC}"
echo -e "Source: ${SCRIPT_DIR}"
echo -e "Target: ${TARGET}"
echo ""

copy_dir() {
    local src="$1"
    local dest="$2"
    local label="$3"

    if [ ! -d "$src" ]; then
        echo -e "  ${YELLOW}SKIP${NC} $label (source not found: $src)"
        return
    fi

    if $DRY_RUN; then
        echo -e "  ${YELLOW}DRY${NC}  $label → $dest"
        return
    fi

    mkdir -p "$dest"
    cp -r "$src"/* "$dest"/ 2>/dev/null || true
    local count=$(find "$dest" -maxdepth 1 -type f | wc -l | tr -d ' ')
    echo -e "  ${GREEN}✓${NC}    $label ($count files)"
}

copy_file() {
    local src="$1"
    local dest="$2"
    local label="$3"

    if [ ! -f "$src" ]; then
        echo -e "  ${YELLOW}SKIP${NC} $label (not found)"
        return
    fi

    if $DRY_RUN; then
        echo -e "  ${YELLOW}DRY${NC}  $label → $dest"
        return
    fi

    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    echo -e "  ${GREEN}✓${NC}    $label"
}

# ── Workflow agents (root level) ──
if $INSTALL_WORKFLOW; then
    echo -e "${BLUE}Installing workflow agents...${NC}"
    copy_dir "$SCRIPT_DIR/root-agents" "$TARGET/.claude/agents" "Root agents"
    copy_dir "$SCRIPT_DIR/root-skills" "$TARGET/.claude/skills" "Root skills"
    copy_file "$SCRIPT_DIR/percy-workflow-guide.html" "$TARGET/.claude/percy-workflow-guide.html" "Workflow guide"
    copy_file "$SCRIPT_DIR/percy-distribution-guide.html" "$TARGET/.claude/percy-distribution-guide.html" "Distribution guide"
    echo ""
fi

# ── Gated workflow skills (project level) ──
if $INSTALL_SKILLS; then
    echo -e "${BLUE}Installing gated workflow skills...${NC}"
    copy_dir "$SCRIPT_DIR/project-skills" "$TARGET/.claude/skills" "Gated skills (orchestrator, QA, local)"

    # Create settings.json if it doesn't exist
    SETTINGS="$TARGET/.claude/settings.json"
    if [ ! -f "$SETTINGS" ] && ! $DRY_RUN; then
        cat > "$SETTINGS" << 'SETTINGS_EOF'
{
  "skills": [
    {
      "name": "percy-orchestrator-gated",
      "path": "skills/percy-orchestrator-gated.md",
      "description": "Gated feature orchestration: research → brief → design → plan → implement → QA → PR, with user approval at every stage"
    },
    {
      "name": "percy-qa",
      "path": "skills/percy-qa.md",
      "description": "Run full QA verification pipeline with comprehensive test reports"
    },
    {
      "name": "percy-local",
      "path": "skills/percy-local.md",
      "description": "Start/restart percy-web dev server at localhost:4200 with production backend"
    }
  ]
}
SETTINGS_EOF
        echo -e "  ${GREEN}✓${NC}    settings.json (skill registration)"
    elif $DRY_RUN; then
        echo -e "  ${YELLOW}DRY${NC}  settings.json"
    else
        echo -e "  ${YELLOW}EXISTS${NC} settings.json (merge skills manually if needed)"
    fi
    echo ""
fi

# ── Web agents + commands ──
if $INSTALL_WEB; then
    echo -e "${BLUE}Installing percy-web agents...${NC}"
    copy_dir "$SCRIPT_DIR/web-agents" "$TARGET/percy-web/.claude/agents" "Web review agents"
    copy_dir "$SCRIPT_DIR/web-commands" "$TARGET/percy-web/.claude/commands/percy" "Web commands"
    copy_dir "$SCRIPT_DIR/web-skills" "$TARGET/percy-web/.claude/skills" "Web skills"
    echo ""
fi

# ── API agents + commands ──
if $INSTALL_API; then
    echo -e "${BLUE}Installing percy-api agents...${NC}"
    copy_dir "$SCRIPT_DIR/api-agents" "$TARGET/percy-api/.claude/agents" "API review agents"
    copy_dir "$SCRIPT_DIR/api-commands" "$TARGET/percy-api/.claude/commands/percy" "API commands"
    copy_dir "$SCRIPT_DIR/api-skills" "$TARGET/percy-api/.claude/skills" "API skills"
    echo ""
fi

# ── Create reviews directory ──
if ! $DRY_RUN; then
    mkdir -p "$TARGET/reviews"
    echo -e "${GREEN}✓${NC} Created reviews/ directory"
fi

# ── Summary ──
echo ""
if $DRY_RUN; then
    echo -e "${YELLOW}Dry run complete. No files were modified.${NC}"
    echo "Re-run without --dry-run to install."
else
    echo -e "${GREEN}Installation complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. cd $TARGET && claude"
    echo "  2. @percy-orchestrator \"your problem statement or PRD\""
    echo ""
    echo "Documentation:"
    echo "  open $TARGET/.claude/percy-workflow-guide.html"
    echo "  open $TARGET/.claude/percy-distribution-guide.html"
    echo ""
    echo "Prerequisites:"
    echo "  Required: Claude Code (npm i -g @anthropic-ai/claude-code)"
    echo "  Required: Opus model access"
    echo "  Optional: /plugins enable figma    (for Figma mockups)"
    echo "  Optional: /plugins enable atlassian (for Jira)"
    echo "  Optional: npm i -g agent-browser   (for visual QA)"
fi
