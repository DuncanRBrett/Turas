# Growth Path: Brand Module

**Date:** 2026-05-24
**Current state:** A full-stack within-category brand health analytics module built on the Ehrenberg-Bass / Romaniuk CBM framework. 13 analytical elements across 56 R source files, an HTML report with 14 panel types and 12 JS renderers, and 1,989 passing test expectations across 51 test files. Production-running for the IPK 2026 brand health programme.
**Stack:** R / Shiny, openxlsx, testthat. Vanilla JS in self-contained HTML output. No build step. Dependencies pinned via renv.

---

## Architecture readiness

### What the current architecture supports without significant rework

- **New analytical elements.** The `element_*` config-toggle pattern in `01_config.R` plus the `cat_result$<element>` orchestration in `00_main.R` is repeatable. A new element follows: an engine R file under `R/`, a panel-data R file (`Ra_*`), a panel R file under `lib/html_report/panels/`, and a registration line in the whitelist loader (00_main.R:54-87). The existing Demographics → Demographics+toggle change took two files.
- **New CEP and attribute batteries.** The role-map system (`00_role_map.R`, `00_role_inference.R`) discovers MA stimuli at runtime by scanning `mental_avail.{kind}.{cat}.*` keys. Surveys can add CEPs and attributes without code changes — only Survey_Structure.xlsx changes.
- **New focal-brand UX patterns.** The brand selector dropdown (`brand_selector_dropdown.js`) and focal-payload contract are reused across Demographics, Cat Buying, MA, Funnel, Portfolio overview, and Summary. Adding focal switching to a new tab follows the established `.po_detect_cat_code` + JSON-payload + `data-focal` pattern.
- **Wave 2+ tracker comparisons.** `tracker` is wired in for any per-respondent metric. Brand metrics that follow the "per-respondent column or simple ratio" rule (memory: `feedback_brand_metrics_tracker_friendly`) will lift to a wave delta with no rework. MMS, MPen, NS, Sole_Pct, Net WOM, awareness, consideration, bought — all tracker-friendly today.
- **White-label / multi-client deployment.** Self-contained HTML reports (no CDN dependencies, TurasPins enabled) and relative-path config files (`feedback_alchemer_data_headers_from_api` confirms this works at scale for IPK with 36 hard quotas and 11+ real brands). A new client gets a new config folder and a re-run; no code touches.
- **AI insight callouts.** `modules/shared/lib/callouts/callouts.json` is the shared template store for plain-English callouts; brand callouts are loaded by panel-data builders without coupling. Adding callouts to a new panel is a JSON edit + a render-time reference.
- **Excel / CSV exports** alongside the HTML report. `99_output.R` is the consolidator; element-level writers (`03d_funnel_output.R`, `10d_br_output.R`) follow a uniform "pass cat_result, write to wb" contract.

### What would require significant rework

- **Engine-level NA semantics.** Several engines (`02_mental_availability.R`, `04_repertoire.R`, `05_wom.R`) return `0` for "no data" rather than `NA`. The C1 fix in this review patches the symptom at the Summary panel; making engines NA-aware end-to-end would touch every Excel writer, every panel-data builder, and every test that asserts the current zero-as-no-data contract (notably `test_wom.R:227` "missing roles degrade to zero"). Mid-sized refactor — affects ~10 R files and ~30 tests. See I2 in the production review.
- **Per-renderer payload-shape coupling.** Each JS panel reads a slightly different shape from the data-transformer. Adding a cross-panel feature (a global focal-brand picker, a wave-comparison overlay) means touching each panel's JS individually. A shared payload contract — one normalised `category_payload` per category, consumed by every panel — would unblock cross-panel work but means rewriting the data-transformer's per-panel branches.
- **Single source of truth for cat-avg.** Cat averages are computed in three different places: the engine (some), the panel-data builders (some), and the panel renderers themselves (Summary card). The C1 fix consolidates Summary; the Cat Buying and Portfolio panels do their own per-tab cat averaging. A shared `compute_cat_avg(df, col, mask)` helper would close cross-renderer drift — but only after engines emit consistent masks (depends on the NA semantics refactor above).
- **Significance testing across the report.** Funnel has a full sig-testing rig (`03b_funnel_metrics.R` `.sig_row_against_summary`); Cat Buying and Portfolio don't. Audience Lens has its own sig layer (`13c_al_classify.R`). Unifying would require a shared `brand_sig_engine` extracted from funnel — non-trivial because the per-element bases differ (cat buyers vs all respondents vs awareness base).
- **The 2.3k–3.3k LOC JS files.** `brand_funnel_panel.js`, `brand_portfolio_panel.js`, `brand_ma_panel.js` each carry too much. Each file mixes table rendering, chart rendering, controls, focal switching, and pin/PNG capture. Splitting into sub-modules (`*_chart.js`, `*_controls.js`, `*_pinning.js`) would improve testability — but vanilla JS with no module bundler means doing it carefully via global namespacing.

---

## Natural next steps

Ordered by impact and feasibility.

### 1. Cross-renderer consistency test pack

**What:** A test file that, for each (focal_brand, category, metric) tuple in the IPK Wave 1 fixture, asserts that `summary_payload$brand$metric == panel_data$brand_row$metric` for every metric that appears in both Summary and a deep-dive tab.

**Why now:** The May 2026 WOM incident and the C1 finding in this review share a root cause — same metric, two render paths, different formula. Code review missed both. The only fix that closes this class of bug going forward is mechanical assertion. The C1 regression test does this for Net WOM ↔ WOM card; one more test file generalises it across Funnel↔Summary, MA↔Summary, Cat Buying↔Summary, Repertoire↔Summary.

**Effort:** Medium. ~200 lines of test code, one fixture pass. The hardest part is enumerating "what should be the same" — likely a manual spec drafted from the report layout once.

**Dependencies:** None. Fixture exists.

**Risk:** Tests may surface 2-3 more drifts beyond the ones already known. Each one becomes a CRITICAL finding for a future review. Acceptable risk — better to find them via test than via client report.

### 2. Engine-level NA semantics ("data-active" column)

**What:** Add a `<Engine>_Active` boolean column (e.g. `MA_Active`, `WOM_Active`, `Buyers_Active`) to every per-brand engine output. Set the value at the engine boundary based on the engine's own data-presence test (linkage matrix has any non-zero entry; brand mention battery has any respondent; pen_mat has any buyer).

**Why now:** I2 documents the systemic risk. The C1 panel-layer fix is duct tape. Every new feature that aggregates across brands will silently inherit the silent-zero risk until the engine signals "data present" explicitly.

**Effort:** Large. Affects 5 engines (MA, WOM, repertoire, cat_buying, branded_reach), every Excel writer, every panel-data builder, and ~10 tests. Each engine change is a 5-line addition; the propagation is the work.

**Dependencies:** Cross-renderer consistency test pack (above) — gives regression coverage before refactor.

**Risk:** Breaking change to engine output shape. Mitigation: feature-flag via a `config$engine_active_column = TRUE` toggle, default ON, with a one-wave deprecation window.

### 3. lintr config + CI

**What:** Add `lintr` to `renv.lock`. Create `.lintr` with brand-appropriate rules. Wire `lintr::lint_dir("modules/brand/R")` into `scripts/trs_gate.sh`.

**Why now:** I7 — there is no static analysis gate today. lintr would catch the kinds of stylistic / correctness drift that humans miss (unused variables, missing `<-`, etc.). The TRS gate would then enforce zero new warnings on PR.

**Effort:** Small for the install + config. Medium for the cleanup of pre-existing lintr warnings (estimate 50-200 in the brand module; the rest of Turas has more).

**Dependencies:** None.

**Risk:** Adds setup friction for fresh clones. Mitigation: `renv::restore()` already handles this; document in the README's Quick Start.

### 4. Doc archive sweep

**What:** Move all `HANDOVER_*`, `PLANNING_*`, `DEV_NOTE_*`, `PRODUCTION_REVIEW_*`, `REVIEW_BRIEF_*`, `GROWTH_PATH_*` files from `modules/brand/docs/` to `modules/brand/docs/archive/<YYYY-MM>/`. Update CLAUDE.md / README cross-references.

**Why now:** I8. The `docs/` folder is currently a graveyard. New developers read it and cannot tell which docs are current. As of 2026-05-24 it holds 18 frozen-in-time docs alongside 7 current spec / guide docs.

**Effort:** Small. One commit. Touches no code.

**Dependencies:** None.

**Risk:** Some active session may still link to the moved files. Mitigation: leave a single `archive/INDEX.md` mapping old → new paths.

### 5. Demographics toggle in Pen mode

**What:** Disable the Cat-avg / Total-sample toggle in Penetration mode (it is a no-op there), and surface a tooltip explaining why. OR add a third "study sample" series in Pen mode (more useful, more work).

**Why now:** I10. The toggle was added 2026-05-19. In Pen mode it fires but the chart does not change. A reader sees a button that "doesn't work" — that's a credibility hit on the whole report.

**Effort:** Small for option (a) — JS attribute + CSS opacity + tooltip. Medium for option (b) — new engine column.

**Dependencies:** None.

**Risk:** Trivial.

### 6. Brand-pin / TurasPin consolidation audit

**What:** Sweep every panel for inline CSS that doesn't survive the TurasPin inliner. The memory note `feedback_turas_pins_inliner_defaults` documents this trap: `text-transform: none` and similar default values don't survive pin → PNG capture. Audit each panel's pinnable cards for inline-default CSS.

**Why now:** Pin / PNG export is part of every brand report's analyst workflow. A silent visual drift between in-report and pinned-out output is the same class of bug as the cat-avg drift — same metric, different render paths.

**Effort:** Medium. ~12 panels, each a 10-minute audit + fix.

**Dependencies:** None.

**Risk:** Low. Visual changes only.

### 7. Audience Lens v2 finalisation

**What:** Per the memory note, Audience Lens v1 shipped on `feature/brand-audience-lens` with a "rebuild from the ground up" planned (new config, questionnaire, methodology) in a future Sonnet session. The current v1 + v2 coexistence in `13b_al_metrics.R` carries a SIZE-EXCEPTION marker explicitly tagged "v1 + v2 coexist during IPK rebuild migration window".

**Why now:** The migration window has been open since IPK Wave 1 launched. Either v2 is the path forward (drop v1) or v1 is staying (drop v2 to remove the duplication). The current state is unstable.

**Effort:** Medium. Depends on which path is chosen.

**Dependencies:** Duncan's decision.

**Risk:** Audience Lens is brand-new; any change is low-blast-radius.

### 8. Brand-funnel-panel.js refactor

**What:** Split `brand_funnel_panel.js` (3,299 LOC) into `brand_funnel_table.js`, `brand_funnel_chart.js`, `brand_funnel_controls.js`, `brand_funnel_pinning.js`. Use a `BrandFunnel` global namespace for cross-file references (no bundler).

**Why now:** Three of the largest brand files are funnel/portfolio/MA JS — all >2,000 LOC. They mix five concerns each. Splitting is mechanical but tedious; doing it now (before more features land) is cheaper than later.

**Effort:** Medium per file (~half a day each); large in aggregate.

**Dependencies:** Cross-renderer consistency test pack (gives regression coverage).

**Risk:** Pure structural change with no behaviour change — low risk if tests exist.

---

## Known limitations

| Limitation | When it matters | Mitigation |
|------------|-----------------|------------|
| Engines return `0` for "no data" | Any aggregation across brands (cat avgs, totals, comparisons) | C1 panel-layer mask in Summary. Item 2 above for the proper engine-level fix. |
| Cat-avg computation lives in 3 layers | Cross-renderer drift (the WOM 22% / 39% pattern) | Item 1 above (consistency test pack); Item 2 above (engine-level mask source). |
| 14 R/JS files >600 LOC without SIZE-EXCEPTION markers | Reviewability; new-developer onboarding | I3 — add markers (one-line per file). Item 8 above for the longer JS refactor. |
| No static analysis gate | Quality drift over time | Item 3 above (lintr config + CI). |
| WOM `pos_freq` / `neg_freq` mask is coarse (any-WOM-active, not per-sharer) | Surveys with broken sharer/count routing | Engine constraint — if survey is well-routed (sp > 0 ⇔ pf > 0) it doesn't fire. M1 — fix during next WOM touch. |
| `df$BrandCode == focal` lookups don't trim / normalise case | Config files round-tripped through Excel may introduce whitespace | M2 — wrap in helper. Tracked for next cleanup. |
| Brand module whitelist loader is opt-in | Adding a new R/ file silently does nothing if not registered in 00_main.R:54-87 | Documented in memory; CI could grep for unregistered files (small enhancement). |
| Demographics toggle is a no-op in Penetration mode | Visible UI; report credibility | I10 — see step 5. |

---

## Technical debt

| Debt | Why accepted | When to pay down |
|------|-------------|-----------------|
| 27 SIZE-EXCEPTION markers across brand R + JS | Domain logic genuinely cohesive; splitting would introduce coupling, not relieve it | Next significant feature in the affected file — split as part of the feature. |
| Legacy funnel test files (`test_funnel_transactional.R` etc.) failing against current code | Cutover decision (see `HANDOVER_FUNNEL_TESTS_PORT.md`) — port deferred to ship the rebuild | Item 1 above includes funnel coverage; remaining gaps stay until a "funnel test port" sprint. |
| WOM engine returns 0 for missing roles (test `test_wom.R:227` encodes this contract) | Backwards compatibility with Excel exports; engine-level NA refactor is larger than the C1 fix | Item 2 above. |
| Two MA paths coexist (`02_mental_availability.R` legacy CEP + `02b_mental_advantage.R` Romaniuk advantage) | Both needed by current report; not actually duplication | None — different metrics, both production. |
| Repertoire engine `Sole_Pct` defaults to 0 (not NA) | Excel writer relies on numeric column type | Item 2 above. |
| The `brsum_*` and `po_*` (portfolio overview) namespace prefixes | History — different sessions, different prefixes for similar work | None — internal-only; renaming would be churn. |
| `~$*.docx` Office lock files in committed `docs/` | Editor crash | I9 — `.gitignore` + `git rm`. |
| README test count stale | Manual counter; updates drift | I4 — replace with "~2k expectations" wording that doesn't need updating. |

---

## External dependencies to watch

| Dependency | Current | Concern |
|------------|---------|---------|
| `openxlsx` | 4.x | Major rewrite to `openxlsx2` is in progress upstream. Migration would touch every Excel writer (`03d`, `10d`, `99_output.R`, `generate_config_templates.R`). Wait for openxlsx2 to stabilise. |
| `ChoiceModelR` | CRAN | Used by `08c_dirichlet_norms.R` (optional, soft-required via PKG_DIRICHLET_MISSING refusal). CRAN-stable. |
| `data.table` | Pinned via renv | Foundational. Watch for v2.0 breaking changes. |
| TurasPins / `modules/shared/lib/turas_pins.R` | Internal | Pin inliner CSS-default trap (memory note) — any TurasPins refactor must preserve the "portable CSS selectors" rule. |
| Alchemer API (translator) | Internal `scripts/alchemer_to_turas.R` | The brand module assumes the `Data_Headers` export-spine convention (memory note). API contract changes break role-map inference. |
| R version | 4.x | No specific concern; tested via renv. |

---

## Summary

The brand module is **deployable to clients tomorrow once the C1 fix in this review lands and is browser-verified**. It is well-tested (1,989 expectations), TRS-clean at the gate, free of hardcoded paths, and structurally cohesive even at scale.

The clearest path forward is the consistency-tests + engine-NA pair (steps 1 and 2 above). Together they close the bug class that produced both the May 2026 WOM incident and the C1 finding in this review — silent-zero conflation hidden behind a passing test suite. Everything else on the list is good hygiene; these two are correctness load-bearing.

The biggest constraint is reviewer bandwidth, not architecture. Each new analytical element (and there are several still in the queue — Branded Reach Phase 2, DBA Phase 2, Audience Lens v2 finalisation, Allocation Type) shadows the same pattern: a new engine, new panel data, new renderer, new tests. The patterns are documented; the missing piece is the cross-renderer assertion that prevents the next "22% vs 39%" mismatch from reaching a client.
