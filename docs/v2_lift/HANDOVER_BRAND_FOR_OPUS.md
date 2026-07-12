# Brand Lift — Handover for Opus Implementation Sessions

**Date:** 2026-07-12. Written by the Fable review session for the Opus 4.8 session(s) that will implement.
**You must read, in this order:** (1) this document; (2) `docs/v2_lift/BRAND_PRODUCTION_REVIEW_2026-07-12.md` (findings — fixes below reference its IDs C1-C2, H1-H5, M1-M9, L1-L3); (3) for Session C only, `docs/v2_lift/V2_LIFT_PROGRAM.md` OPUS-0 and the parked-doc `modules/brand/docs/BRAND_REPORT_V2_UPGRADE_REVIEW.md` (on branch `review/brand-report-v2-upgrade-2026-06`, commit 6c1f0e41 — merge that docs-only commit first, see A0). Load the `fable-method` skill. Project CLAUDE.md rules apply (TRS refusals, console-visible errors, tests before "done").
**Master tracker:** `docs/v2_lift/V2_LIFT_PROGRAM.md` — update the brand row when you finish a session.

---

## 0. Decisions — locked, do not re-litigate

Locked by the Fable review (Duncan may veto — review §9 lists the veto points; if he rules, his message wins):

1. **Brand is the fourth archetype: v2-standard upgrade IN PLACE.** No tabs exporter (per-respondent brand metrics are already tabs-native survey columns; non-duplication rule), no v2 island/view (bespoke aggregate visualisations don't fit the banner-axis row contract; the plan's own :27 wrong-layer warning). Brand's HTML report remains the deliverable and gets lifted where v2 genuinely helps: disclosure gating, serializable insight persistence, native PPTX, Kish-honest significance.
2. **C1 ships as extract-via-API + refuse-on-NA.** Theoretical values from the NBDdirichlet object's function API (`dir_obj$brand.pen(1:n)`, `$brand.buyrate(1:n)` — coordinator-verified working) or `summary(dir_obj)`; if extraction yields NA → TRS refusal `CALC_DIRICHLET_EXTRACT`, never NA-under-PASS.
3. **Category penetrations are weighted wherever weights exist** (H1), and **every penetration/% surface carries its denominator on its face** (M7) plus one reconciliation callout listing the different numbers with their definitions. Deliberate construct differences (freq-scale vs reconciled-pen vs screener-pick) stay — they get labelled, not merged.
4. **One insight-persistence mechanism** (C2): DOM-serializable (input handler writes into a serializable store — textarea `textContent`/`data-` attr or a JSON island, mirroring TurasPins' pattern which survives save). sessionStorage/localStorage retired for report content (also closes H3).
5. **Kish n_eff rewiring (H2) and the shared disclosure gate (M4) land in Session C, gated on OPUS-0** — brand consumes the shared extraction, no local Kish formula. The shared `turas_pins.js` `</script>` fix belongs to **catdriver Session B5** — do not duplicate; brand Session B hardens only brand's own R-side islands.
6. **Rec A (clarity IA redesign) is NOT in these sessions** — separate design-led effort after Duncan sets priorities (parked doc is the spec). Rec B (native PPTX via v2 OOXML engine) is Session C, after `brand_pins.js` retires onto shared TurasPins.
7. **Session split:** A = engine correctness, B = report/GUI fixes, C = OPUS-0 adoption + PPTX (gated). Branches: `feature/brand-correctness`, `feature/brand-report-fixes`, `feature/brand-v2-plumbing`. No merges — Duncan merges after regen + eyeball.
8. **Wave tracking stays with the tracker module** (README.md:131, non-duplication) — reaffirmed, out of scope.

---

## 1. Ground rules for every session

- Fix code + run suites only. **Duncan regenerates reports via `launch_turas()` himself** — never headless-run pipelines on real projects, never touch OneDrive. Brand verification is generated-HTML + browser inspection (no preview server).
- Suite: `Rscript -e 'testthat::test_dir("modules/brand/tests/testthat", reporter = "summary")'`. Baseline 2026-07-12: **2155 pass / 0 fail / 2 skip / 1 warn**. Run before first change and after every fix.
- **Loader-whitelist gotcha:** any NEW file in `modules/brand/R/` must be added to `.source_brand_module` at `00_main.R:54-108` or it silently never loads.
- Every fix ships with a test that fails on the old code. TRS refusals only; errors console-visible (`cat` for anything the GUI user must see).
- If you touch anything in `modules/shared/`, run the other TurasPins modules' suites too and say so.
- Keep an implementation-notes log; deviations logged conservatively; final summary states what was verified by execution and what was not. A Fable pre-merge review follows Session A — leave a clean trail.

---

## 2. Session A — engine correctness (`feature/brand-correctness`)

**A0.** Merge the docs-only commit 6c1f0e41 from `origin/review/brand-report-v2-upgrade-2026-06` (adds `modules/brand/docs/BRAND_REPORT_V2_UPGRADE_REVIEW.md`, nothing else — verify with `git show --stat`), then the branch is closable.

**A1. Fix C1 (Dirichlet expected all-NA).** Rewrite `.dn_extract_expected` (`08c_dirichlet_norms.R:242-269`) per locked decision 2. Also fix the single-brand latent crash (function object passes the `length(v) >= n` guard when n=1). Tests: non-NA expected values + sane ranges on the existing known-answer fixture; DJ_Flag produces at least one non-"on_line" value on a fixture designed to deviate; single-brand path refuses or computes, never crashes. This closes the §5 green-bias (tests currently assert existence only — `test_dirichlet_norms.R:205-211`).

**A2. Fix H1 (unweighted category penetration).** `09h_portfolio_overview_data.R:302`, `09c_portfolio_clutter.R:132`, `09d_portfolio_strength.R:81`: use the weighted base (`n_w`/Σw) when weights are present. Tests: weighted fixture where weighted ≠ unweighted; assert the weighted number and consistency with the Dirichlet `cat_pen` base semantics (same window/definition differences remain — see review §6).

**A3. Resolve H4 (misattribution buckets).** First check the MarketingReach `BrandQuestionCode` option domain in the config/template/docs. If open-list: fold non-matching, non-DK picks into `OTHER` and validate `row$Brand` resolves to a `BrandCode` (`10b_br_misattribution.R:74-102`). If closed-list: add a validating refusal for out-of-domain codes + a comment, and log "confirmed closed". Tests either way.

**A4. Fix H5 + M1 + M2 (honesty plumbing).** H5: null role-map → run returns PARTIAL with a warnings entry; GUI surfaces it (`00_main.R:303-321`, `run_brand_gui.R`). M1: wire `guard_alchemer_parser_shape`/`guard_slot_columns_present`/`guard_per_brand_column_present` into `run_brand()` early (they're already tested), or delete + fix header — prefer wiring since tests exist. M2: output-generator REFUSED → failed/partial in the GUI, not "completed successfully" (`run_brand_gui.R:341-349,389`).

**A5. M8/M9/L1 judgment tier.** M8: `as.numeric` + refusal on non-numeric weights at `00_main.R:286`. M9: convert the GUI package-guard `stop()` (`run_brand_gui.R:29`) to console+TRS-style abort; leave the widget arg-validation `stop()`s with a comment. L1: tighten `.is_none_brand_code` (`00_data_access.R:484-492`) to not match bare "na" residue, or document the reserved codes. Log choices.

Definition of done: suite green with new tests, every ID above fixed or logged deferred, summary states what was executed. Then Duncan regens + independent Fable pre-merge review (do not share your working notes with it).

---

## 3. Session B — report/GUI fixes (`feature/brand-report-fixes`)

**B1. Fix C2 + H3 (persistence unification).** Per locked decision 4: one DOM-serializable store for ALL insight/commentary surfaces (MA `brand_ma_panel.js:1986-1996`, Audience Lens `brand_audience_lens_panel.js:87-94`, funnel/cat-buying/summary textareas, generic `.br-insight-editor`), synced on input, rehydrated on load; retire sessionStorage/localStorage. Also sweep `_brSaveReport` (`brand_report.js:182-204`) with a pre-serialize sync as belt-and-braces. Tests: extend the JS-checking tests (`test_html_report.R` pattern) to assert the store nodes exist and editors bind them; manual round-trip note for Duncan's eyeball.

**B2. Fix M3 (brand-side island hardening).** `gsub("</", "<\\\\/", json)` (or equivalent) at every brand `sprintf('<script type="application/json"...')` site — the ~14 in review M3. Test: a payload containing `</script>` round-trips. Do NOT touch `modules/shared/js/turas_pins.js` (catdriver B5 owns it).

**B3. Fix M4 interim + M7 (labels now, shared gate later).** M7: every penetration/% surface gets its denominator/definition on its face + one reconciliation callout (review §6 table is the spec; closes the deferred penetration-reconciliation item). M4 interim: apply the existing low-base flag pattern (funnel/portfolio style) to Category Buying % Buyers, MA MPen, Demographics, Branded Reach, Summary — the shared gate replaces this in Session C; keep it thin.
Also verify while in there: funnel-parity surfaces read `pen_mat_raw` not `pen_mat` where parity with funnel is claimed (`08b:140`, review §6 note).

**B4. M5/M6 hygiene.** Remove or wire `db_importance_method` (remove, absent an engine use — log it); document the six missing Settings keys in BRAND_CONFIG_GUIDE.md.

---

## 4. Session C — OPUS-0 adoption + native PPTX (`feature/brand-v2-plumbing`, GATED on OPUS-0)

Do not start until OPUS-0 (shared Kish n_eff + shared disclosure gate + TurasPins consolidation) is done and Duncan green-lights.

**C1. Fix H2.** Rewire all sig/CI closures to shared Kish n_eff: `.sig_row`/`.sig_row_against_summary` (`03b_funnel_metrics.R:598-639`), funnel CI `n_eff` (`panels/03_funnel_panel_chart.R:326`), `.ext_sig_test` (`09e_portfolio_extension.R:57`), and any sig site found by grep for the tester. Never a local formula. Tests: dispersed-weights fixture where raw-n says significant and n_eff says not.
**C2. Adopt the shared disclosure gate** everywhere B3's interim flags went; remove the per-element `portfolio_min_base`/`funnel.suppress_base` specials or make them feed the shared gate.
**C3. Retire `brand_pins.js`** (532 lines) onto shared TurasPins, then **swap PPTX export to the v2 native OOXML engine** (`14_pptx_parts.js`/`29_export.js`) replacing the screenshot path (`turas_pins_pptx.js:285,344`) — hi-DPI image fallback stays for bespoke SVG panels the OOXML engine can't express. Run the other TurasPins modules' suites.
**C4.** Log every v2 capability deliberately not adopted (AI insights, tracking, workspace views, banner dual-sig) against V2_MIGRATION_PLAN §7's drop-list, and add a short brand addendum to the plan recording the fourth-archetype route (review §8).

---

## 5. What NOT to do (any session)

- No tabs exporter, no v2 island/view, no `row.kind` additions for brand — locked decision 1.
- Do not start the Rec A clarity/IA redesign — separate effort, Duncan-scoped.
- Do not fix `modules/shared/js/turas_pins.js` here (catdriver B5 owns it); do not touch the shared TURF engine without running maxdiff tests (it has two callers).
- Do not modify OneDrive, client deliverables, or `generate_ipk_9cat_wave1.R`.
- Do not merge or push; Duncan merges after regen + eyeball.
- Do not claim the Dirichlet fix verified without running the known-answer fixture assertions you added.
