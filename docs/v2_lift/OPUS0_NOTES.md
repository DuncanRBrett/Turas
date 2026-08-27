# OPUS-0 Socket Consolidation — implementation notes

Branch: `feature/opus0-socket-consolidation`, off main. **Not merged.**
Spec: `docs/v2_lift/HANDOVER_OPUS0_FOR_OPUS.md`. Implemented 2026-08-27.

Locked decisions taken as the handover's defaults: island hardening pulled into
OPUS-0 (§0.1), maxdiff's divergent Kish copy re-pointed (§0.2), the min-base
gate shaped as a predicate (§0.3).

---

## Definition of done

| Item | State |
|---|---|
| `modules/shared/lib/effective_n.R` exists; tabs + confidence source it; confidence's inline copy deleted | done |
| Golden n_eff tests pass | done — 63 assertions, `modules/shared/tests/testthat/test_effective_n.R` |
| `modules/shared/lib/disclosure_gate.R` exists; ≥1 tabs caller re-pointed | done — two (the proportion z-test and the weighted Welch test) |
| Boundary unit test | done — `test_disclosure_gate.R` |
| `turas_pins.js` island hardened; save→reload round-trip test | done — `test_turas_pins_island.R`, 10 cases |
| Suites green, real numbers quoted | done — see below |
| `*_pins.js` inventory recorded; no wrapper deleted | done — see below |
| Fable pre-merge review | **owed** — Duncan launches it; not this session |

**Suites, after the last change.** Baselines were 0 failures everywhere; these
are the after figures, `fail / err / skip / pass`:

| Module | Result |
|---|---|
| shared | 0 / 0 / 1 / 903 |
| tabs | 0 / 0 / 1 / 5114 |
| confidence | 0 / 0 / 0 / 1063 |
| catdriver | 0 / 0 / 1 / 673 |
| brand | 0 / 0 / 2 / 2155 |
| keydriver | 0 / 0 / 4 / 940 |
| maxdiff | 0 / 0 / 4 / 797 |
| tracker | 0 / 0 / 0 / 1969 |
| pricing | 0 / 0 / 0 / 845 |
| segment | 0 / 0 / 1 / 1026 |
| report_hub | 0 / 0 / 0 / 360 |

---

## Corrections to the handover

### The confidence Kish copy is NOT verbatim identical to tabs
W1 states "The confidence copy is **verbatim identical** to this, so no number
moves." It is not. Verified by execution before any edit:

| weights | tabs | confidence |
|---|---|---|
| `c(1, 1, 3)` | 2.2727… | 2 |
| `c(0.5, 1, 1.5, 2, 3)` | 3.8788… | 4 |

tabs returns the fractional statistic and says so in a comment; confidence
rounds to an integer. A naive consolidation under one name would have silently
changed one module's numbers — exactly what this branch must not do. The shared
file therefore offers both, named for what they are: `calculate_effective_n()`
fractional, `calculate_effective_n_int()` rounded. Confidence's nine call sites
now ask for the integer explicitly.

### maxdiff's divergence is not float-vs-integer
§0.2 describes maxdiff's copy as differing by "no rounding (returns a float, not
an integer)". Both tabs and maxdiff return floats. The real divergence is a
missing finite filter and no scale normalisation. Measured against the canonical
implementation:

| case | tabs | maxdiff |
|---|---|---|
| ordinary weights | 169.183 | 169.183 |
| all equal | 40 | 40 |
| extreme but finite | 85.916 | 85.916 |
| contains `Inf` | 2.5714 | **NaN** |
| overflow scale (`1e200`) | 2.5714 | **NaN** |

So re-pointing maxdiff is numerically inert on any real data and removes two
NaN failure modes. Much safer than §0.2 feared — no golden-value change to call
out, only NaN becoming a number.

### The island escape specified is the superseded one
W3a says to escape `</`, "mirroring the R-side semantics at
`build_report_v2.R:88-89`". That file no longer does that. It escapes **every**
`<` as `<`, with a comment recording why `</` alone failed: `<!--`
followed by `<script` enters the parser's script double-escaped state, and a
respondent pasting an HTML email into an open-end was enough for a blank report
(review 2026-08, I14). This branch mirrors the current approach.

---

## Findings

### `calculate_deff` is two different statistics sharing a name — NOT consolidated
- `modules/confidence/R/03_study_level.R` defines it as `1 + CV²` (Kish
  approximation, sample sd).
- `modules/maxdiff/R/utils.R` defines it as `n / n_eff`.

These are not the same number. W1 says to move `calculate_deff()` into shared
"if you re-point maxdiff", but doing so would have to pick one definition and
move the other module's numbers. Left alone deliberately, and flagged: someone
has to decide which definition the platform means before this can be one
function.

### `report_hub` had the identical island vulnerability, outside the scoped inventory
`modules/report_hub/js/hub_pins.js` writes its own island rather than going
through TurasPins, so the shared fix does not reach it. W3b lists it as
"KEEP — hub-level, out of programme scope", which is true of the pin
*consolidation* but not of the island *format*. Hardened the same way; a test
now fails if any `*_pins.js` writes an island without escaping.

### `simulator_pins.js` is dead code, not a thin wrapper
`modules/maxdiff/lib/html_simulator/js/simulator_pins.js` (461 lines) is a
second, independent pin engine (`SimPins`), not a delegating wrapper — and
nothing loads it: `99_simulator_main.R` reads `sim_pins.js`. Recorded for
maxdiff's own session. Not deleted: OPUS-0 deletes no wrapper.

---

## `*_pins.js` inventory (W3b) — nothing deleted

Every file enumerated and checked for a direct island write, rather than
inferred from its header comment.

| File | Lines | Writes island itself | Verdict |
|---|---|---|---|
| `shared/js/turas_pins.js` | 400 | yes — **hardened** | the library |
| `report_hub/js/hub_pins.js` | 252 | yes — **hardened** | keep; hub-level |
| `tabs/lib/html_report/js/tabs_pins.js` | — | absent from this tree | the classic tabs report was retired 2026-08-05 |
| `tracker/lib/html_report/js/tk_pins.js` | 301 | no | keep |
| `brand/…/brand_pins.js` | 532 | no | keep — that module's own session |
| `catdriver/…/cd_pins.js` | 382 | no | keep |
| `confidence/…/ci_pins.js` | 296 | no | keep |
| `conjoint/…/cj_pins.js` | 486 | no | keep — retired with conjoint's classic report in its Session C |
| `keydriver/…/kd_pins.js` | 294 | no | keep |
| `maxdiff/…/md_pins.js` | 536 | no | keep |
| `maxdiff/html_simulator/sim_pins.js` | 215 | no | keep — the simulator's live wrapper |
| `maxdiff/html_simulator/simulator_pins.js` | 461 | no | **dead** — nothing loads it (finding above) |
| `pricing/…/pricing_pins.js` | 331 | no | keep |
| `segment/…/seg_pins.js` | 325 | no | keep |
| `weighting/…/wt_pins.js` | 303 | no | keep |

---

## What this unblocks

The five gated Session Cs: `feature/maxdiff-v2-report`,
`feature/conjoint-v2-report`, `feature/keydriver-v2-report`,
`feature/catdriver-v2-report`, `feature/brand-v2-plumbing`.
