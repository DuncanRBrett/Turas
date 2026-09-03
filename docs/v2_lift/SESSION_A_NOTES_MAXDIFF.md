# MaxDiff Session A — implementation notes

Branch: `feature/maxdiff-correctness`, off local main (which by then carried
the conjoint v2 merge). **Not merged. Duncan merges after regen + eyeball,
after the Fable independent pre-merge review.** Eight commits, one per work
item (A1–A8), each with tests proven to fail on the old code.

Suite: baseline **797 pass / 0 fail / 4 skip** → after Session A
**902 pass / 0 fail / 0 skip**. Every fix's new tests were run against the
stashed old code and failed there (counts per commit message).

---

## What landed, by work item

| Item | Review IDs | Delta |
|---|---|---|
| A1 | C2 | `strip_respondent_id_cols()`; applied in shares, head-to-head, discrimination, and the TURF call-site (shared engine untouched for brand) |
| A2 | C1, M1 | `stan_declared_data()` whitelists the 8 declared members; designated anchor reordered to the model's last slot, extraction maps back |
| A3 | C3 | `Choice_Value_Type` = ITEM_ID \| ITEM_POSITION; position decode through the design row; out-of-range refuses; validation checks the declared coding |
| A4 | H1–H3, M13 | segments join on the configured ID; absent Weight/ID columns refuse; `validate_maxdiff_weights` wired in; positional design fallback removed (refuses with counts); T{n}-infix task extraction |
| A5 | H4, H5, M2, M5, M6, M11, M12 | GUI status-checks + captures messages; dropped-task disclosure; EB stamp + Spread(SD) not SE; honest stats-pack provenance; stats-pack toggle honest; report defaults ON |
| A6 | H6, M10, M14, M15 | template REGENERATED against the real loader schema and round-trips through `load_maxdiff_config`; duplicate settings refuse, unknown warn; dead sheets deleted; docs de-drifted |
| A7 | M3, M4, M7, M8, M9 | logit-SE caveat documented; excluded-but-fielded items refuse; per-engine weighting disclosure + TURF gets weights; anti-conservative count CI deleted; NA-version respondents counted |
| A8 | §5 | logit + EB recovery tests (ρ > 0.9 vs known truth); hand-computed counts math (weighted + unweighted); six silent-pass stubs now assert |

## Not verified by execution

- **The Stan sampling path.** cmdstanr is not installed in this renv, so no
  MCMC ran. A2 is verified at the data-contract level (declared members
  only, all numeric; anchor-reorder round-trip). Installing cmdstanr +
  CmdStan is Duncan's environment decision (PROG-1).
- The GUI (H4/H5) is covered by source-level tests, not a Shiny session —
  per the standing rule, Duncan exercises `launch_turas()`.

## Deviations, logged

1. **M5 column rename limited to the display layer.** The handover says
   rename the EB columns; nine consumers hardcode `HB_Utility_*`, and the
   System A report layer is retirement-bound (conjoint precedent). Chose:
   `Estimation_Method` stamp column in `population_utilities` (both paths),
   plus the report transformer/table builder rendering the EB column as
   "Spread (SD)" and never "SE". The internal column names are unchanged.
2. **M14: chose DELETE over wire** for REPORT_SETTINGS (branding already
   reads PROJECT_SETTINGS), and moved STUDY_IDENTIFICATION's
   Analyst_Name/Research_House into PROJECT_SETTINGS, where the stats pack
   reads them. IMAGES deleted; SLIDES kept (it is loaded).
3. **M8: kept `compare_segment_utilities`/`test_segment_significance`**
   (dead in production but tested; bootstrap-based, not the
   anti-conservative formula). Deleted only `add_count_confidence_intervals`.
   Segment tables still ship without significance testing — that remains
   an honest gap, stated in the 05_counts.R note.
4. **Template instruction blocks moved to side columns** — below-the-table
   rows read back as data and were a second, unreported way the template
   refused. The loader also filters furniture rows (blank Item_ID /
   Segment_ID / Field_Type) defensively.
5. **M11 semantics:** when the GUI option is set it IS the toggle (the GUI
   sets it every run); headless runs read OUTPUT_SETTINGS first, then the
   legacy PROJECT_SETTINGS spelling.

## What a regen will surface as expected, not regression

- Old configs with the pattern-schema SURVEY_MAPPING or per-level
  SEGMENT_SETTINGS now refuse with the schema named (they silently
  couldn't run before).
- Duplicate setting rows refuse; unknown names warn.
- `Generate_HTML_Report` defaults ON.
- Weighted studies show the per-engine weighting lines on SUMMARY, and the
  logit SE caveat in the manual applies.

Next: **Fable independent pre-merge review** (fresh session, briefed
independent, reads this file as the branch artifact), then Duncan merges.

---

## Correction and follow-up, 2026-09-03 (independent review session)

The suite figure above did not hold at the branch tip. At `6d3e0165` the
suite had 902 passing expectations, 0 failed, 0 skipped and **4 tests
erroring** before any assertion (test bugs in the A8 stubs-to-assertions
work, one of them the C3 non-zero-counts test). The review verdict was
FAILED as committed; the engine fixes verified in both directions. See
`REVIEW_FINDINGS_MAXDIFF_SESSION_A_2026-09-03.md`. Six further commits
(`7ddb716b`..`9f12a31e`) land the test corrections and the review's F2
to F12: report refusals now count as events, the numeric-ID phantom item
is gone from the report and simulator layer, ITEM_SCORES carries the
utility columns (a pre-existing loss), and the smaller decode, weight,
label and doc gaps are closed. Suite after: **945 / 0 fail / 0 skip / 0
error**, from the repo root.
Sessions B (report fixes + tabs exporter) and C (v2 island — note the
conjoint precedent: row kinds were superseded by a frozen island + view)
follow.
