# MaxDiff: bring `feature/maxdiff-v2-report` up to date and land it

**Date:** 2026-09-03. Written by the Fable session that reviewed Session A and landed its follow-ups. For the Opus session that does the merge work.
**Read first, in this order:** this document; `docs/v2_lift/REVIEW_FINDINGS_MAXDIFF_SESSION_A_2026-09-03.md` section 7 (what changed today and how it was verified); `docs/v2_lift/SESSION_BC_NOTES_MAXDIFF.md` on the `feature/maxdiff-v2-report` branch (the implementing session's account of B2 and C, treat as claims); `modules/maxdiff/tests/testthat/test_review_followups.R` (the tests today's fixes must keep passing). Load the `fable-method` skill. Project CLAUDE.md applies.

---

## 0. Where the two branches are

| Branch | Base | State | On origin |
|---|---|---|---|
| `feature/maxdiff-correctness` | local main `f03ee8df` | 9 Session A commits to `6d3e0165`, then 15 commits today (`7ddb716b`..`c35396b9`): test corrections, review findings F2 to F12, Duncan's F5 ruling, the first-ever Stan run and its three fixes, renv now locking cmdstanr, and a copy of the Karoo example. Suite 963 / 0 fail / 1 correct skip / 0 error. **Duncan eyeballed a full Karoo run on 2026-09-03 and is merging this to main.** | first 9 yes, today's 15 no |
| `feature/maxdiff-v2-report` | `6d3e0165` (the OLD tip of the branch above) | B2 tabs share export, C v2 island + MaxDiff tab, examples, integrated demo; 47 files, +3588 / -890, tip `5a4fc0f5`. Lives in a worktree at `.claude/worktrees/maxdiff-v2-report`. Its notes say the simulator and the integrated demo were browser-verified on 2 September. Not verified by the reviewing session. | no |

Both branches therefore share the nine Session A commits and diverge after `6d3e0165`. Nothing on the v2 branch has seen today's fixes; in particular it was built while every HB run was the empirical-Bayes fallback, because cmdstanr was not installed until this evening.

## 1. The job

Rebase or merge `feature/maxdiff-v2-report` onto main once main carries `feature/maxdiff-correctness`, resolve the conflicts listed in section 2 the way section 2 says, get both suites green, exercise the tabs export gate against a real Stan fit, run the integrated demo, and leave the branch ready for an independent review. Do not merge to main yourself. Do not amend anything that is on origin. Do not push.

Recommended mechanics: `git merge main` into the v2 branch (in its worktree, or check it out in the main checkout after Duncan's merge). A rebase rewrites 15-odd commits that were never pushed, which is allowed, but a merge keeps the browser-verified history intact and the conflict set is the same either way.

## 2. Conflicts to expect, and how to resolve each

These are the files both branches changed after `6d3e0165` (computed by `git diff --name-only` on each side).

| File | Today's side | v2 side | Resolution |
|---|---|---|---|
| `modules/maxdiff/tests/testthat/test_data_reshape.R`, `test_design.R`, `test_logit.R` | commit `7ddb716b`, taken verbatim from the v2 branch's `992d945c` | the same fix | Identical content; take either. Confirm with `git diff` that nothing else differs. |
| `modules/maxdiff/R/00_main.R` | F2 (late events fold into the run state, `note_late()`), F11 stats-pack assumption, F4-related merge of `HB_Mean_SE`, TURF weights already from Session A | B2 export call site, C island writer call site, retired report path per the conjoint precedent | Keep BOTH. Today's F2 block sits at the end of `run_maxdiff_generate_outputs`; the v2 branch adds steps in the same function. Make sure any new step the v2 branch adds after `run_result` is built uses `note_late()` for its failures, not `add_warning()` alone, or its refusals will vanish from the verdict the way the HTML refusal did. |
| `modules/maxdiff/lib/html_simulator/01_simulator_data_transformer.R` | F3: drops the ID column by name before the numeric filter | simulator fixes from B1 | Keep both. The ID strip must stay ahead of the `is.numeric` filter. There is a test for it (`F3: the simulator island never carries the respondent ID`). |
| `modules/maxdiff/templates/create_maxdiff_template.R` and the committed `maxdiff_config_template.xlsx` | `Generate_Stats_Pack` default YES, regenerated | new B2 settings rows (`Generate_Tabs_Export`, `Tabs_Question_Code`, `Allow_Approx_Utilities_Export`) | Take the v2 rows and today's YES. Regenerate the xlsx from the merged script (`create_maxdiff_template()`), snapshot the old binary first, and re-run the H6 round-trip test. |
| `modules/maxdiff/docs/USER_MANUAL.md`, `modules/maxdiff/README.md` | F5 (`HB_Utility_SD` meaning, new `HB_Mean_SE` row), F9 (STUDY_IDENTIFICATION drift removed), logit SE caveat | B2 export section, C tab section | Keep both; the sections do not overlap in meaning. Check the merged manual still says `HB_Utility_SD` is the spread across respondents on both paths. |
| `examples/maxdiff/*` | copied verbatim from the v2 branch (`c35396b9`), minus `Output/` | the originals | Identical; take either. |
| `docs/v2_lift/V2_LIFT_PROGRAM.md` | maxdiff row and log entries for the review, F5, PROG-1 | its own row and log entries for B and C | Keep both sets of log entries in date order; merge the maxdiff row by hand so it reads as one status. |

Also check, even though git will not flag them: the v2 branch's `01_data_transformer.R` and `99_html_report_main.R` if it touched them (today's F3 added `.md_drop_id_cols()` there), and `01_config.R` if the v2 branch registered its three new settings in `.known_project_settings` or `get_default_output_settings()` (today's M10 code warns on unknown names; the Karoo config on this branch warns about exactly those three, which is the symptom that they are not registered on this side).

## 3. What today's Stan availability changes for B2

The tabs share exporter refuses under the empirical-Bayes fallback unless `Allow_Approx_Utilities_Export = YES` (locked decision 4 in the original handover). When B2 was built, every run was the fallback, so the refusal path is the only one that can have been exercised for real. Now:

- Run the Karoo example with `Generate_HB_Model = YES` and `Generate_Tabs_Export = YES` and no override. It must export, and the METHOD sheet must say Stan HB with the chain and iteration counts and the Rhat range. Budget 12 minutes; sampling alone is about 5 on 400 respondents.
- Then run it with `Generate_HB_Model = NO` (or temporarily hide cmdstanr) and no override: it must refuse with `CALC_APPROX_UTILITIES`.
- The shares must be computed from `individual_utilities` after the ID strip. A numeric `RespID` is the case to test; today's F3 test fixture shows how.
- `HB_Mean_SE` is a new column in `population_utilities`; if the exporter or the island writer selects columns by name, add it where a precision belongs, and make sure the island does not present `HB_Utility_SD` as an SE anywhere. Under Stan `HB_Utility_SD` is the spread across respondents, same as under the fallback.

## 4. Verification before you hand over

1. `Rscript -e 'testthat::test_dir("modules/maxdiff/tests/testthat")'` from the repo root: 0 fail, 0 error; the one acceptable skip is "check_cmdstanr_availability returns FALSE when cmdstanr not installed". Quote the counts from your own run.
2. `testthat::test_dir("modules/tabs/tests/testthat")`: 0 fail, 0 error.
3. The Karoo runs in section 3, both directions.
4. The integrated demo in `examples/integrated_demo` through `launch_turas()` is Duncan's; you can run its build headlessly since it is synthetic, and grep the produced HTML for the MaxDiff tab and the `MDSHARE` allocation table.
5. `git status --short` shows only what you meant to change. Note that `claude.md` at the repo root has been modified in the working tree since before 2026-09-03 and is not yours.

## 5. Two things Duncan noticed on his eyeball, for the record

- **Chart labels truncate with an ellipsis.** Every SVG chart in the old report hard-truncates item labels at 18 to 25 characters (`modules/maxdiff/lib/html_report/04_chart_builder.R:81, 164, 234, 434, 589, 692`). This is P3 from the July review. Under the conjoint precedent the old report is retired once the v2 tab lands, so fix the labels in the v2 view, not here, and confirm the v2 view wraps or widens rather than truncating. If the old report is kept for any reason, wrapping those six sites is a Session B item.
- **TURF reaches 100% reach at one item on Karoo.** Not a defect. `TURF_Threshold` defaults to `ABOVE_MEAN` (`modules/shared/lib/turf_engine.R:47`): a respondent counts as reached by an item when that item's utility is above the respondent's own mean, and with ten items and a strong favourite almost everyone has the top item above their mean. `TOP_K` with `k = 3` gives a curve that means something. Consider making the Karoo config use `TOP_K` so the demo's TURF table is informative, and say in the manual which threshold produced the table.

## 6. Then

Independent review of the merged v2 branch (fresh session, briefed as independent, same method as `REVIEW_FINDINGS_MAXDIFF_SESSION_A_2026-09-03.md`), Duncan merges, and segment is next in the module queue.
