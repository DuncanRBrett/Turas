# Weighting Module — Production Review (calculations focus)

**Date:** 2026-07-12. Fable review session, token-lean pattern: four Opus subagent readers over the calculation-critical files + Fable verification of the load-bearing claims.
**Scope:** calculation correctness only — weight computation, application to data, and the hand-off to tabs. The HTML report layer (`lib/html_report/`, ~1.9k lines) was **deliberately not reviewed** per Duncan's instruction (reporting side unimportant; weights feed tabs).
**Files read in full by readers:** `run_weighting.R`, `lib/rim_weights.R`, `lib/trimming.R`, `lib/cell_weights.R`, `lib/design_weights.R`, `lib/00_guard.R`, `lib/config_loader.R`, `lib/output.R`, `lib/validation.R`, `lib/validation/preflight_validators.R`, `lib/diagnostics.R`, all `tests/testthat/*` for those areas. Not reviewed: `run_weighting_gui.R`, `lib/generate_config_templates.R`, html_report.
**Verification legend:** [F] = Fable-verified this session by reading the code or running a command. [O] = Opus-reader finding with file:line evidence, not independently re-read by Fable. [O2] = two independent readers converged on it.
**Test suite baseline (executed this session):** `testthat::test_dir("modules/weighting/tests/testthat")` — **all pass, 0 failures**, 1 expected warning (trimming test deliberately trims 20%).

---

## 1. Verdict

The core engines are sound where it matters most: **rim/raking delegates to `survey::calibrate`** (no hand-rolled IPF), category matching is by name everywhere (never position), **row alignment of weights to respondents is correct end-to-end**, weights are written at full precision, and the Kish n_eff / DEFF / efficiency formulas in `diagnostics.R` are exactly right and consistent with what tabs consumes.

The defects are in the **seams around the engines**: post-hoc trimming silently breaks the invariants calibration just established (C1); NA weights and all-NA weight columns flow into the tabs lookup file unflagged (C2); design weights are never normalised in the main pipeline while rim weights are (H1); and the lookup file — whose entire purpose is merge-back — has no duplicate-ID or ID-validity guard (H3). The test suite is green but structurally weak: it verifies statuses and rough properties, almost never exact numbers (§5).

---

## 2. How the pipeline actually works (verified flow)

1. Config loaded (`load_weighting_config`), targets coerced numeric at `config_loader.R:373`. Data loaded once, `as.data.frame` at `run_weighting.R:341`, ID column resolved or **auto-set to column 1** (`:344`). Data is never sorted/filtered/deduped after this. [O, alignment mechanism F-corroborated]
2. Per-weight loop (`run_weighting.R:376-516`): method dispatch to design / rim / cell engine. Each engine returns a **full-length vector aligned to original row positions** via logical masks (design `design_weights.R:106`; cell `cell_weights.R:157`; rim re-expands its complete-cases subset through `weights_full[complete_idx] <-` at `rim_weights.R:377-380`). [O]
3. Rim path: variables coerced character → `factor(levels = names(target))` (`rim_weights.R:180-182`); any NA level (missing data OR unmatched category) → hard TRS refusal `DATA_UNMATCHED_VALUES` (`:184-193`). Population vector built from targets × `base_n`, reference level implied by intercept (`:283-316`). `survey::calibrate(calfun="raking", bounds=c(0.3,3), force=FALSE)` (`:320-328`) — hard non-convergence throws → refusal, weights never returned on failure. [O]
4. Trimming: `apply_trimming_from_config` at `run_weighting.R:455`, result replaces `weights` (`:462`), **no rescale and no re-rake follows**. [F — read `run_weighting.R:440-533`]
5. Attach: `data[[weight_name]] <- result$weights` (`:514`) — positional, safe given (2). On a failed weight in multi-weight PARTIAL mode the column is set all-`NA_real_` (`:509`) and still written. [F]
6. Output: `write_weighted_data` writes `data[, c(id_column, weight_names)]` — all rows, both xlsx and csv at full precision (xlsx numFmt is display-only). [O]

---

## 3. Findings

### CRITICAL

**C1. Config-driven post-hoc trimming silently breaks sum-to-n AND the calibrated margins; diagnostics still report success.** [F]
`apply_trimming_from_config` (`trimming.R:154-213`) caps weights and returns; `rescale_after_trimming` (`trimming.R:333`) is **dead code — zero callers module-wide** (verified by grep), and nothing re-rakes or re-checks margins. The orchestrator swaps in the trimmed weights (`run_weighting.R:462`) and `diagnose_weights` (`:467`) still presents the rim margins as achieved. With `apply_trimming = Y` in config: weights no longer sum to n, raked margins no longer hold, and the module reports GOOD quality. Every downstream tabs base and margin is then wrong.
Mitigating fact [O]: the rim `cap_weights` setting is applied as in-calibration `bounds` (`rim_weights.R:140-146,325`), which does NOT break margins — the correct mechanism already exists; the post-hoc path is a second, uncoordinated trim system layered on top.

**C2. NA weights flow into the tabs lookup file unflagged, three ways.** [F for (c); O2 for (a),(b)]
(a) Design: rows with NA/unmatched stratum get NA weight with warning only (`design_weights.R:110-138`). (b) Cell: rows in cells not covered by targets get NA (`cell_weights.R:190-201`); additionally NA values in cell variables become the literal string `"NA"` in the paste-key (`cell_weights.R:113-119`), so missing data silently routes to "undefined cell" instead of being flagged as missing. (c) PARTIAL multi-weight mode: a failed weight writes an **entire all-NA column** into the lookup file (`run_weighting.R:502-533` — read directly). A tabs run keyed on any of these silently deflates or collapses the weighted base. No flag column, no refusal, no threshold. (Rim is immune: it refuses on NA rather than emitting NA — see §4.)

### HIGH

**H1. Design weights are never normalised in the main pipeline — mean weight = population/sample, not 1.** [F]
`normalize_design_weights` exists and is correct (`design_weights.R:294-322`) but its only caller is the `quick_design_weight` convenience helper (`run_weighting.R:979`), never the config pipeline (verified by grep). A design-weight column therefore arrives in tabs at population scale (e.g. mean 20). Kish n_eff is scale-invariant so significance testing survives, but every weighted N displays at population scale, asymmetric with rim (which calibrates to sum ≈ n). May be *intended* grossing behaviour — needs a Duncan decision (handover §0.2) — but today it is undocumented and inconsistent.

**H2. Cell weighting: an empty target cell (target > 0, zero respondents) is skipped with a warning and no renormalisation.** [O2]
`cell_weights.R:148-151, 181-187`. The weighted base silently drops below n and that cell's population share vanishes — e.g. an 8% census cell with no respondents shrinks every weighted total by ~8% with no refusal. Same pattern for design strata with population but zero sample (`design_weights.R:91-94,124-129`).

**H3. No respondent-ID integrity guard on a file that exists to be merged back.** [F]
No `duplicated()` check anywhere touches respondent IDs (grep — all existing checks are on targets/weight-names/cell-keys). ID auto-set to column 1 with no uniqueness/ID-ness validation (`run_weighting.R:344`). Duplicate IDs make the tabs-side join fan out and mis-map weights. Related [O]: no check that `weight_name` collides with an existing data column or the ID column — `data[[weight_name]] <-` at `:514` silently overwrites (if `weight_name == id_column` it destroys the key before write).

**H4. `converged = TRUE` is hardcoded, and achieved margins are never asserted against a tolerance.** [O]
`rim_weights.R:413` ("TRUE if we got here"). `force=FALSE` catches hard non-convergence, but a bound-constrained calibration that returns while off-target reports converged. Achieved-margin computation exists (`rim_weights.R:583-591`, arithmetic correct) but is display-only — neither `validation.R` nor the pipeline recomputes weighted margins vs targets with a tolerance. This is also why C1 goes undetected.

### MEDIUM

- **M1.** Exported core `calculate_rim_weights` never checks targets sum to 1; the reference category silently absorbs the discrepancy (targets summing 1.05 → implied first-category target reduced, no warning) (`rim_weights.R:293-316`). [O] The **config path is guarded** (preflight sum-to-100 `preflight_validators.R:218` + `00_guard.R:161-181`, both tested) — so this bites direct API callers only.
- **M2.** `validation.R:314-316` rounds `effective_n` *before* deriving design_effect/efficiency — disagrees with the correct unrounded `diagnostics.R:105-107` for small n. Two module outputs quote different DEFF for the same weights. [O]
- **M3.** Preflight category-label mismatch (typo/case/whitespace) is a **Warning, not an Error** (`preflight_validators.R:186,306`) — for design/cell the run proceeds and the mistyped category's respondents get NA weight (feeds C2). Rim labels are also matched exactly with no `trimws` (`rim_weights.R:180-182`) — a leading space in Excel halts a rim run (loud, but brittle). [O]
- **M4.** `config_loader.R:373` `suppressWarnings(as.numeric(...))` silently converts bad target cells ("52%", comma decimals, the known Excel "NA"-string gotcha) into NA. [O]
- **M5.** Cell keys `paste(collapse="|")` with no escaping — any category value containing `|` collides across distinct cells and merges their weights (`cell_weights.R:119,122`). [O]
- **M6.** Direct-API `calculate_cell_weights` checks only sum≈100, not negative/NA target_percent (config path does check) (`cell_weights.R:92-102`); target_percent = 0 silently zero-weights real respondents (`:154-157`). [O]
- **M7.** Rim treats genuine missing data identically to unmatched categories — one NA in a demographic hard-refuses the whole run with a misleading "unmatched value" message (`rim_weights.R:184-193`). Loud, not corrupting, but blocks legitimate data with no exclude-and-disclose option. [O]

### LOW

- `calculate_design_weights_from_config` silently takes only the first stratum variable if config lists several (`design_weights.R:193`). [O]
- Duplicate target category rows → raw factor error, not a clean refusal (`rim_weights.R:478-481`). [O]
- Rim-on-design (`base_weight_column`) is supported by the engine but never passed by the orchestrator loop — combined design×rim weighting is unreachable via config (`run_weighting.R:410-415`). [O]
- Post-hoc `cap`/`percentile` trimming is redundant with calibrate `bounds` (default upper 3.0) — a cap above 3.0 never binds; one below it breaks margins for no benefit (`trimming.R:80-114`). [O]
- Weight-column auto-detect fallback in output (`output.R:52-60`) is dead in the main path but would grep-guess wrong columns if ever reached. [O]

---

## 4. Verified correct — do not re-litigate

- **Row alignment** [O, mechanism corroborated F]: data loaded once, never reordered; every engine returns full-length vectors via logical masks over original positions; positional attach at `run_weighting.R:514` is therefore safe.
- **Raking core** [O]: `survey::calibrate(calfun="raking")` — IPF arithmetic correct by construction; category matching by constructed *name* (`paste0(var,level)` vs `model.matrix` colnames, `rim_weights.R:300-307`), never position; sum-to-n enforced via intercept = `base_n`; `force=FALSE` → non-convergence refuses, weights never returned on failure; NA respondents never leak a distorting weight (refusal or NA, never silent 1/0).
- **Kish/DEFF/efficiency in `diagnostics.R:105-107`** [O]: `n_eff=(Σw)²/Σw²`, `deff=n/n_eff`, `eff=100/deff` — exact, mutually consistent, unrounded value preserved for downstream (tabs-consistent).
- **No rounding of weights on write** [O]: xlsx numFmt display-only; csv full precision; all rows written, not complete-cases.
- **Percent-vs-proportion confusion refused, not mis-scaled** [O]: proportions where percents expected fail the sum-to-100 guards (`00_guard.R:161-181`; cell `cell_weights.R:93-102`).
- **Preflight (14 checks)** [O]: catches missing columns, rim/cell targets ≠ 100, non-positive population, NA/negative/Inf in weight vars, zero-count categories, duplicate weight names — before the engine runs; most are tested.
- **Test suite executes green** [F]: 0 failures this session.

## 5. Test-suite assessment (calculations)

Green but weak on numbers. Strongest numeric tests: design pop/sample=100 per stratum (`test_design_weights.R:5-34`); balanced 4-cell → all weights ≈1 (`test_cell_weights.R:52-76`); single rim margin re-checked ≈0.48 (`test_rim_weights.R:28-47`) — the only genuine post-weighting margin assertion in the suite. [O]

**No numeric verification exists for:** Kish n_eff/DEFF on non-uniform weights (only the trivial uniform case — biggest gap given tabs consumes n_eff); CV; unequal-strata design values; rim-on-design g-weights; multi-variable rim margin achievement; margins after post-hoc trim; row alignment with NA-bearing data through the engine; percent/proportion mismatch behaviour; empty-cell resulting values. The rim cap test asserts ≤3.01 against a default bound of 3.0 — passes even if capping were ignored. [O]

## 6. Fix approach

Single Opus session, one branch. See `HANDOVER_WEIGHTING_FOR_OPUS.md` — decisions for Duncan in its §0 (trimming semantics, design-weight scale, NA-row policy), then work packages W1–W8.
