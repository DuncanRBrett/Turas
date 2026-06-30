# Qualitative Tab — Phase 2 Handover (integrated join + closed↔open jump)

> **✅ PHASE 2 BUILT + REVIEWED (2026-06-29/30) — done + tested, on
> `feature/tabs-qualitative-tab` (15 session commits `16914b42`→`ed65e120`, 37 ahead of `main`,
> NOT pushed/merged).** Round-1 = the five items below; round-2 = Duncan's review of the live
> SACS/SACAP report (sentiment filter, highlighter, the theme chart redesign, a CommentLink
> warning). As-built detail: `QUALITATIVE_TAB_BUILD_NOTES.md` §D3.1–**§D3.5**.
>
> **ROUND-2 (newest, §D3.5):** sentiment filter (list, not chart) · controls moved above the
> comment list under "Filter the comments below:" (the perception fix) · **select-to-highlight** a
> passage (persists, survives Save copy) · `CommentLink` target validation (warns on a typo — caught
> SACS `Q_Values` vs the real composite `Q_Value`, Duncan fixed it) · **the theme chart is now a
> 100% diverging sentiment bar** (every theme equal width, pivots on a shared zero; bar = sentiment
> MIX not volume; volume = the salience % + n + rank). ROOT-CAUSE LESSON: never size these bars by
> volume — one dominant theme compresses the rest into slivers. Tests: `qual_tests.mjs` 47,
> `test_qual_join.R` 44, bundler 25 — green.
>
> **WHAT THE NEXT SESSION DOES:** Phase 2 is feature-complete. Remaining = (a) Duncan regenerates via
> `launch_turas` + eyeballs the new chart on the real SACS/SACAP report; (b) confirm the Satisfaction
> 💬 shows on the **Q28 Crosstabs card** (it's a closed Likert, wired correctly — not on the Dashboard
> like the Q_Engage/Q_Value composites); (c) the **push/merge decision** for the branch; (d) optional
> follow-ups — per-banner-COLUMN jump granularity, the theme×banner sig crosstab render, exporting the
> highlighted excerpt as its own column, and the option to let the noteworthy tier reshape the chart.
>
> **Round-1 summary (the five items):** As-built detail in §D3.1–§D3.4.
> 1. **Join** — `qual_resolve_against_survey` re-keys DATA_QUAL to the host MICRO index by
>    ResponseID (auto-detected / `qual_join_id_column`); `build_integrated_qual_island` rides
>    it into the **main** report as `qual_json`; standalone `*_qual_report.html` is now a
>    fallback. (`test_qual_join.R`, 39 assertions.)
> 2. **Links** — `CommentSheet`/`CommentLink` → `project.qualLinks` (composite-agnostic in R).
> 3. **Jump** — "💬 N comments" on the linked Crosstabs/Dashboard card → the qual tab, focused +
>    filtered to the active cut (`stats.mask`); breadcrumb + browser-back via hash.
> 4. **Shortlist + Excel export** — ★ per comment (survives Save copy) + ⬇ export the visible set
>    (confidentiality honoured). (`qual_tests.mjs`, 33 assertions.)
> 5. **Salience reframe** — board reads "What people raised" (unprompted salience, not incidence).
>
> **ONE DELIBERATE DIVERGENCE** from the plan below: the synthetic theme questions are NOT merged
> into the main `dl`/`micro` (Crosstabs renders every AGG question unfiltered + prevalence computes
> from records, so merging would pollute the client-facing Crosstabs list and fight the reframe).
> Rationale in §D3.1. The theme×banner **sig crosstab** stays a deferred TODO.
>
> **DUNCAN — to light it up on the real SACS/Student config (then regen via `launch_turas`):**
> the live config's **Selection sheet** needs `CommentSheet`/`CommentLink` filled on the open-end
> (Include=N) rows per the locked mapping below, the survey **data must carry a ResponseID column**
> matching the comment workbook, and `qual_workbook` set (SACS already has it). SACS has no embedded
> comment-demographics, so its qual facet dropdowns will be empty — the cut comes from the jump.
>
> The original Phase-2 build brief follows (kept for context).

---

**Date:** 2026-06-29 · **Branch:** `feature/tabs-qualitative-tab` (20 commits since main
`0093d7b0`, **NOT pushed/merged**) · **Start here for the Phase-2 build.**

Read alongside: `QUALITATIVE_TAB_PLAN.md` (the spec), `QUALITATIVE_TAB_BUILD_NOTES.md`
(as-built + the Phase-2 contract in §D3 — the SACS worked mapping is there).

---

## 1. What's DONE (Phase 1 + two feedback rounds) — all on the branch, tested

A self-contained comment report builds end-to-end and renders. Pipeline:
`qual_workbook` (Settings) → reader → respondent master + curated banner → themes
serialised into `DATA_AGG`/`DATA_MICRO` via the **existing** crosstab engine (sig is
byte-identical to a closed question, zero new stats) → `DATA_QUAL` verbatim island →
`*_qual_report.html`, additive (a qual failure never touches the main outputs).

Files (all `modules/tabs/lib/`): `qual_workbook_reader.R`, `qual_workbook_io.R`,
`qual_assemble.R` (respondent master + banner = **the join seam**), `qual_island_builder.R`
(DATA_QUAL + 3 confidentiality dials + noteworthy tiers + per-record demographics),
`qual_quant_layer.R` (theme→AGG/MICRO), `qual_report.R` (`build_qual_report_v2`, + project-
relative `qual_workbook` resolution). JS: `27q_qualitative.js` (rail with collapsible
themed/raw groups + show/hide toggle; theme prevalence board; demographic facet dropdowns
that AND together; quote drawer; noteworthy-tier filter; confidentiality honoured). Wiring:
`DATA_QUAL` island in `build_report_v2.R`/`template.html`; `qual_*`/`show_*` config keys →
`project$tabs`; `tabList()` generic visibility filter; `run_crosstabs.R` sources the qual
files + an additive hook.

Tests green: reader 69 + io 17 + assemble 16 + island 35 + quant 16 + report 12 (R) +
`qual_tests.mjs` 11 (JS) + bundler 25. Verified on the real SACS and SACAP Student workbooks.
Duncan ran it in `launch_turas` — "looking good"; rounds 1–2 of his feedback are in.

---

## 2. What Phase 2 IS (Duncan's direction, 2026-06-29)

**The Turas report becomes the full deliverable (replacing the deck), so the comments move
INTO the one main v2 report — not a separate file.** Concretely:

1. **The JOIN.** Comment respondents join to the main survey by **`ResponseID`** (Duncan
   confirmed the ID is the same in both data + comment workbook), so a comment and a closed
   answer from the same person share the anonymous MICRO index and the **main** banner. This
   is the `qual_assemble.R` seam: swap union-by-workbook → match-against-survey. Then the
   theme questions + `DATA_QUAL` ride in the **main** report's data layer (built inside
   `run_crosstabs.R`'s `html_report_v2` block, alongside the main `dl`/`micro`), and
   `write_html_report_v2` gets the `qual_json` for the main report (not a separate file).

2. **The closed↔open JUMP.** Config contract = two optional columns on the **open-end's**
   Selection row (open-ends are already `Include = N` rows): `CommentSheet` (which comment-
   workbook sheet codes it) + `CommentLink` (the closed question/composite it explains; blank
   = generic). Resolver is **composite-aware** (targets live in Survey_Structure / render on
   the Dashboard — do NOT move them to Selection). On the linked closed/composite's card a
   "💬 N comments" affordance jumps to the qual view, selects the linked open-end, and applies
   the current cut as a filter (`stats.mask` of the active column/cell → keep records whose
   idx ∈ mask = "the comments from the people in this cell" = the diagnostic *why*). Breadcrumb
   + back restores the closed question/column (URL-hash state → browser-back works). Generic
   opens (no `CommentLink`) stay standalone in the Qualitative tab.

   **SACS mapping (locked, from `SACS-2025_Crosstab_Config_rebuilt.xlsx`):**
   Q17→Engagement→Q_Engage · Q24→Values→Q_Values · Q26→Misalignment→Q25 ·
   Q27→Culture→(generic) · Q29→Satisfaction→Q28 · Q30→Engagement Other→(generic).

3. **Save / shortlist comments** — reuse the Story / Save-copy pin path (`30_story.js` +
   the saved-copy island + `userState`) so a starred set survives "Save copy".

4. **Export comments to Excel** — client-side via the bundled xlsx writer (engine has
   `13_zip.js`; prototype had `23y_xlsx.js`); columns idx + demographics + theme + sentiment +
   verbatim; honour the confidentiality mode (don't export hidden text) + current filter/saved set.

5. **Methodology reframe (do this too — it's now client-facing):** present prevalence as
   **salience** ("raised this"), soften the theme×cut significance, let the verbatims lead.
   The jump reframes everything around the closed finding, which is the right shape — open-end
   mentions are salience, not incidence (Duncan's own quant-analysis standard).

---

## 3. Suggested build sequence

1. **Join** — in `qual_assemble.R`, add a `qual_resolve_against_survey(questions, survey_data,
   id_col = "ResponseID")` path returning the master keyed to the survey's MICRO index + the
   MAIN banner (vs the embedded-demographics path). Then in `run_crosstabs.R` html_report_v2
   block, when `qual_workbook` set, build the qual theme questions + `DATA_QUAL` joined to the
   main survey and **merge into the main `dl`/`micro`** + pass `qual_json` to the main
   `write_html_report_v2`. Keep the standalone `build_qual_report_v2` as a fallback for a
   comment-only run. Known-answer test the join (sig still correct on the main banner).
2. **Read the columns** — `CommentSheet`/`CommentLink` from the Selection sheet
   (`crosstabs/data_setup.R` or config) → a links structure {openEndCode → {sheet, linksTo}}.
3. **Jump** — emit the links into the data layer (e.g. `project.qualLinks` or per-question);
   JS: a "💬 comments" affordance on the linked closed/composite card (Crosstabs `25_cards.js`
   + Dashboard composite cards), wired to set `d2.state.tab=qualitative` + activeQ + a facet/
   mask from the current column; breadcrumb + back via the hash.
4. **Save** + **Export** — reuse pins/save-copy; add the xlsx export button.
5. **Reframe** the prevalence wording/sig (small JS/copy pass).

---

## 4. Gotchas / how to verify

- **Template binary:** `Crosstab_Config_Template.xlsx` has an embedded drawing and **corrupts
  on an openxlsx load→save round-trip** — never round-trip it. Duncan fixed his template by
  hand (CommentSheet/CommentLink at cols L/M, left of QuestionText). The generator
  (`generate_config_templates.R`) now carries the two columns (placed before QuestionText) but
  still lacks `Category`/`CategoryOrder` (pre-existing drift) — a clean resync+regenerate is a
  separate tidy-up.
- **Standalone-test bootstrap** (for any pipeline-touching test): cd into `lib/`, set
  `.tabs_lib_dir`, extract `run_crosstabs.R`'s sig functions by source-line (unguarded main),
  source the chain — mirror `test_qual_quant_layer.R` / `test_qual_report.R`.
- **vendored `assets/` is the de-facto source** (already diverged from the stale prototype
  `fable/v2/src/` — don't re-vendor/mirror to it). `assets/template.html` is gitignored by the
  blanket `*.html` but kept via an explicit exception.
- **Verify via the node harness + suites; Duncan regenerates the real report via `launch_turas`**
  (it's GENERATED HTML — never `preview_start`). Don't headless-run the pipeline on his OneDrive
  data or overwrite deliverables.
- Real qual workbooks for dev live in `prototypes/qual/*.xlsx` (gitignored). His SACS config:
  `…/SACS/SACS-2025/SACS-2025_Crosstab_Config_rebuilt.xlsx` (qual_workbook + `redacted` already set).
