---

editor_options: 
  markdown: 
    wrap: sentence
---

# Production Review: Turas tabs module (v2 report path)

**Date:** 2026-08-04 **Branch/Version:** main \@ 31484842 (clean tree, in sync with origin/main) **Reviewer:** Claude (duncan-production-review skill; seven independent fresh-context review agents + spot verification of every CRITICAL at the cited lines) **Language/Stack:** R (crosstab engine, Shiny GUI) + vanilla JS (v2 HTML report) **Trigger:** CCPB W2026 report believed 100%; 4 new projects about to run this module.

## Verification gates

| Gate | Command | Result |
|-------------------|----------------------------|-------------------------|
| R unit/integration suite | `testthat::test_dir("modules/tabs/tests/testthat")` | PASS — 3,345 tests, 0 fail, 3 warn, **9 skip** |
| v2 JS suites (23 files) | `node <each>.mjs` in `lib/html_report_v2/tests/` | PASS — 618 assertions, 0 fail |
| Standalone JS suites (2 files) | `node <each>.mjs` in `tests/js/` | PASS — 21 assertions, 0 fail |
| CCPB W2026 report integrity | static greps + headless Chrome render | PASS — no NA/NaN/undefined leaks, 0 console errors, renders correctly |
| Markers/debug hygiene | grep TODO/FIXME/HACK/browser() | PASS — none |

Gate caveats (findings in their own right): the 9 R skips are the **entire e2e integration suite** silently skipping because `examples/` does not exist (see C6); the 3 warnings are one real code bug (M-R1).

**How to read this review.** Everything below is present in gate-green code — the suites pass *and* these defects are real, because the failing paths are exactly the ones no test covers. Every CRITICAL was verified twice: once by the reviewing agent (by execution where behavioural), once by me at the cited lines. The CCPB W2026 report itself was checked and is **not** affected by most of these (it uses default decimals, no census design, no numeric-sig reliance, and its Patterns tab shipped "no two-camp split found") — these are the traps waiting for the *next four projects*, which is what this review was for.

## Fix status (2026-08-05, branch fix/tabs-prodreview-2026-08)

**FIXED, tested and committed** (each with regression tests; full R suite
3,539 pass / 0 fail / 0 warn / 0 skip — was 3,345/0/3 warn/9 skip — and all
23 v2 JS suites green):

| Findings | Commit |
|----------|--------|
| C6 (examples/e2e gate) | 91ba92e0 — demo project restored, e2e gate live (40 tests, 0 skips) |
| C1 | a60c52f9 — numeric/allocation sig letters real; unknown row_type refuses |
| C4 (+O6 half) | 48dee71a — NPS/0-100 out of the bimodality scan |
| C5 (+I22 crash) | bfdf98fe — wave recovery inserts + reconcile never vacuous |
| C6 (templates), I8 | 644e535c — generator gains Category/CategoryOrder/Theme, templates regenerated |
| C6 (entry point/docs) | f6a67b4c — run_tabs_analysis real (verified end-to-end on the demo), docs match reality |
| C2 (+M6) | 8fafacd2 — disclosure gate holds on every workbook sheet |
| I13, I14, I15, M-R1 | cdc7e8f7 — crosstab decimals, island escaping (verified vs a real browser), named skips, sprintf |
| I4, I5, I7-I12, I16 | a59e17dd — config contract: whitelist/template/loader agree (now a TEST), junk refuses at load, sampling_method normalises, Declaration honest, swallows boxed, GUI honours explicit v2 opt-out |
| I17-I21 | 8d1eea85 — qual workbook verified not trusted; hide fails closed; 1e5 join; stale qual pins re-gate; withheld count rendered |
| I22, I23, I3 (mean half) | f757d973 — NA weights refuse, proportions weight, categories skip by name; pulse counts honestly; wave chip tests raw means (fixture verified decisive) |

**C3 — DECIDED by Duncan (2026-08-05) and implemented:** render-time
suppression is a viewing convenience; **microdata = N is the confidential
ship**. The build now prints a boxed DISCLOSURE WARNING whenever
min_reporting_base > 1 and the microdata island still ships (naming the
page-source leak and the FALSE setting), the qual source-disclosure warning
names the microdata island as a leak regardless of the tag dial, and the
operator guide + template help document the model.

**Classic-report retirement + M4/M16 (2026-08-05, on main).** The classic HTML
report is retired and deleted (`lib/html_report/`, 14 R + 9 JS files): the
loader now names `html_report` as retired instead of ignoring it, the setting
is out of the whitelist and out of `build_config_object`, and the GUI's classic
checkbox is gone. Two things were rescued from inside it first — AI-insights
generation (the v2 data layer reads the sidecar it writes; now
`lib/ai_insights_step.R`, called from run_crosstabs) and the row/palette
helpers the data layer classifies through (now `lib/report_shared.R`). The
logo-file and hex-colour preflight checks were gated on `html_report`, so they
had stopped firing for the report that ships; both are now unconditional.
**M4** dead code deleted (`write_crosstab_workbook`, `question_dispatcher.R`).
**M16** docs batch done, plus the classic report's own manuals and the stale
code inventory. Suites at that point: R 3,327 pass / 0 fail / 0 warn / 0 skip
(3,587 before the classic suites were deleted with their code); all 25 JS
suites green.

**I20 is now FIXED** (2026-08-06), to the binding design in
`I20_READER_MARK_REKEYING_DESIGN.md`. Its other half was already closed
(`qual.textPublished` re-gates every frozen qualitative pin at render,
`8d1eea85`); this is the idx→stable-key migration. Tabs R suite 3,516 pass /
0 fail / 0 skip / 0 warn (was 3,441); 27 JS suites green (26 + the new
`qual_rekey_tests.mjs`). Every part was verified to fail against the pre-fix
code first.

| Piece | What changed |
|---|---|
| **R — the token** | New `lib/qual_reader_keys.R`. `qual_reader_keys(ids, config_obj)` loads or mints an append-only `<config>_reader_keys.json` sidecar of 16-hex random per-respondent tokens, beside the config exactly like the AI-insights sidecar. Never deletes an entry (a respondent who drops out of an export and returns re-attaches to their old marks); never re-mints over an unreadable sidecar (that would orphan every mark); restores the global RNG so minting cannot shift a seeded draw elsewhere in the run. No config path, an unreadable sidecar or a failed write each degrade loudly — boxed console warning — to the pre-I20 island, so nothing ever mis-attaches. |
| **R — the island** | `rid` rides each record beside `idx` through default-NULL parameters (`qual_build_data_qual` → `qual_build_question_island` → `qual_build_record_island`). `idx` changes nowhere, so the banner filter masks still join on it. Both entry points in `qual_report.R` wire the map; the same id universe (`names(master$id_to_idx)`) keys Phase 1 and Phase 2. `rid` is uniform random, so it ships under every privacy dial. |
| **JS — keying** | One rule in `27q_qualitative.js`: `markKeyFor(qcode, rec)` → `qcode#@<rid>` when the record carries a token, `qcode#<idx>` when it does not. Shortlist, highlights and hubs all key through it; `splitMark`/`recordIndex` resolve by that ref, and a record index by `idx` is deliberately NOT kept as a fallback — a stray positional key must read as an orphan, never silently grab whoever now sits at that position. Legacy output is byte-identical (gated). |
| **JS — migration** | One `migrateMarkStore(stored, kind)` inside the three store loaders, gated on a `_v` stamp. A version-less idx store meeting a rid-bearing island is re-keyed once through that island's own idx assignment and persisted immediately with `_owns` exactly as found (migration is not a reader change); hubs rewrite only their `marks`, leaving `seq`/`order`/`name`/`insight` alone. Unresolved idx keys are dropped with one `console.info` naming the count; already-rid keys pass through untouched, so a saved copy's embedded state is a no-op. A `_v: 2` store read against a rid-less island is left completely alone — never re-keyed back toward idx. |
| **Docs** | OPERATOR_GUIDE gains "The Reader-Key Sidecar": what it is, that it must not be deleted or the config renamed, that it travels with the project, and the §3.4 one-rebuild rule — after this ships, rebuild each project once from unchanged data before the next real re-export. |

**Known and documented** (design §3.4): the shim maps old keys through the
*current* island's idx assignment, which is right precisely when the first
rid-bearing rebuild uses the same data the marks were made against. If that
first rebuild also changes the roster, legacy marks migrate to the wrong
respondents once — exactly as they would have mis-attached under the status
quo. There is no client-side detection; the operator rule is in the guide.

**I3 (proportion half), I6, I24, M12 and M14 are now FIXED** (2026-08-06,
branch `fix/tabs-prodreview-batch-2`). Tabs R suite 3,441 pass / 0 fail / 0 skip
/ 0 warn (was 3,394); all 26 JS suites green. Every fix was verified to fail
against the pre-fix code before being accepted.

| Finding | What changed |
|---------|--------------|
| **I6** | I6's own earlier fix was half-landed: `peerExtremes` indexed on `gp.code \|\| gp.title` but the single lookup still keyed on `gp.title`. Real islands always carry codes, so every lookup missed, `peerCount` was always 0, and the `peerCount > 2` gate meant "highest of N" / "leads every X" had silently stopped printing. Key construction is now one `peerKey()` used by both sides. The old test passed only because its fixture omitted `code`; the suite now covers the real island shape. The other two I6 edges were already closed — the steady-card gate rode along with the Group-overview rework, and the single-theme "weakest area" claim went with the Areas retirement. |
| **I3** (proportion) | `sigPair` rebuilt a weighted report's count from the DISPLAY-rounded cell, so a 0dp report tested 47% for anything from 46.5 to 47.5. The current point now carries `pRaw`, the exact weighted proportion `cell.n / col.baseW` — the same pair `22_model.js:367` already divides for Wilson intervals. Displayed deltas still subtract rounded ends; history keeps its published value, as the mean half left it. |
| **I24** | New `tracking_report_option_pairing()`: proportion trends pair row by row on the normalised option label alone and contribute no mean/NPS metric, so the question-level report never looked at them. Live option labels are now compared against each prior wave's `rows` keys, unmatched labels are named per question, and a total miss gets a warning box. `build_tracking_island()` takes the data layer to do it. Silent when no prior wave carries rows. |
| **M12** | Response rate clamped (a stale `population_size` printed "108% response"). The reliability ribbon's MoE now applies the FPC the crosstab base row and every interval already apply, so a census reads ±0.0pp instead of contradicting the table beneath it. A banner column that cleared no base floor contributes no cells, so it has no gate entry — that absence read as "no gate" and let the thinnest column skip the sign test every other column passed; in the fixture it ranked *first*. The exact-tie edge was already closed. |
| **M14** | Sidecar dedupe follows a recorded `built` stamp written at save time, not `file.mtime` — an mtime is when a file was last *copied*, so a stale backup used to outrank the genuine newer run; unstamped sidecars fall back to mtime and the note says which rule ran. Duplicate-title occurrence suffixes are ordered by question code, not by position, so reordering questions no longer hands each the other's history (inserting a lower-sorting code still shifts them — the warning points at `question_mapping`, the only reliable key). An ambiguous wave column now warns and names the candidates instead of silently taking the leftmost. A recovered wave's multi-mention member *columns* resolve through that wave's own structure; only NET *membership* comes from the tracking definition. |

Two things found on the way, both left alone deliberately: `test_audit_stats_fixes.R`'s
own `source()` list omits `report_shared.R`, so the file only runs under
`tools/run_all_tests.R` (which sources everything) and not via the
`testthat::test_file()` invocation its own header documents. And three failures
in Shared Infrastructure predate this batch on `main` — a module-registry count
that expects 14 against a repo with 16, and a missing `docs/adr` directory.

**I1 and I2 are now FIXED** — the cross-engine statistics batch landed on main
as `a013112d` (fractional n_eff), `049fc1c2` (Sig.2 and mean-row carriage) and
`f9ab50d4` (FPC in the R tests, published-view overlay retired), against
`CROSS_ENGINE_STATS_SPEC.md` in this folder. It also leaves behind a permanent
parity gate: a synthetic census fixture
(`modules/tabs/tests/fixtures/parity_project/`), an R suite
(`test_cross_engine_stats.R`) and a JS suite (`parity_stats_tests.mjs`) that
render the same R-generated island. Suites after the batch: R 3,508 pass / 0
fail / 0 warn / 0 skip; confidence 1,063 pass / 0 fail; 26 JS suites green. **M3** (two divergent `format_output_value` definitions,
the later-sourced one winning) was left alone deliberately: deleting the losing
copy is a behaviour change on the default branch and deserves its own check.
The `html_report` retirement entry should come out of `TABS_RETIRED_SETTINGS`
after the next release, at which point the name falls through to the ordinary
unrecognised-setting warning.

------------------------------------------------------------------------

## CRITICAL

### C1. Numeric and Allocation questions have never had working significance letters

**Files:** `modules/tabs/lib/numeric_processor.R:313-314`, `modules/tabs/lib/allocation_processor.R:265-268`, dispatch at `modules/tabs/lib/run_crosstabs.R:280-298` Both processors call `add_significance_row(…, "rating", …)`, but the dispatch accepts only `"proportion"`, `"topbox"`, `"mean"`, `"index"` — anything else returns `significant = FALSE` for every pair. The Sig row is still emitted, all blank, implying "tested, nothing significant". Present since the initial commit; no test exercises row_type "rating". **Failure:** a numeric spend question with a genuinely significant male/female difference ships an empty Sig row in Excel while the v2 report's own computed path can letter the same mean — the two deliverables visibly disagree, and clients are told "no differences" that exist. **Fix:** pass `"mean"` from both processors (the row data already carries values + weights in mean shape — verify at the call sites), add a regression test with a hand-calculated significant pair for each processor.

### C2. The Excel workbook's disclosure gate is defeated by its own summary sheets

**Files:** `modules/tabs/lib/crosstabs/workbook_builder.R:464-476` (suppression applied only in `write_single_question`), `modules/tabs/lib/excel_writer.R:1479-1515` (Index_Summary: every banner column's mean/index/top-box, no `suppressed_idx`), `excel_writer.R:1544-1555` (exact unweighted n per column at sheet foot), `excel_writer.R:1084-1090` (Sample Composition unweighted n per category), `excel_writer.R:836-845` (Summary shows a withheld Total's exact base) **Failure:** `min_reporting_base = 10`, banner column n=4. The Crosstabs sheet says "n\<10"; Index_Summary shows that column's mean and "Unweighted n: 4" three sheets away, in the same file the client receives. For the anonymity-sensitive projects (SACS-type climate studies) the k-gate is a contractual promise, and it is broken inside one deliverable. **Fix:** thread `disclosure_suppressed_columns` into Index_Summary, Sample Composition and the Summary base column; suppress the same columns there. Test: standalone workbook fixture with one sub-k column, assert no sheet in the workbook contains its statistics or base.

### C3. v2 disclosure suppression is render-time only — the withheld numbers ship in the page source

**Files:** `modules/tabs/lib/data_layer_writer.R:583-876` (no k-gate applied to question data; `min_reporting_base` carried as a display field only, :164-167), `modules/tabs/lib/run_crosstabs.R:725-731` (same values written to the `*_data.json` sidecar), `assets/js/22_model.js:590-614` (suppression happens only in the on-screen model) Related: the k-anonymised qual demographic tags are cosmetic whenever microdata ships — DATA_QUAL records carry `idx` into DATA_MICRO, which holds every respondent's banner values, so View-Source reconstructs any comment's full demographic combination regardless of the tag dial (`qual_report.R:136-141` claims "safe" modes are source-safe; `qual_quant_layer.R:37-39` maps "safe"→"allow" in the standalone qual report). Only `microdata = N` actually closes this — and the GUI **forces v2 with the microdata island on** (`run_tabs_gui.R:404`, see I16). **Failure:** a client with Excel skills (or a curious respondent's manager) opens View Source on the HTML deliverable of a k-gated study and reads the exact numbers, bases and per-comment demographics the report visibly withholds. **Fix:** this needs a design decision, not just code — either (a) apply the k-gate at data-layer build time (breaks the "analyst's own copy shows everything" behaviour, if that behaviour is intended), or (b) declare render-time suppression a viewing convenience and make `microdata = N` + a data-time gate the documented confidential-ship mode, with the source-disclosure warning naming microdata as the leak. Decide, implement, and document in the disclosure section of the operator guide.

### C4. Patterns' bimodality scan silently drops all NPS detractors, then reports a fabricated "two camps" finding

**Files:** `assets/js/27f_takeout_data.js:451-475` (`gatherBimodality` has no NPS/scale filter, unlike the cell family at :360-363; verified: binning at :467-474 computes `idx = round(v) - shift` and drops `idx < 0`), `modules/tabs/lib/score_utils.R:44-50` (NPS microdata is −100/0/+100) Detractors (−100) fall outside the bins and are discarded; passives and promoters form two lumps, which the camp detector then flags. The provenance footer prints "found: 'Recommend' splits into two camps behind a calm average" — a false statistical claim on the most common question type in the deliverable, built from a distribution missing a third of respondents. The regression test passes because its fixture encodes NPS as raw 0-10 with `scale_max: 10`, which production never emits for NPS questions. The mirror failure also holds (true detractor-heavy split reads unimodal). CCPB W2026 happened to ship "nothing held up beyond chance", so it was not tripped. **Fix:** apply the same rated-question/scale filter the cell family uses (exclude NPS-typed and \>10-point scales from `gatherBimodality`, or bin NPS on its three-value support). Fix the test fixture to encode NPS the way `score_utils.R` does.

### C5. Recovering a tracking wave that isn't in the values table is a silent no-op that reports "Clean."

**Files:** `scripts/recover_tracking_wave.R:118-134` (verified: splice loop `if (!any(hit)) next` only replaces existing rows, never inserts), `modules/tabs/lib/tracking_wave_values.R:449` (reconcile passes vacuously — `all(logical(0))` is TRUE, "0 of 0 comparable metrics reconcile … PASS") **Failure:** operator recovers a wave never typed into the values table, sees "Clean. Regenerate sidecars…", regenerates — the wave is simply absent from every trend, with an exit code of 0. This is the exact tool built for the CCPB wave-significance rebuild. **Fix:** insert rows for computed metrics with no existing (metric_id, wave) row, and make reconcile refuse (or loudly PARTIAL) when the published slice is empty. Test: recovery against a values table without the target wave asserts the rows appear.

### C6. The path the four new projects will actually walk is broken: stale template, fictional docs, dead entry points, and a skipped e2e gate

**Files/evidence (each verified by execution or openpyxl inspection):** - `modules/tabs/templates/Crosstab_Config_Template.xlsx` — \~5 weeks stale vs the generator. Missing from Settings: the entire QUALITATIVE section (`qual_workbook`, `qual_confidentiality_mode`, `qual_demographic_cuts`, `qual_noteworthy_default`, `qual_verbatim_scope`, `qual_tag_dimensions`, `qual_join_id_column`), PATTERNS (`patterns_exclude_banners`, `patterns_headline`), READER (`generate_reader_report`, `reader_ai_prose`), `sampling_note`, `min_reporting_base`, `html_report_v2_microdata`, `show_weighted_base`. Comments sheet lacks the `Headline` column; Selection lacks `KeyShare`, `AreaSummary`, `SplitDimension`, `NpsScoreQuestion`. - **Regeneration trap:** `generate_config_templates.R` Selection sheet omits `Category`/`CategoryOrder`/`Theme`, which the engine reads (`data_setup.R:237`) and v2 grouping uses — regenerating templates today would *lose* the category columns the shipped template has. Fix the generator before regenerating. - `OPERATOR_GUIDE.md:126,139-153` — tells projects to copy from `examples/{module}/`; **no `examples/` directory exists anywhere in the repo**. This is also why the 9 e2e tests skip: the demo project they load is gone, so the only end-to-end gate never runs. - `modules/tabs/run_tabs.R:77-85` — `run_tabs_analysis()` is a placeholder that prints fake progress and "Analysis complete!" **without computing anything**; docs present it as the scripted entry point (`README.md:15-22`, `docs/07_EXAMPLE_WORKFLOWS.md:94-96`), alongside `source("turas.R")` which references a file that doesn't exist. **Failure:** a new project set up from the shipped template has no visible surface for any feature added since late June; a project following the written docs dead-ends or, worse, gets a fabricated success message. **Fix:** (1) add Category/CategoryOrder/Theme to the generator's Selection sheet; (2) regenerate and commit both templates; (3) delete or implement `run_tabs_analysis` — a placeholder that prints success is a TRS-philosophy violation in its purest form; (4) restore a small `examples/tabs/demo_survey/` (also un-skips the e2e gate); (5) correct the operator guide's entry-point sections.

------------------------------------------------------------------------

## IMPORTANT

### Statistical honesty and cross-output agreement

**I1. FPC parity gap (previously suspected — now confirmed open). FIXED — `f9ab50d4`.** The R/Excel engine had no FPC anywhere (zero callers; FPC existed only in template help text, `generate_config_templates.R:526`). The v2 report narrowed intervals and re-lettered significance on the FPC-corrected base (`22_model.js:371`, `21c_confidence.js:186-210`). A census project showed different sig letters in Excel vs HTML. *Fixed by putting the correction in R and taking it out of the report:* `calculate_fpc_factor()` / `apply_fpc()` / `FPC_MIN_COVERAGE` moved unchanged from the confidence module to `modules/shared/lib/fpc.R`; `weighted_z_test_proportions()` and `weighted_t_test_means()` gained `fpc_mul1`/`fpc_mul2` (default 1, so a report with no population is unchanged); a full-census column is excluded from pairing; `min_base` gates on the corrected base; the NET path passes the same multipliers; weighted studies are corrected too, closing the FPC plan's own out-of-scope gap. The v2 published-view re-lettering overlay (`applyFpcSignificance`) is deleted — it worked from display-rounded percentages and was gated off for weighted designs. FPC intervals, `ciBase`, coverage-aware low-base flags and the PUBLISHED·FPC badge all stay. The stats pack Declaration now states the universe, the coverage and the correction. *Known uncorrected paths, left deliberately:* two callers of `weighted_t_test_means()` outside the crosstab dispatch keep the inert default of 1 — composite (profile) metrics (`composite_processor.R:871`) and ranking mean-rank tests (`ranking/ranking_metrics.R:451`). Neither has a per-column universe to correct against in its current shape, and the default is a no-op rather than a silent half-correction. On a census project their letters are the uncorrected ones; correcting them is a follow-up, not a regression.

**I2. The two significance engines can diverge on weighted studies. FIXED — `a013112d` (n_eff), `049fc1c2` (Sig.2 carriage).** R mean tests used integer-rounded Kish n_eff (`weighting.R:400-401`) with population variance; v2 uses unrounded effBase with n−1 scaling (`21_stats.js:378,96`). Within R itself, proportions got fractional effective bases (`cell_calculator.R:600`) while means got rounded ones — n_eff 29.6 failed min_base 30 for proportions but passed for means. v2's 80% (Sig.2) letters were recomputed from published integer-rounded counts (`22_model.js:94-103`) while R tested unrounded counts. *Fixed:* `calculate_effective_n()` returns the fraction (display sites round at format time), so means and proportions gate on the same base and R matches the JS engine; and the data layer carries the workbook's `Sig.2` row verbatim as `sig2`, from which the report derives its lowercase letters as `sig2` minus `sig` — no recompute, no rounding trap. Mean rows carry letters for the first time, at both alphas (they were tested in R and blank in the report). Islands without `sig2` keep the old recompute as a fallback.

**Residual divergence, bounded and documented (spec D6).** Under live filters and custom banners — where there is no R counterpart to disagree with, and the view is badged *computed* — the JS engine keeps `meanZ` as a z-test where R runs a Welch t, keeps sample-variance scaling `effBase/(effBase-1)` where R uses population variance, and pools weighted proportions on effective bases where R pools on weighted counts. The parity harness pins exact agreement on proportions and asserts the mean divergence only outside a documented band (`parity_stats_tests.mjs`, JS-2 / JS-3). Aligning the mean test is an optional follow-up, not part of this batch.

**I3. The wave-strip significance chip tests display-rounded values — the known rounding trap, live.** `22w_waves.js:545-558` feeds the published (rounded) cell into the wave-on-wave test; for weighted reports the count is reconstructed from the 0dp-rounded percentage. The Tracking tab recomputes from microdata and can disagree with the crosstab chip on the same movement. Aggregate history stored at 1dp has the same exposure, unwarned (`22w:379-390,497-501`). *Fix: put raw values on the wave contribution (as the tracking tab already consumes) and feed `attachDeltas` from them.*

**I4. The stats pack Declaration misstates the run.** `stats_diagnostics.R:67` reads `config_obj$min_base` (real key `significance_min_base`) → "Minimum Base Size: 30" always, whatever the config said. `:101` reads `config_obj$ai_insights` (real key `enable_ai_insights`) → "AI Insights: Disabled" even on AI-on runs — wrong on the exact disclosure line being standardised. `:40,107-108` read never-populated keys → "Source file: unknown". *Fix: read the real keys; test asserts the Declaration echoes a non-default config.*

**I5. `sampling_method` is never validated and is exact-match end-to-end.** A config typing `stratified`, `Simple Random`, or `Stratified sample` silently becomes `not_specified`: the whole report switches to non-probability "stability intervals" vocabulary, the sig legend softens, the ribbon reads "Not specified sample" — for a genuinely probability-sampled study, no warning (`data_layer_writer.R:62-63`, `21c_confidence.js:42-47`). *Fix: validate against the known tokens in the loader; refuse or warn loudly on anything else.*

**I6. Patterns overclaims on three edges** (each reproduced in node): a *polarized* group whose ups and downs cancel gets the "steady … nobody's problem child" card (`27e_takeout_engine.js:602-630`); a study with one tagged theme gets "X is the weakest area — its questions cluster low" in a race of one, even at 4.55/5 (`27e:355-383`); duplicate question titles merge in `peerExtremes` (keyed on title, not code — `27e:155-167`), producing "highest of 6" in a 3-column banner and contaminated "leads every…" claims. *Fixes: gate the steady card on gap magnitude, require ≥2 themes (or drop the "weakest" framing) and speak `raceSize`, key peers by question code.*

### The config contract

**I7. The whitelist commits didn't close the gap — 8 live settings are missing from `TABS_KNOWN_SETTINGS`** (`crosstabs_config.R:305-325` vs :887-952; programmatic diff): `show_dashboard/patterns/differences/tracking/qualitative`, `patterns_headline`, `patterns_exclude_banners`, `sampling_note`. A fresh template config is *warned at* for three settings that work ("Unrecognised … will be ignored" — the loader lies), and the merged-row/case diagnostics — built for exactly the CCPB failure mode — are blind to all 8.

**I8. The template still writes three settings in a case the loader can't read:** `Generate_Stats_Pack`, `Project_Name`, `Analyst_Name` (`generate_config_templates.R:636,672,675`; loader lookups are exact lowercase). `Generate_Stats_Pack = N` does not stop the stats pack (defaults Y, `run_crosstabs.R:1045-1047`); every new config warns on load out of the box.

**I9. The whitelist blesses \~10 settings no code can honour** (typo check passes, value ignored): `create_index_summary` + four `index_summary_*` (read via `get_config_value` from `config_obj`, which never carries them), `ranking_*_threshold_pct`, `significance_level` (real key is `alpha`), bare `decimal_places`, `weight_*_threshold`/`default_weight`, `project_name` (see also I4's family). *Fix for I7-I9 as one batch: make `TABS_KNOWN_SETTINGS`, `build_config_object`, and the template generator agree — ideally derive the whitelist and the template from one settings registry so they cannot drift again.*

**I10. A junk or literal-"NA" cell silently flips \~20 default-TRUE toggles to FALSE.** `safe_logical` falls back to ITS OWN default (FALSE) on unconvertible input; the true default is passed through only for `html_report_v2_microdata` (`crosstabs_config.R:235-236` — whose comment names this exact hazard). A stray "NA" in `enable_significance_testing` removes all significance from the deliverable with one console line. *Fix: pass each setting's real default into `safe_logical`/`safe_numeric` everywhere (mechanical, one file).*

**I11. Primary `alpha` (and `significance_min_base`, `decimal_places_*`) are never validated.** Junk (e.g. European "0,05") → NA → hard error deep in `weighted_z_test_proportions`, re-branded by the orchestrator as per-question DATA\_ refusals — a config fault reported as a data fault for every question (`crosstabs_config.R:186`, `weighting.R:806`). NA decimals → `round(x, NA)` → blank cells. *Fix: validate numerics in the guard with a CFG\_ refusal naming the cell.*

**I12. Two production tryCatch swallows.** A composite that errors is cat-warned and dropped while the run stays PASS (`composite_processor.R:839-844`) — a contractual metric silently absent. A malformed Population sheet is swallowed → FPC silently off (`crosstabs_config.R:612-615`). *Fix: PARTIAL status + refusal-style console box for both.*

### v2 pipeline integrity

**I13. The Crosstabs tab and its exports ignore the config's DECIMAL PLACES** — `fmtPct`/`fmtMean` hard-code 0dp/1dp (`23_render.js:103-108`, verified; used by the table and the clipboard/XLSX/PPTX matrix at :380) and `fmt.toDisplay` has zero callers (verified). With default configs the visible symptom is NPS rows showing "79.0" where the published table holds 79; with `decimal_places_percent = 1` the workbook says 46.3% while the v2 crosstab says 46%. 0484ac4f fixed the tracking-family tabs only. *Fix: route these two formatters through `fmt.toDisplay`; the suite already has the harness.*

**I14. A verbatim containing `<!--` followed by `<script` breaks island embedding — worst case a fully blank report.** `escape_island` (`build_report_v2.R:88`) neutralises only `</`. Verified against a spec-accurate parser: the sequence enters the script double-escaped state and swallows the next island — poison in DATA_QUAL (respondent text; someone pasting an HTML email template is enough) swallows the `{{JS}}` tag: renderer never runs, blank page, no error. *Fix: also escape `<!--` (and `<script`) in `escape_island`; add the poison string to the bundler test.*

**I15. A question can silently disappear from the v2 report while remaining in Excel.** `build_dl_question` returns NULL on a malformed/empty table and `build_data_layer` skips it with no console output (`data_layer_writer.R:585-587`, :1024-1028) — only the all-questions case refuses. *Fix: name each skipped question on the console like the broken-link path already does (:1080).*

**I16. The GUI unconditionally forces v2 + microdata island on** (`run_tabs_gui.R:404` sets `TURAS_HTML_REPORT_V2 = TRUE`, overriding `html_report_v2 = FALSE`), while docs claim "v2 is additive and off by default". Given C3, this makes the confidentiality-relevant default invisible. Also: `detect_config_files()` pre-selects `Survey_Structure.xlsx` as a runnable config (`run_tabs_gui.R:80-91,154,186`) — a fresh project's first click produces a spurious failed run. *Fix: honour the config's v2/microdata settings in the GUI; exclude structure files from config detection.*

### Qual workbook round-trip

**I17. The analyst-workbook reader trusts shape, not names, in dangerous ways** (each reproduced): the verbatim-column fallback picks the *longest-text* column — an added "working notes" column ships as respondent quotes (`qual_workbook_reader.R:145-155`); an extra 1/2/3-coded column right of the verbatim becomes a theme (:194-205); a blank ResponseID keeps the record then silently drops it from every output (:311 + `qual_island_builder.R:250-252`); a duplicated ResponseID shares one `idx`, inflating bases and colliding reader marks (:250-261). *Fix: refuse on blank/duplicate IDs and unrecognised extra columns; require a header match for the verbatim column (fallback → refusal, not guess).*

**I18. The hide mechanism fails open.** `QUAL_HIDE_MARKERS` is exact-match inside a column where *any other non-blank value promotes the comment to noteworthy tier 1* — "hide!", "hid", "hide this one" make the comment MORE visible; a renamed Noteworthy header silently drops every hide/tier mark (`qual_workbook_reader.R:49,283-301,25`). *Fix: refuse on unrecognised markers (there is a small closed vocabulary); report expected-vs-found hidden counts.*

**I19. The ResponseID join breaks silently on numeric IDs ≥ 1e5.** `as.character()` on a double ID column yields "1e+05" vs the workbook's "100000" — those respondents' comments silently unjoin while the run stays PASS (`qual_assemble.R:178,330`; reproduced). *Fix: `format(…, scientific = FALSE, trim = TRUE)` on both sides; test with 6-digit IDs.*

**I20. Reader marks and hub pins are keyed by positional `idx` and survive rebuilds in localStorage.** Re-export the data with one respondent added/removed and shortlists/highlights/hub memberships silently re-attach to *different respondents' comments* (`27q:463,532,946`; `qual_assemble.R:45-53,177-184`). Hub-exhibit pins additionally freeze verbatim text into the snapshot, so a disclosure-tightening rebuild (new hide mark, mode full→hidden) does not reach pinned quotes — Story, present mode and the PPTX quote slide still carry the withheld text (`27q:1082-1093`, `30_story.js:21-60,730-736`), while priority pins re-resolve on every render precisely to avoid this. *Fix: key marks by ResponseID (stable), and make hub exhibits re-resolve like priority pins do (or stamp a data-version and orphan the pin on mismatch).* — **FIXED** (both halves): pins re-gate through `qual.textPublished` (`8d1eea85`); marks now key on a persisted random `rid` token, with a one-time localStorage migration. ResponseID itself is deliberately *not* embedded — the island is readable in View-Source, so a shipped id would rejoin an "anonymous" comment to a named respondent. See the summary table above and `I20_READER_MARK_REKEYING_DESIGN.md`.

**I21. dc94b822's withheld-from-collection count is computed but never rendered** (found independently by two reviewers): `collectPool` returns `withheld`, the collection cover surfaces only `orphans` (`27q:810-825` vs :2034-2036) — a shortlisted comment withheld by a rebuild silently vanishes, the exact failure the commit set out to fix; its test asserts only the counter. *Fix: render the count on the cover; extend the test to the rendered cover.*

### Tracking recovery + display honesty

**I22. `tracking_wave_values.R` fails wrong on four edges** (each reproduced by execution): NA in the weight column → every mean/NPS metric NA under PASS, then reconcile crashes with a bare R error (:155-169,315,449); the `weights` argument is silently ignored for proportions/multi-mention — raw counts, wrong answer for weighted waves (:214-240); reconcile crashes when exactly one computed metric lacks a published figure (unique NA row-name; :427-434 — the shipped test passes because three missing names collide and get discarded); an unresolvable `category:<label>` (typo, or NET label without BoxCategory tags in the supplied structure) computes 0% under PASS instead of skipping (:91-101,232-240). *Fix: refuse on NA weights; weight the proportion paths; make reconcile robust to missing publishes; unresolved category → named skip. The header already promises all four behaviours.*

**I23. The tracker summary counts untested metrics as "stable" and labels untested cells "not significant".** The pulse bar's stable count is `all − up − down − soft` with no testability check (`27u_summary.js:266-268,304`) — a no-SD history renders "0 increases · 0 decreases · N stable". Matrix tooltips append "· not significant" without consulting `tested_prev` (`27u:233-235`), a false statement when no test ran. *Fix: subtract untested metrics into their own count ("N not testable this wave") and gate the tooltip wording on `tested_prev`.*

**I24. Option-level wave matching is silent.** Rows pair by normalised label only; a renamed option (or NET member) silently truncates that trend (`22w_waves.js:135-143,435-445`); the build-time pairing report checks question level only and only for mean/NPS metrics — proportion trends have no pairing check at all (`tracking_island.R:261-294`). *Fix: extend the pairing report to option level, or at least print unmatched-label counts per question.*

------------------------------------------------------------------------

## MINOR

- **M-R1.** `sprintf("every one is", n_down)` — extra argument warns on every all-items-down reader report (`reader_report/derive_reader_model.R:267`; the 3 suite warnings). Drop the argument.
- **M1.** Base-row toggles asymmetric between Excel and v2 (`show_weighted_base` ignored by Excel; unweighted base unconditional in v2). Half-rounding differs on exact .5 bases (R half-to-even vs JS half-up).
- **M2.** Uncategorised questions: Excel folds into "Other" at first occurrence; v2 appends last — different orderings.
- **M3.** Two divergent `format_output_value` definitions (`excel_utils.R:118-151` vs `run_crosstabs.R:521-538`); the later-loaded one wins. Delete one.
- **M4.** Dead code with sharp edges: `write_crosstab_workbook` (`excel_writer.R:92-149`, no suppression) and `question_dispatcher.R` (no callers, latent NULL crashes) — both uncalled; remove or guard.
- **M5.** v2 pivot keeps first row per (label, source, type) — duplicate option labels show both rows in Excel, one in v2 (`data_layer_writer.R:619-627`).
- **M6.** `extract_composite_rows` references `comp_def` outside its NULL guard (`summary_builder.R:303`) — crash-shaped, loud.
- **M7.** Dual-alpha: composite rows never get a Sig.2 row (`composite_processor.R:762`).
- **M8.** Excel proportion sig letters silently vanish when `show_percent_column = N` (`standard_processor.R:225`).
- **M9.** Junk `significance_min_base` → island `low_base_threshold` null → all low-base ⚠ flags silently gone in v2 (`type_utils.R:94-97`, `data_layer_writer.R:144,722`); same silent-NA path drops dashboard questions on junk `dashboard_scale_*`/`gauge_*`.
- **M10.** `decimal_places_index` carried on the island, read by nothing; 0-100 declared rating scales take percent decimals via the `scale_max === 100` NPS proxy (`01_format.js:82`).
- **M11.** A Selection Category named `constructor`/`toString`/`valueOf` crashes the v2 boot (`20_data.js:180-188` plain-object membership test).
- **M12.** Patterns: exact tie at top still crowned "highest of N" (`27e:162-163`); reliability ribbon can print "\>100% response" (unclamped, `27f:312`); one empty banner column silently removes that banner's sign-test gate (`27f:393` + `27e:240`); census ribbon MoE ignores the FPC the rest of the report applies (`27g:423-425`).
- **M13.** Qual: priority-pin tag gate counts records, hub gate counts respondents — different privacy units (`27q:351-353` vs :1032-1036); band reconciliation silently no-ops when the score question is a composite (`qual_unions.R:227-229`); openxlsx turns a literal "NA" verbatim cell into a missing cell (`qual_workbook_io.R:25`).
- **M14.** Tracking: sidecar dedupe by mtime — a copied stale sidecar beats the genuine newer one (`tracking_island.R:396-399`); occurrence-suffixed duplicate titles swap histories on reorder (:154-171); wave-column detection ties to the first column (:107-116); multi-mention member columns for a recovered wave mapped via the *current* wave's structure (`tracking_wave_values.R:112-124`).
- **M15.** `microdata_writer.R:249` falls back to `config_obj$weighting_variable` — a key that has never existed; `reader_ai_prose.R:255` reads unsettable `ai_provider`.
- **M16.** Docs corrections batch (from the cold-start pass): broken README doc links and stale version stamps; `output_format = csv` documented but no CSV writer exists; "-" convention for `structure_file` documented but unhandled; fabricated APIs in the user manual (`modify_config`, `result$validation$has_errors`); template-generation snippet writes a junk-named file (directory passed to a file-path function); "the output file opens automatically" false; sheet-count claims wrong; `*_report_v2.html` vs actual `*_report.html`; "Tabs doesn't process open-ended verbatims" stale; GUI `input$client_name` read but no such input exists.

## OBSERVATIONS

- **O1.** The data-layer sidecar and the embedded island are built twice and drift (sidecar always `tracking_enabled = FALSE`, no diagnostics/echo/qualLinks) — the stated future wave-tracking input inherits the poorer twin (`run_crosstabs.R:725` vs :748).
- **O2.** Corrupt non-agg islands (PREV/QUAL/MICRO) degrade with zero diagnostics — indistinguishable from "not configured" (`24_shell.js:96-99`).
- **O3.** The crosstabs-footer significance callout (open item) is not a double render; it is redundancy with the shared ⓘ legend (`25_cards.js:648-660`). Cosmetic.
- **O4.** microdata=N degrades as designed (disclosure fails closed — verified `21d_disclosure.js:44-48`), but a microdata=N wave writes no `*_wave.json` and is permanently absent from future trend history; console-only announcement.
- **O5.** The k-anon cache key separators in `qual_island_builder.R:197` are raw `\x01`/`\x02` control bytes — invisible in editors and diffs; a reformat could silently strip them into a key collision. Use `""` escapes.
- **O6.** Patterns: dead card paths from the rebuild (`badgeHas`, `oddRow`, `bimodalRow`) with one latent display bug inside; `gatherBimodality` also scans 0-100 composites where the camp gate is meaningless.
- **O7.** `meanZ` uses a normal-z on the Welch SE without Satterthwaite df — slightly liberal near the 30 gate (`21_stats.js:458-464`).
- **O8.** Other ingest routes (classic tracker, segment bridge) still drop dispersion unconditionally — the same values table tests through the tabs aggregate bridge but stays untested elsewhere.
- **O9.** Verified-safe list worth recording: FilterLabel end-to-end (NA-guarded, escaped); old-config compatibility for every new key (whitelist defaults + null-guarded JS reads); KeyShare %/mean separation and NET exclusion; the census/FPC *gating* vocabulary in all four surfaces; hidden qual text never enters the island (cannot leak via drawer/pins/hubs/exports); k-gate honoured by drawer/board/crosstab/export/collection; PPTX/SVG quote escaping; formula-injection and illegal-XML handling in both Excel paths; the island `{{TOKEN}}`-in-data defusal.

------------------------------------------------------------------------

## Verdict

**DEPLOY WITH CONDITIONS.**

The CCPB-shaped path — GUI launch, default decimals, non-census sample, curated qual workbook, no tracking recovery — is genuinely solid: 4,000+ gate assertions pass, the shipped report renders clean, and the reviewers' many probes of that path came back verified-safe (O9). But the review found six CRITICALs, and they cluster exactly where the four new projects will differ from CCPB: fresh configs built from a stale template (C6), any numeric/allocation question expecting significance (C1), any confidentiality-gated deliverable (C2/C3), any NPS study whose Patterns tab finds a "split" (C4), and any tracker needing wave recovery (C5). None of these is visible from the gates — every one lives on a path no test covers.

Conditions before the first new project: fix C1, C4, C5 and the C6 template/generator batch (mechanical, low-risk); decide the C3 disclosure model and apply C2; then take the IMPORTANT config-contract batch (I7-I11), which is what makes a *new* config trustworthy. The remaining IMPORTANTs can be scheduled by which of the four projects has qual, tracking, weighting, or a census frame.
