---
name: percy-orchestrator-gated
description: Gated feature orchestration workflow with mandatory user approval between every stage. Use when the user says "@percy-orchestrator", "orchestrate", "build this feature", or provides a PRD/user story.
user-invocable: true
---

# Percy Feature Orchestration — Gated Workflow

End-to-end feature development pipeline with **mandatory user approval gates** between every stage. No stage proceeds until the user explicitly approves the output or provides feedback for revision.

## Trigger

When the user provides a PRD, user story, or feature request and invokes this skill or `@percy-orchestrator`.

## Gate Protocol

Every stage follows this pattern:

```
1. Execute the stage (run agent, write code, generate report)
2. Present a concise summary of the output to the user
3. Ask: "✅ Approve to proceed to [Next Stage]? Or provide feedback to revise."
4. IF user provides feedback:
   a. Re-run the stage with feedback as additional context
   b. Present updated output
   c. Ask again (loop until approved)
5. IF user says "approve" / "proceed" / "looks good" / "yes":
   → Move to next stage
```

**CRITICAL:** Never proceed to the next stage without explicit user approval. If unsure whether the user approved, ask.

---

## Stage 1: RESEARCH

**Agent:** `percy-researcher` (background) + `feature-dev:code-explorer` (background, parallel)

**Inputs:** PRD or user story from the user

**Outputs:**
- Research report HTML saved to `reviews/research-{feature-slug}.html`
- Competitive analysis
- Codebase architecture mapping

**Required section in research report — "User Benefit Validation":**
```markdown
### User Benefit Validation

**Problem Solved:** [What specific friction point does this feature remove for the user?]

**Impact Metric:** [How does this feature improve the user's velocity, accuracy, or experience? Quantify if possible.]

**Alignment Check:** Does this value proposition align with your current product goals? [Ask the user]
```

**GATE:** Present the research summary including the User Benefit Validation section. Ask:
> "Research complete. Key findings: [2-3 bullet summary]. Does this align with your product goals? Approve to proceed to Product Brief, or provide feedback."

---

## Stage 2: PRODUCT BRIEF

**Agent:** `percy-pm` (background)

**Inputs:** Approved research + PRD

**Outputs:**
- Product brief HTML saved to `reviews/product-brief-{feature-slug}.html`
- Personas, phased deliverables, acceptance criteria, edge cases

**GATE:** Present the brief summary. Ask:
> "Product brief ready. Phase 1 scope: [key deliverables]. [N] acceptance criteria defined. Approve to proceed to Design, or provide feedback."

---

## Stage 3: DESIGN (MANDATORY — cannot be skipped)

**THIS STAGE IS NOT OPTIONAL.** Figma mockups MUST be created before any code is written. The only way to skip this stage is if the user explicitly says "skip Figma" or "skip design" — and even then, you must confirm: "Are you sure you want to skip Figma mockups? This means code will be written without visual validation. Confirm skip?"

### Step 3a: Collect Required Inputs (BLOCKING)

Before launching any design work, ask the user for TWO inputs. **DO NOT PROCEED until both are provided:**

1. **Figma page URL for new mocks:** "Which Figma page should I create the mockups on?"
   - No default — user MUST provide a URL
   - If user says "use the same one" or similar, check memory for previous Figma URLs
2. **Design system reference URL:** "Which Figma file has the reference components/design system?"
   - Default suggestion: `https://www.figma.com/design/7DN2b5rdG6s4HFT6tOrYNx/Percy-DesignStack-Migration`
   - User can confirm default or provide alternative

**Enforcement:** If the user tries to skip to implementation without providing these, respond: "Figma mockups are mandatory before implementation. Please provide the Figma page URL and design system reference to continue."

### Step 3b: Extract Design Tokens from Reference

Before creating any mockups:
1. Load the `figma-use` skill
2. Call `get_design_context` on key nodes from the reference file (Header, Main toolbar, Snapshot list, Comparison viewer)
3. Extract exact Percy design tokens:
   - Background: `--bg/neutral/default`, `--bg/neutral/strong`, `--bg/brand/weakest`
   - Borders: `--border/neutral/default`, `--border/neutral/strong`, `--border/brand/weaker`
   - Text: `--text/neutral/default`, `--text/neutral/weak`, `--text/neutral/weaker`, `--text/brand/strong`
   - Typography: Inter font, 12/14/16px, Regular/Medium/Semi Bold
   - Components: Badge, Button patterns, shadow/sm
4. Document extracted tokens before proceeding

### Step 3c: Create Figma Mockups

1. Load the `figma-generate-design` skill
2. Switch to the user's target Figma page
3. Create mockup screens using the extracted design tokens (NOT hardcoded colors)
4. Minimum screens to create:
   - Screen 1: The feature's primary state (e.g., banner/notification visible)
   - Screen 2: The feature's active/expanded state (e.g., suggestions revealed)
   - Screen 3: Detail view of key interaction (e.g., per-item actions/popover)
5. Take `get_screenshot` of each completed screen

### Step 3d: Design Exploration Report

Save to `reviews/design-exploration-{feature-slug}.html`:
- Wireframes of each approach
- Comparison matrix (PRD alignment, feasibility, consistency, scalability)
- Recommendation with rationale

### Step 3e: GATE (mandatory)

Present all mockup screenshots inline in the conversation. Ask:
> "Figma mockups created on [page URL]:
> - Screen 1: [description] [screenshot]
> - Screen 2: [description] [screenshot]
> - Screen 3: [description] [screenshot]
>
> Recommended approach: [X]. Approve to proceed to Implementation Plan, or provide feedback to revise the mockups."

**If feedback:** Revise the Figma mockups using `use_figma`, take new screenshots, present again. Loop until approved.

### Step 3f: APPEND MOCKS TO PRODUCT BRIEF (after design approval)

Once the design is approved, update the product brief HTML (`reviews/product-brief-{feature-slug}.html`) to embed the approved mockups. This makes the brief the **single source of truth** — requirements + visual reference in one document.

**Add a new section to the product brief HTML:**
```html
<h2>Approved Design Mockups</h2>
<p>Figma source: <a href="[FIGMA_PAGE_URL]">[FIGMA_PAGE_URL]</a></p>

<h3>Screen 1: [Title]</h3>
<p>[Description of this screen and what state it represents]</p>
<img src="[screenshot-screen1.png]" alt="Screen 1" style="max-width:100%; border:1px solid #e5e7eb; border-radius:8px;" />

<h3>Screen 2: [Title]</h3>
<p>[Description]</p>
<img src="[screenshot-screen2.png]" alt="Screen 2" ... />

<h3>Screen 3: [Title]</h3>
<p>[Description]</p>
<img src="[screenshot-screen3.png]" alt="Screen 3" ... />

<h3>Design Decision</h3>
<p>Recommended approach: [X]. Rationale: [why this was chosen over alternatives].</p>
```

**The user can access the mocks via:**
- **Figma** — the direct page URL linked in the brief
- **HTML report** — screenshots embedded in `reviews/product-brief-{feature-slug}.html`
- **Conversation** — screenshots were shown inline during the Stage 3 gate

This ensures the implementation plan (Stage 4) has full visual context without requiring the user to switch between documents.

---

## Stage 4: IMPLEMENTATION PLAN

**Agent:** `feature-dev:code-architect` (background)

**Inputs:** Approved design (from updated product brief with embedded mockups) + codebase architecture from Stage 1

**Outputs:**
- Architecture blueprint with:
  - Database schema (migration SQL)
  - API models, services, controllers, serializers, jobs
  - Web models, adapters, services, components
  - File-by-file change list with specific paths
  - Data flow diagram
  - Build sequence

**GATE:** Present the file list and key architecture decisions. Ask:
> "Implementation plan: [N] new files, [M] modified files across percy-api and percy-web. Key decisions: [2-3 bullets]. Approve to start coding, or provide feedback."

---

## Stage 5: IMPLEMENTATION

**Execution:** Write code directly (not via agents — they can't write files reliably).

**Sub-gates within implementation:**

### 5a: Feature Branch
- Create `feature/{feature-slug}` branch in both repos
- **Mini-gate:** "Feature branches created. Proceeding to API implementation."

### 5b: API Implementation
- Write all percy-api files (migration, models, services, job, serializer, controller, routes)
- Modify existing files (build_service.rb, routes.rb)
- Run `make rubocop` or ESLint equivalent
- **GATE:** Show `git diff --stat` for percy-api. Ask: "API implementation complete ([N] files). Review the changes? Approve to proceed to Web implementation."

### 5c: Web Implementation
- Write all percy-web files (model, adapter, service, components)
- Modify existing files (ignored-region-editor, overlay-viewer, route)
- Run `npx eslint --fix` on all new/modified files
- **GATE:** Show `git diff --stat` for percy-web. Ask: "Web implementation complete ([N] files). Review the changes? Approve to proceed to QA."

---

## Stage 6: QA VERIFICATION

**Skill:** `/percy-qa` (invoke the QA skill)

**Execution:** Run the full 6-stage QA pipeline autonomously (Docker setup, API specs, frontend build, ESLint, visual checks).

**Outputs:**
- `reviews/testresults.md` — comprehensive test report
- `reviews/testresults.html` — styled HTML version

**GATE:** Present test summary. Ask:
> "QA complete. [N] specs passing, [M] failures, [K] bugs found & fixed. Test report: [link]. Approve to commit & PR, or provide feedback."

---

## Stage 7: COMMIT & PR

**Only after Stage 6 approval.**

1. Commit in both repos with descriptive messages
2. **GATE:** "Commits created. Ready to push to remote and create PR?"
3. If approved: push + `gh pr create`
4. Return PR URL

---

## Stage 8: CLEANUP (with approval)

**After commit/PR (or after QA if user chose to hold on commit).**

Do NOT tear down infrastructure without asking. The user may want containers running for debugging.

**GATE:** Present what's still running and explicitly warn about restart cost:
> "Workflow complete. These resources are still running:
> - Docker: `percy-api-api-1`, `db`, `redis` containers
> - Dev server: `https://localhost:4200` (if started)
> - Browser: agent-browser session (if used)
>
> **Note:** Spinning up Docker containers again takes 2-5 minutes (Colima VM + container startup + DB readiness). If you plan to run more tests, debug, or iterate on the feature, I recommend keeping Docker running.
>
> Options:
> 1. **Shut down all** — Docker, dev server, browser (will need full restart later)
> 2. **Keep Docker, shut down rest** — kill dev server + browser only (recommended if you might test again)
> 3. **Keep everything running** — I'll clean up manually when done"

**DEFAULT:** If the user doesn't respond to cleanup, **keep everything running**. Only shut down on explicit approval.

**Shutdown order (when approved):**
1. `agent-browser close` (browser session)
2. `lsof -ti:4200 | xargs kill` (dev server)
3. `cd percy-api && docker-compose down` (containers — preserves volumes)
4. Verify: `docker ps | grep percy` should be empty

**DO NOT:** `docker-compose down -v` (destroys data) or `colima stop` (kills all Docker) unless explicitly asked.

---

## Error Handling

- If any agent fails (permission denied, timeout), retry once then report to user
- If a stage produces empty/invalid output, do not present it — diagnose and retry
- If the user says "skip" for a stage, note it and proceed but warn about downstream risks

## Memory

After completing the workflow, save:
- Feature progress to `memory/project_{feature_slug}.md`
- Any new user preferences to `memory/feedback_*.md`
