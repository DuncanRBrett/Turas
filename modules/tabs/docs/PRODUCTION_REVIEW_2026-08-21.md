# Production Review: Turas Tabs Module (with integrated tracking)

**Date:** 2026-08-21
**Branch/Version:** local main @ 59b17ad9 (engine version string: 10.8.1 — but see I-2)
**Reviewer:** Claude (11 independent review agents + parent verification; every CRITICAL and
IMPORTANT below was re-verified line-by-line by the parent session before inclusion)
**Language/Stack:** R (~39k lines source) + vanilla JS report renderer (~20k lines) + testthat/node suites
**Scope:** the whole tabs module, the report v2 renderer, the callout/authored-text system, the
offline tracking bridges, and (because the brief's weighting risks live there) modules/weighting.

---

## Verification gates

| Gate | Command | Result |
|------|---------|--------|
| R test suite | `testthat::test_dir("modules/tabs/tests/testthat")` | **5041 pass, 1 ERROR, 1 skip, 150 warnings** — the error is a stale test fixture, not a production bug (I-6); the 150 warnings are two benign tibble column accesses (M-19) |
| Node suites (report v2) | `node <each>.mjs` in `lib/html_report_v2/tests/` | **35/35 suites green, zero failures** (37/37 counting the two run individually by agents) |
| Qual suites (subset re-run) | 11 `test_qual_*.R` files | 589 pass / 0 fail |
| Config contract | `test_config_contract.R` | 57 pass / 0 fail |
| Lint | not run | no lintr config in the module; running it cold on 39k lines produces noise, not signal — recorded as not-run, not as pass |

The suite being red on exactly one test — and that test being the C1 regression pin for a past
silent-wrong-output bug — is itself a finding (I-6): a permanently red gate trains a solo
maintainer to ignore red.

---

## Fix status (updated 2026-08-21, after the fix pass)

Fixes landed on branch `fix/tabs-production-review-2026-08-21`, commit `6e3bceff`.
**Suite after fixes: 5077 passing, 0 failures, 0 warnings, 1 skip; 36 node suites green.**
(Before: 5041 passing, 1 error, 150 warnings.)

| Finding | Status |
|---------|--------|
| C-1 checkpoint resume | **FIXED** — fingerprint + discard-with-reason; cleanup moved after the save; 21 new behavioural tests |
| I-1 misleading refusal messages | **FIXED (messages)** — fail-fast kept deliberately; dead branches marked |
| I-2 version stamp | **FIXED** — `TABS_ENGINE_VERSION` captured before sourcing |
| I-3 dangling sig letters | **FIXED** — + `hidden_columns_tests.mjs`, confirmed failing pre-fix |
| I-4 saveCopy escaping | **FIXED** — one-line escape parity with the build side |
| I-5 allocation letters in v2 | **FIXED** — + 4 tests, probe-confirmed pre/post |
| I-6 red gate test | **FIXED** — fixture given both flags; suite green |
| I-7 tracking mapping whitespace | **FIXED** — trim + name unmatched codes |
| I-8 null-year wave | **FIXED** — priors dropped with a warning; current wave never dropped |
| I-9 discarded Kish eff_n | **OPEN** — needs the sidecar rebuild (see growth path step 3) |
| I-10 silently unweighted wave | **FIXED** — one warning per wave |
| I-11 missing union member | **FIXED** |
| I-12 "safe" cuts with k=1 | **FIXED** — declares "allow" and says why |
| I-13 NO_ID_COLUMN silent fallback | **FIXED** — + a catch-all for any non-PASS status |
| I-14 duplicate host ResponseID | **FIXED** |
| I-15/I-16 allocation sums, blank policy | **OPEN** — needs Duncan's policy decision (blank = zero?) |
| I-17/I-18 ranking sentinels, significance | **OPEN** — changes published numbers; needs a decision |
| I-19 large-file BOM bypass | **FIXED** — routed through the standard loader |
| I-20 unknown Variable_Type | **WITHDRAWN — false finding** (see below); message improved |
| I-21 GUI error visibility | **FIXED** — both streams captured; toggle globals cleared |
| I-22/I-23 weighting module dead preflight, unreachable opt-ins | **OPEN** — separate module, deliberately out of scope for this pass |
| I-24 dead guard/validation layers | **OPEN** — deletion of ~1500 lines; wants its own reviewed change |
| I-25 inert settings | **PARTIALLY FIXED** — `alpha_default` wired end to end (and gated so it only applies when a secondary level is actually configured); the three weight thresholds documented as fixed rather than configurable. **Still open:** the `output_format` validator still reads `config_obj`, so both its warnings remain unreachable and a `csv` row is still ignored with no signal; the `significance_level` deprecation shim is still dead; and the contract test still gates only builder-reads ⊆ whitelist, not whitelist ⊆ actually-consumed |
| I-26 filter `enclos` | **OPEN** — behaviour change; grep live configs first |
| I-27 docs | **FIXED** — testing section, phantom files, deps, GUI snippet, 3 plan statuses, new INDEX.md |
| I-28 ReportText silent degrade | **FIXED** — refuses, with the refusal re-signalled past the outer handler |
| M-11 checkpoint cleanup order | **FIXED** (with C-1) |
| M-18 dead writer / duplicate formatter | **DOCUMENTED in place** — both have test callers, so deletion was not the safe move |
| M-19 150 tibble warnings | **FIXED** — `[[ ]]` access; suite warnings now 0 |

Everything still marked OPEN is either a decision only Duncan can make (I-15 to
I-18), a behaviour change needing a survey of live configs (I-26), or a
deliberately-scoped-out module (I-22/I-23) or large deletion (I-24).

---

## Verdict up front

**DEPLOY WITH CONDITIONS.** The statistical core is in genuinely strong shape: the two-proportion
and Welch machinery, Bonferroni scoping, FPC, letters alignment, the R↔JS parity gate (hand-derived
p-values, exact letter vectors, pinned island), the reconciling workbook saver, the JSON island
escaping, and the callout/authored-text system all survived adversarial reading and probing. The
CCPB outing plus the 2026-08 review discipline shows: reviewed decisions carry their incident IDs in
comments, refusals are loud, and the test suites are specific rather than vacuous.

The conditions: **one CRITICAL** (checkpoint resume, C-1) that should be fixed before the next real
project run, and a recurring **silent-degradation pattern** — roughly a dozen places where bad or
unexpected input quietly downgrades the output instead of refusing (tracking mapping typos, missing
weight columns, qual union typos, allocation sums, ranking sentinels, unknown Variable_Type). None
of these produced a wrong number at CCPB because CCPB's inputs were clean; each is a first-project
trap for VAS 2026, ASSA, or SACS. The third condition is documentation: `05_TECHNICAL_DOCS.md`
actively misleads (I-28) and two large validation layers are dead code that testifies to being alive
(I-24).

---

## CRITICAL

### C-1. Checkpoint resume can silently merge results from a different config or stale data
**File:** `lib/crosstabs/checkpoint.R:29-44` (save), `:55-73` (load), `:144-146` (path);
`lib/crosstabs/analysis_runner.R:557-583` (resume); default ON at `lib/crosstabs/crosstabs_config.R:200`.
**Verified by parent session.**
`save_checkpoint` stores only `results`, `processed`, `timestamp`. `load_checkpoint` validates
nothing beyond readability. The filename is a constant `.crosstabs_checkpoint.rds` per
`project_root/output_subfolder`, and `enable_checkpointing` defaults TRUE.
Two failure scenarios:
(a) a run dies mid-way (any per-question refusal does this — see I-1), the operator edits the config
or data and re-runs: the resume seeds results computed under the OLD config/data and skips those
questions, so the workbook silently mixes two vintages;
(b) two configs sharing an output folder (the GUI explicitly batches configs from one folder,
`run_tabs_gui.R:388-564`) share one checkpoint file — config B can resume config A's numbers. If the
configs differ only in weighting, the wrong numbers are invisible.
**Fix:** stamp config path + config mtime + data mtime + a hash of banner/selection into the
checkpoint; on load, discard with a console note on any mismatch; include the config filename in the
checkpoint filename. Move `cleanup_checkpoint` (currently `analysis_runner.R:596-599`, before the
workbook exists) to after the save succeeds. Interim mitigation until fixed: set
`enable_checkpointing = N` on multi-config projects.

---

## IMPORTANT — silent wrong/missing output (fix before the next real project)

### I-1. Per-question "skip" machinery is dead; refusal messages promise the opposite of what happens
**File:** `lib/question_orchestrator.R:773-858`; `modules/shared/lib/trs_refusal.R:232-249`.
The question loop has no tryCatch; every `tabs_refuse` inside `prepare_question_data` /
`process_single_question` is a `stop()` that kills the whole run — yet six refusal messages say
"This question will be missing from output, producing incomplete results". The `is.null(...)` skip
branches at `:809-818` and `:828-837` are unreachable. This also produces the stranded checkpoints
that C-1 then mis-resumes.
**Fix:** either wrap the two calls in `tryCatch(..., turas_refusal = ...)` and route into
`skipped_questions` (making the messages true), or keep fail-fast and rewrite the six messages.
Pick one; today the code says both.

### I-2. Every deliverable stamps engine version "10.1", not "10.8.1"
**File:** `run_crosstabs.R:25` vs `shared_functions.R:29`, `validation.R:43`, `weighting.R:33`,
`ranking.R:52`. **Verified by parent session.**
`run_crosstabs.R` sets `SCRIPT_VERSION <- "10.8.1"` then sources four files that each reassign it.
The start banner, workbook `script_version`, diagnostics payload, and stats-pack header all stamp a
three-years-stale version. Provenance-class bug.
**Fix:** rename the module-file constants (nothing reads them as `SCRIPT_VERSION` downstream), or
capture `TABS_VERSION <- SCRIPT_VERSION` before line 166 and stamp that.

### I-3. Hiding a column leaves significance letters pointing at it — on screen and in every export
**File:** `lib/html_report_v2/assets/js/22_model.js:561-572` vs the correct pattern at `:619-643`.
**Probe-confirmed on the parity fixture; verified by parent session.**
`applyHiddenColumns` drops the column and cells but never strips its letter from surviving cells'
`sig` strings — `applyDisclosureSuppression` does exactly that strip for suppressed columns. Hide
column Gamma (letter C) and cells still render "▲C" in the table, clipboard, XLSX and PPTX with no
column C to point at.
**Fix:** in `applyHiddenColumns`, collect dropped letters and apply the same case-insensitive strip
regex the disclosure path uses.

### I-4. `saveCopy` island escaping is weaker than the build-time escaping it mirrors
**File:** `lib/html_report_v2/assets/js/32_report.js:504` vs `build_report_v2.R:139-148`.
**Verified by parent session.**
The build side escapes every `<` as the JSON escape `\u003c` because `<!--` + `<script` inside an island blanks the
report (your own documented I14 incident, triggered in production by a pasted HTML email). `saveCopy`
escapes only `</`. An analyst pasting HTML-mail content into an Insight box or added slide, then
Save-copying, can ship a blank file to the client.
**Fix (one line):** `.replace(/</g, "\\u003c")`.

### I-5. Multi-option Allocation questions: sig letters in Excel, none in the v2 report
**File:** `lib/data_layer_writer.R:704-714` (`mean_sig_for`) + `lib/report_shared.R:263-272`
(RowSource forward-fill). **Probe-confirmed (1 option keeps letters, 3 options drop all);
verified by parent session.**
Every allocation option's mean row is `RowSource="summary"`, the forward-fill marks each Sig. row
"summary" too, and `mean_sig_for`'s "exactly one sig row per summary block" guard then carries
nothing. This is the same Excel/report disagreement class the D1 work closed for numeric questions.
VAS 2026's wallet questions (6 members) hit this if sig testing is on.
**Fix:** give allocation sig rows their own RowSource, or match summary sig rows by forward-filled
label when more than one exists.

### I-6. The red gate test is a stale fixture — and 21 sibling config reads share the crash pattern
**File:** `tests/testthat/test_sig_row_dispatch.R:126-141` (fixture) vs `lib/numeric_processor.R:426`;
registered default at `lib/crosstabs/crosstabs_config.R:217`. **Reproduced and root-caused by two
agents independently; verified by parent session.**
`make_config()` predates the `show_numeric_sd` setting (added 2026-08-14), so `if (config$show_numeric_sd)`
dies on NULL. Production is safe — `build_config_object` defaults it TRUE — but the fixture crash is
the live demonstration of a systemic contract: 21 bare `if (config$...)` sites across the two
processors (`numeric_processor.R:246,263,370,394,426,445,446,469,587,594,638,643`;
`standard_processor.R:204,217,227,335,429,447,692,1156,1202`) crash identically whenever a new
Settings key is used before every hand-built config/fixture learns it.
**Fix:** add `show_numeric_sd = TRUE` and `show_percent_column = FALSE` to `make_config()` (the
latter is the identical latent crash one feature away). Do NOT "harden" with `isTRUE()` — the flag
defaults ON, so `isTRUE(NULL)` would silently drop the SD row, the exact silent failure the house
rules forbid; if belt-and-braces is wanted, it is `!isFALSE(...)`. Also fix the vacuous guard test
at `test_numeric_two_averages.R:278-284`, which deletes the key and asserts on the config instead of
running the processor — had it run the processor it would have caught this. Add a one-line contract
note at the top of each processor: "config must come from build_config_object".

### I-7. Tracking: a mapping code with stray whitespace silently removes the metric from tracking
**File:** `lib/tracking_island.R:153-154`, `:111-113`; loader never trims. **Probe-confirmed
(trailing space → 1 of 2 metrics returned, zero console output).**
The pairing report can't catch it — the question simply stops appearing in the Tracking tab, which
reads as "not tracked".
**Fix:** `trimws()` wave-column codes and QuestionCode at load, and emit a `[NOTE]` naming any
mapping row that resolves to nothing in this wave's data layer.

### I-8. Tracking: a wave with no derivable year corrupts the trend chart and every delta chip
**File:** `lib/tracking_aggregate_bridge.R:110-115` (year NA for e.g. "Baseline"),
`lib/tracking_island.R:493-497` (NA sorts AFTER current wave), `assets/js/22w_waves.js:544-547`
(that wave becomes "previous"), `23za_trend.js:75-77, 318-321`. **Probe-confirmed (point drawn at
cx=-458 outside the canvas; real waves collapse onto one x).**
**Fix:** warn loudly at assembly when a wave's year key is NA and drop it or require
`waves_meta`/`wave_order`; in JS, skip null-year points explicitly.

### I-9. Weighted tracking: segment history significance runs on raw n; the Kish eff_n is computed and thrown away
**File:** `modules/tracker/lib/statistical_core.R:274` (returns `eff_n`) →
`lib/tracking_segment_compute.R:71-73` (copies only mean/sd/n_unweighted) →
`lib/tracking_segment_bridge.R:99-102` (emits n_unweighted as base) → `22w_waves.js:271-280`
(falls back to raw base). **Verified by parent session.**
On a design effect of 1.5, every wave-on-wave test on sidecar history is sized on n instead of
n/1.5 — over-flagging movement — and the low-base gate is gated on the inflated base. Companion
(M-1): the sidecar prior-wave SD is population-form while the current wave is Kish-Bessel sample
form, so the two ends of one Welch test use different SD definitions.
**Fix:** carry `eff_n` per segment into the sidecar (`eff_bases` beside `bases`) and teach
`effBaseOf` to read it; fix the SD form in the same rebuild.

### I-10. Tracking: a wave whose weight column is missing is silently computed unweighted
**File:** `lib/tracking_segment_compute.R:138-140`. **Verified by parent session.**
`weight_col %in% names(d)` else `rep(1, ...)` — no message, no skip record. The sibling file refuses
loudly (`DATA_WEIGHT_MISSING`, `tracking_wave_values.R:356-361`) in the same situation. One renamed
column in one wave's export and that wave plots unweighted movement against weighted neighbours.
**Fix:** boxed TURAS WARNING naming the wave (or refuse); stop describing the trap as a feature in
the doc comment at `:89-90`.

### I-11. Qual: a typo'd union member sheet silently drops an entire band's verbatims
**File:** `lib/qual_unions.R:202` (`if (is.null(mq)) next`), same at `:141`. **Probe-confirmed
(3-band union built with zero Promoter records, bands still declared, no console output).**
A duplicate across members refuses loudly; a MISSING member is silent — the asymmetry the file
itself fixes elsewhere.
**Fix:** collect members with no matching sheet and warn or refuse, naming the sheet.

### I-12. Qual: "safe" demographic cuts with the default k=1 ships raw tags labelled as safe
**File:** `lib/qual_island_builder.R:320-322` (map built only when k>1) + default
`min_reporting_base = 1` at `crosstabs_config.R:355`; the disclosure warning also gates on k>1
(`qual_report.R:143`). **Probe-confirmed (island: `cuts: safe`, raw tags shipped); verified by
parent session.**
**Fix:** when cuts resolve to "safe" and k <= 1, warn loudly or downgrade the declared label to
"allow" so the island never claims a protection it isn't applying.

### I-13. Qual: NO_ID_COLUMN join failure falls back to the standalone report with no warning
**File:** `run_crosstabs.R:971-977` (only NO_MATCHES warns); `qual_report.R:93-95` also collapses
any non-PASS status into the string "NO_ID_COLUMN".
**Fix:** add a `[WARNING]` branch symmetric to NO_MATCHES, naming `qual_join_id_column`; pass the
real status through.

### I-14. Qual: a duplicated host ResponseID joins first-wins with no warning
**File:** `lib/qual_assemble.R:212-213`. **Verified by parent session.**
Workbook-side and union-side duplicates refuse loudly; host-side is silent — every comment from that
respondent takes the first row's banner values, filters, and NPS band. Duplicated IDs are a real
merge artifact in this project's fieldwork history.
**Fix:** one boxed warning naming the duplicated ids, matching the ambiguous-id-column treatment at
`:178-186`.

### I-15. Allocation: no constant-sum validation exists anywhere
**File:** `lib/validation/data_validators.R:220-301`, `lib/allocation_processor.R` (whole file).
**Absence verified by parent session.**
A respondent whose wallet rows total 150 inflates every option's mean; the run stays PASS.
**Fix:** per-respondent sum check in `check_allocation_columns` — expected total from an optional
structure column (default 100), warn with counts on tolerance breach, error on gross deviation.
Companion (I-16): blanks are dropped from each option's mean rather than counted as zero
(`allocation_processor.R:157-165`), while the base row counts any-column-answered
(`question_orchestrator.R:248-260`) — decide the blank policy explicitly and align the base.
First step: check one real VAS 2026 record where a respondent skipped an option.

### I-17. Ranking: out-of-range values are warned about but never excluded from any statistic
**File:** `ranking.R:229-248` (counts them) vs `lib/ranking/ranking_metrics.R:320-336, 104-122,
227-245` (filter only NA).
A 99="not ranked" sentinel poisons mean rank, inflates the base, deflates top-N, run stays PASS.
**Fix:** NA-out values outside [1, num_positions] after validation, or refuse above a threshold.

### I-18. Ranking: significance testing is documented but does not exist in the pipeline
**File:** `ranking.R:44` (header claims t-tests) vs `compare_mean_ranks`/`run_mean_rank_test`
(`ranking_metrics.R:448-557`) — **zero callers, verified by parent session.**
Every other type letters; ranking shows nothing, which reads as "tested, not significant".
**Fix:** wire a sig row (mirroring the composite pattern, with Bonferroni + FPC), or state in
output and docs that ranking is untested. Related (M-8): partial-ranking percentages denominate on
per-item rankers, so a rarely-ranked item can print "% Ranked 1st = 100%" (`ranking_metrics.R:104-122`);
config thresholds and top_n are silently ignored (`question_orchestrator.R:323, 370`).

### I-19. Large-file load path bypasses BOM stripping and all load validation
**File:** `lib/data_loader.R:449-489`.
Over the 50MB threshold, `load_survey_data_smart` returns `readxl::read_excel(...)` directly —
skipping `strip_leading_bom` (the fix that exists because Alchemer exports broke the qual
ResponseID join), the empty-file and zero-column refusals — and freezes the corrupted names into
the RDS cache.
**Fix:** route the smart path's initial read through `load_survey_data`; apply the BOM strip on
cache read too.

### I-20. ~~Unknown or typo'd Variable_Type silently tabulates as a Standard question~~ WITHDRAWN — the finding was wrong
**Status: FALSE FINDING, disproved 2026-08-21 during the fix pass.** The reviewing agent reported
"no closed-vocabulary check anywhere". There is one, it is live, and it refuses the run:
`check_variable_types` (`lib/validation/structure_validators.R:111`) is called from
`validate_survey_structure` (`validation.R:263`), which `run_all_validations` (`validation.R:1434`)
calls from `analysis_runner.R:48`; an Error-severity finding triggers `ENV_VALIDATION_FAILED`
(`validation.R:1522-1537`).
**Probe run this session** with `Variable_Type` values `Numeric` / `numeric` / `Rating scale`:
both bad values were flagged at severity **Error**, so a typo'd type refuses the run rather than
mis-tabulating. The dispatch really is else-Standard, but no config carrying an unknown type ever
reaches it.
**What was real, and fixed:** the refusal named the bad *values* but not the *questions* carrying
them, and did not mention case-sensitivity. The message now reads
"Invalid Variable_Type on 2 question(s): Q2 (numeric), Q3 (Rating scale). … Note these are
case-sensitive." — a one-line fix on a 200-question structure instead of a hunt.
**Lesson for future reviews:** an agent's "no check exists anywhere" claim needs a caller-chain
trace before it ships as a finding; absence is much harder to establish than presence.

### I-21. GUI runs have split error visibility; nothing streams live
**File:** `run_tabs_gui.R:486-498`.
`sink(type="output")` captures the TRS boxes into a panel shown only after completion; everything
via `message()` (`[TRS PARTIAL]`, checkpoint notes) goes only to the terminal. Neither channel
shows everything — against the project's own console mandate.
**Fix:** also capture `type="message"` (or `withCallingHandlers` collecting both) and append
incrementally. Related (M-9): the GUI leaks `TURAS_HTML_REPORT_V2`, `TURAS_GENERATE_READER_REPORT`,
`TURAS_READER_AI_PROSE` into the session (`run_tabs_gui.R:551-560` cleans the others), so a later
scripted run inherits the last GUI run's choices.

### I-22. Weighting module: the preflight validator layer is dead code; its tests are false assurance
**File:** `modules/weighting/run_weighting.R:87-103` (nine-file whitelist, silently skips missing
files) — `lib/validation/preflight_validators.R` is not on it; `validate_weighting_preflight` has
zero production callers. **Verified by parent session.**
Every design-targets/rim-category/cell-combination check in that 800-line file never executes in a
real run. Third instance of the loader-whitelist trap (brand module, tabs config).
**Fix:** add the file to `source_module_libs`, call the preflight before the weight loop, make the
loader refuse on a missing file instead of skipping, and make the empty-cell check consult
`read_allow_empty_targets_setting` before choosing Error (else wiring it in dead-ends the cell
opt-in).

### I-23. Weighting module: both design-weight opt-ins are unreachable through the config path
**File:** `modules/weighting/lib/design_weights.R:246-276` — `validate_design_config` refuses
unconditionally BEFORE `allow_unmatched`/`allow_empty_targets` are read; the refusal's own
how_to_fix tells the operator to set flags that then do nothing. **Verified by parent session;
engine-level probe shows the flags work when reachable.**
**Fix:** pass the flags into `validate_design_config` and downgrade the three corresponding errors
to warnings when set (the cell path already does this correctly), or move the checks into the
engine. Note: design/cell paths have still never run against a real project — treat the first real
run as a supervised outing.

### I-24. Two large validation layers are dead code that testifies to being alive
**Files:** `lib/00_guard.R` gates (~600 lines: `validate_tabs_config/_data_file/_structure_file/
_survey_structure/_selection/_banner`, `tabs_determine_status`) — referenced only by themselves and
`test_tabs_core.R`; `lib/validation.R:481-1386` (`validate_base_filter`, the five V10.1 statistical
precondition validators) — zero callers anywhere. **Verified by parent session (grep).**
The live paths do their own checks; the dead versions drift (the dead selection gate skips flag
normalisation the live one has), and `test_tabs_core.R` spends most of its length testing the dead
machine. `validation.R`'s maintenance block (:1548-1680) presents these as active.
**Fix:** delete the dead gates + their tests (or wire them in); correct the maintenance notes.
Note `tabs_refuse`, `tabs_with_refusal_handler`, `validate_dual_significance_config` and the FPC
loader in 00_guard.R ARE live — do not delete those.

### I-25. Config: documented-configurable settings that are silently inert
**Files/keys (all verified by parent session):**
- `weight_na_threshold`, `weight_zero_threshold`, `weight_deff_warning`
  (`lib/validation/weight_validators.R:178-180`) — read from config_obj but never registered:
  the hard-coded default always applies AND the typo-warning scolds anyone who sets them.
- `alpha_default` — registered, validated (`00_guard.R:664-683`), templated, consumed by nothing:
  setting `secondary` does nothing, silently.
- `output_format` — whitelisted but unregistered, so its validator (`config_validators.R:182-205`)
  always sees "excel" and BOTH its warnings are unreachable; a `csv` row is ignored with no signal.
- `significance_level` deprecation shim (`config_validators.R:44-49`) — dead for the same reason;
  the promised auto-convert does not exist.
**Fix:** register + whitelist the three thresholds (or delete the "configurable" claims); wire
`alpha_default` into the data layer or retire it via `TABS_RETIRED_SETTINGS`; point the
`output_format` and `significance_level` checks at raw settings. Add the missing contract-test
direction: whitelist ⊆ actually-consumed (the existing test only gates builder-reads ⊆ whitelist).

### I-26. Filter expressions can silently evaluate against session variables
**File:** `lib/filter_utils.R:196-199` — `eval(..., envir=data, enclos=parent.frame())`.
**Mechanism probe-confirmed** (a caller-environment vector of the right length filtered
"successfully", zero warnings). In a `launch_turas()` session the global env is full of objects.
**Fix:** `enclos = baseenv()` — but grep live configs first: this is a behaviour change for any
config filter deliberately referencing a global.

### I-27. Docs: 05_TECHNICAL_DOCS.md actively misleads; the test suite is undocumented
**Files:** `docs/05_TECHNICAL_DOCS.md`, `docs/04_USER_MANUAL.md:260-266`, `README.md:71`,
`tests/README.md`. **Spot-verified by parent session.**
The worst sentence in the repo: 05:1017 "Estimated coverage is under 10% (mostly manual testing)"
— against 73 testthat files + 37 node suites. 05 also documents phantom files
(`question_dispatcher.R`, `run_crosstabs_helpers.R`, `statistical_tests.R`), a config_loader.R
that is a 14-line stub, deleted functions, and fixed "known issues". The user manual's GUI
instruction omits calling `run_tabs_gui()` (a literal follow gets a silent no-op). No numbered doc
says how to run either test suite; `tests/README.md` lists 2 of 73 files and references a file
that doesn't exist. Dependencies are wrong both ways: jsonlite is a hard gate for the default-on
v2 report (`data_layer_writer.R:1331`) but undocumented; htmltools is documented Required and used
nowhere.
**Fix:** rewrite 05's file tree, Core Components, Known Issues and Testing sections (or delete
them and point at 11, which verified 100% accurate); add a "Running the tests" section to README
naming both suites; fix 04:265 and the dependency lists; collapse the two drifting READMEs into
one. Also (class finding): several plan docs' status lines are contradicted by code —
`COMMENT_HUBS_PLAN.md` says "not built" (202 hub references in 27q), `QUALITATIVE_TAB_PLAN.md`
says "planned" (eight qual files in production), `SEGMENT_WAVE_TRENDS_PLAN.md` says "no code yet".
A one-page `docs/INDEX.md` with three buckets (user guides / delivered records / open plans) fixes
the class.

### I-28. Report text: an unreadable ReportText sheet ships platform wording silently
**File:** `lib/crosstabs/crosstabs_config.R:1181-1207` (`load_report_text_sheet`). **Verified by parent session.**
The whole sheet load is a tryCatch → `[WARNING]` → NULL, so a corrupt/renamed-column sheet ships
the client report with platform wording instead of the study's overrides — contradicting the
authored-text system's own refuse-don't-fallback principle (an unknown KEY refuses the build; an
unreadable SHEET degrades on a one-line warning).
**Fix:** refuse (or boxed TURAS ERROR) when the sheet exists but cannot be read.

---

## MINOR (fix opportunistically; grouped by area)

**Statistics**
- M-1. Sidecar-history SD is population-form vs current-wave Kish-Bessel sample form — the two ends
  of one Welch test differ; mildly anticonservative at small segment n (`statistical_core.R:248-249`
  vs `tracking_wave_values.R:155-169`). Fix with I-9's rebuild.
- M-2. `nps_bucket_score` scores a coding-slip 11 as a promoter; the docstring at
  `cell_calculator.R:477-479` claims above-10 leaves the base (verified). Either add
  `if (v > 10) return(NA_real_)` (and regenerate the parity island) or fix the doc.
- M-3. `calculate_effective_base` (`cell_calculator.R:612-635`) doesn't strip NA/Inf weights;
  `calculate_effective_n` (`weighting.R:376-378`) does. Copy the one filter line.
- M-4. Qual theme×banner arrows hard-code z=1.96 ignoring configured alpha, no multiplicity control
  (`27q_qualitative.js:159` vs `21_stats.js:51-79`).
- M-5. Custom-banner letters wrap at 26 and become ambiguous (`21_stats.js:259`); the PPTX side
  already has the base-26 solution (`29_export.js:663-670`).
- M-6. DK box can be seated as "bottom" in the NET POSITIVE DisplayOrder fallback
  (`standard_processor.R:990-1016`) — top pick filters DK, the fallback bottom pick doesn't.
- M-7. Duplicate OptionText silently collapses in the rating-mean lookup
  (`cell_calculator.R:375-379`) — the known Alchemer dup-title gotcha; warn on `anyDuplicated`.
- M-8. Ranking: partial-base %, ignored config thresholds, hard-coded top_n (see I-18).
- M-9 (composite policy): "Sum" composites produce partial sums for respondents missing a member
  item (`composite_processor.R:458-460`, probe-confirmed); no minimum-items rule for Mean. R and
  report agree by construction (single scoring function) — policy gap, not drift. Related
  PLAUSIBLE: the tracking segment-compute path scores composites as raw rowMeans
  (`tracking_segment_compute.R:40-53`), not through `calculate_composite_values` — worded-Likert
  composites backfilled that way yield NA or wrong wave means; trace `metrics$sources` before
  trusting a composite backfill.

**Pipeline / robustness**
- M-10. Three top-level refusal-guard blocks in run_crosstabs.R (`:608-616, 626-633, 648-655`) are
  dead — and a top-level `return()` in a sourced script falls through (empirically probed), so if
  they ever became live the script would continue past them. Delete them.
- M-11. Checkpoint deleted before the workbook exists (`analysis_runner.R:596-599`) — part of C-1's fix.
- M-12. `script_dir` depends on a `toolkit_path` variable nothing sets, then on cwd
  (`run_crosstabs.R:32`).
- M-13. Composite bases fallback can stamp another question's bases (`analysis_runner.R:459-475`).
- M-14. Chi-square row is the one un-isolated section in the Standard path
  (`question_orchestrator.R:521-533`).
- M-15. Weighting engine edges (all probe-confirmed, direct-call paths): zero population → weight 0
  for a stratum with NO warning (`design_weights.R:121-126`); NA population → misleading refusal
  text; `validate_weight_spec` crashes raw when `trim_method` column is absent — this one IS
  config-reachable (`modules/weighting/lib/validation.R:429`); single-value `weight_bounds` skips
  the NA check (`rim_weights.R:720`); `calculate_banner_bases` crashes raw on NA weights (exported,
  test-only callers); duplicate UseBanner=Y question desyncs the banner structure (`banner.R:121`);
  filter tryCatch re-wraps its own validator's refusals (`filter_utils.R:194-220`); one-positive-
  weight crash in `weight_validators.R:222-225`.
- M-16. No duplicate-QuestionCode check on the Selection sheet → question processed twice
  (plausible, traced not executed); QuestionCodes never trimmed at load (validator trims its local
  copy only).
- M-17. `load_config_sheet` lets readxl guess types where `.read_table_sheet` pins text
  (`config_utils.R:63-82` vs `data_loader.R:84`).
- M-18. Dead code with latent bugs: `write_question_table` (excel_writer.R:352-472, zero callers,
  latent column-shift bug — delete); duplicate `format_output_value` definitions where the
  test-loaded copy is not the production copy (excel_utils.R:118-151 vs run_crosstabs.R:576-593 —
  delete the run_crosstabs copy); `ai_easystats.R` (dead, with an overlapping-columns chi-square
  flaw if ever wired).
- M-19. The 150 suite warnings: `$`-access of optional tibble columns at
  `data_layer_writer.R:986, 992-993, 1003` — functionally safe, pure noise; switch to `[[ ]]`.
  Sweep confirmed no unsafe siblings.
- M-20. Hardcoded Summary section-style rows `c(2,7,11,16,22,32)` (`excel_writer.R:708`) —
  currently aligned, silently misstyles on any insertion.
- M-21. Non-Excel writers (data layer JSON, report HTML, tracking sidecars) are not atomic —
  temp+rename exists in the Excel path, reuse it.
- M-22. `tracking_island.R`'s `load_question_mapping` uses openxlsx despite the module's own
  readxl guidance; header-only sheet returns the header as data (probe-confirmed); "NA" text
  becomes missing.
- M-23. Aggregate-history proportion counts reconstructed from rounded published percentages
  (`tracking_aggregate_bridge.R:224`) — the proportion cousin of the known 1dp mean trap; document
  "store ≥1dp" in AGGREGATE_TRACKING_GUIDE.md; the microdata sidecar rebuild remains the real fix.
- M-24. Callout editor: Save rewrites the whole registry from a session-lifetime copy (concurrent
  edits clobbered — the documented concurrent-session collision class;
  `run_callout_editor_gui.R:226, 511-530`); no live markup check to match the live placeholder
  check (`:461-498`); `ofile` path-fallback trap outside launch_turas (`:29-34`); reconciling-saver
  sourcing has no regression test pinning `exists("turas_save_workbook_atomic")`
  (`run_crosstabs.R:60-75`); cover findings count accepts 2.7 and floors it silently
  (`crosstabs_config.R:265-277`).
- M-25. Report v2 cosmetics: doubled word in the filter bar ("with with", `26_filter.js:71`);
  `chartString()` swallows chart errors for PNG export in a bare catch (`25_cards.js:794-800`);
  authored text interpolated unescaped into `title="…"` attributes (`23_render.js:271-274`).
- M-26. Reader report: composites detected by `^Q_` name prefix instead of the `$composite` flag
  (`derive_reader_model.R:94`, verified); no-scale-question study crashes derivation into a vague
  refusal (`:253-256, :158, :317`); the AI disclosure bakes in "Analyst-reviewed." before any
  analyst has seen it (`reader_ai_prose.R:331`) — in a product whose brand is honesty machinery,
  drop it or gate it on a sign-off flag.
- M-27. AI deterministic number check is weak by construction (integers 0-10 and 100 never
  checked, ±0.6 tolerance vs any payload number; `ai_verify.R:143-150`) — defence-in-depth exists
  (LLM verify pass, suppression, "Unverified draft" flagging), so weakness not hole; the header
  says "fail-open" but the code fails closed (fix the comment). High-confidence callouts silently
  drop their `data_limitations` (`data_layer_writer.R:1121`).
- M-28. Qual polish: partial join prints an info line rather than a `[WARNING]` when commenters
  drop (`run_crosstabs.R:940-941`); coded-but-blank-ID workbook rows vanish untracked
  (`qual_workbook_reader.R:353`); band reconciliation silently no-ops if score_utils isn't sourced
  (`qual_unions.R:288`); invisible `\x01`/`\x02` literals in the k-anon cache key
  (`qual_island_builder.R:204` — correct, but unreadable; use escaped literals).
- M-29. Four tracking lib files are offline tooling with no header saying so; examples/ scripts
  default to this machine's absolute paths; static `templates/Crosstab_Config_Template.xlsx`
  (13 Aug) predates the generator's ReportText sheet (19 Aug) — regenerate it.

---

## OBSERVATIONS (fine as-is; recorded for the future maintainer)

- O-1. Tested variance ≠ displayed SD (Σw vs Bessel) — recognised survey convention, pinned by the
  parity gate; a doc line would help readers recomputing t from printed SDs.
- O-2. Wave-on-wave tests use zPrimary with no Bonferroni across pairs while crosstab letters
  correct across columns — deliberate tracker convention; the two surfaces apply different
  multiplicity philosophies; document it.
- O-3. Pairwise z-tests can run between overlapping BoxCategory banner columns (OR-unions) — the
  independence assumption fails; consider suppressing tests between intersecting columns.
- O-4. Default rim bounds [0.3, 3.0] refuse moderately ordinary panel corrections (probe: needed
  max weight 3.18) — loud and well-advised, but consider wider defaults or naming the binding
  bound.
- O-5. Microdata island carries raw per-respondent numeric answers — your documented C3 decision
  with the boxed DISCLOSURE WARNING; residual risk is an operator ignoring the console. Optional
  hardening: a config key to bin or drop Numeric scores.
- O-6. E2E harness extracts functions from run_crosstabs.R by text-grep and pins its own third
  version string — fragile; the single highest-leverage refactor in the module is making
  run_crosstabs.R's body a callable function (it fixes I-1's catchability, I-2, M-10, the GUI
  global leaks and the harness fragility in one move).
- O-7. The data layer is built twice (sidecar vs embedded island) and only the embedded copy gets
  diagnostics/patterns/tracking attachments; the ":775 Build ONCE" comment is inaccurate.
- O-8. 80%-letter fallback recomputes from display-rounded counts on pre-sig2 islands — contained
  and self-documented; regenerating an old island without sig2 quietly diverges from the workbook.
- O-9. localStorage ownership-marker pattern copy-pasted across six stores — extract one helper
  before the seventh copy diverges. Story snapshot pins are the one raw-HTML sink (own-output
  trust boundary today).
- O-10. `sig_row` label filter excludes only RowType "Sig." — a future labelled Sig.2 row needs
  `%in% c("Sig.", "Sig.2")` in two places (`run_crosstabs.R:132-133`, `summary_builder.R:142`).
- O-11. Single-file `Rscript testthat::test_file` from inside the test dir loses renv and fails
  misleadingly — always run from repo root; worth a doc note.
- O-12. The callout-editor delete dialog says "cannot be undone" (10 backups exist) and doesn't
  warn that deleting a tabs entry makes every future v2 build refuse.
- O-13. Whitespace-structural authored entries (one bullet per newline) can be silently reflowed
  in the editor — context notes exist, no enforcement.
- O-14. `permanently-skipped` template test (`test_config_templates.R:718`) — check it isn't also
  skipped under the full-suite entry point, else template↔tracking-reader drift has no gate.

## Verified-clean list (checked adversarially, no findings)

Two-proportion and Welch machinery with hand-checked formulas; zero-SE and degenerate-p semantics;
letters alignment under dropped columns; per-banner-group Bonferroni; FPC single-definition,
census→excluded, below-floor bit-identical; R↔JS parity gate asserting numeric agreement
(0.0088417 vs 0.0038374 around the threshold) and pinning the committed island; negative weights
refused/loudly repaired at extraction; reconciling saver wired and loud-fallback only; JSON island
NA/NaN/Inf → null and every `<` → `\u003c` (probed); rounded-values-into-significance does NOT recur
(letters ride verbatim, recompute uses microdata, wave contributions store 4dp micro scores);
microdata=N degrades loudly not wrongly; aggregate-only questions under filters show "n/a" not
stale numbers; medians return null rather than wrong weighted values; disclosure control fails
closed without microdata; export values share the screen's formatting path; NET POSITIVE OptionText
gotcha fixed and excluded from tracking tests; trendline toggle + delta axis correct (15/15, 9/9);
banner key↔letter↔data alignment self-checking (`BUG_SIG_LETTER_MISMATCH`); cell/design weight
arithmetic hand-checks exactly; the callout/authored-text loop closed at four layers (build refusal
naming key+tokens, live editor token warnings, runtime miss tracking + selftest, real-bundle
catalogue test + mutation check) with atomic, backed-up, parse-verified writes and mtime-keyed
cache; the 31_selftest is a genuine stats spot-check against the file's own published tables; zero
TODO/FIXME/HACK/debug leftovers in ~59k lines; roxygen sampled accurate; cross-engine commit
hygiene — the last ~20 commits were each reviewed in context, per-commit verdicts:

| Commit | Verdict |
|---|---|
| 59b17ad9 wording | sound (deliberately hard-codes two crosstab tooltips outside the authored system, says so) |
| 5b2b4e28 collapse-all | sound — state-driven, search-through-collapse handled, 12 tests |
| fce6cbc1 Allocation end-to-end | sound-with-caveat — all four named faults closed; leaves the I-5 sig-letter gap in v2 |
| dcf563c8 cover duplicate | sound — 5 new tests |
| d5f89f18 cover ×4 | sound-with-caveat (fractional findings-count floors silently, M-24) |
| e1e22882 placeholder help | sound — manifest-driven, R test pins every token |
| bb3efc71 reconciling saver | sound-with-caveat — fix real, no regression test pins the sourcing (M-24) |
| 7431b505 callout registry cache | sound — mtime+path keying, writer clears cache, real-failure test |
| 0045bc57 one-entry-per-block | sound — render-diff-verified merge; whitespace-structural residual (O-13) |
| 559a3f53 token escaping | sound — char-for-char escapeHtml twin, 10 unit tests, no re-scan injection |
| bf10426b unused-text check | sound — manifest-intersected candidates |
| cae16bc2 per-study overrides | sound-with-caveat (I-28: unreadable sheet degrades silently) |
| 0c882c08 + Stages 1-5 extractions | sound (spot-checked three files with real logic changes; rest trusted to suites + mutation check) |
| 354c392c selftest misses | sound (lazy renders can hide a miss until clicked — inherent) |
| 7e461a68 Stage 0 plumbing | sound — refuse-don't-fallback coherent; v2 failure is tryCatch-isolated so the workbook survives |

## Corrections to project memory made during this review

- Composite tracking IS committed on main (1b79bdc8) — the "UNCOMMITTED" note was stale.
- `COMPOSITE_BANNER_HANDOVER.md`'s status line disagrees with reality — update on next touch.
- The known CCPB 1dp Welch trap: engine confirmed faithful (no further rounding); the fix tooling
  (`wave_values_from_microdata` → `reconcile_wave_values` → `splice_wave_values`) exists and is
  well-tested; the open item is running it on CCPB data, unchanged. M-23 is the same trap's
  proportion side (new).

## Triage against the known-open list

Already on your list, re-confirmed, no new action: CCPB sidecar rebuild; design/cell weights never
run on a real project (now with concrete findings I-22/I-23 to fix first); config whitelist trap
(now with the concrete instances in I-25). Newly found, not previously known: everything else above.

## Verdict

**DEPLOY WITH CONDITIONS.** Condition 1: fix C-1 (or disable checkpointing on multi-config
projects) before the next real run. Condition 2: before VAS 2026 reporting ships allocation/ranking
tables or weighted segment tracking, land I-5, I-9/I-10, I-15/I-16, I-17/I-18. Condition 3: the
silent-degradation cluster (I-7, I-8, I-11, I-12, I-13, I-14, I-20) — each is a one-boxed-warning
fix; batch them. The docs condition (I-27) has no code risk and pays for itself the first time a
future session is briefed from 05. Everything in MINOR/OBSERVATIONS can ride normal maintenance.
