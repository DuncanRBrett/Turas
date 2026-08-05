---

editor_options: 
  markdown: 
    wrap: sentence
---

# Growth Path: Turas tabs module

**Date:** 2026-08-04 **Current state:** Production crosstab engine + v2 interactive HTML report; CCPB W2026 shipped clean; 4 new projects queued. **Stack:** R (engine, Shiny GUI, openxlsx/readxl) + dependency-free vanilla JS (v2 report, 23 test suites).

## Architecture readiness

What the current architecture supports without significant rework: - **The 4 new projects on the CCPB pattern** — the GUI → crosstabs + v2 report path is well-tested and verified end to end; project variation is config-driven. - **Single settings registry (the I7-I9 fix)** — `TABS_KNOWN_SETTINGS`, `build_config_object` and the template generator already sit in two files; deriving all three from one table of (key, type, default, section, help) is a contained refactor that permanently ends whitelist/template drift. This is the highest-leverage structural fix available. - **Carrying R-computed statistics into v2 instead of recomputing** — the data layer already carries sig letters for the primary alpha; extending it to Sig.2, FPC-corrected letters, and raw (unrounded) wave values removes the whole dual-engine divergence class (I2, I3) without new architecture. - **Reader-mark stability (I20)** — ResponseID is already in the island; re-keying marks from positional idx to ResponseID is a data-shape change plus a migration shim for existing localStorage.

What would require significant rework: - **Data-time disclosure (C3)** — suppressing at data-layer build changes what saved copies and offline viewing can do; it needs a decided confidentiality model first (viewing-convenience vs contractual gate), then touches data_layer_writer, the sidecar, and the qual island together. - **FPC in the R engine (I1)** — the correction itself is small, but it touches every test-path in weighting.R and demands a parity test harness between the two engines; treat as its own project (it is already on the roadmap). - **Option-level wave matching with diagnostics (I24)** — a real matching layer (code-based, with a pairing report at option level) rather than label equality; medium rework in tracking_island + 22w.

## Natural next steps

### 1. Pre-projects fix batch (CRITICALs C1, C4, C5, C6)

**What:** numeric/allocation sig dispatch; NPS filter on the bimodality scan; wave-recovery insert + non-vacuous reconcile; generator Category/Theme columns then template regeneration; delete the fake `run_tabs_analysis`; restore a demo project so the e2e gate runs. **Why now:** these are the exact traps the 4 new projects walk into; all are mechanical with clear tests. **Effort:** Small-Medium — a focused session or two, each fix with its regression test. **Risk:** template regeneration must follow the generator fix, not precede it (the Category-loss trap).

### 2. Config-contract batch (I7-I11 + I4)

**What:** one settings registry; real defaults through safe_logical/safe_numeric; validate alpha/min_base/decimals/sampling_method in the guard; fix the stats-pack Declaration keys. **Why now:** this is what makes a *fresh* config trustworthy — the other four projects all start from fresh configs. **Effort:** Medium. The registry is the bulk; the rest is mechanical once it exists. **Risk:** touching the loader needs the full suite + a golden-config fixture to prove no behaviour change for existing configs.

### 3. Disclosure decision + implementation (C2, C3, I16)

**What:** decide the confidentiality model (render-time = convenience vs data-time = contract), then: suppress in Index_Summary/Sample Composition/Summary; k-gate the data layer (or document microdata=N as the confidential ship and make the GUI honour it). **Why now:** at least one upcoming project type (climate/anonymity studies) sells the k-gate as a promise. **Effort:** Medium — the Excel side is small; the v2 side depends on the decision. **Risk:** data-time suppression changes analyst-copy behaviour; needs an explicit "full internal copy" escape hatch.

### 4. Qual workbook hardening (I17-I21)

**What:** refuse on blank/dup IDs, unrecognised markers, and guessed columns; fix the 1e5 ID join; render the withheld count; re-resolve hub pins. **Why now:** before the first new project with an analyst-edited comment workbook. **Effort:** Medium. Reader changes are contained; pin re-resolution mirrors existing priority-pin code. **Risk:** stricter refusals will reject workbooks that used to "work" — that is the point, but budget a pass over live CCPB/SACS workbooks to confirm they still load.

### 5. Tracking honesty batch (I22, I23, C5 follow-through, I3)

**What:** weight-aware recovery, robust reconcile, "not testable" as its own count everywhere, raw values on the wave contribution. **Why now:** before the first tracker wave lands (CCPB wave-significance rebuild is the live consumer). **Effort:** Medium. **Risk:** low — mostly making promised behaviour actual.

## Known limitations

| Limitation | When it matters | Mitigation |
|---------------------|------------------------------|---------------------|
| v2 suppression is render-time (C3) | Any k-gated deliverable shipped as HTML | microdata=N + step 3 above |
| No FPC in Excel engine (I1) | Census/known-population projects | Note on Excel output; v2 is the corrected surface |
| Wave matching by option label (I24) | Trackers whose questionnaires drift | Freeze option wording between waves; pairing report |
| Reader marks positional (I20) | Any data re-export after readers engage | Re-export before circulating, not after |
| localStorage pins survive rebuilds (I20) | Disclosure tightened after pinning | Clear-stale-state work (already parked on the roadmap) |

## Technical debt

| Debt | Why accepted | When to pay down |
|-----------------|------------------------|--------------------------------|
| Dual significance engines (R + JS) | v2 must work offline from the island | Shrink by carrying more R results in the island (step 2 enabler) |
| Sidecar/island built twice (O1) | Sidecar predates the island | When the first sidecar consumer lands |
| Dead code: question_dispatcher, write_crosstab_workbook, dead patterns card paths | Rebuilds left remnants | Delete in the next touch of each file |
| Docs describing a scripted API that doesn't exist (C6/M16) | GUI became the real path | Rewrite entry-point docs in the C6 batch; solo-op requires docs that match reality (WAY_FORWARD.md) |

## External dependencies to watch

| Dependency | Concern |
|-----------------------------------------|-------------------------------|
| openxlsx | Known traps (blank-row shift, "NA" coercion) — mostly defended; keep readxl for value-critical reads |
| No JS runtime deps | The v2 report's biggest asset; keep it that way |

## Summary

The module is production-solid on the path it has actually been exercised on, and the test estate (4,000+ assertions) is real — but the review shows its blind spots sit precisely on the paths the next four projects introduce: fresh configs, numeric significance, confidentiality gates, NPS patterns, wave recovery. Batches 1-2 (a few focused sessions) close the gap between "CCPB works" and "any new project works"; batch 3 is the one genuine product decision. The single-settings-registry refactor is the structural investment that stops this class of drift from recurring.
