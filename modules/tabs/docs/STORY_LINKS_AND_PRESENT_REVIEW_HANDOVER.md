# Independent review handover: narrative links and the Present stage

Written 23 September 2026 by the session that built both changes. You are the
independent reviewer. You did not write this code, and the author's reasoning
below is a map, not evidence. Verify everything by reading and running.

Use the `duncan-production-review` skill in independent re-review mode, and
`fable-method`. Report findings; do not fix anything unless Duncan asks.

## What is under review

Two changes, both merged to local `main` and NOT pushed.

| Change | Commit | Merged as | Brief |
|---|---|---|---|
| Links from the Word narrative to a question | `490fa133` | `78f48a7c` | `STORY_EXPLORE_AND_RETURN_BRIEF.md`, item 3 (stage 3) |
| Present on a scaled 16:9 stage | `fe629245` | `a1e517de` | No brief. Built from a conversation, described below |

Review with `git show 490fa133` and `git show fe629245`. Stages 1 and 2 of the
story brief (the return point and Explore) were reviewed and pushed earlier
and are out of scope, except where these changes call them.

There is a third branch, `feature/present-headline` (`92ea29b2`). Duncan saw it
and rejected it. It is not merged. Do not review it or suggest reviving it.

## Change 1: links from the Word narrative

The author selects words in the Word narrative, presses Ctrl+K and types
`turas:Q12`. The report shows those words as a link on every narrative surface
(Report tab card, cover, story card, Present). A click opens Q12 in the
crosstabs, with the reader's own banner and filters, under a return point.

How Word stores it was proved on a document Word 16 saved (Duncan's SACS 2026
narrative, a copy in OneDrive that you may read but never write): a
`w:hyperlink r:id="rId6" w:history="1"` around a run styled `Hyperlink`, and a
relationship `Target="turas:Q28" TargetMode="External"`, verbatim. No field
code.

Where it lives:

- Reader, `modules/tabs/lib/crosstabs/narrative_reader.R`:
  `.narrative_segments` (line 705) walks a `w:hyperlink` with the code in scope;
  `.narrative_turas_link` (789) resolves `r:id` to a `turas:` target (scheme
  case-blind, trimmed, URL-decoded); `.narrative_runs` (847) merges runs only
  when their `link` matches; `ctx$links_kept` counts links a screen keeps, and
  `.narrative_count_document` (980) subtracts them from the "hyperlink(s)
  dropped" console count; `.narrative_report` (1035) prints the kept codes.
- Island check, `modules/tabs/lib/data_layer_writer.R`:
  `.dl_check_narrative_links` (1420), called from `build_data_layer` (1269),
  drops a link whose code is not a question in the report and prints a
  WARNING naming the words and the code.
- A partial-match fix rode along (line 397): with no screens,
  `config_obj$narrative` read `narrative_file` and put that setting's text on
  the island. It is now `config_obj[["narrative"]]`.
- JS, `modules/tabs/lib/html_report_v2/assets/js/24b_narrative.js`: `linkCode`
  (88) repeats the island check; `runsHtml` (98) renders
  `<a class="nar-link" href="#tab=crosstabs&q=Q12" data-nar-link="Q12">`;
  `follow` (123) takes the return point (`story2.leavePresent` from Present,
  else `returnPoint.leave`) and calls `shell.goQuestion`; `wireLinks` (137) is
  one delegated document click listener, installed in `24_shell.js` (612).
- CSS `.nar-link` in `assets/styles.css`.
- Tests: `tests/narrative_links_tests.mjs` (17), plus changes to
  `test_narrative_reader.R`, `test_data_layer_writer.R`, `narrative_tests.mjs`,
  the fixture generator and `narrative_fixture.docx` and `narrative_island.json`.

Duncan's rule for this change: the report stays self-contained. A `turas:`
address must never reach the page as an href, and no external URL may appear.
The test `L1: nothing the report ships ... holds a turas: address` scans every
asset.

## Change 2: the Present stage

Duncan presents both in a room and on Teams. Present previously laid slides out
as a web page: at 1920x1080 it used 65% of the width and the top half of the
screen, with 11px tables. Now:

- Every slide sits on a 1280x720 logical stage, scaled with a CSS transform to
  the window (`30_story.js`: constants at line 35, `story2._presentFit` at
  1222, `fitPresent` at 1234). The markup is `.pr-sizer > .pr-stage >
  .pr-progress + .present` (`renderPresent`, 1333). The sizer holds the scaled
  size so the overlay scrolls.
- A slide taller than the stage shrinks to fit, never below 55% of full scale
  and never below 0.9, and scrolls past that. The 0.9 floor is a judgement
  call: on a 1280x720 Teams share a 15-row table scrolls a little at about
  10px text instead of fitting at about 8px.
- A resize listener is installed when Present opens and removed when it
  closes. A picture's `load` event refits.
- Controls (`.pr-chrome`, Explore) and the cursor fade after 2200ms without
  the mouse moving (`wakePresent`, 1258). Keyboard focus shows them
  (`:has(:focus-visible)`); a mouse click's focus does not.
- A Full screen button (never automatic) calls `requestFullscreen` on the
  document element (`toggleFullscreen`, 1276). While full screen, Esc only
  leaves full screen; the next Esc closes Present (`presentKeys`, 1294).
- Dividers are centred; a thin progress line runs along the top.
- Text keys `story.present.fullscreen` and `story.present.exit_fullscreen` in
  `text_manifest.json` and `modules/shared/lib/callouts/callouts.json`.
- Tests: `tests/present_stage_tests.mjs` (10 at `fe629245`).
- Manual: the "Presenting" paragraph under The Story Tab in `04_USER_MANUAL.md`.

## Decisions already made (do not re-litigate)

- Links are only `turas:` plus a question code, and only in the narrative
  screens. Links in headings and tables keep their words and lose the link.
  Field-code HYPERLINKs are not handled, because Ctrl+K did not produce one.
- A detour always restores the view; there are no live controls on a slide.
- For CCPB, Duncan decided arrow keys are enough (no clicker keys), there
  will be no speaker notes, the CCPB rounding fix is out, the insight stays in
  the callout box under the question title, full screen is never automatic,
  and Explore into Tracking is parked.

You may still report a defect that touches any of these, but frame it as a
defect, not a redesign.

## What the author verified, and what not

Run at the commits above:

- All 55 node suites in `modules/tabs/lib/html_report_v2/tests/*.mjs` exited 0,
  run one file at a time. That includes `mutate_text_check`,
  `production_bundle_tests` and `pptx_visual_qa`, which rendered through
  LibreOffice.
- R `testthat::test_dir("modules/tabs/tests/testthat")` with `TURAS_ROOT` set:
  83 files, 1840 tests, 0 failures, 1 skip
  (`test_config_templates.R:742`, tracking_island.R not sourced, unrelated).
- Browser pane, on a scratch report built with `build_report_v2_html`, never
  on a OneDrive project. For links: the Report tab link clicked for real, Back,
  and a Present link and Back to the slide. For the stage: slides measured at
  1920x1080 and 1280x720, before and after, including a 15-row table and a
  15-row chart; idle fade; progress line.
- Duncan regenerated SACS 2026 through `launch_turas()` and confirmed a Word
  link works.

Not verified, so look hard here:

1. Full screen and the Esc sequence. The browser pane refuses full screen
   ("Permissions check failed"). Whether a browser delivers the Esc keydown
   when it exits full screen is untested.
2. Text sharpness under `transform: scale`. Pane screenshots are downsampled.
3. A real Teams share.
4. The hardened and composed build path (`scripts/turas_harden_report.R`,
   `modules/shared/lib/turas_minify.R`). Only `production_bundle_tests` ran. Check that the
   `data-nar-link` listener, the stage and the idle fade survive hardening.
5. The cover surface in a browser (the scratch build had no cover). Node tests
   cover it.
6. `overlay.clientWidth` excludes a vertical scrollbar. When a slide scrolls,
   check for a horizontal scrollbar or a clipped right edge.

## Where the author suspects weakness

- The kept-link count when two separate hyperlinks to the same code sit side
  by side, when a link's words are only whitespace, and for links inside
  `w:ins`, `w:sdt` or before the first Heading 1.
- `follow()` from the Story tab records origin `{kind: "story", at: null}`, so
  Back returns to the tab, not the card.
- The idle fade hides Explore; keyboard navigation does not wake the controls.
- `:has()` is needed for the keyboard-focus reveal. Older browsers lose only
  that reveal.
- An Explore detour or a link click while full screen: the page stays full
  screen by design. Check Back and the return bar there.

## How to run things

- Check the branch and `git status --short` first. Work on a review branch if
  you write anything (a findings file is fine).
- Node: `node modules/tabs/lib/html_report_v2/tests/<file>.mjs`, one file at a
  time. `timeout` is not installed on macOS; a loop that uses it runs nothing
  and still looks clean.
- R: from the repo root, `TURAS_ROOT=$PWD Rscript -e
  'testthat::test_dir("modules/tabs/tests/testthat")'`.
- Browser checks: build a scratch report from the fixtures in
  `modules/tabs/tests/testthat/test_report_v2_bundler.R` (`build_data_layer`,
  `serialize_data_layer`, `build_report_v2_html`) into your scratchpad. Serve
  it with a TEMPORARY entry in `.claude/launch.json` (it is tracked; restore
  it with `git checkout -- .claude/launch.json`). The pane caches pages, so add
  `?v=N` to the URL after a rebuild.
- Never write into `OneDrive*/TurasProjects`, never run the pipeline on a real
  project config, never push, never merge.

## What to hand back

Write `modules/tabs/docs/STORY_LINKS_AND_PRESENT_REVIEW_FINDINGS.md` and
report:

- a verdict first (ship, ship after fixes, or do not ship);
- findings ranked by severity, each with `file:line`, the failure scenario, the
  evidence (a command and its output, or the lines read), and a proposed fix;
- what you ran, with pass and fail counts quoted from your own runs;
- what you could not verify, stated next to the claim it qualifies.

No em dashes in anything Duncan reads.
