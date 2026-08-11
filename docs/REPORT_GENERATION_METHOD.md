# How Turas reports are made

**Status:** Current policy. Written 2026-08-11, lifted from §2 of
[`docs/RUN_EVERYTHING_FROM_TURAS_PLAN.md`](RUN_EVERYTHING_FROM_TURAS_PLAN.md) when the Steps
module landed (Phase 1).

**Relationship to the compliance guideline.** `docs/Turas_AI_Compliance_Guideline.docx`
(Duncan Brett, terms verified 16 July 2026) is the authored, dated, client-facing document
about *what data goes where*. It is not edited by this file and not superseded by it. This
document answers the adjacent question — *who and what produced the deliverable* — and quotes
the guideline where the two meet. Where this document and the guideline differ, the
difference is flagged in the text (there is one, in rule 4).

Read this before adding any feature that writes text into a report, a deck, or an export.

---

## The six rules

### 1. AI builds Turas; Turas runs reports

Claude sessions write code, tests and documentation. Client deliverables are produced by
Duncan running deterministic Turas code through `launch_turas`. A Claude session never
headless-runs the report pipeline, and never writes into a client's project folder.

This is long-standing practice; it is written down here so it survives the people who
remember it. The compliance guideline says the same thing from the data side: "All analysis
— crosstabs, weighting, significance testing, tracking, report generation — runs in R on your
machine through launch_turas. No AI model is involved and nothing is sent anywhere."

### 2. Deliverables are not "AI-generated" and carry no AI mark

Because deliverables are produced by deterministic code, they are software output, not AI
output — the guideline's phrasing for workflow 1 is: "AI was used to build the software; the
software itself is just code."

No tool, library or export path may watermark, tag or label a deliverable as AI-generated.
That includes marks nobody sees on the page: anything writing an Office file sets document
metadata (author / creator / producer) explicitly to TRL or Turas values, never left to the
library default, so no third-party stamp rides along inside the file.

### 3. AI-written deliverable text is prohibited unless it is expressly tagged

The one sanctioned path is the built-in AI-insights feature: it sends aggregates only, and it
states its disclosure on the face of the report. That disclosure is the model for what an
"express tag" means. Any future AI-at-runtime text feature follows the same pattern — **off
by default, aggregates only, disclosed in the output itself.**

Enforcement is by policy and code review. There is deliberately no automated lint gate.

Text that a *tool* renders must be either template prose (labels and boilerplate, reviewed as
code) or analyst-typed configuration text (the Comments-sheet pattern). A build session must
never bake project-specific interpretive sentences into a tool's output.

#### What "AI-written" means here — the mechanism test, not the topic

Reports already contain AI-*authored* text that is fine: the static explainers (the
Differences tab's how-to-read prose) and the deterministic generated narrative (the
group-overview cards — fixed sentence templates filled with computed numbers, e.g. "ahead on
17 and behind on 10 of 28"). These state findings, and they are still software output: no
model runs at report time, identical data always yields identical words, and the
numbers-to-words mapping is a rule reviewed as code. Such text may truthfully carry a "no AI"
provenance line — the overview card's footer is the exemplar: "no AI · scanned 4 groups × 49
questions … curated by the researcher".

The test:

> **Is a model called at runtime, or could the words differ between two runs on identical
> data?**

If either is yes, the text is AI-written and rule 3 applies. If both are no, it is
deterministic software text under rule 1 — however fluent it reads.

### 4. AI-assisted analysis is distinct from AI-written text, and is allowed

Decided by Duncan, 2026-08-11. The worked example is verbatim comment theming: AI proposes
the coding, Duncan checks every output before it is used.

Permitted under **Max terms by default**; use API / commercial terms when a client requires
the contractual tier; off entirely when a client expressly prohibits AI. Such steps appear in
a project runbook as type `ai-assisted` and are described as analyst-supervised coding —
never hidden as "manual".

> **Flagged difference.** The compliance guideline's workflow 3 recommends running comment
> theming under commercial API terms ("This is respondent data; it gets the contractual
> tier"). The rule above records Duncan's current, relaxed position on the terms tier. The
> guideline's *anonymisation* steps for that workflow — ResponseID and verbatim only,
> self-identifying detail redacted inside the text, the ID-to-person key kept local — are
> unchanged and still apply in full. The docx stays as authored.

### 5. Scope: deliverables, not the codebase

Git commits carry Claude co-author trailers by design. That is build-side, and consistent
with rule 1.

### 6. Custom views consume Turas outputs, never raw data

A bespoke client view reads the generated data layer beside the report (`*_data.json`, the
stats pack, the wave JSON). It never recomputes statistics and never opens the raw data file.
That keeps it cheap, guaranteed-consistent with the crosstab, and compliant with the rules
above. See §3.4 of the plan for the full convention.

---

## Where the rules live in the code

| Rule | Where it shows up |
|------|-------------------|
| 1 | `launch_turas.R` is the only launch surface; the Project Steps tile (`modules/steps/`) exists so that steps which used to run as ad-hoc terminal commands run from it too. |
| 2 | Applies to every path that writes an Office file (the PPTX export, any xlsx writer). **Not yet audited:** a search of the export code on 2026-08-11 found no code setting document author/creator metadata either way, so today those files carry whatever the writing library defaults to. Checking and setting them is open work, not a claim this document can make. |
| 3 | `enable_ai_insights` defaults to FALSE (`modules/tabs/lib/crosstabs/crosstabs_config.R:406`) and the feature prints its own disclosure; the overview cards print the "no AI · scanned N groups × N questions" provenance line (`modules/tabs/lib/html_report_v2/assets/js/27h_takeout_read.js:149`). |
| 4 | Runbook rows typed `ai-assisted`, plus the per-project Provenance block — **Phase 2, not built yet.** |
| 6 | `custom/<client>/` views reading the tabs data layer — **Phase 3, not built yet.** |

## What a project will record (Phase 2 — not built yet)

Each project folder gets a runbook workbook (`<Project> Runbook.xlsx`) with the ordered
steps that produced the deliverable, each typed `module`, `tool`, `ai-assisted` or `manual`,
and a small **Provenance** block: which AI features were on for this project (insights
narrative on/off; theming Max / API / none) and where the client's approval or restriction
lives (proposal section, email date).

Nothing enforces off that block — it is the record that makes "no AI-written text unless
specified" auditable, and it is what Duncan shows a client who asks.

---

## Saying it to a client

The guideline already supplies the sentences for the data question. The equivalent for the
production question:

> "The report is produced by our own analysis software, run by us. It is not AI-generated:
> the same data always produces the same report. Where AI assists — comment coding, for
> example — a person checks every output before it is used, and the project record says so."
