# Brand destinations: naming the tables, and giving Mental Availability an Advanced drawer

**Date:** 7 September 2026. Worktree `/Users/duncan/Dev/Turas-mal`, branch
`fix/brand-destination-labelling`, cut from main at `36f97062`.
**Scope:** two reader-facing problems Duncan found on his own regenerated
four-category report. No numeric change, no anchor change.

Brief: the task message, against
`modules/brand/docs/SIMPLIFICATION_IMPACT_MAP.md`,
`docs/v2_lift/NOTES_BRAND_SIMPLIFICATION_STAGE2.md`,
`docs/v2_lift/NOTES_BRAND_SIMPLIFICATION_STAGE5.md` and
`docs/v2_lift/REVIEW_FINDINGS_BRAND_SIMPLIFICATION.md`.

## The two problems

1. **Tables are unlabelled.** Stage 5 collected every explanatory block into
   one collapsed "How this works" drawer per view. That was right for
   methodology and wrong for orientation: a reader now meets a stack of
   tables with nothing on their face saying what each one is.
2. **Mental Availability has no Advanced drawer and should.** The impact map's
   destination summary puts the full Mental Advantage matrix, the buyer-gap
   diagnostic and the MA methodology in Advanced; today all three are in the
   main view, which is why the page reads as a list of everything.

## Baseline, executed before the first edit

- Brand suite from the repo root:
  `TURAS_ROOT=/Users/duncan/Dev/Turas-mal Rscript -e 'testthat::test_dir("modules/brand/tests/testthat")'`
  gave **FAIL 0, WARN 1, SKIP 2, PASS 3659**, 107.8 s. Matches the brief.
- The three QA reports, built with
  `modules/brand/tests/qa/generate_qa_reports.R --out <scratchpad>/before`:
  `committed.html` 4,056,423 bytes, `extras.html` 4,172,037 bytes,
  `ungated.html` 4,171,952 bytes. All three PASS. Nothing was written into
  the repository or into any project folder.

## How the labelling is measured

`modules/brand/tests/qa/count_headings.py`, added by this work. It drives the
report in headless Chrome, activates every category tab and every destination,
opens the Advanced drawer and each of its items in turn (the drawer is a
one-at-a-time accordion, so opening them all at once leaves only the last one
open), and reads the headings and tables **out of the rendered DOM**. A
heading hidden by a collapsed ancestor is not a label a reader can see, and
that distinction has already caused two bugs in this programme.

It walks each pane in document order and pairs every visible data table with
the heading that most recently preceded it. A heading already spent on an
earlier table does not name the next one, so two tables under one heading
counts the second as unnamed.

Two heading definitions are reported, because they answer different
questions. The strict count is `h1` to `h6`, which is the method Duncan used.
The wider count adds the panel-native title classes, which render as headings
on screen but are `div` elements in the markup.

### Before, on the IPK fixture

`t/h` is visible tables over visible headings, the wider definition.

| Report | Destination | main t/h | advanced t/h | pane t/h | pane t/h1-6 | unnamed |
|---|---|---|---|---|---|---|
| committed | overview | 0/1 | - | 0/1 | 0/1 | 0 |
| committed | mental | 5/8 | - | 5/8 | 5/8 | 1 |
| committed | buying | 4/5 | 5/9 | 9/14 | **9/0** | 1 |
| committed | meaning | 2/1 | - | 2/1 | 2/1 | 1 |
| committed | audience | 7/8 | - | 7/8 | 7/8 | 0 |
| extras | mental | 5/8 | - | 5/8 | 5/8 | 1 |
| extras | buying | 4/4 | 5/9 | 9/13 | **9/0** | 1 |
| extras | meaning | 2/1 | 0/4 | 2/5 | 2/4 | 1 |
| extras | audience | 8/10 | 3/7 | 11/17 | 11/12 | 0 |

The fixture reproduces Duncan's complaint. Brand and Buying carries nine
tables and **not one `h1` to `h6` heading**; its three visible labels are
`div.cb-section-title` and `div.cb-ctx-subtitle`. Brand Meaning is 2 tables
and 1 heading, which is exactly the count he reported. Audience is the one
that reads properly, as he said.

Two differences from his four-category report, recorded rather than
reconciled: he counted ten tables on Brand and Buying and one heading,
"Summary". On the fixture the funnel panel's Summary `h3` carries the
`hidden` attribute (impact map section 4, the dead sub-tab), so the harness
sees zero. His report is a different config and a different category.

The four unlabelled tables the harness names:

| Destination | Table | Today |
|---|---|---|
| mental | Brand Attributes linkage | falls under the metrics chart heading "MMS vs Share of Mind" |
| mental | Category Entry Points linkage | the same, and it is the one Duncan named |
| buying | the funnel table | no heading above it at all |
| meaning | the Brand Attitude table | no heading above it at all |

## Decisions taken, with reasons

*(filled in as the work lands)*
