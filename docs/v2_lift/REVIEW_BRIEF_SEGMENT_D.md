# Segment Session D: independent review brief

For an Opus 5 session at high effort, fresh context, with the `fable-method` skill loaded. Paste the prompt at the end of this file. The session that builds D must not be the session that reviews it, and the reviewer must not read `SESSION_D_NOTES_SEGMENT.md` until its own findings are written.

## What is being reviewed

Branch `feature/segment-demographics`, built to `docs/v2_lift/HANDOVER_SEGMENT_D_FOR_OPUS.md`. Two work items and three wording fixes: demographic profiling wired end to end (finding F2 of `REVIEW_FINDINGS_SEGMENT_2026-09-21.md`), `tabs_export` refused in combined mode (F14), and F8, F9, F17.

## What the reviewer must do

1. Read the handover and the F2 and F14 rows of the September review as claims, not evidence. Then read the diff against the branch's merge base.
2. Verdict by execution, both ways where the old code can be sourced. At the merge base, `profile_demographics()` has no caller and the Thornhill HTML has no Demographics section; on the branch it must. A combined config with `tabs_export = Y` runs silently at the base and must refuse on the branch.
3. Check the numbers, not only their presence. Run the Thornhill example to a scratch folder, read `thornhill_segment_assignments.xlsx` and `Thornhill_Segment_Data.xlsx`, compute the region by segment column percentages independently, and compare them with the Demographics table in the HTML and the `Demo_region` sheet in the Excel report. Do the same for one numeric demographic if the branch renders them. A table that is present with wrong numbers is a CRITICAL.
4. Check the honesty text: the base note, the chi-square caveat, and that percentages are within segment among respondents with an answer, which means checking how blanks in a demographic are handled and whether the note says so.
5. Mutation-test the new tests: revert each behavioural change one at a time (the call in `00_main.R`, the section placement in `03_page_builder.R`, the Excel sheets, the refusals) and run the suite. Any test that stays green with its change reverted is a finding.
6. Run the segment suite and quote the counts against the handover's baseline of 1258 / 0 / 0 / 0. Run the tabs suite too if any file outside `modules/segment` changed; otherwise say it was not needed and why.
7. Look for what the handover did not ask about: `html_show_demographics` in the template and the generated template workbook; combined mode; a demographic variable that is also a clustering or profile variable; a demographic with a single category; a numeric demographic with exactly ten distinct values, which `profile_demographics()` treats as categorical.
8. Then read `SESSION_D_NOTES_SEGMENT.md` and say where it and the findings disagree.

## Deliverable

`docs/v2_lift/REVIEW_FINDINGS_SEGMENT_D_<date>.md`, same structure and severity scale as `REVIEW_FINDINGS_SEGMENT_2026-09-21.md` (verdict paragraph first: MERGE, MERGE AFTER FIXES or BLOCK; gates table; findings table with file:line, how verified and status; claims one by one; what was not run). Update the segment row in `V2_LIFT_PROGRAM.md` section 4 and add a section 5 log line. Review only; fixes to the reviewer's own findings are welcome as separate commits identified as the reviewer's. Every finding carries file:line evidence read in the session; anything unverified is labelled next to the claim; no defect is reported that was not reproduced. No em dashes anywhere in the document.

## The prompt

> Run the independent pre-merge review of segment Session D on branch `feature/segment-demographics`. Load the `fable-method` skill. Read `docs/v2_lift/REVIEW_BRIEF_SEGMENT_D.md` first and follow it exactly; it names the handover, the findings under test, what to execute, and the deliverable. Treat the handover and the September review's rows as claims to test. Do not read `docs/v2_lift/SESSION_D_NOTES_SEGMENT.md` until your findings are written, then read it and record the disagreements. Verdict by execution: every claim you rate CRITICAL or HIGH should fail at the merge base and pass on the branch, or you say why you could not run it. Quote suite counts from your own runs. No fabrication: every finding carries file:line evidence read in this session, anything unverified is labelled inline, and you report no defect you have not reproduced. Review only; fix only your own findings, in separate commits identified as the reviewer's. Do not merge or push.
