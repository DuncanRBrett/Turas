# Brand Module — Production Review (V2 Lift Programme, late addition)

**Date:** 2026-07-12. Coordinator: Fable review session. Method: programme §2 — four parallel independent Opus readers (a: statistical engine, b: config/UX/doc-drift, c: report layer, d: tabs/v2 integration) + full test-suite run + coordinator spot-verification of every CRITICAL and load-bearing HIGH.
**Evidence rule:** every finding carries file:line read this session. Tags: **[COORD-VERIFIED]** = coordinator re-verified by execution or direct read; **[READER]** = single-reader code-read, not independently re-verified; **[SUSPECTED]** = plausible, needs the named confirmation. Nothing here is invented.
**Scope note:** brand was outside the original programme ("own roadmap", V2_LIFT_PROGRAM.md:48) and is added by this review. It is absent from `modules/tabs/docs/V2_MIGRATION_PLAN.md` entirely (grep: zero hits) — so unlike the six prior modules there is no false plan premise to correct; a brand route must be *added* to the plan.

---

## 0. Verdict

**Second-best-shape module after segment, with one dead-on-arrival flagship analytic and one work-destroying report bug.** The GUI honours engine refusals and the shipped templates load (the two plagues of the other six modules — both absent, empirically checked). Weights are genuinely threaded through every element. Funnel math is correct. But: the Dirichlet/Double-Jeopardy *expected* values — the entire point of that element — have never produced a number (all NA under PASS), and the report's Save button silently discards analyst commentary because three divergent persistence mechanisms all fail to round-trip. Significance everywhere is design-effect-naive (weighted estimates, raw-n tests), which is the module's main OPUS-0 dependency.

Suite baseline (run twice this session): **2155 pass / 0 fail / 2 skip / 1 warn** — but green-biased on exactly the broken feature (§5).

## 1. CRITICAL

### C1 — Dirichlet norms: every expected/theoretical value is NA, under PASS [COORD-VERIFIED by execution]
`modules/brand/R/08c_dirichlet_norms.R:242-269` (`.dn_extract_expected`/`get_field`), wired at `00_main.R:678-698`.
`get_field()` probes `dir_obj[["pen"]] / [["buyrate"]] / [["SCR"]] / [["heavy"]]` (+aliases). Coordinator ran `NBDdirichlet::dirichlet()` this session: the object has **none** of those fields; `brand.pen`/`brand.buyrate` exist but are **functions** (length 1 < n brands, so the length guard rejects them). Every candidate misses → `rep(NA_real_, n)` → `Penetration_Pct_Exp`, `BuyRate_Exp`, `SCR_Pct_Exp`, `Pct100Loyal_Exp` all NA → all deviation columns NA → every `DJ_Flag` collapses to `"on_line"` → DJ theoretical curve absent → `focal_*_exp` metrics NA. `run_dirichlet_norms` still returns `status="PASS"`, and buyer-heaviness runs on top as if norms succeeded (`00_main.R:698`).
**Consequence:** the observed-vs-Ehrenberg-Bass-norm comparison — the element's reason to exist — has never worked in production; panels show blank expected columns and no over/under flags.
**Latent crash (fold into fix):** with a single brand (n=1), `length(v) >= n` passes for the function object and `v[seq_len(n)]` throws "closure not subsettable" *outside* the tryCatch (`08c:249-250`) — raw error instead of refusal. [COORD-VERIFIED by read; not executed]
**Fix direction (verified viable this session):** `dir_obj$brand.pen(1:n)` / `$brand.buyrate(1:n)` return the correct theoretical vectors (coordinator executed `d$brand.pen(1)` → 0.289); or use `summary(dir_obj)`. SCR = theoretical brand buyrate share of category requirement; loyalty from the `$wp`/heavy summary. Refuse (`CALC_DIRICHLET_EXTRACT`) if extraction yields NA — never NA-under-PASS. Test must assert **non-NA expected values** on the known fixture (see §5).

### C2 — "Save Report" silently loses analyst insight commentary [COORD-VERIFIED by read]
`modules/brand/lib/html_report/js/brand_report.js:182-204`: `_brSaveReport` serializes `document.documentElement.outerHTML` with **no pre-serialization sync**. Three divergent persistence mechanisms exist and none round-trips:
- **Mental Advantage** insight boxes → `sessionStorage` only (`brand_ma_panel.js:1986-1996` [COORD-VERIFIED]) — invisible to `outerHTML`, gone when the tab closes.
- **Audience Lens** → `localStorage` (`brand_audience_lens_panel.js:87-94` [READER]) — doesn't travel with the saved file; see H3 for the collision.
- **Funnel / Category Buying / Summary** textareas → `.value` read only at pin time (`brand_funnel_panel.js:2304`, `brand_cat_buying_panel.js:1736` [READER]) — textarea `.value` is not reflected in `outerHTML`.
- Generic `.br-insight-editor` survives **only if** the analyst toggled editor→rendered before saving (`brand_report.js:120` [READER]).
**Consequence:** analyst writes commentary across the report, clicks Save, reopens → most or all of it is gone, no warning. Brand's report is the client deliverable; this destroys work-product. (Same family as keydriver/catdriver save-loss, but broader — three mechanisms, most surfaces.)
**Fix direction:** ONE persistence mechanism, DOM-serializable (write `.value` into a serializable node or a JSON island on input, mirroring TurasPins' `textContent` store which *does* survive save — `shared/js/turas_pins.js:257-260`); retire sessionStorage/localStorage for report content.

## 2. HIGH

- **H1 — Portfolio category penetration unweighted while everything beside it is weighted.** [COORD-VERIFIED `09h:302`] `cat_usage_pct <- base$n_uw / n_total * 100` (`09h_portfolio_overview_data.R:302`); same pattern `09c_portfolio_clutter.R:132`, `09d_portfolio_strength.R:81` [READER]. `build_portfolio_base` computes `n_w` (`09_portfolio.R:92-95`) but these consumers use `n_uw`, while awareness cells in the same payload are weighted (`09h:295`). On weighted studies the category number disagrees with the weighted Dirichlet `cat_pen` (`08c:64`) by construction. Direct contributor to the "five penetration numbers" (§6).
- **H2 — All significance and CIs are design-effect-naive: weighted estimates tested on raw weighted totals, no Kish n_eff.** [COORD-VERIFIED `03b:598-639`] `.sig_row`/`.sig_row_against_summary` feed `x=base_weighted, n=Σw` into a two-proportion test; funnel CI uses `n_eff <- max(1, n_total)` (`panels/03_funnel_panel_chart.R:326` [READER]); portfolio extension `.ext_sig_test` (`09e_portfolio_extension.R:57` [READER]) same class. Found independently by readers (a) and (d). With dispersed weights, p-values are too small and ▲/▼ markers over-fire. Brand does not source `tabs/lib/weighting.R::calculate_effective_n` (its only tabs touchpoint is the section-insights mirror comment, `01b_section_insights.R:11`). **This is brand's primary OPUS-0 dependency** — rewire the closures to shared Kish n_eff when OPUS-0 extracts it.
- **H3 — Audience Lens commentary keyed `"turas_al_insight_" + cat_code` in localStorage.** [READER `brand_audience_lens_panel.js:80-94`] Two clients' reports sharing a category code in the same browser read/overwrite each other's commentary — cross-client contamination. Fix: retire localStorage per C2; if kept interim, namespace by report identity.
- **H4 — Branded-reach misattribution drops credit given to off-list brands. [SUSPECTED]** `10b_br_misattribution.R:74-102` [READER]: buckets are `c(brand_codes,"DK","OTHER")`; a pick that matches none is in `n_seen` (denominator) but no row, so `pct_of_seen` under-sums; and `is_correct` compares `row$Brand` to codes — a label there reads correct-attribution as 0. **Confirm against the MarketingReach `BrandQuestionCode` option domain** (closed list → fine; open list → real base error).
- **H5 — Role-map build failure silently degrades to a report missing ALL v2 elements, reported as success.** [READER `00_main.R:303-321`] `build_brand_role_map` error → `role_map <- NULL`, console warning, run continues; GUI status check passes (`run_brand_gui.R:321`) → "completed successfully", but every role-map-driven element (MA, funnel v2, …) silently skipped (`00_main.R:402`). The suite's own log shows the message five times (`CFG_ROLE_MAP_BUILD_FAILED`, coordinator's suite run). Escalate to PARTIAL surfaced in the UI.

## 3. MEDIUM

- **M1 — Role-map guard layer is dead code (tested, never wired).** `00_guard_role_map.R:47,119,158,195` defined + tested in `test_guard.R`, zero production callers [READER, grep-verified]. The advertised "re-export via the parser" early refusal never happens; malformed files fall through to generic column errors or NA columns (`00_data_access.R:194`). Wire into `run_brand()` or delete + fix the header.
- **M2 — GUI: output-generator refusals presented as success.** `run_brand_gui.R:341-349,389` [READER]: HTML/Excel generator REFUSED → `success` stays TRUE, "completed successfully!", NULL paths. (Engine refusals ARE handled — `:319-323`.)
- **M3 — JSON islands not `</`-hardened, ~14 sites + shared pins store.** [READER] e.g. `panels/02_ma_panel.R:322`, `03_funnel_panel.R:396`, `14_summary_panel.R:2141`, `13_audience_lens_panel.R:563`, `09_portfolio_panel.R:648,842,1108`, `11_demographics_panel.R:504`; plus known cross-module `shared/js/turas_pins.js:257-260`. A literal `</script>` in any config/data free-text breaks the render/saved file. The **shared** turas_pins fix is already scoped to catdriver Session B5 — brand hardens its own R-side islands only, no duplicate shared fix.
- **M4 — Min-base/disclosure gating inconsistent.** [READER] Funnel warns n<30 (`brand_funnel_panel.js:2958-2961`) and portfolio flags low base (`brand_portfolio_panel.js:2019+`), but Category Buying % Buyers, MA MPen, Demographics, Branded Reach, Summary render per-brand percentages with no flag at any n. OPUS-0's shared disclosure gate should replace the scattered per-element gates (`portfolio_min_base` `09b:269,301`; `funnel.suppress_base` `03c:401`).
- **M5 — Dead config key `db_importance_method`** (`01_config.R:159`, template `generate_config_templates.R:256`, documented in guide; no engine reader) [READER, grep-verified].
- **M6 — Doc drift:** live Settings keys undocumented in BRAND_CONFIG_GUIDE.md: `chip_default`, `audience_lens_max`, `funnel_tenure_threshold`, `portfolio_min_base`, `portfolio_cooccur_min_pairs`, `portfolio_extension_baseline` [READER].
- **M7 — Penetration surfaces show different definitions with no on-face denominator** (§6). Report-side: label every % surface with its base + definition; a reconciliation callout closes the long-standing deferred item (memory: `project_brand_penetration_reconciliation`).
- **M8 — Weights not coerced/validated numeric at ingestion** (`00_main.R:286`) — character weights error loudly downstream rather than refuse cleanly [READER].
- **M9 — Residual `stop()`s:** GUI package guard `run_brand_gui.R:29`; `panels/00_brand_selector_widget.R:30,34` (programmer-arg validation, low reachability) [READER].

## 4. LOW

- **L1 — `.is_none_brand_code` treats any code whose letters reduce to "na" as the NONE pseudo-brand** (`00_data_access.R:484-492`) — a real brand coded `N.A.` would vanish from every table [READER].
- **L2 — Buyer-heaviness buckets: boundaries AND labels both hard-coded** (`08d_buyer_heaviness.R:363-366,407-412`). No internal mismatch (memory's "labels overridable" is wrong — nothing is overridable engine-side); risk only if the report relabels independently. Boundary edges verified correct [READER].
- **L3 — Suite warning:** `test_ma_panel_cat_avg_mask.R:155` max-of-empty −Inf warning (cosmetic, coordinator's suite run).

## 5. Test suite — 2155/0/2/1, structurally green on the broken feature

Both skips legitimate (unreachable mocked PKG path since NBDdirichlet is installed; on-CRAN timing guard). But: `test_dirichlet_norms.R:205-211` asserts `_Exp` columns **exist**, never that they're non-NA; `:149,161` accepts all-NA `DJ_Flag→"on_line"`. The suite hand-verifies the *observed* Dirichlet half against a known-answer fixture (`:60-118` — good) and never checks the *expected* half — exactly where C1 lives. Session A must add non-NA expected-value assertions. Same green-bias family as the other five modules, milder.

## 6. Penetration reconciliation inventory (the "five numbers", root-caused)

Three different buyer definitions × weighted-vs-unweighted × two screener windows. Engine-side computations [reader (a), H1 site coord-verified]:

| # | Metric | Where computed | Numerator / Denominator | Weighted? |
|---|--------|----------------|-------------------------|-----------|
| 1 | Cat-buying "% buyers" | `08_cat_buying.R:178-186` | freq-scale ≠ never / all asked | Yes |
| 2 | Dirichlet `cat_pen` | `08c:64` | reconciled BRANDPEN2/3 any-brand (incl. case-B promotions `08b:282-287`) / cat respondents | Yes |
| 3 | Portfolio overview/clutter/strength cat pen | `09h:302`, `09c:132`, `09d:81` | screener SQ2 (3m; SQ1 fallback) picks / full sample | **No (H1)** |
| 4 | Portfolio base (footprint/DoA) | `09_portfolio.R:92-95` | SQ2-or-SQ1 pick; `n_w` exists, overview uses `n_uw` | mixed |
| 5 | Funnel bought stages | `03b:453` | **raw** BRANDPEN1/2 (deliberately unreconciled `08b:135-152`) / cat Σw | Yes |
| 6 | Demographics within-demo pen | `11_demographics.R:267-274` | per-brand buyers / weighted known base in option | Yes |

Report surfaces reading these (reader (c)): Cat-Buying Loyalty+Shopper "% Buyers" (`panels/08_cat_buying_panel.R:152-153`, `_shopper.R:87-95`), Dirichlet panel `Penetration_Obs_Pct` (`08_cat_buying_panel_chart.R:81,606,624`), MA "Mental Penetration" (different construct sharing the word — `02a_ma_panel_chart.R:110,316-317`), Portfolio footprint % pen on **all respondents** (`09_portfolio_footprint_table.R:282-292`), Branded Reach `reach_pct` (`10_branded_reach_panel.R:101-102`), Summary loyalty island (`14_summary_panel.R:848-884`), DoP-aware table (aware base).
**Resolution shape:** #1/#2/#3 *should* differ (different constructs) — the fixes are (i) H1 weighting, (ii) on-face denominator labels everywhere (M7), (iii) one reconciliation callout listing the numbers side by side with definitions. Also confirm the funnel-parity claim reads `pen_mat_raw` not `pen_mat` where claimed (`08b:140`).

## 7. Report layer vs tabs-v2 (curated, D1)

Genuinely valuable from v2: **(i)** shared disclosure gating (fixes M4); **(ii)** v2's serializable insight-persistence model (fixes C2); **(iii)** native OOXML PPTX engine (`14_pptx_parts.js`/`29_export.js`) replacing TurasPins' screenshot `slide.addImage` path (`shared/js/turas_pins_pptx.js:285,344`) — the parked doc's Rec B; **(iv)** diffs/standout auto-callouts (MEDIUM value). Not gaps: AI insights (brand is deliberately analyst-manual), tracking (belongs to tracker — `README.md:131`), workspace/story views, v2 dual-sig parity (brand's comparison model is focal-vs-rest, not banner letters). Brand already ships PPTX via shared TurasPins bundle (`shared/lib/turas_pins_js.R:70-71`) **and** a 532-line `brand_pins.js` — retiring the latter onto shared TurasPins is the OPUS-0 tie-in and the precondition for (iii).

## 8. Integration route — fourth archetype: v2-standard upgrade IN PLACE

Reader (d), coordinator-endorsed. Brand is absent from V2_MIGRATION_PLAN (zero grep hits; scope line :5 names five modules; landing-zone table :33-39 and checklist :93-103 silent). The plan's own crux (":27 — migrate = emit v2 islands, NOT port the HTML report; classic reports are throwaway") is exactly where brand inverts: **brand's HTML report IS the deliverable** (~48k R+JS lines, 40 panels of bespoke funnel/constellation/Dirichlet visualisations that are cross-respondent aggregates, not per-question rows).
- **No tabs exporter.** The per-respondent-expressible subset (funnel stage booleans, attitude, WOM/NPS, repertoire) is already tabs-native survey microdata derivable via QuestionMap; exporting duplicates capability and violates the non-duplication principle. The aggregate analytics (Dirichlet, TURF, MA network, DoP/DoA, constellation) can't ride microdata recompute.
- **No v2 island/view.** Forcing bespoke aggregates into `row.kind` arms is the wrong-layer port the plan itself warns against.
- **Route:** upgrade in place, consuming OPUS-0 plumbing — shared Kish n_eff into the sig closures (H2), shared disclosure gate (M4), TurasPins consolidation → native PPTX (Rec B), then the parked doc's clarity IA (Rec A) as a design-led effort. Wave tracking stays deferred to tracker.
- **Parked `review/brand-report-v2-upgrade-2026-06` reconciled:** its one unmerged commit is the 213-line review doc (6c1f0e41); every load-bearing claim verified **still-true** against today's main (reader (d) table) except it under-examined significance (missed H2). Recommendation: cherry-pick/merge the doc commit (docs-only), close the branch. **Memory correction:** `feature/branded-reach-and-dba` is already merged into main [COORD-VERIFIED `git merge-base --is-ancestor`] — the "browser-verify then merge" memory item is stale, and the DBA/Branded-Reach elements make the overload case for Rec A stronger.

## 9. For Duncan to rule on (handover §0 has the locked defaults)

1. C1 fix ships expected values extracted via the package's function API + refuse-on-NA — any objection to refusal over silent-NA for old configs?
2. H1: weighted category penetration everywhere — or keep §3's screener counts deliberately unweighted and label them? (Default: weight them.)
3. C2: single DOM-serializable persistence retires sessionStorage/localStorage — accepts losing "commentary survives page reload without saving" in exchange for commentary surviving Save. (Default: yes.)
4. Rec A (clarity IA redesign, parked doc) — separate design-led session needing your priorities; not bundled into A/B/C.
5. H4 needs the MarketingReach option-domain answer (closed vs open brand list) — one-line ruling.

## 10. Good news (verified sound, file:line in reader reports)

Funnel "% of aware" independent-intersection and "% of previous" cumulative-chain semantics both correct (`03b:143-198`); funnel NA-column handling correct (no false 0%); weights genuinely threaded module-wide (`00_main.R:281-296`); GUI honours engine refusals (`run_brand_gui.R:319-323`) — first module of seven reviewed without engine-level success-on-refusal; shipped templates load, loader auto-scans header offsets (`01_config.R:234-240,351-364` — keydriver/catdriver defect absent, verified via openpyxl); guard enums match template dropdowns; loader whitelist effectively clean; alias resolution union-matched and sound (`00_data_access.R:133-282`); Dirichlet *observed* metrics hand-verified against fixture; buyer-heaviness tertiles/NMI sound; DoA D-law computed in-house correctly (`09b_portfolio_dop_awareness.R:376-408`); demographics NA handling correct; MA CEP weighted path correct (0/1 tensor by construction); pins DO survive save; HTML escaping sound (`.br_esc`/`.br_escape`); brand colours single-sourced and test-enforced.

## 11. Coverage gaps (not reviewed / not verified — honest list)

Math not line-verified: `02b/02c` mental-advantage MMS + cat-avg masking (flagged as highest-value follow-up), `04_repertoire` DoP end-to-end, `05_wom`, `06_drivers_barriers` gaps, `07_dba`, `12_adhoc`, `13b/13c` audience-lens metric denominators, `08e/14` shopper. Report renderers not executed against edge payloads (single-brand/zero-buyer) beyond Summary+CatBuying guard spot-checks. Summary `.brsum-insight-editor` persistence path inferred, not line-read. `officer`/`base64enc` in renv.lock unchecked. No end-to-end `run_brand()` execution this session (suite only). Reader line numbers outside the coordinator-verified set were not independently re-read.
