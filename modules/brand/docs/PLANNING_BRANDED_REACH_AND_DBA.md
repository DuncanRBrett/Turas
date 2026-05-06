# Branded Reach Polish + DBA Modernisation — Project Plan

**Author:** Duncan Brett (planning) + Claude (drafting)
**Date:** 2026-05-06
**Branch:** `feature/branded-reach-and-dba`
**Status:** EXECUTED — ready for browser verification + PR sign-off

---

## Execution log (2026-05-06)

| Step | Commit | Outcome |
|------|--------|---------|
| Pre-flight baseline | — | HTML + 1653/1651/0/2 tests captured at `~/.turas-baselines/IPK_pre_BR_DBA_branch/` |
| Branch + plan | 735e192 | `feature/branded-reach-and-dba` created from main |
| Fixture script | 9637f1c | `BR_DBA_test/{placeholder,populated}/` builder + readme |
| Commit 1 — DBA panel files | b70d9bf | 7 new files (~1030 active lines), all source clean, smoke-tested |
| Commit 2 — Wire + remove legacy | 6a0d108c | Modern panel renders; legacy chart+table fully removed |
| Commit 3 — BR polish | 9114568d | Insight strip + SVG image fallback + (focal highlighting unchanged — was already correct) |
| Commit 4 — BR pin/PNG | DROPPED | Already implemented at `.br_reach_card_toolbar` |
| Commit 5 — Test coverage | 5fbcae20 | +86 tests (58 DBA panel + 28 BR polish). Caught + fixed a vectorisation bug in `.br_worst_misattribution`. |
| Commit 6 — Docs | (this commit) | README + planning doc cross-references |

**Final test counts:** 1739 total / 1737 pass / 0 fail / 2 skip (was 1653/1651/0/2). Net +86 tests, no regressions.

**Canonical IPK regression:** confirmed at multiple points — no HTML elements emitted for DBA or BR (both flags remain N for IPK), only ~5KB of CSS bytes added to the bundled stylesheet (matches the convention every other panel follows).

**What's left before merge:**
1. Browser verification in `launch_turas()` against `BR_DBA_test/placeholder/` and `BR_DBA_test/populated/`.
2. Final IPK regression run via `launch_turas()` against the canonical config — confirm no visible change to existing IPK report output.

---

> ## ⚠️ Hard Constraint — IPK Project Must Not Be Impacted
>
> Duncan is actively using the brand module on the live IPK project. This
> work must **not** affect any aspect of the current IPK report rendering.
> Specifically:
>
> - The canonical synthetic files at
>   `OneDrive/.../IPK/Tabs/synthetic/8822527_*.xlsx` are **READ-ONLY**.
> - Every commit must be verified against the canonical IPK config to
>   confirm no regression in any existing element (Funnel, Cat Buying,
>   MA, Portfolio, Demographics, Ad Hoc, WOM, Branded Reach Phase-1
>   output, current DBA output).
> - A pre-flight baseline (HTML + screenshots) of the current IPK report
>   is captured **before any code change** and compared against after
>   every commit.
> - If at any point the IPK report's non-DBA, non-BR sections change in
>   any way, the change is treated as a regression and reverted.
> - The DBA section may change appearance (legacy → modern panel). It
>   may not lose any information that the legacy path currently shows.

---

## 1. Problem Statement

Two of the brand module's three Romaniuk-grounded asset elements are present
in code but not at production grade. Branded Reach (per-category) shipped as a
Phase-1 skeleton, has a working HTML panel, but was never polished or
browser-verified end-to-end. Distinctive Brand Assets (DBA, per-brand) has a
solid engine but renders through the **legacy chart+table path** — the same
pattern used before per-element modular panels existed — so it does not match
the visual or interaction quality of Cat Buying, MA Focal View, Portfolio, or
Demographics.

The opportunity is to bring both elements to the same standard already set by
the rest of the module, so that when an IPK-style project does collect
Marketing Reach data and DBA batteries, the report surfaces them with the
clarity, callouts, pin/PNG export, and visual coherence Duncan has set as the
brand-module bar. For IPK Wave 1 specifically, both elements run as
"Data not yet collected" placeholders — the work future-proofs the platform
without requiring the Wave 1 questionnaire to change.

---

## 2. Landscape & Approach

### What already exists

| Layer                          | Branded Reach                          | DBA                                      |
|--------------------------------|----------------------------------------|------------------------------------------|
| Engine                         | ✅ `10_branded_reach.R` + 4 helpers    | ✅ `07_dba.R` (project-level)            |
| v2 entry / placeholder pattern | ✅ `BR_PLACEHOLDER_NOTE`               | ✅ `DBA_PLACEHOLDER_NOTE`                |
| Tests                          | ⚠️ 137 lines (light)                   | ⚠️ 158 lines (light)                     |
| Modern HTML panel              | ✅ `10_branded_reach_panel.R` (Phase 1)| ❌ legacy chart+table only               |
| Page-builder wiring            | ✅ in `build_br_category_panel`        | ⚠️ legacy block at `03_page_builder.R:1083` |
| Pin/PNG export                 | ❓ unverified                          | ❌ no panel root → no pin                |
| Browser-verified               | ❌ deferred                            | ❌ never                                 |
| IPK config                     | ❌ flag missing in 3cat                | ✅ `element_dba` present                 |
| Survey-structure templates     | ✅ MarketingReach + ReachMedia in 9cat | ✅ DBA_Assets sheet in 3cat              |

### Approach options considered

**Branded Reach**

- *Option A (chosen): polish-only* — finish Phase 1 to production grade; defer
  Phase 2 enhancements (overlap analysis, brand-asset-on-ad heatmap, etc.).
- Option B: build Phase 2 features now. Rejected — premature; let real reach
  data dictate what's needed.
- Option C: rebuild the panel from scratch under a new structure. Rejected —
  Phase 1 is sound and tracks the WOM panel pattern.

**DBA**

- Option A: keep legacy chart+table, just polish CSS. Rejected — does not meet
  the bar set by other modern panels; no pin/PNG; no insight box; not
  composable.
- *Option B (chosen): modernise to two-sub-tab panel* — Quadrant view +
  Asset detail with images and CIs. Matches MA Focal View / Portfolio polish
  bar without over-extending.
- Option C: full Romaniuk competitive treatment (which competitor's DBAs
  outscore yours in this category). Rejected — out of scope; revisit if a
  client asks for it.

### Decisions confirmed by Duncan (2026-05-06)

1. Branded Reach: polish Phase 1 to production grade; no Phase 2 features.
2. DBA panel: Option B (two sub-tabs, asset images + CIs).
3. DBA scoping: per brand (one section in the report for the focal brand's
   DBAs). Engine stays project-level.
4. IPK config: enable both elements as placeholders so "Data not yet
   collected" cards appear in the Wave-1 report.
5. Branch: one feature branch covering both elements.

### Tools & resources reused

- TurasPins library (pin/PNG capture across iframes — see
  `feedback_turas_pins_inliner_defaults` memory; portable CSS rules required).
- Brand module CSS conventions (dark-navy tables, focal-brand highlighting,
  cream accent colour from `polish/brand-colour-consistency`).
- Existing JSON-payload + JS re-render pattern (see
  `reference_brand_portfolio_patterns` memory and Cat Buying / MA /
  Portfolio precedents).
- Insight-box pattern from MA Focal View and Portfolio.
- Existing `build_scatter` chart helper for Quadrant view (already used by
  the legacy DBA path) — replace with a Quadrant-specific Romaniuk variant.

---

## 3. Objectives

### Branded Reach

**Must-have (production-grade Phase 1):**

1. Insight-box callouts generated from per-ad metrics (best-branded ad,
   worst misattribution, dominant media channel, focal-brand reach gap).
2. Pin + PNG export per card via TurasPins, verified in launch_turas browser
   session.
3. Focal-brand row visually highlighted in misattribution table (same dark
   navy / cream treatment as Portfolio).
4. Image fallback when `ImagePath` is missing (placeholder graphic + asset
   code).
5. Empty-state for a category with `element_branded_reach = Y` but no ads
   in scope (clear "no assets in this category" card, distinct from
   placeholder-mode).
6. Test coverage expanded: known-answer tests for `compute_br_reach_metrics`,
   `compute_br_misattribution`, `compute_br_media_mix`; edge cases for zero
   seen, all DK, missing media columns.
7. `element_branded_reach = "Y"` enabled as placeholder in IPK 3cat config;
   verified that the placeholder card renders cleanly in the report.

### DBA

**Must-have (modernised panel):**

1. Two-sub-tab modular panel parallel to other brand panels:
   - **Quadrant view** — Romaniuk Fame × Uniqueness scatter, 4 quadrants
     labelled, threshold lines, brand-coloured points, asset labels.
   - **Asset detail** — one card per asset showing image, Fame % with CI,
     Uniqueness % with CI, quadrant assignment, action recommendation per
     Romaniuk's framework.
2. Insight-box callouts (count by quadrant, strongest asset, weakest asset,
   recommended action focus).
3. Pin + PNG export per sub-tab + per asset card via TurasPins.
4. Legacy chart+table path **removed** from `03_page_builder.R:1083` and
   from `01_data_transformer.R` / `02_table_builder.R` once new panel is
   verified — no parallel rendering paths.
5. Confidence intervals computed for Fame % and Uniqueness % (Wilson;
   delegate to `modules/confidence` if simpler, otherwise inline).
6. Test coverage expanded: known-answer tests for the new panel-data
   builder, panel HTML emits the correct asset cards, placeholder shape
   when no DBA assets defined.
7. IPK 3cat already has `element_dba`; ensure the placeholder card renders
   cleanly when `DBA_Assets` sheet is empty or absent.

### Cross-cutting

8. All quality gates green: `Rscript -e "testthat::test_dir(...)"` passes
   for the brand module suite; no pre-existing tests regress; structure
   check (file ≤ 300 active lines, function ≤ 50 active lines) passes for
   all new files.
9. Browser-verified end-to-end in `launch_turas()` against a **new** IPK
   synthetic fixture folder (see §10 below). Two scenarios:
   - **Placeholder scenario:** structure has no MarketingReach + no
     DBA_Assets — both placeholder cards render cleanly, no errors.
   - **Populated scenario:** structure has MarketingReach + DBA_Assets
     with synthetic data — both modern panels render fully (sub-tabs,
     pins, PNG export, callouts).
10. Plain-English delivery summary written for Duncan covering what
    changed, what was tested, what to manually verify, and known limits.

---

## 4. Requirements

### Capabilities

- Branded Reach panel renders three modern sub-tabs (Overview /
  Misattribution / Media mix) with insight-box callouts and per-card pins.
- DBA panel renders two modern sub-tabs (Quadrant / Asset Detail) with
  insight-box callouts and per-asset pins.
- Both panels degrade to a clean "Data not yet collected" placeholder card
  when their structure inputs are absent or empty.
- Both panels honour the focal-brand colour and the existing brand-module
  CSS variables.

### Quality standards

- 300-line file limit applies; split panel rendering into multiple files
  where needed (precedent: Cat Buying split into `_chart`, `_shopper`,
  `_styling`, `_table`).
- 50-line function limit applies; rendering helpers decomposed accordingly.
- Known-answer tests for every metric and shape transformation.
- Zero regressions in the existing brand-module test suite.
- TRS refusals only — no `stop()` calls in production paths.
- Console output for refusals so they are visible in the launch_turas
  console (per `CLAUDE.md` Shiny error-handling pattern).

### Constraints

- Budget: this is a self-funded polish round — keep scope tight; no
  speculative additions.
- Timeline: target completion in a single working week of focused effort,
  including browser verification.
- Must not break any existing brand-module element (Funnel, Cat Buying,
  Portfolio, MA, Demographics, Ad Hoc, Branded Reach Phase 1 base output,
  current DBA legacy output before the swap).
- Brand module loader is whitelist-based — every new R source file MUST be
  registered in `00_main.R` `module_files` list (see
  `feedback_brand_module_loader_whitelist` memory).
- TurasPins inliner skips default values — use portable CSS rules with
  `!important` (see `feedback_turas_pins_inliner_defaults` memory).
- All brand metrics must remain expressible as per-respondent columns or
  simple ratios (see `feedback_brand_metrics_tracker_friendly` memory).

### Dependencies

- Existing engines: `run_branded_reach`, `run_dba`.
- TurasPins JS bundle.
- `modules/confidence` (optional — for Wilson CIs on Fame/Uniqueness).
- Existing structure-loader patterns in `modules/brand/R/00_data_access.R`.
- Brand-report HTML pipeline: `01_data_transformer.R`, `02_table_builder.R`,
  `03_page_builder.R`, `04_chart_builder.R`.

### Scenarios

- **Analyst with IPK Wave-1 config (no MR/DBA data collected):** opens the
  brand report, navigates to a category panel, sees a clean
  "Branded Reach — Data not yet collected" placeholder card. Switches to
  the project-level DBA section, sees a clean "DBA — Data not yet
  collected" placeholder card. No errors, no broken charts.
- **Analyst with future Wave-2 config (full data):** opens the report,
  sees the polished Branded Reach panel with three sub-tabs per category;
  pins the misattribution table, exports a PNG of the media mix. Navigates
  to DBA, sees a Romaniuk quadrant scatter with the focal brand's assets
  positioned, switches to Asset Detail, sees images and CIs per asset.
- **Unhappy paths:** ad in scope but `SeenQuestionCode` column absent in
  data → engine emits per-ad refusal note; panel renders the card with a
  clear "data missing" notice on that asset only, other ads continue.
  DBA assets defined but Fame column has zero non-NA values → engine
  emits PARTIAL with NA metrics; panel surfaces the asset card with a
  "no responses" notice rather than failing the whole panel.

### Coherence check

The objectives all trace back to one outcome: **two more brand-module
elements meet the same production-grade bar already set by Cat Buying /
MA / Portfolio / Demographics.** No objective adds a feature beyond the
agreed scope. No requirement implies functionality the objectives do not
mention. The placeholder strategy aligns with the IPK rebuild conventions
already established in memory.

---

## 5. Design & Experience

### Branded Reach — Phase 1 polish (no structural change)

The three sub-tabs (Overview / Misattribution / Media mix) keep their
current navigation. Polish lands inside each sub-tab:

- **Overview cards:** add insight box at top summarising "best branded
  reach", "worst misattribution risk", "dominant channel". Card layout
  unchanged. Image fallback box shows when `ImagePath` is missing.
- **Misattribution table:** focal-brand row highlighted with cream
  background + bold; DK and OTHER rows pinned to bottom (already done);
  "% of seen" formatted to 1 dp.
- **Media mix table:** show the top channel with a focal-brand-coloured
  bar overlay; rows ordered by `DisplayOrder` if present, else by
  descending share (already done).
- **Pin/PNG export:** each card and the panel as a whole gain a pin
  button using the existing TurasPins handler. Verify the inliner picks
  up the brand-card border treatment (use portable selectors).

### DBA — modernisation to two-sub-tab panel

**Sub-tab 1 — Quadrant view**

- 2×2 scatter. Y-axis = Fame %, X-axis = Uniqueness %, both 0-100.
- Threshold lines drawn at the configured Fame / Uniqueness thresholds
  (default 50 / 50, both overridable via config).
- Quadrant labels in the four corners: "Use or Lose" (top-right),
  "Avoid Alone" (top-left), "Invest to Build" (bottom-right),
  "Ignore or Test" (bottom-left).
- One dot per asset, sized uniformly, coloured with the focal brand
  colour. Asset code labels above each dot.
- Insight box below the scatter: e.g. "3 of 5 assets are in 'Use or
  Lose' — IPK's identity is anchored. 1 asset is 'Invest to Build' —
  consider amplifying."

**Sub-tab 2 — Asset Detail**

- One card per asset (vertical stack on narrow screens, 2-column grid
  on wide).
- Each card: asset image (with placeholder fallback), asset label,
  Fame % with Wilson CI band, Uniqueness % with Wilson CI band, quadrant
  badge, one-line action recommendation per Romaniuk.
- Pin / PNG button per card.

### Information hierarchy

- Both panels lead with their insight box.
- Quadrant scatter sits above asset detail (consistent with "summary
  before detail" principle used elsewhere).
- Placeholder card is a single hero card — short, calm, actionable.

### Accessibility

- Quadrant scatter must encode quadrant by **shape OR label**, not colour
  alone (memory: brand non-duplication, accessibility per coding
  standards). Asset labels above each dot satisfy this.
- Misattribution highlighting uses cream background + bold weight, not
  colour alone.
- Pin button alt-text + ARIA label per existing pattern in TurasPins.

### Journey check against objectives

- BR objective 1 (insight callouts) → covered by overview insight box.
- BR objective 2 (pin/PNG) → covered by per-card pin buttons.
- BR objective 3 (focal-brand highlight) → covered by misattribution
  styling.
- DBA objective 1 (two sub-tabs) → covered.
- DBA objective 2 (insight callouts) → covered by quadrant insight box.
- DBA objective 3 (pin/PNG) → covered per asset card.
- DBA objective 4 (legacy removal) → handled in implementation order:
  new panel lands first, legacy block removed once verified.
- All objectives trace to user-visible behaviour.

---

## 6. Growth Roadmap

### Immediate scope (this branch)

- Branded Reach Phase 1 polish (objectives BR-1 to BR-7).
- DBA modernisation (objectives DBA-1 to DBA-7).
- IPK 3cat placeholder enablement.
- Test expansion + browser verification.

### Near-term extensions (3-6 months, future branches)

- **Branded Reach Phase 2 (when real Reach data lands):** ad-overlap
  analysis (which ads compound reach), brand-asset-on-ad heatmap (links
  DBA + BR — which DBAs appear in your ads vs theirs), category-vs-focal
  benchmark.
- **DBA wave-on-wave delta** (when tracker integration matures): which
  assets are gaining vs losing Fame/Uniqueness over waves. Currently
  tracker sees per-respondent Fame/Uniqueness columns so this is already
  data-feasible.
- **Competitive DBA (Option C from landscape):** which competitor's
  assets outscore the focal in the category. Engine already supports
  multi-brand DBA inputs in principle.
- **Asset benchmarking against category norms:** Dirichlet-style "given
  your share of voice, your DBA Fame should be X" comparison.

### Long-term potential (6-18 months)

- DBA + Branded Reach become the asset half of a "Distinctive Asset
  Health" tracking system (Romaniuk's full framework — DBA test +
  Branded Reach test + creative asset audit linked to media spend).
- Integration with creative audit tools (e.g. Romaniuk DBA grid scored
  on each ad's image asset → links visual elements to ad performance).
- White-label as a stand-alone Asset Audit deliverable for clients who
  want a fast Romaniuk-style asset review without the full BHT.

### Structural implications

- Engine code already supports growth: per-respondent Fame/Uniqueness
  columns are tracker-compatible.
- Panel structure (sub-tab pattern, JSON payload + JS re-render) extends
  cleanly to additional sub-tabs without rewriting.
- Placeholder pattern means IPK and other "no data yet" projects do not
  break when these grow.
- Avoid coupling the BR panel to media-channel assumptions — the engine
  drives off `ReachMedia`, so future media list expansion is free.

### Commercial lens

- Strengthens TRL's Romaniuk-grounded BHT positioning. DBA + Branded
  Reach are the two most identifiable "Romaniuk methods" for clients
  familiar with Building Distinctive Brand Assets and the Ehrenberg-Bass
  literature.
- Polished panels are demoable for new-business pitches even before a
  client has the data — the placeholder card itself communicates that
  the platform is ready when the data arrives.
- No additional licensing or recurring cost.

---

## 7. Risks & Mitigations

### Execution risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Removing legacy DBA path before new panel is verified | DBA disappears from reports during the gap | Land new panel first, run reports, confirm rendering, only then remove legacy block. Two-commit sequence: "add DBA panel" → "remove legacy DBA" |
| TurasPins inliner skipping default CSS | Pinned/PNG exports look broken | Use portable selectors + `!important`, follow `feedback_turas_pins_inliner_defaults` memory; verify pin output in browser, not just code review |
| Brand module loader missing new files | New R files silently never load | Add every new file to `00_main.R` `module_files` whitelist; verify via "TURAS>... loaded" console messages on launch |
| Pre-existing failing tests inflating delta | Hard to spot regressions | Capture baseline pass/fail count before changes; run after each commit |
| Wilson CI dependency on `modules/confidence` | Cross-module coupling | Use a small inline Wilson helper in `07a_dba_panel_data.R` if the cross-module call complicates testing; document the choice |
| Placeholder rendering inconsistency between BR and DBA | Two different "data not collected" experiences | Define a single shared placeholder-card helper for the brand module and use it from both panels |
| 3cat / 9cat examples are stale post-IPK-rebuild | Cannot use them for verification — would mislead | Use new IPK synthetic test folder (§10) as the only verification target; do not modify `examples/3cat` or `examples/9cat` configs |
| Existing inline-fixture unit tests reference 9cat in comments | Cosmetic only — no runtime dependency | Update comments where misleading; do not rewrite the tests |

### Strategic risks

| Risk | Mitigation |
|------|------------|
| Scope creep into Phase 2 BR features mid-build | Hold the line — Phase 2 is documented in the growth roadmap, not in objectives |
| DBA quadrant labels feeling clichéd to clients ("Use or Lose") | Keep Romaniuk's exact terminology — that's the authoritative source clients respect; revisit only if a client objects |
| Asset images bloating report file size | Document expected image size budget in the README; consider lazy-load or thumbnail strategy if needed (defer until first real data wave) |

### Quality standards (Duncan's universal bar)

- [ ] No shortcuts — first version must be properly done, not a rough draft.
- [ ] No known compromises without a remediation plan documented in this file.
- [ ] Fully documented — README updated, roxygen on every new function,
      planning doc retained in `modules/brand/docs/`.
- [ ] Fully verified — automated tests + browser session against IPK 3cat
      and 9cat configs.
- [ ] Easily maintained — modular files, no god-files, clear separation
      of engine / panel data / HTML emit.
- [ ] Genuinely good to use — pins work, callouts are sensible, placeholder
      reads as helpful not broken.
- [ ] Transparent and ethical — no manipulative quadrant labelling beyond
      Romaniuk's framework; no hidden assumptions.

---

## 8. File Inventory & Commit Plan

### New files

| File | Purpose | Est. active lines |
|------|---------|-------------------|
| `modules/brand/R/07a_dba_panel_data.R` | Shape engine output for HTML | ~120 |
| `modules/brand/lib/html_report/panels/07_dba_panel.R` | DBA panel orchestrator + sub-tab nav | ~150 |
| `modules/brand/lib/html_report/panels/07_dba_panel_quadrant.R` | Quadrant view sub-tab | ~180 |
| `modules/brand/lib/html_report/panels/07_dba_panel_detail.R` | Asset Detail sub-tab | ~200 |
| `modules/brand/lib/html_report/panels/07_dba_panel_styling.R` | Panel CSS | ~120 |
| `modules/brand/lib/html_report/panels/_shared_placeholder.R` | Shared placeholder card helper | ~60 |
| `modules/brand/tests/testthat/test_dba_panel.R` | Panel data + HTML emit tests | ~200 |

### Modified files

| File | Change |
|------|--------|
| `modules/brand/R/00_main.R` | Add new R files to `module_files` whitelist |
| `modules/brand/R/07_dba.R` | Optional: factor `build_dba_panel_data` into 07a |
| `modules/brand/lib/html_report/03_page_builder.R` | Wire new DBA panel; remove legacy block at line 1083 once verified |
| `modules/brand/lib/html_report/01_data_transformer.R` | Remove legacy DBA chart build at line 217 once verified |
| `modules/brand/lib/html_report/02_table_builder.R` | Remove `build_dba_tables` once verified |
| `modules/brand/lib/html_report/panels/10_branded_reach_panel.R` | Polish per BR objectives 1-5 |
| `modules/brand/tests/testthat/test_branded_reach.R` | Expand coverage (BR objective 6) |
| `modules/brand/tests/testthat/test_dba.R` | Confirm engine tests still pass |
| `modules/brand/README.md` | Update test count + note DBA modernisation + BR polish + new test fixture location |

### Commit sequence (atomic, reviewable)

1. `feat(brand/dba): add modern DBA panel — quadrant + asset detail` —
   New panel files; engine + page-builder NOT yet swapped.
2. `feat(brand/dba): wire new panel + remove legacy chart+table` —
   Swap done; verify report.
3. `feat(brand/branded-reach): insight callouts + image fallback +
   focal-brand highlighting`
4. ~~`feat(brand/branded-reach): pin/PNG export per card`~~ — **dropped.**
   On reading the existing code, per-card pin + PNG export was already
   implemented at `.br_reach_card_toolbar` and the buttons are auto-
   stripped from PNG captures by `brand_pins.js:29`. No additional code
   needed; pin/PNG verification rolled into commit 5 (tests).
5. `test(brand): expand BR + DBA panel test coverage` — also covers
   pin section-id resolution + capture-strip behaviour.
6. `docs(brand): update README + planning doc cross-references`

Each commit must leave the suite green. Note: there is no separate
"enable BR for IPK" config commit because the canonical IPK config
lives in the synthetic test folder (§10), not in the deprecated
`modules/brand/examples/3cat/`.

---

## 9. Next Steps

When Duncan signs off this plan:

1. **Pre-flight IPK baseline (CRITICAL).**
   Before creating the branch, run `launch_turas()` against the canonical
   IPK config (`OneDrive/.../IPK/Tabs/synthetic/`), generate the brand
   report, and save the output to
   `~/.turas-baselines/IPK_pre_BR_DBA_branch/` along with screenshots of
   each element panel. This is the regression target — any change to
   non-DBA, non-BR panels in subsequent runs is a regression.
2. Create branch: `git checkout -b feature/branded-reach-and-dba` from `main`.
3. Capture baseline test counts: `Rscript -e "testthat::test_dir('modules/brand/tests')"`.
4. Set up the new IPK synthetic test fixture folder per §10 below.
5. Begin commit 1 (new DBA panel files), running tests after each new file.
6. After commit 2 (DBA legacy swap), re-run the canonical IPK config and
   **diff against the pre-flight baseline** — confirm only the DBA panel
   changed; everything else byte-identical (or visually unchanged where
   timestamps differ).
7. Browser-verify the placeholder scenario after commit 2 and again after
   commit 4.
8. Browser-verify the populated scenario after commit 5.
9. Run the canonical IPK config one final time before opening the PR;
   confirm no unexpected regressions.
10. Sign-off checkpoint with Duncan after step 9.
11. Open PR to `main`.
12. Add a short memory note when merged.

---

## 10. Test fixture setup

### Constraint

The brand module was reformatted during the IPK rebuild (merged 2026-05-01).
The legacy `modules/brand/examples/3cat/` and `modules/brand/examples/9cat/`
examples are **stale and will not run** under the current brand module.
They are not deleted (yet) but cannot be used for verification.

The canonical working IPK example lives at:

```
/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/IPK/Tabs/synthetic/
  ├── 8822527_Brand_Config.xlsx
  ├── 8822527_Crosstab_Config.xlsx
  ├── 8822527_Survey_Structure.xlsx
  ├── 8822527_Survey_Structure_Brand.xlsx
  ├── 8822527_Synthetic_Data.xlsx
  └── Output/
```

This must not be disturbed.

### New fixture folder

Create a sister folder inside the synthetic directory:

```
/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/IPK/Tabs/synthetic/
  └── BR_DBA_test/                      ← new
      ├── placeholder/                  ← scenario A
      │   ├── 8822527_Brand_Config.xlsx                (copy)
      │   ├── 8822527_Survey_Structure_Brand.xlsx      (copy, no MR/DBA sheets)
      │   └── 8822527_Synthetic_Data.xlsx              (copy)
      └── populated/                    ← scenario B
          ├── 8822527_Brand_Config.xlsx                (copy + element flags)
          ├── 8822527_Survey_Structure_Brand.xlsx      (copy + MR + DBA sheets)
          └── 8822527_Synthetic_Data.xlsx              (extended with synthetic
                                                         MR + DBA columns)
```

### Placeholder scenario (verify "Data not yet collected" cards)

- Copy the canonical files unchanged.
- In the `Brand_Config` workbook, set `element_branded_reach = Y`
  and `element_dba = Y` so the placeholder cards are exercised.
- Run `launch_turas()`, pick this folder, generate the brand report,
  visually inspect both placeholder cards.

### Populated scenario (verify modern panels render with data)

- Copy the canonical files.
- Add a `MarketingReach` sheet to the structure with 2-3 synthetic ads
  (one ALL, one DSS-only) referencing existing brands.
- Add a `ReachMedia` sheet with 4-5 channels (TV, SOCIAL, PRINT, RADIO,
  ONLINE).
- Add a `DBA_Assets` sheet with 3-5 IPK-only distinctive assets
  (e.g. logo, packaging, slogan).
- Extend the synthetic data file with:
  - `reach.seen.{ad}` columns (1 = seen, 2 = not seen, NA = not shown)
  - `reach.brand.{ad}` columns (brand code from the category list,
    "DK", or "OTHER")
  - `reach.media.{ad}` columns (comma-separated media codes)
  - `DBA_FAME_{asset}` columns (1 = Yes, 2 = No, 3 = Not sure)
  - `DBA_UNIQUE_{asset}` columns (focal-brand code or competitor code)
- Distribute the synthetic answers so each panel has interesting
  numbers (e.g. one ad with strong branded reach, one with bad
  misattribution; one DBA in each quadrant).

### Out of scope

- Deleting the legacy `examples/3cat` and `examples/9cat` folders. That
  is a separate cleanup task, tracked elsewhere.
- Changing the canonical IPK synthetic files. Hands off.

---

## Appendix A — Quality checklist (project-specific)

- [ ] **Pre-flight IPK baseline captured before any code change**
- [ ] **Canonical IPK report unchanged in non-DBA, non-BR sections at every commit**
- [ ] **Canonical IPK files in OneDrive synthetic/ folder NEVER modified**
- [ ] All 7 BR objectives met
- [ ] All 7 DBA objectives met
- [ ] Both panels render placeholder cards cleanly when data is absent
- [ ] No file exceeds 300 active lines (or is marked `SIZE-EXCEPTION`)
- [ ] No function exceeds 50 active lines (or is marked `SIZE-EXCEPTION`)
- [ ] All new functions have roxygen with `@param`, `@return`, `@examples`
- [ ] Known-answer tests for every metric calculation
- [ ] Wilson CI helper either used or documented as deferred
- [ ] No `stop()` calls in production paths — TRS only
- [ ] Console output for every refusal in launch_turas
- [ ] All new R files registered in `00_main.R` whitelist
- [ ] TurasPins selectors use portable rules with `!important`
- [ ] New BR_DBA_test placeholder fixture renders both placeholder cards
- [ ] New BR_DBA_test populated fixture renders both modern panels
- [ ] All brand-module tests pass; pre-existing failing test count unchanged
- [ ] Plain-English delivery summary written for Duncan

---

## Appendix B — References

- Romaniuk, J. (2018). *Building Distinctive Brand Assets.* OUP.
- Romaniuk, J. & Sharp, B. (2016). *How Brands Grow: Part 2.* OUP.
- Existing brand-module patterns:
  - `modules/brand/lib/html_report/panels/02_ma_panel.R` (sub-tab pattern)
  - `modules/brand/lib/html_report/panels/09_portfolio_panel.R` (insight
    box pattern, focal-brand highlighting)
  - `modules/brand/lib/html_report/panels/10_branded_reach_panel.R`
    (current Phase 1 — the polish target)
- Memory references:
  - `feedback_brand_module_loader_whitelist`
  - `feedback_turas_pins_inliner_defaults`
  - `feedback_brand_metrics_tracker_friendly`
  - `reference_brand_portfolio_patterns`
  - `project_brand_branded_reach`
  - `project_brand_ipk_rebuild_plan`
