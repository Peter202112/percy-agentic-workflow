# Percy Agentic Workflow

A multi-agent system for [Claude Code](https://claude.ai/code) that takes a problem statement through research, product definition, design exploration (with Figma mockups), implementation, QA verification, and PR creation — with **mandatory user approval gates** at every stage.

**20 agents | 17 commands | 8 skills | 8 stages | 9 approval gates**

## Quick Start

```bash
# 1. Clone this repo
git clone https://github.com/Peter202112/percy-agentic-workflow.git

# 2. Run the installer targeting your Percy monorepo
./percy-agentic-workflow/install.sh --all /path/to/percy

# 3. Start Claude Code in the Percy monorepo
cd /path/to/percy && claude

# 4. Run the gated workflow
/percy-orchestrator-gated "As an SDET, I want to reduce repetitive review work..."
```

Or install selectively:

```bash
./install.sh --workflow     # Orchestration workflow only
./install.sh --web          # percy-web review agents + commands
./install.sh --api          # percy-api review agents + commands
./install.sh --skills       # Gated skills only (orchestrator, QA, local)
./install.sh --dry-run      # Preview what would be installed
```

## Gated Workflow

Every stage produces artifacts, pauses for your approval, and loops on feedback. No downstream work is wasted.

```
 PRD / User Story
  │
  ├─ Stage 1: Research ─────── competitive analysis + user benefit validation
  │   └─ 🚦 GATE 1: approve findings
  │
  ├─ Stage 2: Product Brief ── personas, phases, acceptance criteria
  │   └─ 🚦 GATE 2: approve scope
  │
  ├─ Stage 3: Design ────────── MANDATORY Figma mockups using DesignStack
  │   ├─ BLOCKS until Figma page URL + design system reference provided
  │   ├─ Creates 3+ screens, extracts tokens from reference file
  │   ├─ After approval: mockups embedded into product brief
  │   └─ 🚦 GATE 3: approve mockup screenshots
  │
  ├─ Stage 4: Plan ─────────── architecture blueprint, file-by-file changes
  │   └─ 🚦 GATE 4: approve architecture
  │
  ├─ Stage 5: Build ────────── API + Web implementation
  │   ├─ 🚦 GATE 5a: approve API diff
  │   └─ 🚦 GATE 5b: approve Web diff
  │
  ├─ Stage 6: QA ───────────── comprehensive test pipeline + detailed reports
  │   └─ 🚦 GATE 6: approve test results
  │
  ├─ Stage 7: Ship ─────────── commit + PR creation
  │   └─ 🚦 GATE 7: approve push to remote
  │
  └─ Stage 8: Cleanup ──────── graceful infrastructure shutdown
      └─ 🚦 GATE 8: choose what to shut down (default: keep running)
```

## Key Features

### Mandatory Figma Mockups
Stage 3 blocks until you provide a Figma page URL and design system reference. Mockups are created using extracted tokens (not hardcoded colors). After approval, screenshots are embedded into the product brief — making it the single source of truth.

### Comprehensive QA Reports
The `/percy-qa` skill produces test reports with:
- Full test plan (objective, strategy, scope, risk assessment)
- Test suite mapping to PRD requirements
- Detailed test cases (ID, title, objective, steps, data, expected/actual, notes)
- Bugs found with root cause analysis
- Acceptance criteria coverage matrix

### Graceful Cleanup
Docker containers only shut down with explicit approval. Warns about 2-5 min restart cost. Default: keep everything running.

### Feedback Loops
Every gate accepts "approve" or "feedback". Feedback re-runs the current stage with your context — the system never wastes work on downstream stages built on unapproved artifacts.

## Skills

| Skill | Invoke | Purpose |
|-------|--------|---------|
| **percy-orchestrator-gated** | `/percy-orchestrator-gated` | Full 8-stage gated workflow |
| **percy-qa** | `/percy-qa` | QA pipeline with detailed test reports |
| **percy-local** | `/percy-local` | Start percy-web at localhost:4200 |

## Prerequisites

| Requirement | Install | Required |
|-------------|---------|----------|
| Claude Code | `npm i -g @anthropic-ai/claude-code` | Yes |
| Opus model access | Via Anthropic account | Yes |
| Figma MCP plugin | `/plugins enable figma` in Claude Code | For design stage |
| Atlassian MCP plugin | `/plugins enable atlassian` | For Jira integration |
| agent-browser | `npm i -g agent-browser && agent-browser install` | For visual QA |
| Docker (Colima) | `brew install colima docker docker-compose` | For API tests |

## What's Included

```
percy-agentic-workflow/
├── install.sh                    # ← Run this
├── README.md                     # This file
├── root-agents/                  # 6 workflow & cross-repo agents
├── root-skills/                  # Report generator skill
├── project-skills/               # 3 gated skills (orchestrator, QA, local)
├── web-agents/                   # 5 web review agents
├── web-commands/                 # Web commands
├── web-skills/                   # Web PR validation
├── api-agents/                   # 9 API review agents
├── api-commands/                 # 14 API commands
├── api-skills/                   # 3 API skills
├── percy-workflow-guide.html     # Visual workflow guide
└── percy-distribution-guide.html # Distribution options guide
```

## Where Agents Live

Claude Code scopes agent discovery by working directory:

| Location | Available When | Contains |
|----------|---------------|----------|
| `.claude/` (root) | Always | Workflow agents, skills, guides |
| `percy-web/.claude/` | In percy-web | Web review agents, commands |
| `percy-api/.claude/` | In percy-api | API review agents, commands |

## Updating

```bash
cd percy-agentic-workflow && git pull
./install.sh --all /path/to/percy   # Re-run installer
```

## Documentation

After installing, open in a browser:

```bash
open /path/to/percy/.claude/percy-workflow-guide.html
open /path/to/percy/.claude/percy-distribution-guide.html
```

## License

Private — BrowserStack internal use.
