# Story: explore the data and come back

Build brief, written 23 September 2026 after a conversation with Duncan.
Design decisions are made (see "Decisions made" at the end). The build
session implements, it does not redesign.

## The problem

The tabs v2 story is a deck that lives inside the data. Today it does not use
that. A presenter who is asked "what about the under-25s?" has to leave
Present, find the question, change the banner, and then find their place in
the story again by hand. Checked against the code on 23 September 2026:

1. Present has no way out to the data. Escape closes it, and it always
   restarts at slide 1 (`startPresent` sets `presentAt = 0`, `30_story.js`
   near line 1123).
2. The Story tab card's "open" button (`30_story.js` near line 783) jumps to
   the pinned question, but it overwrites the reader's own filters with the
   pin's, and there is no way back.
3. A question pin is already live, not a picture: `modelFor` (`30_story.js`
   near line 380) redraws it from the data with the pin's banner and filters.
   Present shows it at the pinned settings only, with no way to vary them.
4. The narrative screens drop every Word hyperlink and keep its words
   (`narrative_reader.R`: `w:hyperlink` is walked for its runs near line 709
   and counted as skipped near line 940).

The goal is a story that beats a PowerPoint hand-over because the evidence is
one click away and the presenter never loses their place. It must stay a
generic tool: nothing per project, no new setting, no new config sheet.

## The one mechanism: a return point

Everything in this brief rides on one thing, built once: a return point. It
records where the reader was and how the report looked, lets them go
anywhere, and brings them back.

- A return point holds the origin (Present at slide N, the Story tab at item
  N, the Report tab, or the cover) and a deep copy of `TR.d2.state`
  (`20_data.js` line 13), taken as the reader leaves.
- While a return point is open, a slim bar sits above the tab content:
  "Back to the story, slide 7 of 18" (or "Back to the Report tab", "Back to
  the cover"). It stays while the reader moves between tabs, questions,
  banners and filters, because wandering is the point.
- "Back" restores the saved state whole, so the report looks exactly as it
  did before the detour (Duncan, 23 Sep: "definitely go back to how it looked
  before"), and reopens the origin at the same place. A small "Stay here" control drops the return point and keeps the
  current view.
- One return point at a time. A detour started while one is open keeps the
  first return point, so "Back" always goes to where the reader first left.
- It lives in memory for the page's life. A reload drops it. It is never
  written to localStorage and never travels in a saved copy.

Prior art to copy, not reinvent: the Qualitative tab's jump and breadcrumb
(`27q_qualitative.js`: `qual.jumpTo` near line 1765, `qual.back` near line
1782, `breadcrumbHtml` near line 1865). The routing entry points are
`shell.goQuestion` and `shell.route` (`24_shell.js` near lines 430 and 376).

## Scope: the fixed list

1. Explore from a question slide. In Present, a question slide gets an
   "Explore" button. It opens that question in the crosstabs with the pin's
   banner and filters, under a return point to that slide.
2. Live in place. DROPPED by Duncan on 23 September 2026 (decision 3 below).
   It was built as a strip on each Present question slide (banner, chart or
   table, 95% intervals, "Reset to pinned view"), seen on SACS, and taken out.
3. Links from the narrative. In Word, the author selects words, presses
   Ctrl+K and types `turas:Q12`. The reader keeps the link on those runs;
   every narrative surface (Report tab card, cover, story card, Present)
   shows the words as a link in the brand colour; a click opens Q12 under a
   return point to where the reader was. The exported deck shows the words as
   plain text.
4. A link to a slide. `#tab=story&slide=7` opens Present at slide 7. While
   Present is open the address carries the current slide, so copying the
   address gives a link to it. A slide number past the end is clamped to the
   last slide.
5. Resume where you stopped. Present reopens at the last slide shown in this
   page's life, and each Story tab card gets "Present from here".
6. The Story tab card's "open" button uses the return point, so it no longer
   overwrites the reader's filters without a way back.

Links in more detail (item 3), in plain terms:

- Only `turas:` followed by a question code is a Turas link. An ordinary web
  link keeps its words and loses the link, exactly as today, and is still
  counted in the console.
- A `turas:` link whose code is not a question in the report prints a console
  line naming the link and the code, and its words render as plain text. The
  check is made where the island is assembled and the report's question list
  is known; the JS repeats it, so a hand-edited island cannot produce a dead
  link.
- A run carries `link = "Q12"` only when it has one, so every existing island
  and test stays unchanged. Adjacent runs merge only when their links match.

## Not in this build, deliberately

- Link variants: a chosen banner (`?banner=`), the dashboard, other tabs.
- Links from anywhere but the narrative screens (question comments, study
  slides, pin notes).
- Anything that pulls a figure into the narrative text (the narrative brief's
  rule stands).
- Explore from exhibits, heatmaps, composites or study slides. Question pins
  only.
- Any control on a Present slide beyond Explore (decision 3), and so any
  "save this view as the pin".
- Browser Back as a return. The bar is the return. Browser Back keeps its
  current behaviour.
- The whole story re-shown for one group (idea 7 in the conversation). It
  needs its own design because small groups trip disclosure on every slide.

## Rules that apply

- Disclosure travels. The explore detour lands in the crosstabs themselves,
  and the slide draws through the same model path (`TR.model.forQuestion`),
  so every disclosure gate applies. Nothing is re-derived in the story.
- UI strings go through `TR.txt` and `assets/text_manifest.json`, with the
  shared registry `modules/shared/lib/callouts/callouts.json` kept in step (the
  `story.narrative_gone` precedent). `tests/mutate_text_check.mjs` guards it.
- No em dashes in any string that reaches Duncan or a client.
- No new dependency. Edit surgically. Check the branch and `git status
  --short` before the first edit, and work on a feature branch.
- The existing PPTX export, image deck and every existing pin kind behave
  exactly as today, apart from item 3's plain-text link words. Prove
  non-narrative slides byte-identical, as the narrative build did.

## Stages, each ending in a check that can fail

Stage 1, the return point. Items 4, 5 and 6 plus the mechanism. JS only.
Check: new node tests that (a) every field of `TR.d2.state` survives a leave
and return unchanged, including filters, hidden rows and columns and the
custom banner; (b) Back from the crosstabs reopens Present at the same slide,
and from each other origin reopens that origin; (c) Stay here drops the bar
and keeps the view; (d) the slide link opens, clamps and updates while
presenting; (e) the story card's open no longer loses the reader's filters.
All node suites pass run one file at a time, and `mutate_text_check.mjs`.

Stage 2, explore. Item 1 only (item 2 was dropped, decision 3). JS only.
Check: node tests that Explore opens the pin's question, banner and filters
under a return point, and that Back reopens the slide with the reader's view
restored. All node suites, one file at a time.

Stage 3, links from Word. Item 3. R and JS. Before any code, prove the one
real unknown on a document saved by Word itself, which Duncan makes (a
paragraph with one `turas:Q12` link made with Ctrl+K): that Word keeps the
address, and exactly how it stores it (the relationship target and any
encoding). If Word refuses or mangles the address, stop and bring it back to
Duncan with the evidence; do not invent a different syntax. Then: the reader
keeps the link, the island check, the JS link and its detour, the plain deck
text. Check: R `test_dir("modules/tabs/tests/testthat")` with `TURAS_ROOT`
set, asserting the exact runs read from the Word-saved document and the
console line for a missing code; node tests for the rendered link and the
detour from each surface; `pptx_visual_qa.mjs`. Then Duncan regenerates a
project through `launch_turas()` and tries it. Nothing is done until that
eyeball.

## Decisions made

Duncan, 23 September 2026:

1. After a detour the report goes back to how it looked before. A presenter's
   detour never leaves a client's view changed; "Stay here" is the only way
   to keep what the reader found.
2. The wording is "Explore" on the slide and "Back to the story" on the bar
   (with "Back to the Report tab" and "Back to the cover" for those origins).
   They are text keys, so they can be changed later without code.
3. No live controls on a Present slide. After seeing the strip on a SACS
   question slide, Duncan dropped item 2: the row of banners and toggles made
   the slide busy and confusing, and the pin is already his curated view. The
   slide carries the Explore button only, and anyone who wants another banner,
   a filter or the intervals gets the full crosstabs there, with Back to
   return. Do not rebuild the strip.

## Model and effort

Implement on Opus 5 at high effort with the fable-method skill, one session
per stage, suites run per stage. Independent review in a fresh session after
stage 3, as for the narrative screens.
