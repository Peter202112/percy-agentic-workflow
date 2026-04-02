---
name: percy-report-generator
description: Generates styled HTML review reports for Percy workflow review gates. Call this after any agent produces findings to render them as a self-contained HTML file.
context: fork
allowed-tools: Read, Write, Bash, Glob
---

# Percy HTML Report Generator

Generate a self-contained, professionally styled HTML report and save it to `Percy/reviews/`.

## Usage

When an agent (researcher, design-explorer, validator, usability-reviewer) finishes its work, call this skill with:
1. **Report type** — one of: `research`, `product-brief`, `design-exploration`, `implementation-plan`, `validation`, `usability-review`, `pr-summary`
2. **PRD title** — short title from the PRD for the report header
3. **Report content** — the structured findings/analysis from the agent

## Output

Each report produces **two files** with the same timestamp:
- `reviews/{report-type}-YYYY-MM-DD-HHMMSS.md` — structured markdown (source of truth for agents)
- `reviews/{report-type}-YYYY-MM-DD-HHMMSS.html` — styled HTML (for human review)

The timestamp uses the current date/time. Run this bash command to get it:
```bash
date +"%Y-%m-%d-%H%M%S"
```

**Always write the `.md` file first**, then generate the `.html` from the same content.

## HTML Template

Generate the HTML report using this template structure. All CSS is inline — no external dependencies.

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Percy Review: {{REPORT_TITLE}}</title>
    <style>
        :root {
            --brand: #7B2FBE;
            --brand-light: #F3ECFB;
            --brand-dark: #5A1F8E;
            --danger: #DC2626;
            --danger-light: #FEE2E2;
            --warning: #D97706;
            --warning-light: #FEF3C7;
            --success: #059669;
            --success-light: #D1FAE5;
            --info: #2563EB;
            --info-light: #DBEAFE;
            --neutral-50: #F8FAFC;
            --neutral-100: #F1F5F9;
            --neutral-200: #E2E8F0;
            --neutral-300: #CBD5E1;
            --neutral-600: #475569;
            --neutral-700: #334155;
            --neutral-800: #1E293B;
            --neutral-900: #0F172A;
        }

        * { margin: 0; padding: 0; box-sizing: border-box; }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            color: var(--neutral-800);
            background: var(--neutral-50);
            line-height: 1.6;
        }

        .header {
            background: linear-gradient(135deg, var(--brand), var(--brand-dark));
            color: white;
            padding: 32px 48px;
        }

        .header h1 { font-size: 28px; font-weight: 700; margin-bottom: 8px; }
        .header .meta { opacity: 0.85; font-size: 14px; }
        .header .meta span { margin-right: 24px; }

        .container {
            max-width: 1100px;
            margin: 0 auto;
            padding: 32px 48px;
        }

        .executive-summary {
            background: var(--brand-light);
            border-left: 4px solid var(--brand);
            padding: 24px;
            border-radius: 0 8px 8px 0;
            margin-bottom: 32px;
        }

        .executive-summary h2 { font-size: 18px; color: var(--brand-dark); margin-bottom: 12px; }

        .section { margin-bottom: 32px; }
        .section h2 {
            font-size: 22px;
            color: var(--neutral-900);
            border-bottom: 2px solid var(--neutral-200);
            padding-bottom: 8px;
            margin-bottom: 16px;
        }
        .section h3 { font-size: 17px; color: var(--neutral-700); margin: 16px 0 8px; }

        details {
            border: 1px solid var(--neutral-200);
            border-radius: 8px;
            margin-bottom: 12px;
            background: white;
        }

        summary {
            padding: 12px 16px;
            cursor: pointer;
            font-weight: 600;
            color: var(--neutral-700);
            list-style: none;
        }

        summary::before { content: "▶ "; font-size: 12px; }
        details[open] summary::before { content: "▼ "; }

        details .content { padding: 0 16px 16px; }

        table {
            width: 100%;
            border-collapse: collapse;
            margin: 12px 0;
            font-size: 14px;
        }

        th {
            background: var(--neutral-100);
            text-align: left;
            padding: 10px 12px;
            font-weight: 600;
            color: var(--neutral-700);
            border-bottom: 2px solid var(--neutral-200);
        }

        td {
            padding: 10px 12px;
            border-bottom: 1px solid var(--neutral-200);
        }

        tr:hover td { background: var(--neutral-50); }

        .badge {
            display: inline-block;
            padding: 2px 10px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: 600;
            text-transform: uppercase;
        }

        .badge-high { background: var(--danger-light); color: var(--danger); }
        .badge-medium { background: var(--warning-light); color: var(--warning); }
        .badge-low { background: var(--info-light); color: var(--info); }
        .badge-pass { background: var(--success-light); color: var(--success); }

        .comparison-grid {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 16px;
            margin: 16px 0;
        }

        .approach-card {
            border: 2px solid var(--neutral-200);
            border-radius: 12px;
            padding: 20px;
            background: white;
        }

        .approach-card.recommended {
            border-color: var(--brand);
            box-shadow: 0 0 0 1px var(--brand);
        }

        .approach-card h3 { color: var(--brand); margin-bottom: 8px; }
        .approach-card .tag {
            display: inline-block;
            background: var(--brand);
            color: white;
            padding: 2px 8px;
            border-radius: 4px;
            font-size: 11px;
            margin-bottom: 12px;
        }

        .pros-cons { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-top: 12px; }
        .pros h4 { color: var(--success); }
        .cons h4 { color: var(--danger); }
        .pros li, .cons li { font-size: 13px; margin-bottom: 4px; }

        .figma-embed {
            border: 1px solid var(--neutral-200);
            border-radius: 8px;
            overflow: hidden;
            margin: 12px 0;
        }

        .figma-embed img { width: 100%; display: block; }
        .figma-link {
            display: inline-block;
            background: var(--brand);
            color: white;
            padding: 8px 16px;
            border-radius: 6px;
            text-decoration: none;
            font-weight: 600;
            margin: 8px 0;
        }

        .footer {
            text-align: center;
            padding: 24px;
            color: var(--neutral-600);
            font-size: 13px;
            border-top: 1px solid var(--neutral-200);
            margin-top: 48px;
        }

        ul, ol { padding-left: 24px; margin: 8px 0; }
        li { margin-bottom: 4px; }
        p { margin-bottom: 12px; }
        code { background: var(--neutral-100); padding: 2px 6px; border-radius: 4px; font-size: 13px; }

        @media print {
            .header { background: var(--brand); -webkit-print-color-adjust: exact; }
            details { break-inside: avoid; }
            details[open] summary ~ * { display: block !important; }
        }

        @media (max-width: 768px) {
            .header, .container { padding: 16px 24px; }
            .comparison-grid { grid-template-columns: 1fr; }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>{{REPORT_TITLE}}</h1>
        <div class="meta">
            <span>📋 {{REPORT_TYPE}}</span>
            <span>📅 {{DATE}}</span>
            <span>🎯 PRD: {{PRD_TITLE}}</span>
        </div>
    </div>

    <div class="container">
        <div class="executive-summary">
            <h2>Executive Summary</h2>
            <p>{{EXECUTIVE_SUMMARY}}</p>
        </div>

        <!-- Agent-specific sections go here -->
        <!-- Use <section class="section">, <details>, <table>, .badge-*, .comparison-grid, .approach-card -->

        {{REPORT_BODY}}

        <div class="footer">
            Percy Review Report · Generated by Claude Code · {{DATE}}
        </div>
    </div>
</body>
</html>
```

## Instructions for Agents

When generating a report:

1. Run `mkdir -p reviews` in the Percy root directory
2. Get the timestamp: `date +"%Y-%m-%d-%H%M%S"` — use the **same timestamp** for both files
3. **Write the markdown file first** to `reviews/{report-type}-{timestamp}.md`:
   - Use clean, structured markdown with headers, lists, and tables
   - This is the source of truth that downstream agents will read
   - No HTML markup — pure markdown
4. **Then generate the HTML file** to `reviews/{report-type}-{timestamp}.html`:
   - Construct the full HTML by replacing template placeholders with the same content
   - Use the appropriate HTML elements:
     - `<section class="section">` for major sections
     - `<details><summary>Title</summary><div class="content">...</div></details>` for collapsible sections
     - `<span class="badge badge-high">HIGH</span>` for severity badges
     - `<div class="comparison-grid">` with `<div class="approach-card">` for comparing approaches
     - `<div class="approach-card recommended">` for the recommended option
     - `<a class="figma-link" href="...">Open in Figma</a>` for Figma file links
     - `<div class="figma-embed"><img src="..." alt="..."></div>` for Figma screenshots
5. Report both file paths back to the user
