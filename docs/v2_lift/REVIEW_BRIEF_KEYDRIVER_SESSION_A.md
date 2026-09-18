# KeyDriver Session A. Independent review brief

**Written:** 2026-09-17, by the session that built Session A, for a session
that did not.

**You are independent of the implementation.** Treat the code as a claim.
Section 2 of `HANDOVER_KEYDRIVER_FOR_OPUS.md` is the specification; the
implementation is not. Where the author's reasoning appears below it is there
to be falsified.

`docs/v2_lift/SESSION_A_NOTES_KEYDRIVER.md` is the author's account of the
author's own work. **Do not read it until section 4 of your own findings is
written.** Then read it and say where it and your findings disagree.

---

## 0. What you are being asked

Four questions.

1. **Are the numbers right where they were wrong before?** Two CRITICALs and
   six HIGHs were wrong client-facing numbers or features that produced none.
   Verify each by execution, in both directions, not by reading the diff. The
   new Suiderland example exists for exactly this.
2. **Are the new refusals calibrated for real studies?** Several runs that used
   to complete now stop or degrade: a near-singular mixed model, an
   all-categorical correlation request, an unrecognised quadrant source, a
   pre-flight Error, a segment variable absent from the data, a dominance run
   truncated past fifteen drivers. Each is defensible. Would any of them block
   a legitimate study, and does each refusal tell the analyst what to do?
3. **Is the new green earned?** The suite went from 337 tests / 940 passing /
   4 skips to 395 / 1,198 / 2, all written by the author. Is any new test
   asserting what the code does rather than what is correct? Two of the
   original four skips were tests that named a function that does not exist and
   had therefore never run; check there are no others of that shape.
4. **Did anything that worked stop working?** The config loader, the template,
   the GUI, the Excel writer, the quadrant charts and the HTML report all
   changed shape or inputs.

### Pay particular attention to

- **`modules/shared/lib/import_all.R`.** Session A changed the shared loader
  used by NINE modules. It is the only change outside `modules/keydriver`.
  Satisfy yourself it cannot break another module's loading, on any of the
  paths those modules use.
- **The example is part of the deliverable.** `examples/keydriver/` builds a
  study whose true driver order is known by construction. Build it, run both
  configs, and check the claim. If the example's own fixture is wrong, every
  conclusion drawn from it is worthless, so audit the generator as code, not
  as scenery.
- **The branch history was rewritten on 2026-09-17.** Three commits belonging
  to another session had landed on it; they were moved to
  `steps/rescued-from-keydriver` and this branch was rebuilt from main. It
  should now contain 16 commits touching only `modules/keydriver`,
  `modules/shared/lib/import_all.R` and its test, `examples/keydriver` and
  `docs/v2_lift`. Confirm that, because if anything else is on it the untangle
  was incomplete.

### Out of scope, do not re-open

- **The locked decisions** in `HANDOVER_KEYDRIVER_FOR_OPUS.md` section 0. If
  you think one is wrong, one paragraph at the end.
- **Sessions B and C.** Config, template, GUI and report honesty is Session B;
  the v2 island and view is Session C. Session A deliberately left
  `results$segment_comparison` pointing at the first segment variable because
  the HTML report reads that slot and the report is Session B's.
- **The deferred items** the handover names: extending the bootstrap to
  Shapley, and the None-alternative work.

---

## 1. The specification

Read these, in this order.

1. `docs/v2_lift/HANDOVER_KEYDRIVER_FOR_OPUS.md`, sections 0, 1 and 2.
2. `docs/v2_lift/KEYDRIVER_PRODUCTION_REVIEW_2026-07-11.md`, the findings each
   fix references by ID.
3. `docs/v2_lift/V2_LIFT_PROGRAM.md` sections 1 and 2 for the standing
   decisions and the method.

## 2. The work under review

`feature/keydriver-correctness`, 16 commits, one per work item A1 to A11 plus
the example, the notes and the shared loader fix. `git log main..HEAD` lists
them. Not merged, not pushed.

## 3. Method

Section 2 of `V2_LIFT_PROGRAM.md` sets it: independent readers on separate
concerns, then a coordinator who re-verifies every CRITICAL and every
load-bearing HIGH by execution. Suggested concerns: the importance engine
(C1, H4, M1, M6); the segment and dominance layers (C2, H5); the features that
had never produced a number (H6, H7, H8); and the example plus the shared
loader.

Run the suite yourself and quote your own numbers. From the repo root:
`testthat::test_dir("modules/keydriver/tests/testthat")`, and the shared suite
too, since the loader changed.

Do not write into `examples/*/Output` beyond rebuilding the keydriver example
into a scratch folder, and never into OneDrive. Duncan regenerates through
`launch_turas()`; a session does not. He ran the example on 2026-09-17 and the
driver order matched the README.

## 4. The deliverable

`docs/v2_lift/REVIEW_FINDINGS_KEYDRIVER_SESSION_A_<date>.md`, with a verdict of
PASS, PASS WITH FIXES or BLOCK, findings numbered and rated, each saying
whether it was verified by execution or by reading, and a closing section
naming what you could not verify. Update the keydriver row and the log in
`V2_LIFT_PROGRAM.md`. Do not fix anything unless Duncan asks: the review record
and the fix record stay separate in this repo.
