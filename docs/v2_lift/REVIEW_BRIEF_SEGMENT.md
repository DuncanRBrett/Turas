# Segment Sessions A, B and C. Independent review brief

**Written:** 2026-09-21, by the session that built the work, at Duncan's
instruction to commission the review.

**That is the first thing to hold on to.** This brief was written by the
author. Every statement in it is a claim about the author's own work, including
the ones that sound like evidence. Where it says something was "verified", the
verification is the author's; reproduce it or disbelieve it. Do not take the
framing here as the shape of the problem.

The three session notes (`SESSION_A_NOTES_SEGMENT.md`,
`SESSION_B_NOTES_SEGMENT.md`, `SESSION_C_NOTES_SEGMENT.md`) are the author's
running account of the author's own decisions. **Do not read them until
section 4 of your own review is written.** Then read them and say where they
and your findings disagree. They contain a dozen judgment calls that deserve
to be challenged, and a reviewer who reads the defence first will find it hard
to challenge them.

---

## 0. What you are being asked

Five questions.

1. **Were the two CRITICALs real, and are they fixed?** Verify by execution in
   both directions: reproduce the old behaviour at `c1151cf2` and check the new
   one. C1 is mini-batch k-means dying for any study over 10,000 rows. C2 is
   LCA, a 767-line feature no production path could reach, which is now deleted
   with a refusal in its place.

2. **Is anything now deleted that should not be?** This is the question the
   author is least able to answer about their own work. Three bodies of code
   were removed or amputated: `11_lca.R`, `14_ensemble.R`, and the
   `seg-insight-store` textarea in two report builders. A fourth,
   `calculate_gap_statistic_range()`, was deliberately KEPT while
   `calculate_separation_metrics()` was deliberately left dead. Test whether
   those four calls are consistent with each other and with the handover's
   locked decisions, or whether the author simply stopped deleting when they
   got tired.

3. **Does the new honesty reach a real user?** Sessions A and B added refusals,
   console warnings, a GUI outcome classifier, report footnotes and a
   provenance sheet, all on the claim that silence was the defect. Check each
   one fires on the path a real run takes, and lands where someone sees it. A
   console note nobody prints is the same defect in a new place.

4. **Is any of the new green earned by testing the code against itself?** The
   suite went from 1,026 passing with 1 warning and 1 skip, to 1,185 with
   neither. Find any test that asserts what the code does rather than what is
   correct, and any test that would still pass with its fix reverted. The
   author spot-checked a few this way; check the rest.

5. **What did fourteen commits break?** They touch the clustering dispatcher,
   the config parser, the scoring entry points, the profiling statistics, the
   validation metrics, the GUI, four report builders, the template generator
   and `launch_turas.R`.

---

## 1. Scope

Fourteen commits on `main`, `d3ba63d6` to `5afa835d`, merge base `c1151cf2`.
All merged and pushed. Nothing is on a branch.

```
git diff c1151cf2..HEAD -- modules/segment examples/segment launch_turas.R
```

Suites, as the author measured them. Reproduce rather than trust:

| | FAIL | WARN | SKIP | PASS |
|---|---|---|---|---|
| Segment at `c1151cf2` | 0 | 1 | 1 | 1,026 |
| Segment now | 0 | 0 | 0 | 1,185 |
| Tabs now | 0 | 1 | 1 | 6,215 |

`Rscript -e 'testthat::test_dir("modules/segment/tests/testthat")'` from the
repo root.

The July review is `SEGMENT_PRODUCTION_REVIEW_2026-07-11.md` and the work order
is `HANDOVER_SEGMENT_FOR_OPUS.md`. Findings are referenced by their IDs
(C1, C2, H1 to H3, M1 to M8, L1 to L5).

---

## 2. The decisions most worth attacking

Each of these is the author's judgment, not the handover's instruction. Any of
them could be wrong.

1. **`use_lca = FALSE` is not refused, `use_lca = TRUE` is.** The reasoning was
   that an old template carrying the default must stay runnable. A reviewer
   might argue the key should be refused whatever its value, or that the
   warning in `segment_warn_unused_settings()` already covers it.

2. **`calculate_gap_statistic_range()` kept; `calculate_separation_metrics()`
   left dead.** Both are exported, correct and uncalled. The author kept the
   first because deleting an exported function is an API break, and left the
   second because wiring Calinski-Harabasz and Davies-Bouldin into every run is
   a feature. Meanwhile `k_selection_metrics` is parsed and offers both as
   choices while nothing reads it. Decide whether that leaves the module
   advertising two metrics it cannot compute, which is the exact shape of C2.

3. **`golden_questions_trees` hard-coded** as `SEGMENT_GOLDEN_QUESTION_TREES`
   rather than made a real setting. L1 allowed either.

4. **Nominal variables routed to chi-square with Cramer's V (M3), and a
   variable with more than 30 categories skipped with a console note.** The 30
   is the author's number and appears nowhere else in the module.

5. **`segment_should_write_stats_pack()` lets the GUI option win when set.**
   This was not in the handover. It means a GUI run ignores the config's Y/N
   whenever the checkbox has been touched, and the checkbox does not
   initialise from the config.

6. **`company_name` and `researcher_name` were NOT added as settings**; the
   report was rewired to read `research_house` and `analyst_name` instead,
   while `client_name` WAS added. Check that asymmetry is defensible.

7. **The tabs export refuses a partial join by default.** A reviewer might
   think a warning would do. The author's argument is in the refusal text;
   test whether it holds.

8. **The banner stub does not write into the user's `Survey_Structure.xlsx`.**
   It emits rows to paste. Decide whether that is caution or an unfinished job.

---

## 3. Places to look that the author may have missed

- **The join in `15_tabs_export.R`.** It is new code on a path with no
  precedent in this module. It matches with `match()` on `as.character()` of
  both keys. Consider numeric IDs, leading zeros, whitespace, factors, and an
  ID column read as a different type from each file. The author tested none of
  those.
- **`segment_gui_outcome()`** is tested at function level, and the GUI wiring
  is asserted by reading `run_segment_gui.R` as text. No Shiny reactive was
  ever executed. A refusal has never been through the actual GUI.
- **The report layer changes** (`03b`, `03c`, `06`, `07`, `07a`) were verified
  by regenerating the worked example and reading the HTML. Combined mode was
  exercised once, with `kmeans,hclust`. GMM in combined mode was not run at
  all.
- **`build_seg_importance_footnote()`** decides between eta-squared and F from
  the columns present. Check what happens when both are present, and which one
  the percentages were actually built from in that case.
- **The example itself** (`examples/segment/`) is the author's own fixture,
  built to make the author's own code look right. Its "99.6% recovery" is a
  claim about a dataset the author designed.

---

## 4. Rules

Review only. No code changes, except that fixes you make to your own findings
are welcome if you commit them separately and say so.

No fabrication. Every finding carries `file:line` evidence read this session,
and anything unverified is labelled inline, next to the claim. Do not report a
defect you have not reproduced.

Verdict by execution wherever the old code can be sourced: a CRITICAL or HIGH
claim should fail at `c1151cf2` and pass now, or you should say why you could
not run it.

Deliverable: `docs/v2_lift/REVIEW_FINDINGS_SEGMENT_2026-09-XX.md`, and an
update to the segment row in `V2_LIFT_PROGRAM.md` §4 and the §5 log. Use the
severity scale the other reviews use (CRITICAL, HIGH, MEDIUM, LOW) and open
with a one-paragraph verdict: MERGE, MERGE AFTER FIXES, or BLOCK. The work is
already merged and pushed, so a BLOCK means a revert, and say so plainly if
that is your finding.
