# Pricing Session B. Independent review brief

**Written:** 2026-09-17, by a session that did not build Session B, for a session
that also did not.

**You are independent of the implementation.** Session B was built on 2026-09-04
and merged to main without any independent review. It is the only piece of the v2
lift programme that reached main unreviewed. Duncan has run the integrated demo and
the Karoo configs through `launch_turas()` since, and they completed, but nobody has
checked the work itself. Treat the code as a claim, not as a starting position.

`docs/v2_lift/SESSION_B_NOTES_PRICING.md` is the author's account of the author's
own work. Do not read it until section 4 of your own review is written. Then read
it and say where it and your findings disagree.

---

## 0. What you are being asked

Four questions.

1. **Does the client see the right numbers?** Session B put pricing into the tabs
   v2 report for the first time: an island written by `14_v2_island.R`, a Pricing
   tab rendered by `27z_pricing.js`, a crosstabbable export written by
   `15_tabs_export.R`, and a standalone simulator. Every one of those is a new path
   from the engine to a client's eyes. Verify by execution that what the tab and the
   export show equals what the engine computed. Hand-recompute at least one figure
   per surface rather than comparing the code to itself.
2. **Is the tabs contract actually honoured?** The author found two contract facts
   the July brief had wrong and says both are now pinned by tests: a `Multi_Mention`
   counts a mention by comparing each cell to the option's `OptionText`, so a grid
   of 0/1 flags reports zero at every row; and its option rows are keyed by column
   (`GGACC_1`), not by the question code. Confirm both against tabs' own code, and
   look for a third.
3. **What did the retirement break?** `Generate_HTML_Report` is withdrawn rather
   than retired: it announces and the run continues, deliberately, so that configs
   in the field do not refuse over a deliverable that moved. Check that a config
   carrying the old setting still produces everything else it used to, and that
   nothing downstream believes a report exists when none was written.
4. **Is the new green earned?** The pricing suite and 41 node gate files all pass.
   Is any new test asserting what the code does rather than what is correct? The
   author's own list of what was not verified is in section 0 below.

### The author said these were not verified

Take them as leads, not as the limit of your scope: the GUI path, the workbooks
opened in Excel itself, and `turas_prepare_deliverable()` minifying the standalone
simulator (only ever exercised headless, where that function does not exist).

### Out of scope, do not re-open

- **Session A and its review follow-ups.** The engine correctness work is reviewed
  (`REVIEW_FINDINGS_PRICING_SESSION_A_2026-09-03.md`) and its follow-ups landed on
  2026-09-17 as the commits between `cf56b220` and `9ad4ce85`, with their own log at
  `NOTES_PRICING_REVIEW_A_FOLLOWUPS.md`. They are on main and they touch the same
  files, so read around them. If one of them broke something Session B built, that
  IS in scope and is exactly the kind of thing this review should catch.
- **The decisions in `HANDOVER_PRICING_V2_FOR_OPUS.md` section 1 and the rulings in
  its section 7.** If you think one is wrong, one paragraph at the end.
- **The shared stats-pack writer's em dashes.** Shared code, Duncan's call.
- **Whether pricing should have a v2 view at all.** It was decided twice.

---

## 1. The specification

Read these, in this order. They are the specification. The implementation is not.

1. `docs/v2_lift/HANDOVER_PRICING_V2_FOR_OPUS.md`, section 4, which is the brief
   Session B was built from.
2. `docs/v2_lift/V2_LIFT_PROGRAM.md`, sections 1 and 2: the standing decisions and
   the pipeline, in particular D1 curated content, D2 simulators standalone, and D5
   the honest-sig principle.
3. `modules/tabs/docs/V2_MIGRATION_PLAN.md` for the socket contract.

## 2. The work under review

Four commits, all on main:

| Commit | What |
|---|---|
| `ed19c98a` | B2, the tabs side: the Pricing tab and its wiring |
| `c9914973` | B1, B3, B4: the island, the tabs export, the standalone simulator, the classic report withdrawn |
| `67ba8195` | B5: the integrated demo gains pricing, plus the author's notes |
| `089ef7d2` | the chart's colliding price-point labels |

`git diff ed19c98a~1..089ef7d2` is the delta, but read it in the context of current
main, which has moved.

## 3. Method

Section 2 of `V2_LIFT_PROGRAM.md` sets the method: independent readers on separate
concerns, then a coordinator who re-verifies every CRITICAL and every load-bearing
HIGH by execution. Suggested concerns here: the island and the view; the tabs
export against tabs' own processors; the simulator; and the withdrawal path plus
the demo.

Run the suites yourself and quote your own numbers. From the repo root:
`testthat::test_dir("modules/pricing/tests/testthat")`, the tabs R suite, and the
node gates under `modules/tabs/lib/html_report_v2/tests/`.

Do not regenerate anything into `examples/*/Output` and do not write to OneDrive.
Duncan regenerates through `launch_turas()`; a session does not.

## 4. The deliverable

`docs/v2_lift/REVIEW_FINDINGS_PRICING_SESSION_B_2026-09-17.md`, with a verdict of
PASS, PASS WITH FIXES or BLOCK, findings numbered and rated, each one saying
whether it was verified by execution or by reading, and a closing section naming
what you could not verify. Update the pricing row and the log in
`V2_LIFT_PROGRAM.md`. Do not fix anything unless Duncan asks; the review record and
the fix record stay separate.
