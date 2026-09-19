# CatDriver Session A. Independent review brief

**Written:** 2026-09-19, by the session that built the work, at Duncan's
instruction to commission the review.

**That is the first thing to hold on to.** This brief was written by the author.
Every statement in it is a claim about the author's own work, including the
claims that sound like evidence. Where it says a defect was "proved", the proof
is the author's; reproduce it or disbelieve it. Do not take the framing here as
the shape of the problem.

`docs/v2_lift/SESSION_A_NOTES_CATDRIVER.md` is on the branch and is the author's
running account of the author's own decisions, including twenty numbered
deviations. **Do not read it until section 4 of your own review is written.**
Then read it, and say where it and your findings disagree. Several of those
deviations are judgment calls that deserve to be challenged, and a reviewer who
reads them first will find it hard to challenge them.

---

## 0. What you are being asked

Four questions.

1. **Are the numbers right now, and were they wrong before?** The session claims
   three CRITICALs from the July review are fixed. Verify each by execution, in
   both directions: reproduce the old behaviour on `main`, and check the new one
   against an implementation you write yourself from the definition, not against
   the module's own code. The weighted multinomial likelihood-ratio path is the
   one to write independently, because it is the one that shipped zero per cent
   importance for every driver.
2. **Does the honesty actually reach the user?** This session added refusals,
   degraded reasons, console output and stamps on the claim that silence was the
   defect. Check that each one fires on the path a real run takes and lands
   somewhere a user sees: the console, the Run_Status sheet, the stats pack, the
   workbook. A degraded reason that no sheet prints is the same defect in a new
   place.
3. **Is any of the new green earned by testing the code against itself?** The
   suite went from 227 tests and 673 passing to 278 and 919. Find any test that
   asserts what the code does rather than what is correct, and any test that
   would still pass with the fix reverted. The author checked one of these
   (`test_pipeline_end_to_end.R`) by reverting the column contract; check the
   others.
4. **What did the session break?** Eleven commits touched the engine, the guards,
   the importance path, the bootstrap, the output sheets, the template generator,
   four documents and one shared file. The unweighted binary and ordinal paths
   were said by the July review to be defensible before this session. Are they
   still the same numbers?

### The author's own list of what was not verified

Leads, not the limit of your scope.

- **Nobody has run the Shiny GUI end to end.** Not this session, not any earlier
  one. The pipeline is exercised by a test and by scripts that source the files
  in the GUI's order, which is not the same thing.
- No report was regenerated and no client project was touched. Duncan ran two
  demo configs through `launch_turas()` on 2026-09-18 and reported that the
  unified report's Overview tab is blank, which is P1 of the July review and
  Session B's to fix. It is not evidence about Session A, but the multi-config
  path is otherwise unexercised by anyone.
- The surviving suite warning is a raw `glm()` call inside a mapper test, not the
  engine.
- The stats pack's Declaration fields were fixed by mapping to the loader's own
  setting keys. Only `Project_Name` was exercised on a real config, because the
  demo carries no analyst or research house.

### Out of scope, do not re-open

- **The locked decisions in `HANDOVER_CATDRIVER_FOR_OPUS.md` section 0.** If you
  think one is wrong, one paragraph at the end. The amputation of
  `multinomial_mode` and the decision not to rebuild weighting on the `survey`
  package are both Duncan's rulings.
- **Sessions B and C.** The report layer's P-tier is Session B's: the blank
  unified Overview, slides lost on save, the dead nav links, the help button, the
  odds-ratio narration. The two dead JS files stay on this branch deliberately,
  because the HTML startup guard requires them; say so if you disagree, but do
  not treat their presence as a finding against Session A.
- **Whether catdriver should have a v2 view.** Decided.

---

## 1. The specification

Read these, in this order. They are the specification. The implementation is not.

1. `docs/v2_lift/CATDRIVER_PRODUCTION_REVIEW_2026-07-11.md`, the findings this
   session was built to close: C1 to C3, H1 to H11, M1 to M12 and section 5's
   required test additions.
2. `docs/v2_lift/HANDOVER_CATDRIVER_FOR_OPUS.md`, sections 0 to 2, which is the
   work order.
3. `docs/v2_lift/V2_LIFT_PROGRAM.md` sections 1 and 2 for the standing decisions,
   in particular D5, the honest-provenance principle.
4. The project `CLAUDE.md`: TRS refusals, console-visible errors, no `stop()`.

## 2. The work under review

Branch `feature/catdriver-correctness`, cut from main `46eb9a01`, twelve commits,
unmerged and unpushed.

| Commit | Work item | What it claims |
|---|---|---|
| `5b8147a6` | A1 | C3, the refusal system: one `catdriver_refuse`, 00_guard.R deleted |
| `5e6cd04c` | A2 | C1, H1, H2, M6: weights through every likelihood, normalised to mean 1 |
| `eee0ea2b` | A2 follow-ups | the rescale threshold, and the weight vector kept out of results |
| `88f08dea` | A3 | C2, the subgroup comparison reads the mapper's schema |
| `fa993b39` | A4 | H3, H4, the ordinal guards |
| `62f79330` | A5 | H5, M1, the bootstrap |
| `6455003f` | A6 | H6, `multinomial_mode` amputated |
| `938aeddc` | A7 | H11, M5, provenance |
| `e7d50246` | A8 | M2, M3, M4 |
| `86efc4e5` | A9 | dead code, CODE_INVENTORY, the end-to-end test |
| `04ff7be4` | notes | notes, tracker row, two provenance nits |
| `c7b17e36` | notes | the discrimination check on the pipeline test |

`git diff main..feature/catdriver-correctness` is the delta: 34 files, roughly
3,000 insertions against 2,500 deletions, most of the deletions being dead code.

## 3. Method

Section 2 of `V2_LIFT_PROGRAM.md` sets the method: independent readers on
separate concerns, then a coordinator who re-verifies every CRITICAL and every
load-bearing HIGH by execution. Suggested concerns here: the weighted likelihood
machinery, including the importance refits and the null models; the refusal and
guard layer, read in the GUI's source order rather than the test helper's; the
subgroup comparison and the output sheets; and the test suite's honesty.

Run the suites yourself and quote your own numbers. From the repo root:

    Rscript -e 'testthat::test_dir("modules/catdriver/tests/testthat", reporter = "summary")'

and the shared suite, because one line of `modules/shared/lib/callouts/callouts.json`
changed. The author's numbers are 278 tests, 919 passing, 0 failed, 1 skip,
against a baseline of 227 and 673; shared 469 and 1,330, 0 failed.

The module's demo generates its own data and config workbooks:

    Rscript -e 'demo_output_dir <- "modules/catdriver/examples/demo"; source("modules/catdriver/examples/demo/generate_demo.R")'

They are gitignored. A fifth config, `demo_config_multinomial_weighted.xlsx`, was
generated by hand this session because the shipped demo has no weighted
multinomial config, which is exactly why C1 never showed up in it. That is worth
a thought in itself: a fixture set that cannot reach the module's worst defect.

Do not regenerate anything into a client folder and do not write to OneDrive.
Duncan regenerates through `launch_turas()`; a session does not.

## 4. The deliverable

`docs/v2_lift/REVIEW_FINDINGS_CATDRIVER_SESSION_A_2026-09-19.md`, with a verdict
of PASS, PASS WITH FIXES or BLOCK, findings numbered from F1 so they do not
collide with the July review's IDs, each one rated and each one saying whether it
was verified by execution or by reading, and a closing section naming what you
could not verify. Update the catdriver row and the log in `V2_LIFT_PROGRAM.md`.

Do not fix anything unless Duncan asks. The review record and the fix record stay
separate.
