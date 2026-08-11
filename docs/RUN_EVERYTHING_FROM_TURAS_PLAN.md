---

editor_options: 
  markdown: 
    wrap: 72
---

# Run everything from Turas — plan

**Status:** Design approved for implementation. Written 2026-08-11 (Fable design session). Implementation sessions (Opus) work phase by phase from this document. **Read the whole document before writing any code.**

------------------------------------------------------------------------

## 1. What this is and why

The CCPB W2026 report showed the gap: most of the pipeline runs from the `launch_turas` GUI, but some production steps run outside it — the Comment Appendix builder (`scripts/build_comment_appendix.py`, Python), and other steps that today live only in Duncan's head or in ad-hoc terminal commands.

Two problems follow:

1.  **The steps aren't documented anywhere executable.** With TRL now a one-person operation, the repo must self-document (see `docs/WAY_FORWARD.md` context). A step that exists only as a remembered terminal command is a step that gets lost.
2.  **The process boundary is blurry.** Duncan's operating rule is: **AI builds Turas; Turas runs reports. AI never runs a report.** Steps that run outside the GUI are exactly the steps that tempt an AI session into running them.

The goal: every step in producing a client deliverable is runnable from the `launch_turas` GUI, documented per project in a runbook, and covered by the provenance policy below. Python (or any other runtime) is fine — the GUI wraps it; the language doesn't matter, the launch surface does.

## 2. Policy (the golden rules)

Phase 1 lifts this section into a standalone `docs/REPORT_GENERATION_METHOD.md` that Duncan can draw on for his client-facing description of how reports are made. Do **not** edit `docs/Turas_AI_Compliance_Guideline.docx` — that is Duncan's authored, dated, client-facing document. The new markdown file quotes and extends it.

1.  **AI builds Turas; Turas runs reports.** Claude sessions write code, tests, and docs. Client deliverables are produced by Duncan running deterministic Turas code via `launch_turas`. A Claude session never headless-runs the report pipeline and never overwrites files in a client's OneDrive project folder. (This is already standing practice — it moves from Claude's memory into the repo here.)
2.  **Deliverables are not "AI-generated" and carry no AI mark.** Because deliverables are produced by deterministic code, they are software output, not AI output — per the compliance guideline's workflow 1: "AI was used to build the software; the software itself is just code." No tool, library, or export path may watermark, tag, or label a deliverable as AI-generated. This includes invisible marks: tools that write Office files set document metadata (author/creator/producer) explicitly to TRL/Turas values — never left to library defaults — so no third-party stamp rides along inside the file.
3.  **AI-written deliverable text is prohibited unless express-tagged.** The one sanctioned path is the built-in AI-insights feature, which sends aggregates only and states its disclosure on the face of the report. That disclosure is the model for what an "express tag" means. Any future AI-at-runtime text feature must follow the same pattern: **off by default**, aggregates only, disclosed in the output itself. Enforcement is by policy and code review — no automated lint gate (over-engineering). Text a *tool* renders must be template prose (labels, boilerplate reviewed as code) or analyst-typed config text (the Comments-sheet pattern) — a build session must never bake project-specific interpretive sentences into a tool's output.
    **What "AI-written" means here — the mechanism test, not the topic.** Reports already contain AI-*authored* text patches that are fine: static explainers (the Differences tab's how-to-read prose) and deterministic generated narrative (the group-overview cards — fixed sentence templates filled with computed numbers, e.g. "ahead on 17 and behind on 10 of 28"). These state findings, yet they are software output: no model runs at report time, identical data always yields identical words, and the numbers→words mapping is a rule reviewed as code. Such text may truthfully carry a "no AI" provenance line (the overview card's footer is the exemplar: "no AI · scanned 4 groups × 49 questions … curated by the researcher"). The test for whether text needs the express tag: **is a model called at runtime, or could the words differ between two runs on identical data?** If either is yes, it is AI-written and rule 3 applies; if both are no, it is deterministic software text under rule 1, however fluent it reads.
4.  **AI-assisted analysis is distinct from AI-written text, and is allowed.** (Duncan's decision, 2026-08-11.) Example: verbatim comment theming — AI proposes the coding, Duncan checks every output before it is used. Permitted under **Max terms by default**; use API/commercial terms only when a client requires the contractual tier; off entirely if a client expressly prohibits AI. Such steps appear in runbooks as type `ai-assisted` and are described in the method description as analyst-supervised coding — never hidden as "manual". (Note: the compliance docx recommends API terms for theming; this policy records Duncan's current, relaxed position. The docx stays as authored.)
5.  **Scope: deliverables, not the codebase.** Git commits carry Claude co-author trailers by design; that is build-side and consistent with rule 1.
6.  **Custom views consume Turas outputs, never raw data.** See §3.4.

## 3. Architecture

Two layers, wrapped in one new launcher tile.

### 3.1 The Steps module (repo-level tool registry)

A new module `modules/steps/` following the standard module pattern (`run_steps_gui.R`, `lib/`, `tests/testthat/`), registered as a tile in the `launch_turas.R` module registry (add to the existing data-driven `modules` list; category `"reporting"`, id `"steps"`, name **"Project Steps"** — decided-and-noted, rename freely).

**Tool manifests.** Each external tool is described by a manifest — an R list, consistent with the launcher's existing data-driven registry style:

``` r
list(
  id          = "comment_appendix_build",
  name        = "Comment Appendix — build/update",
  description = "Append new respondents' verbatims to the coded-comment workbook",
  runtime     = "python3",                                # or "Rscript"
  entry       = "scripts/build_comment_appendix.py",      # relative to TURAS_ROOT
  requires    = c("openpyxl", "pandas"),                  # importable-module check
  docs        = "scripts/README_comment_appendix.md",
  args = list(
    list(id = "data",         label = "Survey data file",        type = "file",   required = TRUE,  cli = "--data"),
    list(id = "appendix",     label = "Appendix workbook",       type = "file",   required = TRUE,  cli = "--appendix"),
    list(id = "columns_file", label = "Comment-columns file",    type = "file",   required = FALSE, cli = "--columns-file"),
    list(id = "pattern",      label = "Column pattern (regex)",  type = "text",   required = FALSE, cli = "--pattern"),
    list(id = "dry_run",      label = "Dry run (report only)",   type = "flag",   required = FALSE, cli = "--dry-run")
  )
)
```

Arg types: `file`, `dir`, `text`, `choice` (with `choices`), `flag`. Built-in registry lives at `modules/steps/lib/registry.R`. Tools themselves stay where they live (`scripts/`, `custom/`); the registry only points at them.

**Execution.** The GUI renders a form from the manifest, builds the command, and runs it via `system2()`/`processx` with:

- **Live-streamed stdout/stderr to the R console** (Shiny rule: all output console-visible; a long fieldwork append that buffers looks hung). Prefer `system2()` with inherited stdout — that already streams live to the console. Only reach for `processx` if in-UI output display turns out to be required, and check `renv.lock` / ask Duncan first (new-dependency rule). The appendix script's preview output — resolved columns, per-column counts — is a feature; surface it, never swallow it.
- **Exit-code mapping:** non-zero → TRS-style refusal (`IO_STEP_FAILED`) printed in the boxed console format *and* shown via `showNotification`, with the tail of stderr in the message. Zero → PASS with the output path(s).
- **Path resolution via `TURAS_ROOT`**, exactly as `launch_turas.R` does. Never `getwd()`-relative, never hardcoded.

**Environment guard (Phase 1 requirement, Docker-aware).** Before running a tool, check: the runtime binary is on PATH; each `requires` module imports (`python3 -c "import openpyxl"`). On failure, TRS refusal (`PKG_RUNTIME_MISSING`) with the exact fix (`python3 -m pip install -r scripts/requirements.txt`). Add `scripts/requirements.txt` pinning what the scripts need (today: openpyxl and pandas — the appendix script imports both). Document in the Docker notes that the image needs python3 + those packages — verified working on Duncan's machine today (`/usr/bin/python3` 3.9.6, openpyxl 3.1.5, pandas 2.3.3), but that is this machine only.

### 3.2 Per-project runbook

Each project folder gets a runbook workbook, e.g. `CCPB CSAT W2026 Runbook.xlsx`, sheet `Steps`:

| Order | Step | Type | Module / Tool ID | Args (one column per arg id) | Notes |
|-------|------|------|------------------|------------------------------|-------|

`Type` is one of `module` (a Turas module run — documented, launched from its own tile), `tool` (runs via the Steps GUI), `ai-assisted` (an analyst-supervised AI step, e.g. verbatim theming — see policy rule 4), or `manual` (a genuinely human step, e.g. coding the appendix in Excel, building the deck — documented so the sequence is complete even where the GUI can't run it).

**Provenance section (decided 2026-08-11).** Each runbook also carries a small `Provenance` block (own sheet or rows at the top of `Steps`): which AI features are on for this project (insights narrative on/off; theming Max / API / none), and one cell pointing at where the client's approval or restriction lives (proposal section, email date). Nothing enforces off it in Phase 1 — it is the per-project record that makes "no AI-written text unless specified" auditable, and what Duncan shows a client who asks.

The runbook is **the document Duncan asked for** — the ordered, complete record of how a deliverable is produced — and in Phase 2 the Steps GUI reads it and presents it as a checklist with Run buttons for `tool` rows.

**Explicitly not a pipeline engine.** No dependency resolution, no auto-sequencing, no "run all" button. It is a checklist that remembers last-run timestamps and last-used args (stored in a sidecar `.runbook_state.rds` beside the workbook — never written into Duncan's xlsx). Duncan clicks each step; between-step human work (coding, review) is the normal case, not an edge case.

### 3.3 The proof case: Comment Appendix (all three modes)

The comment appendix builder is **already merged on main** with tests (`scripts/build_comment_appendix.py`, `scripts/test_build_comment_appendix.py`, `scripts/README_comment_appendix.md`). Phase 1 wraps its full flow as three registry entries:

1.  **Build/update** — append new respondents (the manifest above).
2.  **Report changes** (`--report-changes [FILE]`) — writes the review workbook of changed verbatims; changes nothing.
3.  **Apply changes** (`--apply-changes FILE`) — rewrites approved rows only.

This trio is the arg-schema stress test: optional args, flags, file *outputs*, and Duncan editing a workbook in Excel between GUI steps. If the design handles this flow cleanly, it handles the general case.

### 3.4 Custom views

From time to time a client needs a bespoke view that standard Turas output doesn't cover. Convention:

- **Location (decided 2026-08-11):** `custom/<client>/` in the repo (e.g. `custom/ccpb/`), each view a script + manifest + tests. Versioned in git; the repo still holds code and synthetic fixtures only — scripts take project-folder paths as arguments at runtime.
- **Lifecycle (anti-mess rule, goes in `custom/README.md`):** when a project ends, its view folder is either **deleted** (git history keeps it recoverable; the registry stops listing it the moment it's gone) or **promoted** into a shared tool if it proved generally useful — the path the comment appendix itself took. Nothing lingers as a zombie.
- **Registration:** the Steps registry discovers `custom/*/manifest.R` and lists those tools alongside built-ins (grouped under the client name).
- **Design rule: custom views consume the Turas data layer, never raw data.** The tabs run already writes `*_data.json`, the stats pack, and the wave JSON beside the report (all present in the CCPB output folder). A custom view reads those generated outputs. It never recomputes statistics and never opens the raw data file — that keeps it cheap, guaranteed-consistent with the crosstab, and compliant with §2. (This converges with the proposed section-report module idea; if that module lands, it becomes the natural home for most custom views.)
- **Development target = synthetic fixture (decided 2026-08-11).** Phase 3 ships a synthetic data-layer fixture (one committed example, or a generator producing a fake `*_data.json` in the real shape). Custom views are **developed and tested against the fixture**, for three reasons independent of compliance: repo tests cannot use client data; a build session pointed at OneDrive is one clumsy write away from touching a deliverable (read-only reference only, never a working directory); and a view built solely against one real file overfits to that project's quirks. A build session *may read* the real data layer as an occasional read-only sanity check — under the policy rules 3–4 defaults, that is acceptable unless a client prohibits it (note the qual island carries verbatims; it is not aggregates-only).
- **Process:** AI (Opus) builds the view with tests; Duncan runs it from the Steps GUI. Same golden rules apply.

## 4. Phases

Each phase ends with a check that can fail. Split the verification explicitly: **automated tests cover the non-Shiny layer; the GUI itself is verified only by Duncan via `launch_turas()`**. An implementation session must not claim the GUI done from tests alone, and must never headless-run the pipeline or touch the OneDrive project folder.

### Phase 0 — inventory and decisions — **DONE 2026-08-11**

- CCPB W2026 step inventory captured in §5; all §6 decisions made.
- Gate met: the draft runbook table exists in this doc.

### Phase 1 — Steps module + policy doc (Opus) — **BUILT 2026-08-11, awaiting Duncan's GUI gate**

Landed: `modules/steps/` (`run_steps_gui.R`, `lib/registry.R`, `lib/run_tool.R`, `README.md`, `tests/`), `scripts/requirements.txt`, `docs/REPORT_GENERATION_METHOD.md`, the tile + icon in `launch_turas.R`, and doc cross-links (`OPERATOR_GUIDE.md`, `QUAL_COMMENT_APPENDIX_GUIDE.md`, `Docker/DOCKER_MANUAL.md`, `CHANGELOG.md`).

Three deviations from the section below, each with its reason:

1.  **processx, not `system2` with inherited stdout.** The launcher starts a module as a background `Rscript` whose stdout goes to a temp log it deletes after 5s (`launch_turas.R:934-945`), so console-only streaming is invisible in exactly the launched-from-hub case. Output streams into the page (300ms poll) and is `cat()`-ed as well for a directly-run session. processx 3.8.6 is already in `renv.lock` — no new dependency, no lockfile change. This is the branch the section below pre-authorised.
2.  **stdout and stderr merged.** One stream, so the console reads in the order the tool produced it, and because the appendix script prints its errors to stdout. The refusal therefore carries the tail of *combined output*, not of stderr alone.
3.  **The review manifests carry the column arguments too, and drop `--dry-run`.** `build_comment_appendix.py` resolves the comment columns *before* it dispatches on mode (line 501 vs 520-524), so a review mode without `--columns-file`/`--pattern` would silently fall back to the default pattern — on CCPB's 39 named columns, reviewing the wrong set of sheets. `--dry-run` is checked after the dispatch (line 532), so it does nothing in the review modes and is not offered there. Both are asserted by tests.

The section below's "Docker-aware" requirement is now moot: **Docker was mothballed 11 August 2026** (Duncan, after Jess left — nothing runs in a container). The env guard stays runtime-agnostic and the note about an image needing python3 is kept in `Docker/DOCKER_MANUAL.md` for a possible revival; no Docker work is outstanding.

Also added beyond the section below: a manifest-level `exclusive` group (two mutually exclusive arguments both set refuses before the tool runs, naming both) and a `must_exist` flag per path argument (the appendix does not exist on the first build).

Not exposed in the manifests, deliberately: `--columns`, `--structure`, `--auto`, `--yes`, `--id-header`, `--no-backup`.

Verified: `modules/steps/tests/testthat` — 60 tests / 201 assertions / 0 failures / 0 skips, including the appendix trio end to end (both the named and the auto-named review-list paths) against a synthetic workbook in a temp folder, and the GUI's *server* logic through `shiny::testServer` (form rendered from a manifest, blank required field refusing without starting a process, a real run streaming through the polling observer to PASS). `python3 scripts/test_build_comment_appendix.py` — 30 passed / 0 failed, untouched. **Not verified: the page itself** — layout, file pickers, how the output reads mid-run. That is the gate below.

Original scope, for reference:

Files: `modules/steps/run_steps_gui.R`, `modules/steps/lib/registry.R`, `modules/steps/lib/run_tool.R` (manifest validation, command build, env guard, execution + TRS mapping), `modules/steps/tests/testthat/…`, `scripts/requirements.txt`, `docs/REPORT_GENERATION_METHOD.md` (lifted from §2), registry entry + icon in `launch_turas.R`.

Scope: the three comment-appendix manifests; form rendering with file pickers; live console streaming; env guard.

Tests (run without Shiny): manifest validation (missing fields, bad types, duplicate ids refuse), command construction (args → CLI vector, quoting, flag handling), env-guard refusal paths (mock a missing binary/module), exit-code → TRS mapping (mock the subprocess). The existing Python test suite (`python3 scripts/test_build_comment_appendix.py`) must still pass untouched.

Gate: suites green **and** Duncan runs the appendix build against CCPB W2026 from the GUI and confirms output + console visibility.

### Phase 2 — runbook checklist (Opus) — **BUILT 2026-08-11, awaiting Duncan's GUI gate**

Landed: `modules/steps/lib/runbook.R` (read/validate, sidecar state, template generator), the checklist UI in the Steps GUI, and starter runbooks for **ASSA** (22 steps), **Electrum VAS 2026** (10) and **SACAP SACS 2026** (16), written into their project folders on Duncan's explicit instruction.

Two decisions taken against the section below:

1.  **CCPB W2026 is not the first runbook.** Duncan's call, 2026-08-11: that wave is finished, so its runbook would be a retrospective record. The live and upcoming projects are where a runbook earns its keep, and for SACS and ASSA it is prospective — the steps written down before they happen.
2.  **Arguments are `arg:<id>` columns, not a fixed set.** The section below says "one column per arg id"; the prefix convention makes that self-describing, tolerant of extra columns, and free of a fixed schema. A blank cell is simply not passed.

Also added: `Order` sorts numerically when every value is a number and otherwise leaves sheet order alone (so `2a` / `2b` do not break); a `Mark done` control on non-tool rows, because a checklist where most rows cannot be ticked is not a checklist; a Type dropdown and a `Guide` sheet in the generated template; and the sidecar is named after its workbook so two runbooks in one folder cannot collide.

**The gap this exposed.** Of the tool-shaped steps in the three projects, only the comment-appendix trio is registered. ASSA's `build_assa_field_report.py`, `prepare_assa_data.R` and `title_appendix.py`, and all four of VAS's `.command` stages, are real scripts living in project folders — they are typed `manual` with the exact command in Notes, which is truthful but not runnable. Registering them is what Phase 3's `custom/<client>/` discovery is for.

Verified: 88 tests / 303 assertions / 0 failures across `modules/steps/tests/testthat`, including a real tool run driven from a runbook step with its outcome recorded in the sidecar. All three runbooks were read back through the parser after being written. **Not verified: the page itself.**

Original scope, for reference:

Files: `modules/steps/lib/runbook.R` (read the xlsx, validate), checklist UI in the Steps GUI, sidecar state read/write, a runbook template generator (or a committed template file `modules/steps/templates/Runbook_template.xlsx`).

Tests: runbook parsing (good file, missing columns, unknown tool id → refusal naming the row), state round-trip, template generation.

Gate: suites green **and** Duncan opens the CCPB runbook in the GUI, sees the checklist, runs one tool row from it.

### Phase 3 — custom views (Opus, when the first real need arrives)

Files: `custom/README.md` (the convention + lifecycle rule, from §3.4), discovery in `registry.R`, the synthetic data-layer fixture (or generator), the first real custom view with its own tests.

Tests: discovery (finds manifests, refuses malformed ones), plus the view's own suite against synthetic fixtures shaped like the tabs data layer.

Gate: Duncan runs the first custom view from the GUI on a real project.

Docs to touch when phases land: `OPERATOR_GUIDE.md` (new tile), `modules/tabs/docs/QUAL_COMMENT_APPENDIX_GUIDE.md` (cross-link "or run from the Project Steps tile"), `CHANGELOG.md`.

## 5. CCPB W2026 step inventory (Duncan, interview 2026-08-11)

The full project sequence as it actually happened — survey to archive, not just report production. This becomes the first `Runbook.xlsx`. Two scope notes: the runbook documents the **whole** lifecycle, but GUI-wrapping (Phase 1–2) prioritises the recurring report-production tools; and where a `tool` row's script lives outside the repo today, migrating it into `scripts/` or `custom/ccpb/` is part of wrapping it (current locations unverified — the wrapping session must find and read each script first). No weighting step was part of this project.

| # | Step | Type | Notes |
|---|------|------|-------|
| 1 | Survey programmed in Alchemer | manual | Done by Jess this wave; future waves may be `ai-assisted` (ASSA precedent: Claude programmed via API) |
| 2 | Customer database received; invalid records excluded | manual | |
| 3 | Telephone-record cleaning | tool | Python script, AI-built; location outside repo, migration candidate |
| 4 | Sample plan drawn | manual | |
| 5 | Telephonic interviewing | manual | Fieldwork |
| 6 | Telephone-log ↔ Alchemer reconciliation | tool | AI-built script; migration candidate |
| 7 | Reconciliation checked | manual | |
| 8 | Backcheck | manual | |
| 9 | Config files created | ai-assisted | AI assisted; Duncan finalises |
| 10 | Comment appendix built | tool | `scripts/build_comment_appendix.py` — the Phase 1 proof case (incl. changed-comment review/apply on re-runs) |
| 11 | Noteworthy comments proposed | ai-assisted | AI marks noteworthy candidates |
| 12 | Noteworthy marks checked and changed | manual | The analyst-review half of step 11 |
| 13 | Ratings history pulled in; 2025 ratings read for significance | tool | Two AI-built scripts reading a manually created pre-Turas history spreadsheet. Known open issue: 2025 means stored at 1dp can flip a Welch significance call — sidecar rebuild still open |
| 14 | Crosstab config run in launch_turas | module | Tabs → crosstabs xlsx, report + reader HTML, data JSON, stats pack |
| 15 | Commentary added through the Turas report | manual | Analyst-written text — not AI-generated |
| 16 | PPT built from last year's deck as template | manual + ai-assisted | AI redid slides on demand (mechanics only — slide text was Duncan's own, confirmed 2026-08-11). Policy note: slide *text* stays analyst-written or express-tagged — rule 3 applies to decks too |
| 17 | Results presented | manual | |
| 18 | Folder cleaned and archived | ai-assisted | Post-project housekeeping; no deliverable involved |

## 6. Decisions

Decided by Duncan, interview of 2026-08-11:

(b) **Runbook format: xlsx.** One `Runbook.xlsx` per project folder, sheet `Steps` + `Provenance` block (§3.2).

(c) **Custom-view location: repo `custom/<client>/`**, with the delete-or-promote lifecycle rule (§3.4).

(d) **AI-assisted vs AI-written text:** runbook type `ai-assisted` exists; AI-assisted verbatim analysis allowed, checked by Duncan, **Max terms by default** (API only when a client requires the contractual tier; off if prohibited). AI-*written* deliverable text prohibited outside the express-tag pattern (policy rules 3–4).

(e) **Synthetic data-layer fixture: yes** — Phase 3 deliverable; real data layer is read-only reference only (§3.4).

(f) **Provenance recorded in the runbook** (§3.2).

(a) **Step inventory: complete** — §5 holds the full CCPB W2026 sequence from Duncan's walkthrough (2026-08-11). Phase 2 turns it into the first `Runbook.xlsx`.

Phase 0 is therefore done; Phase 1 can start.

## 7. Facts verified this session (for the implementing session)

- `scripts/build_comment_appendix.py` + tests + README are **on main** (commits `bae05002`, `dfa08955`; `git branch --contains` includes main).
- `launch_turas.R` (952 lines) holds a data-driven `modules` list; each entry points at a `run_*_gui.R`; icons are inline SVG in the same file; TURAS_ROOT resolution and `.env` loading happen at the top of `launch_turas()`.
- CCPB W2026 output folder contains report HTML, reader HTML, `_data.json`, `_wave.json`, stats pack, crosstab xlsx, two PPTX decks, an exec-summary docx.
- `/usr/bin/python3` is 3.9.6 with openpyxl 3.1.5 and pandas 2.3.3 **on Duncan's machine**; the appendix script imports both.
- `docs/Turas_AI_Compliance_Guideline.docx` (16 July 2026) already states: analysis runs locally with no AI at runtime; AI-insights is the sole, disclosed AI-at-runtime path; the repo holds code and synthetic data only.
