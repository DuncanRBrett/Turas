# Pricing: the Session A review follow-ups

Built 2026-09-16 on `fix/pricing-review-a-followups-2`, five commits off main
`9df7b044`. Brief: section 6 of
`docs/v2_lift/REVIEW_FINDINGS_PRICING_SESSION_A_2026-09-03.md`, plus Duncan's
rulings of 2026-09-03 on F4/F6 and F3.

F2 was already on main as `7fbfa461`. Everything else in the list was still
live when this session started, checked in the code rather than taken from the
tracker.

## What landed

| Finding | Commit | What |
|---|---|---|
| F1 | `cf56b220` | The binary domain check runs on long-format ladders; the coder refuses what it cannot read |
| F3 | `dfe0b23a` | NMS refuses by name, PI_Scale no longer passed, five documents say so |
| F4, F6 | `56f7c77c` | The missingness shape decides between refusing and excluding, with disclosure |
| F5 | `836aee3f` | The violation count survives the handling it describes |
| F7 to F12 | `dd951770` | Currency, zero weights, the bootstrap warning, a refusal that could not fire, three disclosure gaps, the saver locator |
| F4 knock-on | see below | The tabs export's `pricing_valid` honours the completeness exclusion |

Checked and clear: `create_pricing_config()` writes `Col_PI_Cheap` blank, so
the F3 refusal does not fire on a fresh config from the template. Verified by
generating a template and loading it back.

Pricing suite from the repo root: 28 files, 379 tests, 1,078 passing, 0 failed,
0 errors, 0 skipped, 14 warnings. The baseline at session start was 348 tests
and 984 passing. The two extra warnings are the package's own flag_only warning
from two new tests, the same one the existing H3 test raises.

Node gates: pricing view 16 passed, island encoding 18 passed.

Every new test was run against the code as found. Of the 27 added, 23 fail or
error there; the three that pass are deliberate controls (the ONE_TWO wide
path, Van Westendorp without the NMS extension, and the stop-early ladder that
must still refuse).

## Duncan's proof for F4

Required: reproduce the review's simulation table under the new rule, and show
the Karoo stop-early config still refuses.

The review's table, refusals out of 200 runs:

| Item non-response | n = 150 | n = 300 | n = 600 |
|---|---|---|---|
| 1% | 43 | 12 | 0 |
| 2% | 124 | 49 | 11 |
| 3% | 150 | 103 | 33 |
| 5% | 184 | 144 | 99 |

Under the new rule every one of those twelve cells is 0. The stop-early ladder
of the same shape still refuses `DATA_GG_UNEQUAL_BASES`, with a missingness
shape share of 1.000, and `NO_AFTER_STOP` still recovers the true curve
(0.950 / 0.740 / 0.490 / 0.290 / 0.055 on the review's fixture, optimum 40).
The Karoo test "the stop-early ladder refuses by default and passes with the
opt-in (C2)" passes unchanged.

## Decisions this session made, rather than Duncan

**F1, text handling.** The review left open whether an unrecognised spelling
should refuse. It does, on the same terms as the wide-format domain check,
because the alternative is a rung quietly losing part of its base.

**F3, a fifth document.** Duncan named `USER_MANUAL.md`, `TECHNIQUE_GUIDE.md`,
`QUESTIONNAIRE_DESIGN_GUIDE.md` and `README.md`. `docs/AUTHORITATIVE_GUIDE.md`
describes the same unavailable extension in its section 2.3, and leaving one
document recommending it while four say not to is a trap. It got the same
one-line note.

**F5, the v2 island.** Session B deliberately kept the violation count out of
the Pricing tab with a test named "the violation count stays out until the F5
fix lands". The fix has landed, so the island carries it and that test now
checks the opposite. Both new keys were added to the island's scalar
whitelist, or jsonlite would have wrapped them in arrays.

**F10, what the refusal tests.** The review offered delete or rewrite. Rewritten:
`.gg_order_derivable()` is FALSE exactly when a long-format price failed to
parse, which is a real failure worth refusing, so the refusal now describes
that instead of a missing order column.

## One thing the completeness rule broke, found and fixed in the same session

The tabs export's `pricing_valid` column reproduced validation's exclusions
only. A respondent the new Gabor-Granger completeness rule set aside afterwards
would therefore sit in the tabs base with no mention at any rung, reading as
"would not buy at any price" and pulling every rung below the module's own
curve. `.pricing_tabs_valid_flag()` now also drops anyone absent from the frame
the curve was computed from. On the probe fixture the exported base is 259 of
300, matching the module's analysed base exactly, with 41 zeros.

## A dead field, found by Duncan's eyeball

`diagnostics$warning` in `03_van_westendorp.R` was set and read nowhere: not
printed, not written to a sheet, not in the stats pack. That was true before
this work; F5 only changed which rate fed it, so a dead field went from saying
nothing to saying nothing. Turas runs inside Shiny and the console is where a
run is debugged, so it now prints, names the count and the handling, and points
at the stats pack. Duncan asked for this before the merge.

On the shipped Karoo config the line reads:

```
[WARNING] Van Westendorp Monotonicity: 44 respondents (11.0%) gave illogical
price sequences. Review data quality. Handled as 'drop'; the stats pack records
the count.
```

Nothing else about violations reaches the pricing console, before or after.

## What Duncan should know

**The exclusion rate is not small.** Gabor-Granger completeness is 1.0, so a
respondent missing any rung leaves the analysis. On a five-rung ladder with 3%
independent item non-response that is about 14% of the sample: the probe run
this session excluded 41 of 300. This is the ruling working as intended, and
the count and rate are disclosed in the console, the diagnostics, three
stats-pack rows and the workbook's Validation sheet. It is still a number worth
seeing before a client does.

**The Karoo both-methods run now prints a warning it never printed before**,
for the reason in the section above. The run is still PASS and the price points
are unchanged. Checked by running the shipped config headless this session.

**The NMS question from the review is still unanswered.** The old code called
the package with the intent columns on its defaults, which on this install
returns reach 0 everywhere. Whether a revenue-optimal figure from that path
ever reached a client is Duncan's to check; no code change can settle it.

## Still open

- **F11, fourth part.** The shared `stats_pack_writer.R` writes em dashes into
  every module's Declaration and Warnings rows. Out of scope per the review
  brief, and it is shared code, so it stays Duncan's call.
- **F13 and F14** are INFO in the review and were not addressed: four test
  assertions weaker than they look, and the monadic Executive_Summary's
  "Two methods available for comparison" on a one-method run.
- **A wider gap F10 exposes.** A long-format price column that does not parse
  is only caught under `NO_AFTER_STOP`. Without that setting the prices become
  NA and the demand curve is built on them. Not fixed: it needs a validation
  check of its own rather than a refusal inside the imputation branch.
- **Duncan's 90% threshold has an edge.** A genuine stop-early ladder whose
stoppers also carry stray blanks, enough that fewer than 90% of the incomplete
respondents match the staircase, takes the exclusion route instead of refusing.
Everyone incomplete leaves, the survivors are the ones who said Yes at every
rung, and the disclosed exclusion rate is the only signal that it happened.
His rule, his call, but worth knowing it exists.

**Pre-existing, observed not diagnosed.** In a probe run the workbook's
  Validation sheet printed an "EXCLUSION BREAKDOWN" heading with no rows under
  it. The condition guarding that block tested non-empty, so something in the
  breakdown frame read as blank. Nothing to do with this work.

## Not verified

The GUI path, `launch_turas()`, and a regeneration of the Karoo deliverables.
No workbook under `examples/pricing/Output` was touched, and nothing was
written to OneDrive. Duncan regenerates; a session does not.

## Duncan's eyeball, 2026-09-17

Run through `launch_turas()` on this branch. `Karoo_Pricing_Config.xlsx`
completed. `Karoo_Pricing_Config_StopEarly.xlsx` refused, which is the C2
protection the F4 rule had to keep and the thing most at risk from this change.

The eyeball found the dead warning field above, because the line it was told to
expect was not there. Fixed before the merge on Duncan's instruction.

Confirmed by this session against the real Karoo output rather than a fixture:
the Price_Ladder sheet reads "Standard tier anchored to optimal price point
(R100.99)", which carried a dollar sign before; the stats pack's Assumptions
sheet carries "VW: violations_before_handling | 44 (11.0%)" beside the old
"VW: violation_rate | 0.0%"; and the console now carries the warning line.

Owed: the merge.
