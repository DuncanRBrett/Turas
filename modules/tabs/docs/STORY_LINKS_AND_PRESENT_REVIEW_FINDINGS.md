# Independent review findings: narrative links and the Present stage

Reviewed 23 September 2026, on branch `review/story-links-present` cut from
local `main` at `d2cc7e90`. Scope and rules as set in
`STORY_LINKS_AND_PRESENT_REVIEW_HANDOVER.md`. I did not write this code. Every
claim below comes from reading the diff (`git show 490fa133`, `git show
fe629245`) or from something I ran in this session. Nothing was fixed in the
review pass; the fixes Duncan then asked for are in the last section.

## Verdict

**Ship after fixes.** Both changes do what they claim on the happy path, in
the normal build and in the hardened build. Two presenter-facing defects
should be fixed before the CCPB presentation: an older return point hijacks
Back from Present (I1), and a slide opens scrolled when the one before it was
scrolled (I2). Each is a small, local change. The rest are minor.

## Gates run

| Gate | Command | Result |
|------|---------|--------|
| Node suites | each `modules/tabs/lib/html_report_v2/tests/*.mjs` run on its own with `node` | 57 files, all exit 0. 56 are suites; `_text.mjs` is a shared helper. 1078 passes counted from the files that print "N passed, M failed", 0 failed. The other 18 suites print only "N passed" or a named check. All exited 0, and the five I opened (charts, cover, mutate_text_check, pptx_visual_qa, xlsx) ended on a pass line |
| New suites | `narrative_links_tests.mjs`, `present_stage_tests.mjs` | 17 passed, 0 failed; 10 passed, 0 failed |
| Hardened bundle | `production_bundle_tests.mjs` | 25 passed, 0 failed, parity suite passes on the production bundle |
| R suite | `TURAS_ROOT=$PWD Rscript -e 'testthat::test_dir("modules/tabs/tests/testthat")'` | 83 files, 6367 expectations, 0 failed, 0 errors, 1 skipped (`test_config_templates.R:742`, tracking_island.R not sourced) |
| Hardening | `Rscript scripts/turas_harden_report.R` on a scratch report | "Verification: ALL CHECKS PASSED", 0 warnings |

The handover quotes 1840 R tests and 55 node suites. My R count is
expectations (`sum(nb)` from the testthat results), not `test_that` blocks,
so the two numbers measure different things. A later run counted 1841
`test_that` blocks, which is the handover's 1840 plus the one test added in
the fixes. I did not reconcile 55 with the 57 files I ran.

## How I tested in a browser

I built a scratch report into my scratchpad with `build_data_layer`,
`serialize_data_layer` and `build_report_v2_html`. It had three questions (Q2
has 15 rows, so it overflows the stage at 1280x720), the narrative read by
`read_narrative_docx` from the test fixture (links to Q1, Q2 and Q999), and
`html_report_v2_cover = TRUE`. I served it with a temporary
`.claude/launch.json` entry, which was restored afterwards. The
build printed the expected warning for Q999, and `grep 'turas:'` over the
built page found nothing.

## IMPORTANT

### I1. An older return point hijacks Back from Present, and Present closes

**Files:** `modules/tabs/lib/html_report_v2/assets/js/30_story.js:874`
(`story2.leavePresent`), `modules/tabs/lib/html_report_v2/assets/js/24_shell.js:502`
(`rp.leave`, which returns early at 503 when one is already open)

**Scenario, reproduced.** Duncan checks a link on the Report tab while
preparing and does not press Back or Stay here. The bar stays open across
tabs, by design. He opens Present, and on a slide he clicks a narrative link
(or Explore). `leavePresent` calls `rp.leave({kind: "present"})`, which keeps
the older Report-tab point. The bar reads "Back to the Report tab". Back then
lands on the Report tab with Present closed (`tab: "report"`, `slide: null`,
overlay hidden). In front of a client, the presenter has lost the deck.

The clean path works. With no older return point, Present, link, Back gave
"Back to the story, slide 4 of 8" and reopened Present on slide 4.

**Why it is a defect, not a redesign.** The manual added in `490fa133` says
Back returns "in Present, the same slide". The "first point wins" rule is a
settled decision, and it is right for wandering between tabs. Starting a
presentation is a new context, though, and the older point is stale by then.

**Fix.** In `startPresent`, when a return point is open and its origin is not
`present`, drop it (`TR.shell.returnPoint.stay()`) before rendering. A narrower
alternative is for `leavePresent` to replace any non-present origin. Add a node
test: open a Report origin, start Present, follow a link, and assert
`returnPoint.current().kind === "present"`.

### I2. The next slide opens scrolled when the previous one was scrolled

**File:** `modules/tabs/lib/html_report_v2/assets/js/30_story.js:1333`
(`renderPresent`). Nothing resets `#present-overlay`'s `scrollTop`.

**Scenario, reproduced at 1280x720 (a Teams window share).** Two 15-row
slides in a row. Each is fitted at the 0.9 floor and scrolls (`scrollHeight
799`, `clientHeight 720`). I scrolled the first to 200 and pressed ArrowRight.
The next slide opened at `scrollTop 79`, its maximum, with the counter and
the top of the title off screen. ArrowLeft goes through the same path. A
1280x720 share is the case the 0.9 floor was chosen for, so this is where it
will happen.

I did not check whether this also happened before `fe629245`. The overlay was
`overflow: auto` then too, so it may be older than this change.

**Fix.** Set `overlay.scrollTop = 0` in `renderPresent` when the slide index
has changed. Leave it alone on a re-render of the same slide (the
`fullscreenchange` handler re-renders), so that one keeps its place.

## MINOR

### M1. Space on a focused Full screen or ✕ button moves the slide instead

**File:** `modules/tabs/lib/html_report_v2/assets/js/30_story.js:1307`.
`presentKeys` exempts only `[data-explore]` from Space.

**Reproduced with real key presses.** I focused Full screen and pressed Space.
The slide went from 1 to 2, `requestFullscreen` was never called (0 calls on
a counting stub), and focus fell to `BODY` because the re-render removed the
button. Space on `#pr-close` moved from slide 2 to 3, and Present stayed open.
Enter on Full screen did call `requestFullscreen` (1 call). The CSS reveals
the controls on keyboard focus (`:has(:focus-visible)`), so keyboard use is
intended.

**Fix.** Return early from the Space branch when `e.target.closest("button")`
is inside the overlay, as the Explore guard already does.

### M2. The kept-link console count is wrong for whitespace-only or adjacent links

**File:** `modules/tabs/lib/crosstabs/narrative_reader.R:518` (adds the
walked-link count), `:989` (subtracts it from the dropped count), `:1050` (the
INFO line).

`n_links` counts every `turas:` hyperlink walked in a paragraph, not the links
that survive `.narrative_runs`. Probes run through `read_narrative_docx` on
generated documents gave:

- A link whose words are only a space, at the end of a paragraph: the run is
  trimmed away, but the console prints `1 Turas link kept, to .` with an empty
  code list, and the dropped-hyperlink count is one too low.
- A link whose words are only a space, mid-paragraph: kept as a separate run,
  so the page shows a clickable space.
- Two separate links to the same code side by side: they merge into one run
  (correct), and the console says 2 kept.
- A link in a paragraph before the first Heading 1: the paragraph is counted as
  preamble and the link as a dropped hyperlink "The words are kept", though
  preamble words are not kept. That is a wording issue only.

Links inside `w:ins` and inline `w:sdt` were kept and counted correctly. A link
in a table cell and a Heading 2 lost its link and was counted as dropped, as
the manual says. A link inside a body-level content control is not read and
not counted as a hyperlink, and the control itself is counted, which is
consistent.

**Fix.** Count kept links from the final screens (distinct link runs, the
same walk the INFO line already does for the codes), not from `n_links`.
Drop a run whose text is only whitespace from carrying a link, or skip it in
the count. Console only, so it does not block.

## OBSERVATIONS

### O1. Handover item 4, the hardened build: works

I hardened the scratch report with `scripts/turas_harden_report.R` and loaded
it. The Report tab link opened Q2 with "Back to the Report tab". Present
scaled to 0.9 at 1280x720. The Full screen button rendered, the progress line
drew, and `pr-idle` was set after 2600 ms and cleared on `mousemove`. A Present
link round-tripped to "slide 11 of 12". The console had no errors.

### O2. Handover item 5, the cover: works, with one stub

`coverAvailable()` needs `TR.userState`, which only a saved copy has. I set
`TR.userState = {}` in the page. The cover then rendered the Ratings link to
Q1, the click gave "Back to the cover", and Back returned to the cover. A real
saved copy was not built.

### O3. Handover item 6, the scrollbar: not a problem in Chromium

I forced a 17px classic scrollbar on the overlay with injected CSS, at
960x600, and stepped through all 11 slide transitions, including divider to
the 15-row slide. Every one had `scrollWidth == clientWidth`. The stage fitted
to 943px. The unscaled 1280px stage overflows while `fitPresent` measures, so
the scrollbar already exists when `clientWidth` is read. For windows at least
1280 wide, a scrolling slide sits at the 0.9 floor (1152px), well inside the
width. Firefox and a real Windows machine were not tried.

### O4. Story card Back returns to the card's scroll position

The author feared that `{kind: "story", at: null}` returns to the tab, not the
card. `rp.back` restores `scrollY` for non-Present origins. I measured
`scrollY` 4061 before the click and 4061 after Back.

### O5. The stage fit at 1920x1080

The executive summary slide rendered at `scale(1.5)`. The 15-row Q2 slide fit
without scrolling at `scale(1.21622)`, stage height 888. A synthetic `resize`
refit changed the scale from 0.7367 to 0.75 once the scrollbar CSS was
removed, so the resize listener works.

### O6. Full screen inside the report hub

`modules/report_hub/07_page_assembler.R:104` gives the report iframe
`allow="clipboard-write *"` and no fullscreen. In Chromium, a same-origin
iframe with that attribute reported `document.fullscreenEnabled === true`, so
the button is probably not dead there. I could not prove a full screen actually
starts, because the pane refuses full screen at the top level too. If Duncan
wants belt and braces, `canFullscreen()` could also require
`document.fullscreenEnabled`.

### O7. `exitFullscreen()` promises are not caught

`toggleFullscreen` and `presentKeys` call `document.exitFullscreen()` without a
`.catch`. It only rejects when nothing is full screen, which the guards rule
out, so this is noted, not a finding.

## What I could not verify

- **Handover item 1, the Esc sequence in real full screen.** The pane refuses
  full screen. The specific risk: if a browser leaves full screen on Esc and
  also delivers that keydown after `document.fullscreenElement` is already
  null, `presentKeys` falls through to `closePresent()`, and one Esc closes
  Present. I recall that Chrome does not deliver it, but that is unverified.
  A 30-second check in Chrome and Edge: open Present, press Full screen, press
  Esc once, and confirm Present is still showing.
- **Handover item 2, text sharpness under `transform: scale`.** Not checked.
  The pane was hidden for most of the session, so screenshots were unavailable
  and I used DOM measurements. There is no `will-change: transform` on the
  stage, which is the usual cause of blurry scaled text, but that is reasoning,
  not a look.
- **Handover item 3, a real Teams share.** Not possible here.
- **Refit when a picture loads.** The fixture pictures are inline and load at
  once, so the capture `load` listener was never exercised.
- **Cmd+K in Word for Mac.** The manual says Cmd+K works the same. The storage
  shape was proved on one Word 16 document. Which platform saved it is not
  recorded, and I did not test a Mac-saved file.
- **Firefox and Safari.** Only Chromium (the pane) was used.

## Not produced

The review skill's growth-path document was skipped on purpose. The scope is
two features inside an existing module, and the handover asked for this
findings file only.

## Fixes applied (23 September 2026, at Duncan's request)

All four findings were fixed on branch `fix/story-present-review`. Each new
test was run against the unfixed file first and failed there.

- **I1.** `startPresent` closes any open return point when Present opens
  (`dropStaleReturnPoint` in `30_story.js`). Moving between slides while
  presenting leaves a point alone, and Back clears its own point before it
  reopens Present. This changes one stage 2 test,
  `story_explore_tests.mjs` "(2) Explore while a return point is already open
  keeps the first", which asserted the old behaviour. It is now "(2) Starting
  Present closes an older return point". The brief records the refinement
  under "One return point at a time". A detour started while a point is open
  still keeps the first (`narrative_links_tests` L2). It closes a point of
  any kind, including one from an earlier slide: a reader mid-detour who goes
  to the Story tab and presses Present again has restarted the deck, and the
  old bar goes. Test: P6.
- **I2.** `renderPresent` sets the overlay's `scrollTop` to 0 when the slide
  index changes and keeps it on a redraw of the same slide (full screen
  toggled). Test: P7. In the browser at 1280x720, a slide scrolled to 79
  followed by ArrowRight, then ArrowLeft, opened at 0 both times.
- **M1.** `presentKeys` ignores Space when the focus is on a button in the
  overlay, so the button presses. Arrows still move the slide. Test: P8. In
  the browser I could only dispatch key events, because the pane was hidden.
  Space on Full screen and on exit left the slide alone, while an arrow and
  Space with nothing focused moved it.
- **M2.** A `turas:` link whose words are only spaces is no longer a link. Its
  spaces stay plain, and it counts as a dropped hyperlink rather than a kept
  one. A link with real words that also spans a space run still links. The
  count of kept links still counts Word hyperlinks, so two adjacent links to
  one question count as 2, though they show as one link. That count is true
  to the document and left as is. The preamble wording was not changed. Test:
  "a Turas link on nothing but spaces is no link" in `test_narrative_reader.R`.

After the fixes: 57 node files, all exit 0, 1081 passes counted, 0 failed;
R tabs 83 files, 1841 tests (6373 expectations), 0 failed, 1 skipped.
