# Qualitative Tab — Phase 1 Build Notes & Architecture Decisions

**Companion to** `QUALITATIVE_TAB_PLAN.md` (the spec). **Date:** 2026-06-29 ·
**Branch:** `feature/tabs-qualitative-tab`.

This note records (A) what the four real coded workbooks actually look like, (B) the
column-classification algorithm the adapter uses, (C) the architecture decision taken
with Duncan on 2026-06-29, and (D) the confidentiality model — which gained a **third
dial** in that conversation. It is the build contract for Phase 1; the spec is the why,
this is the how.

> The four workbooks live in `prototypes/qual/*.xlsx`. They are caught by the
> `*.xlsx` rule in `.gitignore` (only `templates/**` is re-included), so they are
> **never committed** — they carry real verbatims. Build against them locally; ship
> only synthetic fixtures in the test suite.

---

## A. Real-workbook structural matrix (verified by direct inspection, 2026-06-29)

| Workbook | Sheets | Themed/Raw | Demographics | Header row | Sentiment | Noteworthy | Notable quirks |
|---|---|---|---|---|---|---|---|
| **SACS** (staff) | 6 | all themed | none (anonymous) | floats (e.g. r5) | Overall-Sentiment col {1,2,3}; legend in summary block (1=Positive skew / 2=Mixed sentiment / 3=Negative skew) | `"Yes"` | verbatim column header **is** the question text; summary block on the **left**; `"total mentioss"` typo (in the ignored block); header whitespace on themes |
| **SACAP Student** | 23 (+`Contents`) | mixed | Campus, Course, Year, Intensity, NPS (+ per-Q cuts: Rating, Registration category/rating) | floats (r2/r3/r5) | Overall-Sentiment col, but **sometimes mislabelled `"Theme"`** | `"x"` | `Contents` sheet drives order + flags Themed Y/blank; summary block on the **right**; raw sheets = demographics+Rating+Comment+Noteworthy |
| **CCPB** (trade) | 38 | mixed | Centre, Channel, Size, Sales method, Interview language, Distributor | floats (r1/r3) | per-mention valence on theme cells; no separate sentiment col on themed sheets | `"x"` | **irregular split-by-cut**: NPS Promoter/Passive/Detractor are 3 sheets with **different follow-up questions and different theme frames**; Detractor is raw; Distributor degenerate (always `CCPB`); `Rating` 1–5 on `Overall`; question wording in rows above header |
| **Helderberg** (residents) | 14 | all raw | Segment/Persona, NPS category, Status (+ Rating) | r0 or r1 | none (raw) | **none** | **no Noteworthy column at all**; `"-"` = missing demographic; Rating 0–10; one sheet renames `Segment` → `Persona run 3` (intra-workbook column drift) |

**Invariants that drive the design:**
- The header row position is **not fixed** — detect it, never offset to it.
- Column names drift (whitespace, `"Theme"` for sentiment, `Segment`/`Persona run 3`),
  so classify by **name-regex + value-type sampling + position relative to the
  verbatim**, never by absolute column index.
- Noteworthy, Overall-Sentiment and Rating are all **optional**.
- The 5-ish-row preamble (question wording + a derivable summary block) sits above the
  header; ignore the summary for data, but mine it for the sentiment **legend** (tooltip
  labels) when present.

---

## B. Column-classification algorithm (per worksheet → one question)

The adapter operates on an already-read sheet (a list/matrix of rows), so the pure
classification + normalisation is unit-testable with synthetic fixtures (no `.xlsx`
needed in tests). A thin `openxlsx` reader wraps it.

1. **Skip metadata sheets.** A sheet named `/^contents$/i` (or with no ID-anchored
   header) is metadata: use it for triage order + themed/raw hints, do not render it as
   a question.
2. **Find the header row** `H` = first row whose first non-blank cell matches
   `/^(response\s*)?id$/i`. Rows above `H` = preamble; rows below = data.
3. **Title.** Last non-blank preamble line in col A (the open-end prompt) if present;
   else the verbatim column's own header (SACS); else the sheet name. Trim + collapse
   whitespace.
4. **Classify each header column** (name trimmed + whitespace-collapsed):
   - **ID**: `/^(response\s*)?id$/i` — the join key (used internally to union
     respondents across sheets; carried only as the anon index downstream).
   - **Noteworthy**: `/noteworthy/i` — optional; any non-blank cell = noteworthy.
   - **Verbatim**: prefer header `/^(comment|comments|verbatim|response|feedback)$/i`;
     else the column whose **sampled data cells have the largest mean length** (handles
     SACS, where the verbatim header is the question text). Exactly one.
   - **Rating**: `/rating/i` — numeric closed cut (range varies 1–5, 0–10); kept as a
     cut + per-record value.
   - **Overall sentiment**: a column named `/overall\s*sentiment|^sentiment$|^theme$/i`
     **whose non-blank values ⊆ {1,2,3}** (the `^theme$` clause catches the Student-NPS
     drift; the value-set test stops a real theme named "Theme" being misread). Logged
     in `meta.label_variants`.
   - **Theme columns**: remaining columns **right of the verbatim** whose non-blank cells
     are all ∈ {1,2,3} (blanks allowed). Header = theme label.
   - **Demographic / cut columns**: remaining named columns **left of the verbatim**
     (excluding ID), string/category values. Become banner dimensions. `"-"`/`""` =
     missing.
5. **Question type:** `themed` if ≥1 theme column, else `raw` (VERBATIM-ONLY). Stamped
   at ingest; the runtime never re-infers (spec §6).
6. **Per-record extraction** (rows below `H`; skip rows blank in both ID and verbatim):
   `id`, `text` (exact), `noteworthy` (bool, marker-agnostic), `sentiment` (1|2|3|null),
   `rating` (num|null), `themeVals` ({label: 1|2|3}), and the demographic values.
7. **Normalisation:** numeric {1,2,3} → canonical pos/neu/neg, original label kept as
   tooltip; any non-blank Noteworthy → true; trim headers + demographic values; `"-"` →
   missing; **stray theme/sentiment codes (e.g. a rogue `11`) → quarantine**: count in
   `meta.dropped_codes`, never coerce, never silently drop.

---

## C. Architecture decision — self-contained first → join eventual (2026-06-29)

**Duncan's steer:** the comments *are* part of the main survey data, so joining (not
duplicating demographics) is the eventual target; he asked for guidance on sequencing,
and added a requirement to be able to **block demographic association** in sensitive
studies (see D).

**Decision: build Phase 1 self-contained; commit to the join as Phase 2.**

- **Self-contained (Phase 1):** the comment workbook is the data source. Union
  respondents by ID across its sheets → one respondent master; the embedded demographic
  columns → banner (single-choice questions); each themed sheet → a multi-mention
  question; each raw sheet → a verbatim-only question. The anon index = position in the
  union master.
- **Why first:** the adapter (read + classify + normalise + quarantine + scrub) is the
  high-risk core and is **identical in both models**. Self-contained validates the whole
  spine end-to-end against the four real workbooks today, with **no external
  dependency**. The join needs a matching main-survey crosstab project (data + config
  with aligning IDs), which we don't have in-repo and which would block all testing.
- **Not throwaway:** `DATA_QUAL`, the theme→`AGG`/`MICRO` serialisation, the JS tab and
  every confidentiality gate are byte-identical across models. **The join swaps exactly
  one seam** — where the banner columns + respondent index come from. Build that seam as
  one isolated function (`qual_resolve_banner_and_index()` or similar) so Phase 2 adds a
  code path, not a rewrite. The "don't duplicate demographics" payoff lands at the join;
  the self-contained path then survives as the standalone qual-only-report fallback.

**Split-by-cut (CCPB NPS):** Phase 1 ingests each sheet as an independent question (NPS
bands stay separate). Reassembly into one question with the band as a banner dimension is
**Phase 2** (spec §14), and CCPB's trio is *irregular* (different question + frame per
band) — so reassembly is auto-with-override and must not force-merge incompatible frames.

---

## D. Confidentiality — three orthogonal dials

Spec §10 had two; Duncan added a third on 2026-06-29. All three are independent config
switches read by the R inliner, with runtime state scoped per report via `d2.storeKey`.

1. **Tab visibility** (§10a) — `show_qualitative` (+ the generic `show_*` family).
   Whole-tab on/off; also self-hides when `DATA_QUAL` is null (Tracking pattern).
2. **Verbatim text level** (§10b) — `qual_confidentiality_mode ∈ {hidden, redacted,
   full}`, **default `hidden`**. HIDDEN ships numbers only (text nulled in the island);
   REDACTED ships rule-scrubbed text (logged diff); FULL ships exact text. PII scrub runs
   **at ingest**, before any string enters the island.
3. **Demographic association** (§10c, NEW) — `qual_demographic_cuts ∈ {allow, block}`,
   **default `allow`** (cuts are the core analytical value); room to go per-demographic
   later. When `block`: the qual tab renders **Total-only** — prevalence, sentiment and
   verbatims still show, but no banner columns, no demographic chips on quote cards, no
   "which group over-mentions" standout — and the island records carry no demographic
   fields. The control to stop "the only X in dept Y" being triangulable.

**Composition:** with text HIDDEN (default) nothing is re-identifiable regardless of
dial 3; demographic-blocking is the extra guard for when REDACTED/FULL text *is* shipped.
A small/anonymous study (SACS staff) would set `qual_confidentiality_mode` up to redacted
**and** `qual_demographic_cuts = block`.

---

## D2. Noteworthy tiers (triage, not confidentiality — Duncan 2026-06-29)

The noteworthy flag is a **tier**, not a boolean: `2 = must-read`, `1 = noteworthy`,
`0 = other`. The reader captures the raw marker and derives the tier
(`qual_noteworthy_tier`); the boolean `noteworthy` stays as `tier >= 1` for back-compat.
Marker-agnostic + case-insensitive, so today's binary markers ("Yes"/"x") read as tier 1
and a coder's "Must read" reads as tier 2 — the must-read tier is dormant until a workbook
uses a stronger marker. The must-read marker set is `QUAL_MUSTREAD_MARKERS` (a config hook
for studies with custom markers).

The tier rides per record in `DATA_QUAL`. The JS quote drawer + browser get a tier filter
(**All / Noteworthy+ / Must-read**) whose initial state is `qual_noteworthy_default ∈
{all, noteworthy, must_read}` (report-level), and the noteworthy spotlight reel leads with
must-read. This is the "show noteworthy-only, or switch noteworthy vs all" control.

---

## D3. Phase 2 — integrated join + closed↔open jump (Duncan 2026-06-29)

Decision: the qual content moves from a separate `*_qual_report.html` into the **one** main
v2 report (Turas report = the full deliverable, replacing the deck). That means the **join**:
the comment workbook's respondents join to the main survey by `ResponseID`, so a comment and
a closed answer from the same person share the anonymous MICRO index and the main banner. This
is the `qual_assemble.R` seam — only the index/banner source swaps (union-by-workbook →
match-against-survey); the DATA_QUAL schema, theme serialisation and the tab are unchanged.

**Config contract (Selection sheet — two optional columns on the OPEN-END's row):**
- `CommentSheet` — the comment-workbook sheet that codes this open-end (sheets are topic-named,
  so the pipeline can't infer it). Open-ends are already Selection rows (`Include = N`).
- `CommentLink` — the closed question or **composite** this diagnostic open-end explains;
  blank = generic/standalone. The resolver looks the target up across closed questions AND
  composites (composites live in Survey_Structure and render on the Dashboard — they do NOT
  need moving to Selection; the resolver is composite-aware).

**Worked example (SACS-2025_Crosstab_Config_rebuilt.xlsx; join key confirmed = ResponseID):**

| Open-end (Include=N) | CommentSheet | CommentLink |
|---|---|---|
| Q17 | Engagement | Q_Engage (composite) |
| Q24 | Values | Q_Values (composite) |
| Q26 | Misalignment | Q25 |
| Q27 | Culture | *(generic)* |
| Q29 | Satisfaction | Q28 |
| Q30 | Engagement Other | *(generic)* |

**The jump.** On the linked closed/composite's card (Dashboard for composites, Crosstabs for
Q25/Q28) a "💬 N comments" affordance appears. Clicking it switches to the qual view, selects
the linked open-end, and applies the current cut as a filter (`stats.mask` of the active
column/cell → keep comment records whose idx is in the mask) — i.e. "the comments from the
people in this cell," the diagnostic *why* behind the score. A breadcrumb + back restores the
closed question and column (URL-hash state, so browser-back works too). Generic opens (no
`CommentLink`) just live in the Qualitative tab standalone.

**Plus:** save/shortlist comments (reuse the Story/Save-copy pin path → survives Save copy);
export comments to Excel (client-side via the bundled xlsx writer; honours the confidentiality
mode + current filter/saved set).

**Methodology note:** since it's now client-facing, reframe prevalence as *salience* ("raised
this"), soften the theme×cut significance, and let the verbatims lead — the jump reframes the
whole thing around the closed finding, which is the methodologically right shape (open-end
mentions are salience, not incidence).

> TEMPLATE GOTCHA: `Crosstab_Config_Template.xlsx` has an embedded drawing and does NOT survive
> an openxlsx load→save round-trip (it breaks the drawing ref and corrupts the file — reverted).
> History (092c3e44) added Category/CategoryOrder by editing the binary directly in Excel.
> The generator (`generate_config_templates.R`) is the cleaner source but had drifted (lacked
> Category/CategoryOrder); `CommentSheet`/`CommentLink` are now added to it. To refresh the live
> template, add the two headers in Excel (cols M/N) or do a careful generator-resync + fresh
> regenerate — never an openxlsx round-trip of the existing file.

### D3.1 — Phase-2 AS-BUILT (the join; one deliberate divergence from the plan above)

**The join (DONE, tested — `test_qual_join.R`, 28 assertions).** When `qual_workbook` is set,
the comments are joined into the ONE main v2 report by ResponseID and ride in as the `qual_json`
of the *main* `write_html_report_v2` call (see `run_crosstabs.R` html_report_v2 block). The seam:

- `qual_resolve_against_survey(questions, survey_data, id_col)` (`qual_assemble.R`) keeps the
  workbook's embedded demographics (so a Student workbook keeps its Campus/Course/NPS facets)
  but **re-keys the anonymous index to the host survey's MICRO rows** (`id_to_idx` = workbook
  ResponseID → host 0-based row, `n` = `nrow(survey_data)`). The host id column auto-detects via
  the `^(response )?id$` anchor; `qual_join_id_column` (new config key) overrides it. Commenters
  with no host row resolve to NA and are dropped (the island builder already skipped NA — this is
  why that guard was there).
- `build_integrated_qual_island(qual_workbook, config_obj, survey_data)` (`qual_report.R`) reads
  + classifies + joins + builds the island, returning `status ∈ {PASS, NO_ID_COLUMN, NO_MATCHES}`.
  On non-PASS the wiring falls back to the standalone `*_qual_report.html` (so nothing regresses);
  a join failure never touches the Excel/HTML/v2 outputs.
- Because the island shares the main MICRO index, `stats.mask(filters)` (a `Uint8Array` over the
  host respondents) is directly usable as the closed→open jump filter: keep DATA_QUAL records
  whose `idx` has `mask[idx] === 1`. That's the next task.

**DIVERGENCE (deliberate): the synthetic theme questions are NOT merged into the main `dl`/`micro`.**
The plan above said "merge theme Qs + DATA_QUAL into the main dl/micro." But the Crosstabs tab
renders **every** `TR.AGG.questions` with no filter (`25_cards.js` sidebarHtml / `20_data.js`
d2.categories), and the qual tab's prevalence board computes **from the DATA_QUAL records directly**
(`27q_qualitative.js` `qual.prevalence`), not from a dl AGG question. So merging the synthetic
theme questions would dump raw theme×banner questions into the **client-facing** Crosstabs list —
which fights the very reframe this phase is about ("soften the theme×cut significance, let the
verbatims lead"). The integrated path therefore ships the verbatim/record island only; this also
lifts the standalone path's "needs themes" restriction (a verbatim-only workbook can now integrate).
The theme×banner **significance** crosstab (render via `model.forQuestion`) remains a separate,
not-yet-built TODO; if it's ever wanted in the integrated report, run the qual quant layer against
the *host* banner and append under a dedicated tab/section flag — do NOT let it leak into Crosstabs.

## E. Phase-1 file plan

**R (new, `modules/tabs/lib/` convention):**
- `qual_workbook_reader.R` — pure column-classification + normalisation + per-record
  extraction (operates on in-memory sheet rows; TRS-compliant; testable without xlsx) +
  a thin `openxlsx` reader wrapper.
- `qual_island_builder.R` — assemble the self-contained respondent master + banner +
  theme/raw questions; emit the `DATA_QUAL` island (§11 schema), apply the three
  confidentiality dials; isolate the banner/index seam for the future join.
- Serialise theme questions into `DATA_AGG`/`DATA_MICRO` via the existing
  `process_standard_question()` path (synthetic `Multi_Mention` question) — **verify the
  significance is genuinely correct, not just present.**

**JS (new):** `27q_qualitative.js` defining `TR.qual.render(host)` (auto-bundled by
filename) — prevalence board, theme×banner crosstab (`model.forQuestion`), quote drawer
(reusing `stats.mask` for click-to-evidence), raw browser. Tab registered in `tabList()`
+ `shell.route()` (`24_shell.js`), island parsed in `shell.boot`.

**Config:** Settings keys `qual_workbook` (path), `show_qualitative`,
`qual_confidentiality_mode`, `qual_demographic_cuts`, `qual_noteworthy_default`
({all, noteworthy, must_read}) — added to `build_config_object()` and attached to `proj`
in `build_dl_project()`.

**As-built so far (commits on `feature/tabs-qualitative-tab`):** `qual_workbook_reader.R`
+ `qual_workbook_io.R` (reader subsystem, task 1), `qual_assemble.R` (respondent master +
banner curation = the join seam, task 2), `qual_island_builder.R` (DATA_QUAL + the verbatim
confidentiality dial + noteworthy tiers, task 2), `qual_quant_layer.R` (theme→AGG/MICRO via
the existing engine, task 3), `qual_report.R` + the pipeline wiring (DATA_QUAL island in
`build_report_v2.R`/`template.html`, the `qual_*`/`show_*` config keys → `project$tabs`, and
the additive `run_crosstabs.R` hook that emits a `*_qual_report.html`, task 4). ~158 test
assertions green; all verified against the four real workbooks + a significance known-answer +
an end-to-end report build (HIDDEN ships zero raw text, FULL ships it). **The whole R backend +
wiring is done — the comment report builds.** Remaining: the JS Qualitative tab (task 5), which
is what makes the dedicated tab appear (until then the report builds with the themes as ordinary
Crosstabs questions + the DATA_QUAL island present).

NOTE: the vendored `assets/template.html` was caught by the blanket `*.html` gitignore and never
tracked; a `.gitignore` exception now tracks it (precedent: `!modules/hub_app/app/index.html`),
and the tracked prototype source (`prototypes/report-redesign/fable/v2/src/template.html`) carries
the same `{{DATA_QUAL}}` placeholder.

**Task 3 quant-layer notes (`qual_quant_layer.R`):** each themed question becomes a synthetic
`Multi_Mention` question (one option per theme; a respondent's mentioned theme labels left-
packed into `code_1..code_k` slot columns), the embedded demographics become a real banner via
`create_banner_structure`, and it all runs through `process_all_questions` → `build_data_layer`
→ `build_microdata`. Significance is byte-identical to a closed question — nothing theme-aware
touches the stats. A `QUAL_NO_THEME_SENTINEL` seats zero-theme commenters into the base so theme
prevalence reads "% of commenters". `demographic_cuts="block"` → Total-only banner. The standalone
test bootstraps the chain by cd-ing into `lib/` and extracting `run_crosstabs.R`'s sig functions
by source-line (it has an unguarded main), mirroring `test_e2e_integration.R`. Per-mention
sentiment stays in `DATA_QUAL.records.themeVals` (not MICRO) for Phase 1; the JS joins it to
the banner by anon index — add `micro$sentiments[[qcode]]` later only if live-filtered sentiment
recompute is needed.

**Island wiring:** `{{DATA_QUAL}}` placeholder in `template.html`; token replace in
`build_report_v2.R` (`null` when no open-ends or HIDDEN strips text), mirroring the
Tracking null-island.

**Tests/fixtures (synthetic, shippable):** workbook ingest (themed + raw + the §A
quirks), header-row detection, label/marker normalisation, stray-code quarantine,
theme-row serialisation into AGG/MICRO (with a sig known-answer), quote-ID existence
check, the three confidentiality dials.

> Validate the spine on **SACS or Student** (smaller bases) before CCPB's 38 sheets.
> Duncan does the real-report visual validation via `launch_turas`, not headless.
