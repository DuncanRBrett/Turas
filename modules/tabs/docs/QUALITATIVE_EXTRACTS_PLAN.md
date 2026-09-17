# Qualitative extracts: quoting a fragment, counting the whole comment

Spec written 17 Sep 2026. Design pass by Fable, facts verified in the repo and in the
live SACS appendix by the Opus session that wrote this file. Decisions first; the build
notes follow. Nothing in this document has been built yet.

---

## 1. The problem

A coded-comment sheet carries one row per respondent: one verbatim cell, one sentiment,
and a 1/2/3 code in each theme column. The reader turns that row into one record with a
single `text` and a bag of theme codes. When a reader opens a theme, the drawer lists
every record coded to that theme and shows that record's single text.

An analyst who shortens the verbatim for length or identity cover is therefore editing
the evidence for counting. If the extract speaks to Unfairness and the comment was also
coded Compensation, the extract appears under Compensation as if it were evidence for it.
The codes are right, because they were coded on the whole comment. The quote under each
heading is what breaks.

Measured on `2026 SACS Comment Appendix.xlsx`, the workbook the SACS 2026 config points
at, counting only rows that ship text (a `hide` mark withholds the rest):

| Sheet | Rows shipping text | Of those, multi-theme | Multi-theme and ellipsised |
|---|---|---|---|
| Engagement | 65 | 56 | 48 |
| Values | 47 | 44 | 28 |
| Misalignment | 9 | 7 | 7 |
| Culture | 35 | 26 | 21 |
| Satisfaction | 55 | 48 | 38 |
| Engagement Other | 26 | 24 | 22 |

205 rows across the six sheets are quoted under more than one theme from a single
fragment. This is the normal case in a climate study, not an edge case.

---

## 2. Decision: separate quoting from counting

Coding is a judgement about the whole comment, which is what makes prevalence correct.
Quoting is a judgement about a fragment. Today both live in the verbatim cell.

The fix gives quoting its own layer:

1. The verbatim column holds the comment as given, and is never edited. The workbook
   stays the archive, which also retires the "full" / "edited" / "full with edits"
   copies a hand-edited appendix forces an analyst to keep.
2. Coding stays exactly as it is. One row per respondent, one code per theme, bases and
   the theme x banner crosstab untouched.
3. Quotable text moves into an optional extracts layer: zero or more extracts per
   comment, each tagged with the theme or themes it evidences.

A project that needs no extracts adds nothing and behaves exactly as today.

---

## 3. Decision: the workbook shape

A sibling sheet per coded sheet, named `<CommentSheet> Extracts` ("Engagement Extracts").
Three columns:

| ID | Theme | Extract |
|---|---|---|
| 213 | Recognition; Workload & Burnout | the fragment that evidences those two themes |
| 193 | | a general shortening, offered anywhere |

- One row per extract. Several rows may share an ID.
- `Theme` is a semicolon-separated list of theme labels exactly as the coded sheet's
  headers spell them. Semicolon, not comma, because labels contain `&` and may contain
  commas.
- `Theme` has three states, which is the resolution of the blank-cell question:
  blank means the extract stands in for the comment in the general comment list only, and
  never reaches a theme page; the single word `all` means it stands in for the comment
  everywhere, including every theme the row is coded on; a named list means those themes.
  Blank is the safe default because a forgotten theme list then fails visibly, as a quote
  missing from a theme page, rather than silently reproducing the bug this spec fixes.
  `all` keeps the pure length trim to one word rather than five theme labels, and it is an
  explicit claim rather than an omission.
- At most one general extract per comment. A comment with both a blank row and an `all`
  row is contradictory and refuses.
- An optional fourth column, `Lead`. Any non-blank mark names the one fragment to lead
  with for that comment wherever the context is not a theme page: the priority block,
  pins and the story tab. Two marked rows for one comment REFUSE. A mark on a comment with
  a single extract is allowed and has no effect.
- Several rows for the same ID and theme are allowed and join with " ... ", which mirrors
  the ellipsis practice the SACS appendix already uses.

Why not a marker or text inside the theme cell, and why not an extract column per theme:

- The theme cells are consumed by the analyst's own summary block. Verified in the live
  workbook: rows 2 to 5 of each sheet are `=COUNTIF(D$7:D$178,$B3)` and
  `=SUM(D3:D5)` across every theme column. Anything but a bare 1/2/3 in those cells
  breaks the analyst's counts as well as the reader's purity check
  (`QUAL_THEME_PURITY_MIN`, `qual_workbook_reader.R:84`).
- The SACS sheets carry 14 to 17 theme columns, so an extract column per theme is 30-odd
  mostly empty columns.
- A second prose column right of the verbatim would trip the verbatim ambiguity refusal
  (`qual_detect_verbatim_col`, `qual_workbook_reader.R:190`). SACS labels its verbatim
  with the question text, so the verbatim is found by being the longest prose column, and
  a second prose column makes that ambiguous. A named sheet cannot be confused with
  anything.

Projects with no themes, and projects with no extracts. A sheet with no theme columns is
already read as a `raw` question rather than a themed one
(`qual_workbook_reader.R:488`), and the qualitative tab handles it today. On such a
project an extracts sheet still works as pure shortening: every row carries a blank
`Theme`, because there are no theme pages to reach, and the general comment list is the
whole tab. A project that needs none of this, CCPB included, adds no extracts sheet, and
the island it builds is byte-identical to one built before this feature existed.

Sheet-name limit: Excel allows 31 characters, and the longest SACS name derives to
"Engagement Other Extracts" at 25. A derived name over 31 characters refuses and says
what to shorten.

---

## 4. Decision: the display contract, through one accessor

Every display site in `27q_qualitative.js` reads `r.text` today. The build introduces
one accessor and nothing else reads the field:

```js
qual.textFor(rec, themeId)   // themeId null/undefined = the unscoped context
```

Precedence under a theme T:

1. the extracts tagged T, joined with " ... " in sheet order;
2. else the `all` extract, if the comment has one;
3. else nothing, when the record has any extract at all. A blank-Theme extract does NOT
   qualify here; that is what blank means;
4. else the verbatim.

Unscoped contexts (the all-comments browse, the priority block, hubs, pins, the story
tab): the `Lead`-marked extract, else the comment's general extract, blank or `all`, else
the first themed extract carrying its theme label as a chip, else the verbatim.

A comment with at least one extract never ships its full verbatim. Trimming for identity
is then enforced by the file rather than by remembering to overwrite a cell.

Rule 3 is the plain reading of the bug: under a theme the extract does not address, the
comment still counts and no text shows, which is the behaviour a `hide` mark already
produces. The drawer's existing withheld-first counting handles the list arithmetic
(`27q_qualitative.js:875` and `:909`).

The JS gate suite asserts statically that no raw `.text` read survives in the
qualitative module outside the accessor. That check is what makes a six-site sweep safe
rather than hopeful.

---

## 5. Decision: the island shape

- `record.text` keeps its current meaning, now the unscoped text: the general extract, or
  the verbatim when the record has no extracts, or null when withheld.
- `record.extracts = { "<themeId>": "text" }` is emitted only when the record has themed
  extracts, so every island built from a workbook without an extracts sheet stays
  byte-identical to today's.
- `suppressed` keeps its meaning, withheld from the readable list. An extract-only record
  is not suppressed.
- Every extract string passes `qual_verbatim_shows` and `qual_apply_text_mode` exactly as
  `text` does (`qual_island_builder.R:93` and `:62`). A withheld record emits no
  `extracts` key at all, `hidden` mode emits none, and `redacted` scrubs each extract and
  adds to the redaction count.

That last invariant is what keeps the release audit meaningful. Verified: the audit reads
the declared `textMode` and each record's `rid` and `cut`, not the text strings
(`modules/shared/lib/turas_release_audit.R:107` and `:122`). So extracts add no new audit
surface, provided they obey the dial in the builder. An R test pins that, and
`test_client_safe_qual_chain.R` is the place for it.

---

## 6. Decision: the refusal set

TRS refusals, console box, naming the sheet, row, ID and theme:

| Case | Behaviour |
|---|---|
| Theme label not found on the coded sheet | REFUSE, listing the valid labels |
| ID not present on the coded sheet | REFUSE, naming the ID |
| Extract tagged to a theme the row is not coded on | REFUSE. This is the inverse of the bug and must not pass as a warning |
| Extract on a `hide`-marked row | REFUSE, same reasoning as the hide-like typo rule |
| Blank Extract cell | Skip, with a console note |
| Derived sheet name over 31 characters | REFUSE, say what to shorten |
| Extracts sheet with no matching coded sheet | REFUSE, naming both |
| Several rows for the same ID and theme | Allowed, joined with " ... " |
| Two `Lead` marks on one comment | REFUSE, naming the ID |
| A blank row and an `all` row for one comment | REFUSE, naming the ID |

---

## 7. Decision: the reader must know a quote is a fragment

A fragment shown under a theme says it is an extract from a longer comment. This is part
of the fix, not decoration: it answers the opposite question, a client reading three lines
and asking how they earned four theme codes.

Reuse an existing chip class so `styles.css` is not touched. Another session is working
in the pricing module and has that file modified.

---

## 8. Verified anchors for the builder

Read before changing anything; these were checked on 17 Sep 2026.

| What | Where |
|---|---|
| Theme cell purity, verbatim ambiguity guard | `modules/tabs/lib/qual_workbook_reader.R:84`, `:190` |
| Sheets are enumerated with `openxlsx::getSheetNames` and EVERY sheet is classified | `modules/tabs/lib/qual_workbook_io.R:133`, `qual_classify_all_sheets` at `:38` |
| Duplicate ResponseIDs already refuse | `modules/tabs/lib/qual_workbook_io.R:182` |
| Confidentiality dial and scope applied per record | `modules/tabs/lib/qual_island_builder.R:62`, `:93`, `:104` |
| Display sites in the qualitative JS | `27q_qualitative.js`: `prevalence:52`, `recordsForTheme:77`, `textPublished:416`, `priorityQuotes:491`, `priorityQuotesFor:508`, `renderHighlighted:840`, `shown:875`, `scopeChip:887`, `poolBeforeSentiment:909`, `visibleRecords:920`, `championQuotes:951`, `exportRows:1008`, `collectionExportRows:1168`, hub payload `:1353` to `:1403` |
| Highlight ranges are character offsets into the exact text | `27q_qualitative.js:769` |
| Cross-file quote consumers | `30_story.js:417` (calls `textPublished`), `29_export.js:1301` (consumes a quotes payload built in 27q) |
| Release audit judges the declared mode, not the strings | `modules/shared/lib/turas_release_audit.R:107`, `:122` |
| The appendix builder appends rows only and preserves existing ones | `scripts/build_comment_appendix.py`, "SAFE TO RE-RUN" |

Verified NOT affected, so the build does not need to touch them: prevalence and the
theme x banner crosstab (they read codes, never text), and the AI insight payload. There
is no qual verbatim path in `ai_insights_step.R` or `qual_quant_layer.R`, so no insight is
being written from a mismatched quote today.

---

## 9. Blindspots, with status

1. **Curated items forget their context.** The shortlist and the hubs key by record. A
   quote shortlisted under Compensation, then viewed in the collection or exported to
   PPTX, would show the general or first themed extract, not the one the analyst picked.
   Stage 2 stores the theme on the item. Stage 1 documents it and must not crash.
2. **Sheet enumeration.** Verified: every sheet with an ID anchor is classified as a
   question. An extracts sheet would be read as a question sheet, or skipped, before any
   new parser saw it. Routing by the name suffix must run first, in
   `qual_classify_all_sheets`.
3. **`textPublished`.** It walks `recs[j].text` to decide whether a frozen story pin may
   still render. A pinned extract fails that test unless it walks extracts too.
4. **saveCopy back-compat.** Highlight and shortlist keys embedded in saved copies must
   still load. Extend the key with an optional theme suffix; never change the base format.
   Highlights on extract text need their own key, or marks land on the wrong characters.
5. **Release audit.** Verified as declared-mode only. The risk is not the audit, it is an
   extract that bypasses the dial in the builder. Pinned by test.
6. **Other JS files.** Only `30_story.js` and `29_export.js` touch qual quotes outside
   27q. Re-grep at build time; the sweep is small but must be complete.

---

## 10. Staging

**The fix is four build stages plus a migration script.** Each stage ends with its suite
green; no stage is started before the previous one is green.

1. **Reader and workbook I/O.** Route `<Sheet> Extracts` by name BEFORE sheet
   classification, parse the three columns, and enforce the whole refusal set in section 6
   against the coded sheet. Attach extracts to the reader records. Proof: the qual reader
   and workbook-io testthat files, plus a fixture workbook carrying every refusal case.
   This is the biggest stage and the one that must be exactly right, because a silent
   parse is the failure this feature exists to remove.
2. **Island builder.** Emit `record.extracts` only when present, every string through
   `qual_verbatim_shows` and `qual_apply_text_mode`, redaction counts included, and an
   island byte-identical to today's when a workbook has no extracts sheet. Proof: the
   island-builder tests plus `test_client_safe_qual_chain.R` for the dials.
3. **The accessor and the sweep.** Add `qual.textFor(rec, themeId)`, convert every `.text`
   read listed in section 8, including `textPublished`, both exports and the hub payload,
   and add the static gate check that no raw read survives. Proof: the v2 JS gate suite.
   Second-biggest stage, and the static check is what makes it verifiable rather than
   hopeful.
4. **What the reader sees.** The extract caption, the "counted here, quoted elsewhere"
   notation so a theme page's comment count and quote count reconcile on their face, and
   the scope chip wording. Reuse existing chip classes; do not touch `styles.css`. Then
   the docs: `QUALITATIVE_TAB_BUILD_NOTES.md`, the tabs module README and
   `README_comment_appendix.md`.
5. **The SACS migration script** (separate, openpyxl, writes a new candidate workbook and
   never overwrites), with its own test. Independent of stages 1 to 4 and can be written
   while Duncan is pruning nothing, but it is useless until stage 1 can read what it
   writes.

After stage 4: an independent Opus review of the whole feature, then Duncan regenerates
through `launch_turas()` and eyeballs a theme page.

**Stage 2.** Quote-as-unit listing, curated context memory, the PPTX theme chip, a tool
that restores full verbatims into an appendix whose cells were hand-edited, and the
`turas-project-setup` skill update so a new project starts with the archive convention.

---

## 11. SACS 2026 migration

Do not restore full verbatims for SACS. The appendix has hand-edited cells and the report
is in flight.

A script writes a NEW candidate workbook with openpyxl (never an `openxlsx` load-and-save
round trip, which collapses sheet dimensions, and never overwriting the original). It
pre-fills each `<Sheet> Extracts` with one row per shipping multi-theme row: `Theme` = all
that row's coded labels joined, `Extract` = the cell text as it stands. Duncan then prunes
the labels that the fragment does not actually evidence.

No second comment column, in SACS or anywhere. The sheet keeps ONE verbatim column plus
an extracts sheet. Where a SACS cell now holds a hand-edited fragment, that cell simply
goes unused once the same text sits in the extracts sheet, because a comment with any
extract never ships its verbatim. Nothing needs restoring for the report to be correct.
The full text, if Duncan wants to draw a second fragment for an uncovered theme, is in
`2026 SACS Comment Appendix full.xlsx` under the same IDs.

The property that makes this safe: a row left untouched behaves exactly as today, a row
deleted behaves exactly as today, and a row pruned fixes the bug. The shipped set of texts
is a subset of what ships now, by construction. That is 205 rows to prune across the six
sheets, and the pruning is the analyst's judgement, which cannot be automated.

---

## 12. Build constraints

- **Concurrency.** Another session is working in the pricing module and has
  `27z_pricing.js`, `styles.css`, `pricing_view_tests.mjs`, `test_pricing_island.R` and
  `V2_LIFT_PROGRAM.md` modified in this checkout. Do not create or switch a branch here,
  which would move that session's working tree. Build in a worktree, and set
  `RENV_CONFIG_AUTOLOADER_ENABLED=FALSE` with `R_LIBS_USER` pointed at the main
  checkout's library, or the suites run against an empty library. Commit by explicit
  path, never `git add -A`.
- **Do not touch `styles.css`.** Reuse an existing chip class.
- **Verification.** Duncan regenerates through `launch_turas()` and eyeballs the report.
  This build runs the R testthat suites and the v2 JS gate suite, and never headless-runs
  the pipeline or writes into a TurasProjects output folder.
- **Wording.** No em dashes in any string that reaches a reader: chip labels, refusal
  text, console boxes, commit messages.
- **Model.** Stage 1 is Opus work from this spec, followed by an independent Opus review.
  Fable is not needed again unless the review keeps finding things.

---

## 13. How the noteworthy tiers interact

The `Noteworthy` column stays where it is, on the comment row, and nothing about the way
it is marked changes. A tier is a judgement about the comment, and it drives four things:
the drawer's tier filter, the reading order (highest tier first, `byTierDesc:41`), the
build-time scope dial when `qual_verbatim_scope = noteworthy`, and the priority block and
pins, which take tier 3 comments (`priorityQuotesFor:508`).

In theme-scoped places the two work independently and correctly. The theme decides which
fragment shows, the tier decides filtering and order. A must-read comment on the
Unfairness page shows the Unfairness fragment and is still must-read.

The one place that needs a decision is the priority block, which is not theme-scoped: it
takes every tier 3 comment and shows one quote each. When a comment has several extracts,
something must choose. Either the unscoped precedence in section 4 decides (general
extract, else the first themed extract with its theme as a chip), or the extracts sheet
gains an optional fourth column where the analyst marks the one fragment to lead with.
The second is a handful of marks per question and gives exact control over what reaches a
slide. Section 14 asks Duncan which.

Two consequences to state rather than discover:

1. The tier remains a judgement about the whole comment. A comment marked priority on the
   strength of its unfairness content still counts as a priority comment on the
   Compensation page, showing the Compensation fragment. Nothing misleading is shown, but
   the tier there describes the comment, not the fragment. Moving the tier into the
   extracts sheet would change what the drawer's tier counts mean, and this spec does not.
2. A priority comment with no extract for a theme shows no text under that theme and drops
   out of its readable list, while still counting. That is the same behaviour a `hide`
   mark already produces.

The `hide` marker shares that column, and an extract on a hide-marked row refuses
(section 6). A hidden comment is not a comment to quote.

---

## 14. Decided by Duncan, 17 Sep 2026

All four as recommended, so stage 1 starts from here.

1. **Sheet layout: one extracts tab per question**, named `<CommentSheet> Extracts`. The
   tab decides which question a fragment belongs to, so it cannot be misfiled.
2. **A blank Theme means the general comment list only**, never a theme page. The single
   word `all` claims every theme the row is coded on. A named list claims those themes.
   The reasoning is that a forgotten theme list must fail visibly rather than silently.
3. **A starred quote does not remember its theme in build one.** The shortlist and the
   PowerPoint export show the comment's general fragment, which can differ in wording from
   the fragment starred on a theme page. Documented, must not crash, and it moves to
   stage 2.
4. **The analyst marks the lead fragment**, via the optional `Lead` column in section 3.

---

## 15. Implementation log

### Stage 1, reader and workbook I/O. BUILT 17 Sep 2026, not merged.

Branch `feature/qual-extracts` in the worktree `/Users/duncan/Dev/Turas-qual-extracts`,
branched off main at 917b26b6. Built in a worktree because another session had checked out
`fix/pricing-export-all-no-base` in the main checkout.

Files changed: `modules/tabs/lib/qual_workbook_reader.R` (pure parse, validate, attach),
`modules/tabs/lib/qual_workbook_io.R` (name routing, the refusal, the console line), and
the two test files.

Evidence: 803 checks pass and 0 fail across the 13 `test_qual*` and
`test_client_safe_qual_chain` files, of which 54 are new in the reader tests and 8 new
cases in the I/O tests. The live SACS appendix reads through unchanged, read-only, with
the same six questions and the same record counts (136 / 132 / 74 / 131 / 130 / 123) and
no extracts attached. A scratchpad copy of that workbook with a hand-written
"Engagement Extracts" sheet attached two fragments of comment 213 to exactly the two
themes named, out of the five it is coded on, and carried the Lead mark.

The record fields stage 2 consumes, present only when the workbook supplies them:
`extracts` (named list, theme label to fragment), `extract_all`, `extract_general`,
`extract_lead`, `has_extracts`.

Deviations from sections 3 to 6, all conservative:

1. The extracts failures get their own refusal, `DATA_QUAL_EXTRACTS_INVALID`, rather than
   joining `DATA_QUAL_WORKBOOK_INTEGRITY`. Different failure family, different fixes, and
   folding them in would have rewritten a refusal message that is not part of this work.
2. An extracts tab that exists but is entirely empty is a console note, not a refusal. A
   tab created ahead of the coding is work in progress, and refusing would block a report
   run over an empty sheet. A tab with content but no ID-anchored header still refuses,
   because its rows would otherwise vanish in silence.
3. Theme labels match exactly, including case. A case mismatch refuses and lists the valid
   labels rather than being silently corrected, which keeps the reader honest about what
   the coded sheet actually says.
4. `qual_unions.R` copies whole records when it merges sheets into a union question
   (`:215`), and unions themes by label, so extracts survive a union untouched. Checked
   rather than assumed.

Not built yet: stages 2 to 5. Extracts are read, validated and attached to the records,
and nothing displays them, so a report built from this branch today is unchanged.

### Stage 2, island builder. BUILT 17 Sep 2026, not merged.

Files changed: `modules/tabs/lib/qual_island_builder.R`, plus a one-field addition to
stage 1's attach step (`extract_lead_theme`, the lead fragment's theme label, so the
report can name the theme a fragment speaks to when it shows it away from that theme's
page). Tests added to `test_qual_island_builder.R` and `test_client_safe_qual_chain.R`.

The island record now carries, only when the workbook supplies them:

| Field | Meaning |
|---|---|
| `extracts` | `{ "<themeId>": "fragment" }`, the themed fragments |
| `extractAll` | the fragment claiming every coded theme, shipped once rather than repeated per theme |
| `hasExtracts` | TRUE when the comment has any fragment. It cannot be inferred: a comment with only a blank-Theme fragment has neither field above, and must still not show that fragment beside a theme |
| `textTheme` | the theme id the unscoped `text` speaks to, when `text` is a themed fragment |

`record$text` keeps its meaning and is now the unscoped text, by the section 4 precedence:
the Lead fragment, else the general fragment, else the first themed fragment, else the
verbatim. A comment with any fragment never ships its verbatim.

Evidence: 855 checks pass, 0 fail, across the 13 qual and client-safe files (49 new since
stage 1). Two of those pin the disclosure invariant the release audit depends on: a
client-safe build with fragments carrying an email and a phone number ships neither
string anywhere in the island JSON, and the hidden dial ships no fragment text while
`themeVals` survives. The committed island fixture's drift gate
(`test_qual_island_fixture.R`) still passes, which is the byte-identical claim proven
rather than asserted: a record without extracts emits exactly the fields it emitted
before.

Deviations: none from section 5. One addition, `extract_lead_theme` in stage 1, needed
because the island must name the theme of a lead fragment and stage 1 stored only its
text.

JS baseline before stage 3, on this branch: 338 + 23 + 20 = 381 checks pass, 0 fail,
across `qual_tests.mjs`, `qual_island_shape_tests.mjs` and `qual_rekey_tests.mjs`.
Stage 3 should extend the committed island fixture with an extract-bearing record, so the
JS suite exercises the real shape rather than a hand-authored one.

### Stage 3, the accessor and the sweep. BUILT 17 Sep 2026, not merged.

Files changed: `modules/tabs/lib/html_report_v2/assets/js/27q_qualitative.js`, the island
fixture generator and its committed JSON, `test_qual_island_fixture.R`, and a new JS suite
`modules/tabs/lib/html_report_v2/tests/qual_extracts_tests.mjs`. No other JS file needed a
change, and `styles.css` was not touched.

Three helpers now carry the whole rule:

- `qual.textFor(rec, themeId)` is the ONE place a comment's text is read for display.
- `qual.quotableUnder(rec, themeId)` is the extracts rule alone, used by the filters.
- `qual.drawerTheme(q, st)` is the one definition of which theme is on screen, so the
  card, the export and focus reading cannot disagree.

Swept: the readable pool, champion quotes, the drawer card, the curated split, the drawer
export, focus reading, the highlight store and the collection pool. The twelve remaining
raw reads are the deliberately unscoped ones (a pin, a hub exhibit, the collection, the
priority block) and each carries an `unscoped-text` marker on its line.

The sweep turned out smaller than section 8 feared, because stage 2 made `record.text` the
unscoped text: every context with no theme was already correct, so only the theme-scoped
sites needed changing.

Evidence: 866 checks pass, 0 fail, across the 13 R qual and client-safe files, and 1,182
across all 50 JS suites, every suite exiting 0. The new JS suite's 18 checks run against
Q3 of the committed island, which the R generator now builds with a real extract-bearing
record, so nothing there can pass against a shape R does not emit.

The static gate was tested by planting a forgotten raw read in `qual.sentimentCounts`. The
gate failed, named the line and said what to do, and passed again once it was removed. A
gate nobody has seen fail is decoration.

Deviations and one gap the gate could not catch:

1. The first version of the pool filter used `textFor(...) != null` to decide whether a
   comment has readable text. That conflated two different questions, because
   `qual.shown()` filters on `suppressed` rather than on text, and it dropped every
   hand-authored test record (which carries no `text` field at all). Nine checks went red.
   `quotableUnder` now expresses the extracts rule on its own and the withheld rule is left
   exactly where it was.
2. A static gate cannot see a mark KEY that is built in the wrong scope. The drawer card
   emitted `data-hl-key` from the bare comment key, so a highlight made on a fragment
   would have been stored against the comment and reappeared on its other fragments. Found
   by reading the DOM plumbing, fixed, and now asserted (check 17).
3. Highlight keys gain an optional `:t<themeId>` suffix. The base format is untouched, so
   marks in a saved copy made before extracts existed still load. The shortlist key stays
   bare, which is decision 3: a comment is starred once, not once per fragment.
4. `clearHighlights` now clears a comment's marks on every theme as well as its unscoped
   ones, because its caller is dropping the comment from the collection, not one fragment.

Not done here, and it is stage 4's whole job: nothing on screen yet says a quote is an
extract, and nothing tells a reader that a theme page counts comments it does not quote.

### Stage 4, what the reader sees, plus the docs. BUILT 17 Sep 2026, not merged.

Files changed: `27q_qualitative.js`, `qual_extracts_tests.mjs`,
`test_qual_report.R`, and four documents. `styles.css` was NOT touched: both new
notations reuse `.ql-hint` and `.ql-scopechip.hide`, which already exist.

Three things now say on the page what the workbook knows:

1. **A fragment is labelled `extract`.** Away from its theme page the label names the
   theme the fragment speaks to ("extract on Pay"), so a partial quote in a collection,
   a pin or the priority block is never presented as the whole comment with no clue
   which part of it this was. `qual.extractLabel(rec, themeId, q)`.
2. **A theme page states what it counts but cannot quote**: "N counted here, quoted
   elsewhere", with a tooltip saying those comments raised this theme, are counted in
   every number on the page, and are quoted beside the theme their extract speaks to.
   This is what lets a reader reconcile "18 comments" with 11 quotes without seeing the
   workbook. `qual.elsewhereChip(q, st, audience)`.
3. **The question states the fact once**: "Some comments quoted by extract". Appended to
   the scope chip rather than folded into its branches, so a question that both hides
   uninformative comments and quotes by extract states both. A question with no extracts
   is unchanged.

Without (1) the page invites the exact opposite of Duncan's original complaint: a client
reads three lines and asks how they earned four theme codes. The codes were coded on the
whole comment; only the quote is a fragment.

Docs updated: `QUALITATIVE_TAB_BUILD_NOTES.md` (new section D4, the technical record),
`QUAL_COMMENT_APPENDIX_GUIDE.md` (new section 2b, the analyst's instructions, next to
the noteworthy and hide rules it sits beside in practice), `README_comment_appendix.md`
(the same for anyone driving the builder script), and this plan.

Evidence: the whole tabs R suite, 79 files, 6,105 checks pass, 0 fail, 1 skip. All 49 JS
suites (the directory holds 50 .mjs files, one of which is a shared helper), 1,186
checks pass, 0 fail, every suite exiting 0. The extracts JS suite is now 22
checks.

The strongest of them is end to end, in `test_qual_report.R`: a real workbook whose
"Overall Extracts" sheet carries a Price-only fragment and an `all` fragment goes through
`build_qual_report_v2`, and the HTML that comes out contains both fragments, does NOT
contain either of those two comments' full verbatims, still contains the other ten in
full, and carries an island keying the fragment to the Price theme id with both of that
comment's themes still counted.

Deviations: none. One decision worth recording: the card takes the question as an argument
rather than reading `qual._view`, so the label is testable without a rendered view.

### Review fixes. BUILT 17 Sep 2026, not merged.

An independent Opus session reviewed stages 1 to 4 and found thirteen confirmed defects,
two of them serious enough to reach a client: the drawer's Excel export dropped the theme
and wrote another theme's fragment into the file, and highlight keys were suffixed per
theme for every comment, which retired every reader mark in every saved copy the moment a
theme was selected, on projects with no extracts sheet at all.

All thirteen are fixed, each one mutation-checked by reverting the fix and requiring the
suite to go red. Three of the tests written with the first attempt at these fixes passed
against the reverted code and were rewritten. Findings, fixes and the evidence per finding:
`modules/tabs/docs/REVIEW_FINDINGS_QUAL_EXTRACTS_2026-09-17.md`.

What the review could not break, having probed it directly: extracts obey the
confidentiality dial on every path, the release audit's declared-mode shortcut stays
honest, an island built without an extracts sheet is identical field for field, and
unions carry fragments through by label.

Also recorded there: a story pin frozen before an extracts sheet was added stops
rendering, because `textPublished` refuses a pin whose text the island no longer
publishes. That is the designed behaviour for any change to what ships, and it applies
equally to editing a verbatim by hand.

## The fix is complete

Stages 1 to 4 plus the review fixes deliver the whole of it. What remains is stage 5 (the
SACS migration script, section 11) and Duncan's own regeneration through
`launch_turas()`.
