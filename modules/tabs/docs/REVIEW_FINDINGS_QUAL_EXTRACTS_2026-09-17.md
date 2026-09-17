# Independent production review: qualitative extracts

**Date:** 17 September 2026
**Branch:** `feature/qual-extracts` in the worktree `/Users/duncan/Dev/Turas-qual-extracts`,
four commits on top of main at 917b26b6.
**Reviewer:** a fresh Opus session. I did not write this code. Every claim in
`QUALITATIVE_EXTRACTS_PLAN.md` section 15 was treated as unverified and re-established
by reading the code or running something.
**Stack:** R (reader, island builder) plus browser JS (`27q_qualitative.js`).

---

## Verification gates, as I ran them

| Gate | Command | Result |
|---|---|---|
| R qual + client-safe suites | `test_file()` over the 13 `test_qual*` / `test_client_safe_qual_chain` files | PASS, 876 checks, 0 fail, 0 skip |
| JS extracts suite | `node qual_extracts_tests.mjs` | PASS, 22 checks, 0 fail |
| Live workbook read | `qual_read_workbook()` on a scratchpad copy of `2026 SACS Comment Appendix.xlsx` | PASS, 6 questions, records 136 / 132 / 74 / 131 / 130 / 123, 0.41 s |
| Live workbook + a real extracts sheet | same workbook with a 56-row `Engagement Extracts` sheet written by openpyxl | PASS, 56 comments attached, 0.38 s |
| `styles.css` | `git diff --stat main..HEAD -- '*styles.css'` | untouched, and `.ql-hint` / `.ql-scopechip.hide` both exist (`styles.css:1009`, `:1024`) |
| Em dash rule | `git diff main..HEAD \| grep '^+' \| grep -E '—\|\\u2014'` | no em dash introduced by this branch |

The record counts and the 0.41 s read reproduce the stage-1 log's claim independently.

---

## CONFIRMED findings

### C1. CRITICAL. The drawer's Excel export re-creates the exact bug the feature removes

**File:** `modules/tabs/lib/html_report_v2/assets/js/27q_qualitative.js:1174` and `:1185`

`qual.exportXlsx` gained a `themeId` parameter and never passes it on:

```js
qual.exportXlsx = function (island, q, records, themeId) {   // :1174
  ...
  qual.exportRows(island, q, records, safeDemos), { keepText: true });   // :1185
```

The click handler at `:2960` does pass `qual.drawerTheme(v.q, st)`, so the theme is
known and then dropped. `exportRows` therefore calls `qual.textFor(r, undefined)`, which
returns the unscoped text.

**Failure scenario.** Comment X is coded Pay and Workload and the analyst writes two
fragments, one per theme. On the Workload theme page the reader sees the Workload
fragment. They click Export. The spreadsheet that reaches the client carries the **Pay**
fragment in the verbatim column of a Workload-scoped export. That is a fragment about pay
presented as evidence for workload, in a file, which is the defect the feature exists to
remove.

**What I ran.** A node probe with a hand-built island holding exactly that record
(`scratchpad/probe_export.mjs`):

```
drawer shows on Workload   : "and I work every weekend"
exportRows WITH themeId    : "and I work every weekend"
exportRows as exportXlsx calls it (themeId dropped): "my pay is too low"
```

JS test 11 ("the drawer export writes the text the drawer is showing") passes because it
calls `exportRows` directly with the theme. It never goes through `exportXlsx`, so the
wiring bug is invisible to it.

**Why CRITICAL and not HIGH.** The export button sits in the shipped report, so the
person who clicks it can be the client, and the file they get contradicts the screen they
got it from. There is no way to notice from the report: the drawer shows the right
fragment. A misattributed quote in a research deliverable is the one failure this feature
was commissioned to remove, and it is worse here than before the feature, because before
it the quote at least matched what the analyst saw.

**Fix:** pass `themeId` through at `:1185`, and change test 11 to drive `exportXlsx`
with a stubbed `TR.xlsx.download` so the wiring is what is asserted.

---

### C2. HIGH. Every reader highlight made before this branch stops rendering on a theme page

**File:** `27q_qualitative.js:931` (`hlKeyFor`), consumed at `:2475` (`quoteCard`),
`:1071` (`curatedSplit`) and `:1604` (focus reading)

```js
function hlKeyFor(qcode, rec, themeId) {
  return markKeyFor(qcode, rec) + (themeId == null ? "" : ":t" + themeId);
}
```

The suffix is appended for **every** record, including the overwhelming majority that
carry no extracts and whose text under a theme is identical to their unscoped text. Before
this branch `quoteCard` had no theme concept and always read the bare key.

**Failure scenario.** A project with no extracts sheet at all. Duncan opens a saved copy,
selects a theme, highlights a passage. He reloads, or opens the all-comments list: the
mark is there. He goes back to the theme page: the mark is gone, and the comment has
dropped out of "Analyst's selection". The same happens to every mark in every saved copy
made before this branch.

**What I ran.** `scratchpad/probe_hl.mjs` against HEAD, seeding the store exactly as
an old build wrote it (Q1 record 0, no extracts):

```
store key                   : Q1#@079e4881d8081b95  (identical on main and HEAD)
unscoped lookup             : 1
theme 0 lookup              : 0   | textFor === rec.text ? true
theme 1 lookup              : 0   | textFor === rec.text ? true
curatedSplit on theme page  : curated=0 rest=1
curatedSplit unscoped       : curated=1 rest=0
card on theme page has <mark>? false
card unscoped       has <mark>? true
```

and `scratchpad/probe_main.mjs` against `git show main:...27q_qualitative.js`, which
returns `1` and `curated=1` for the same store.

The plan's blindspot 4 said "never change the base format", and the base format is indeed
unchanged. The regression is in which key the drawer *reads*, which the plan did not
consider. JS test 13's comment ("a mark made before extracts existed still loads") is
tested only on the unscoped path.

**Fix:** key on the theme only when the record actually shows a different string there,
e.g. `themeId == null || !rec.hasExtracts ? "" : ":t" + themeId`. Then add a check that
seeds a bare key and asserts it renders on a theme page for a record with no extracts.

---

### C3. MEDIUM. In `hidden` text mode the report states three things that are not true

**File:** `modules/tabs/lib/qual_island_builder.R:199`

```r
if (shows && isTRUE(rec$has_extracts)) record$hasExtracts <- TRUE
```

There is no text-mode guard. `hidden` is the default dial ("numbers-only ship",
`qual_island_builder.R:22`), and in that mode no fragment text and no verbatim ships, but
`hasExtracts: true` does.

**Failure scenario.** A numbers-only report on a project with an extracts sheet. On a
theme page: every extract-bearing comment is dropped from the comment list (because
`quotableUnder` asks `textFor(...) != null` and everything is null); the header chip says
"N counted here, quoted elsewhere", which claims those comments are quoted on another
theme's page when nothing is quoted anywhere; and the question chip says "Some comments
quoted by extract" on a report that quotes nothing.

**What I ran.** `scratchpad/probe_hidden.mjs`, two comments both coded Pay, one with
`hasExtracts`:

```
hidden mode, Pay page: drawer shows 1 of 2 comments
elsewhereChip: "1 counted here"
scopeChip says quoted-by-extract? true
```

and an R probe over `qual_build_record_island` at all three modes:

```
mode=hidden    text=[NA]           extracts=[]              hasExtracts=TRUE
mode=redacted  text=[pay fragment] extracts=[pay fragment]  hasExtracts=TRUE
mode=full      text=[pay fragment] extracts=[pay fragment]  hasExtracts=TRUE
```

**Fix:** emit `hasExtracts` only when some fragment text survived the dial, i.e. gate it
on `!identical(text_mode, "hidden")` alongside `shows`.

---

### C4. MEDIUM. The static gate catches three spellings and misses seven plausible ones

**File:** `modules/tabs/lib/html_report_v2/tests/qual_extracts_tests.mjs:295`

```js
const READ = /\b(r|rec|recs\[[^\]]*\])\.text\b/;
```

**What I ran.** Planted one raw read at a time inside `qual.sentimentCounts` and ran the
suite. Positive control first, to prove the harness works:

| planted line | gate |
|---|---|
| `var leak = rec.text;` | **RED** (correctly names line 292) |
| `var leak = record.text;` | green |
| `var leak = records[0].text;` | green |
| `var leak = it.record.text;` | green |
| `var leak = row.text;` | green |
| `var leak = rec["text"];` | green |
| `var t2 = rec` / newline / `.text;` | green |
| `var leak = (rec).text;` | green |

`record`, `records[i]` and `it.record` are all spellings this very module already uses
(`it.record` at `:2585`, `record` throughout the R builder's vocabulary). The gate is the
thing the plan says "makes a six-site sweep safe rather than hopeful"; as written it makes
one spelling safe. The `unscoped-text` marker is also an unconditional escape hatch: any
line carrying that comment is exempt, with nothing checking it was considered.

The gate also scans `27q_qualitative.js` only. `30_story.js` consumes the quotes payload
(`:417`, `:490`) and is ungated. That is currently harmless, see C7 and the sound list.

**Fix:** widen to something like `/(?<![\w$])([A-Za-z_$][\w$]*(\[[^\]]*\])?)\.text\b/`
with an allowlist of non-record receivers (`qt`, `ins`, `sl`), or better: rename the
island field so any raw read is a name that cannot occur by accident, and keep the
accessor as the only reader.

---

### C5. MEDIUM. The "counted here, quoted elsewhere" number does not reconcile, which is its only job

**File:** `27q_qualitative.js:167` to `:179` (`qual.elsewhereChip`)

The chip counts over `recordsForTheme(bandFilter(shown(audience)), theme)`. The count it
sits beside comes from `visibleRecords`, which also applies `tierFilter`, `savedFilter`
and the sentiment pick. The theme's headline `n` in the prevalence table counts the raw
records, suppressed ones included.

**Failure scenario.** Four comments all coded Workload: A priority with a Pay-only
fragment, B tier 0 with a Pay-only fragment, C priority with no fragment, D hide-marked.

**What I ran.** `scratchpad/probe_chip.mjs`:

```
prevalence n on Workload (the page's headline count): 4
tier=all     : drawer count=1  chip says=2  -> 1+2 = 3 vs prevalence 4
tier=priority: drawer count=1  chip says=2  -> 1+2 = 3 vs prevalence 4
```

Two separate problems. With no filter the sum misses the hide-marked comment, so the
reader who is invited to add the two numbers gets the wrong total. With the tier filter on
Priority the chip still counts B, which that filter excludes for an unrelated reason, so
the chip over-claims: only two priority comments raised Workload, and the page reads as
three.

**Fix:** compute the chip over the same pool the count comes from, i.e. apply
`tierFilter` / `savedFilter` / the sentiment pick before counting, and word it against the
readable list rather than against every number on the page. If the hide-marked comments
are to be reconciled too, say so in the same chip.

---

### C6. MEDIUM. An extracts row with no ID can attach silently to the wrong record

**File:** `modules/tabs/lib/qual_workbook_reader.R:662` (`qual_attach_extracts`,
`at <- match(e$id, ids)`)

`qual_classify_extracts_sheet` keeps a row that has text but no ID (only a wholly blank
row is skipped), and `qual_extract_records` keeps coded rows with a blank ID as records
(reported as an integrity finding, not refused). So `match("", ids)` can succeed.

**Failure scenario.** The coded sheet has one row where the ID was lost (already flagged
on the console as a blank-ID row). The analyst writes an extract and forgets the ID.
Expected: a refusal naming the row. Actual: the fragment attaches to the blank-ID record,
which never joins the host survey and is dropped from the island, so the fragment vanishes
from the report with nothing said.

**What I ran.** An R probe over the pure functions:

```
coded sheet with a blank-ID row  -> problems: 0 (NONE), attached to record 2 with id [ ]
coded sheet with no blank-ID row -> problems: 1
   "Engagement Extracts row 2 (ID blank): no comment with that ID on sheet 'Engagement'"
```

**Fix:** refuse an entry whose `id` is blank before the `match`, with the row number.

---

### C7. MEDIUM. A fragment in a pin, the priority block, a hub exhibit or the deck carries no "extract" label

**Files:** `27q_qualitative.js:615` (`priorityQuotesFor`), `:672` (`priorityBlockHtml`),
`:1541` (the hub exhibit blockquote), `:1561` (the pin payload), consumed by
`30_story.js:490` and `29_export.js`

The stage-4 log says: "Away from its theme page the label names the theme the fragment
speaks to ... so a partial quote in a collection, **a pin or the priority block** is never
presented as the whole comment". The collection card does carry it (`:2591`,
`exLabel = qual.extractLabel(r, null, q)`). The priority block does not. The quote payload
is `{ text, q, band, tags, sentiment }` and `priorityBlockHtml` renders
`esc(qt.text)` plus a `<cite>` chip, with nothing about extracts. Nothing in
`30_story.js` or `29_export.js` adds it either.

**Failure scenario.** A tier-3 comment with a Lead fragment. Its fragment leads the
priority block on the crosstab page, a story pin and the PowerPoint quote slide, presented
as a complete verbatim. The client reads three lines and asks how they earned four theme
codes, which is precisely the question section 7 of the plan says the label exists to
answer.

**What I read.** `27q_qualitative.js:615-650`, `:672-690`, `:1536-1570`, and
`grep '\.text\b'` over `30_story.js` (six hits, none on a record) and `29_export.js`.

**Fix:** carry an `extract` flag (and its theme label) on the quote payload in
`priorityQuotesFor` and the pin/hub payloads, and render it in `priorityBlockHtml` and
the exhibit blockquote. The payload change is the one that has to happen first, because a
pin freezes it.

---

### C8. LOW. A coded sheet whose name ends in " Extracts" hard-refuses the whole report

**File:** `qual_workbook_reader.R:529` (`QUAL_EXTRACTS_SHEET_PATTERN`) via
`qual_workbook_io.R:53`

The pattern is `^(.*)\bextracts$` against the lowercased name, and routing happens before
classification, by design. Plan section 3 claims "A named sheet cannot be confused with
anything." It can.

**What I ran.**

```
Engagement Extracts    is_extracts=TRUE  base=[Engagement]
Extracts               is_extracts=TRUE  base=[]
Key Extracts           is_extracts=TRUE  base=[Key]
Contract Extracts      is_extracts=TRUE  base=[Contract]
Verbatim Extracts      is_extracts=TRUE  base=[Verbatim]
Engagement-Extracts    is_extracts=TRUE  base=[Engagement-]
```

**Failure scenario.** A study with an open-end sheet called "Key Extracts", or a scratch
tab called "Extracts": the sheet is routed to the extracts parser, has no `Theme` /
`Extract` column, and `qual_refuse_extracts_invalid` refuses the entire report with a
message about missing columns on a sheet the analyst thinks is a question. Low likelihood,
but the refusal is baffling rather than actionable.

**Fix:** require the derived base to name an existing question sheet before treating the
sheet as extracts; otherwise fall through to `qual_classify_sheet` as before. Say so in
the console line either way.

---

### C9. LOW. A misspelled `Lead` header silently drops every Lead mark

**File:** `qual_workbook_reader.R:532` (`QUAL_EXTRACTS_LEAD_PATTERN <- "^lead$"`), read at `:601`, and the
`cell()` closure in `qual_classify_extracts_sheet`, which returns `""` for an NA column

**What I ran.** An R probe with four header spellings, the same two extract rows each:

```
Lead header [Lead          ] problems=0 lead=[the pay bit]
Lead header [Lead?         ] problems=0 lead=[NONE]
Lead header [Lead fragment ] problems=0 lead=[NONE]
Lead header [LEAD          ] problems=0 lead=[the pay bit]
```

**Failure scenario.** The analyst labels the column "Lead?" or "Lead fragment", marks one
fragment per comment, and the report leads with a different fragment in every pin, the
priority block and the deck. No refusal and no console note, because an absent Lead column
is legal.

**Fix:** either widen the pattern (`^lead`) or, better, note on the console how many Lead
marks were read per sheet, so zero on a sheet with a Lead-ish header is visible.

---

### C10. LOW. The join separator is asserted against itself, so it is not pinned

**File:** `modules/tabs/tests/testthat/test_qual_workbook_reader.R:466`

```r
paste0("first bit", QUAL_EXTRACTS_JOIN, "second bit")
```

**What I ran.** Mutation M6, `QUAL_EXTRACTS_JOIN <- " / "`: 876 pass, 0 fail. No test
notices.

**Why it matters.** Setting the constant to `""` would splice two non-adjacent fragments
of a comment into one continuous sentence the respondent never said. That is a fabrication
risk, not a formatting preference, and the spec chose `" ... "` for exactly that reason.

**Fix:** assert the literal `" ... "` in at least one check.

---

### C11. LOW. The JS check that claims to pin the disclosure guard does not exercise it

**File:** `qual_extracts_tests.mjs:133` ("a withheld comment stays withheld, fragments or
not")

It uses `ISLAND.questions[0].records[2]`, a scope-withheld record that carries no
fragments, so the assertion passes through `return rec.text` rather than through the
guard.

**What I ran.** Mutation J4, replacing
`if (!rec || rec.text == null) return null;` with `if (!rec) return null;`: 22 pass, 0
fail. The guard is genuinely load-bearing for a record that has both `text == null` and
`extracts` present:

```
textFor(withheld record carrying a fragment): null   (guard present)
```

The R builder cannot currently produce such a record (see the sound list), so this is
defence in depth against a future builder change or a hand-edited island, and the test
that is supposed to hold the line does not.

**Fix:** assert `textFor` on a hand-built `{ text: null, hasExtracts: true, extracts: {...} }`
record.

---

### C12. LOW. A theme label with a non-breaking space cannot be matched, and the refusal looks wrong

**File:** `qual_workbook_reader.R:680` (`if (!(label %in% labels))`)

Labels are compared after `trimws`, which does not strip U+00A0. A coded header
`"Pay Rise"` and an analyst typing `"Pay Rise"` are unequal, so the run refuses and
lists a valid label that is visually identical to the one it just rejected.

**What I ran.**

```
coded header with NBSP: Pay Rise | trimws keeps it: TRUE
analyst types a normal space -> equal? FALSE
```

**Fix:** normalise U+00A0 to a space on both sides before comparing, or add the codepoint
to the refusal message when the two differ only by whitespace class.

---

### C13. LOW. The drawer's sentiment split beside a theme silently becomes "of quotable comments"

**File:** `27q_qualitative.js:1049` (the new `quotableUnder` filter in
`poolBeforeSentiment`), consumed at `:2132`

The sentiment filter's own counts are `qual.sentimentCounts(qual.poolBeforeSentiment(...))`,
and `poolBeforeSentiment` now drops every comment whose fragments speak to other themes.
So the Positive / Mixed / Negative numbers on the buttons beside a theme count only the
comments that theme can quote, while the theme's own row in the prevalence table
(`qual.prevalence`, unchanged) counts them all.

**What I ran.** The same four-comment island as C5:

```
sentimentCounts on the pool the buttons read : {"pos":1,"neu":0,"neg":0}
sentimentCounts on every comment the theme counts: {"pos":4,"neu":0,"neg":0}
```

Two of the three missing are the extract-filtered comments, new with this branch; the
third is the hide-marked one, which was already excluded before it.

**Why only LOW.** These are filter counts, not a reported statistic: the theme's published
pos/neu/neg split comes from `qual.prevalence` over the raw records and is untouched, and
`qual.shown` already set the precedent that the filter counts describe the readable list.
It is listed because the change is invisible: nothing on the page says the sentiment
buttons are now scoped to what this page can quote.

**Fix:** either fold the extract-filtered comments back into these counts, or extend the
C5 chip's tooltip to say the sentiment counts describe the quoted comments.

---

## SUSPECTED, not established

### S1. Adding an extracts sheet to a live project invalidates existing story pins

`qualPinStale` (`30_story.js:412`) drops a whole frozen payload when any quote it holds is
no longer published, and `qual.textPublished` scans `.text`. Once a comment gains any
extract, its `text` becomes the fragment, so a pin holding the full verbatim goes stale
and the pinned collection renders the `QUAL_STALE_NOTE` instead. That is the safe
direction, and it is the designed behaviour for a rebuild that withheld text, so I am
recording it as a consequence rather than a defect. I did not construct the two-build
sequence to watch it happen.

### S2. The aggregate cube and the client-safe delivery modes

I read the cube path (`qual_build_question_island` takes `cut_map`, and the record's `cut`
tags are built after the extracts fields, untouched by them) and the delivery floor
(`tabs_delivery_qual_dials` / `tabs_apply_qual_floor`, exercised by
`test_client_safe_qual_chain.R`, which I ran). I did not build a cube deliverable, so the
cube claim rests on reading, not running.

### S3. The PPTX deck

I traced `priorityQuotesFor` to `priorityBlockHtml` and to `30_story.js:773`'s
`TR.exporter.quoteSlide`, and confirmed the payload shape is unchanged, so nothing can
crash on the new fields. I did not build a deck. C7 is the substantive point here.

---

## Verified as sound

Each of these was a candidate failure I went looking for and did not find.

1. **The confidentiality dials reach every fragment.** An R probe over
   `qual_build_record_island` at all three text modes plus both scopes:
   `hidden` ships no fragment; `redacted` scrubs each fragment and counts it; a
   hide-marked record and a scope-withheld record ship no fragment and no `hasExtracts`.
   Mutation M1 (dropping the `if (shows)` guard on `frag`) turns
   `test_qual_island_builder.R` red with 3 failures, so this is pinned by test and not
   only by inspection.
2. **The release audit's surface really is declared-mode only.** Read
   `turas_release_audit.R:104` to `:190`: it judges `commentKey`, per-record `rid`,
   `demographicCuts`, `textMode` and the `cut` tag combinations against the cube's bases.
   It never inspects a text string. So extracts add no audit surface, which is sound
   *because* of point 1. `test_client_safe_qual_chain.R`'s two new tests assert that an
   email and a phone number planted in fragments survive nowhere in a client-safe island,
   and they pass.
3. **No path found where a fragment reaches a file that declares `hidden` or `redacted`
   dishonestly.** Beyond the R dial, `qual.textFor` returns null the moment `rec.text` is
   null, which covers a malformed island as well.
4. **The island is byte-identical for records without extracts.** The fixture drift gate
   passing on this branch proves only generator-equals-JSON, since both moved. I diffed
   `git show main:...qual_island.json` against HEAD's per record and per key: Q1's four
   records and Q2's two records are identical field for field; the only changes are `n`
   5 to 7 and the added Q3. So a record with no extracts emits exactly the fields it did
   before.
5. **A fragment on a theme the comment is not coded on genuinely refuses.**
   `qual_record_from_row` starts from `theme_vals <- list()` with no pre-seeding
   (`qual_workbook_reader.R:377`), skips a blank cell, and writes `theme_vals[[label]]`
   only for a valid 1/2/3 code (`:380`). So an uncoded theme is **absent** from the list,
   never `NA`, and `is.null(rec$themeVals[[label]])` is the right test. I checked the
   pre-seeding explicitly, because if the list were seeded with `NA` the check would be
   inverted and mutation M4 would be passing for the wrong reason. M4 turns two files red
   with 4 failures.
6. **Unions carry extracts through untouched, in the right order.** `qual_report.R:88`
   reads and attaches extracts, then `:91` applies `qual_apply_sheet_unions`, which copies
   each record whole (`qual_unions.R:215-218`) and unions themes by label (`:221`). Because extracts are keyed by theme **label** in the reader and only remapped
   to ids at island build (`qual_island_builder.R:345`), a band sheet's fragment cannot
   land on the wrong theme id after a union reorders the theme list.
7. **A record absent from the host survey join cannot leak.** `qual_build_question_island`
   drops it before the record builder runs (`qual_island_builder.R:354`), so it never reaches the island
   at all, extracts included.
8. **`OTHER_THEME` and raw questions behave.** `textFor` and `quotableUnder` treat
   `OTHER_THEME` as no theme, and `drawerTheme` returns null for a `raw` question, so a
   themeless project sees the pre-extracts behaviour throughout. An unthemed comment can
   only carry a blank-Theme fragment (a named theme must be coded), so its unscoped text
   is the right one to show under "everything else".
9. **`theme_id_map` cannot be missing a label the reader accepted.** Both sides derive
   from `question$roles$themes`, including after a union. The silent `next` in
   `qual_apply_extracts_text_mode` is therefore unreachable today; it is a latent risk only
   if that invariant is ever broken.
10. **`bareMark` round-trips.** rids are hex tokens and qcodes never contain `#`, so the
    `lastIndexOf(":t")` split cannot cut a legacy key. `:t0` strips correctly
    (`parseInt("0")` is not NaN). `themeAttr` returns a number, so `themeLabel`'s strict
    `===` comparison holds and the key written and the key read back agree.
11. **The R suite is load-bearing, not tautological.** Ten of eleven plausible mutations
    go red:

| mutation | result |
|---|---|
| M1 `frag` ignores the scope / hide dial | RED (3) |
| M2 `hasExtracts` never emitted | RED (4) |
| M3 hide-marked rows may carry an extract | RED (1) |
| M4 fragment on an uncoded theme allowed | RED (4) |
| M5 blank Theme behaves as `all` | RED (5) |
| M6 join separator changed | **green** (C10) |
| M7 unknown theme label accepted | RED (3) |
| M8 unknown ID accepted | RED (2) |
| M9 two Lead marks allowed | RED (1) |
| M10 blank + `all` contradiction allowed | RED (1) |
| M11 unscoped precedence: general before Lead | RED (2) |

12. **The JS suite is load-bearing too.** Ten of the eleven JS mutations go red, each
    figure being the number of the 22 checks that failed: `hasExtracts`
    ignored (7 fail), `extractAll` fallback removed (5), themed fragment ignored (8),
    theme suffix dropped from the highlight key (3), pool no longer filtered by
    quotability (1), extract label never rendered (2), `elsewhereChip` always empty (1),
    `scopeChip` notice removed (1),
    `championQuotes` filter dropped (1), `drawerTheme` returning the theme for
    `OTHER_THEME` (1). Only J4 stays green, which is C11.
13. **The end-to-end test in `test_qual_report.R` is the real thing.** It writes a 12-row
    workbook with an `Overall Extracts` sheet, runs `build_qual_report_v2`, and asserts
    against the produced HTML that both fragments ship, that the two fragment-bearing
    comments' full verbatims do not, that the other ten still do, and that the island keys
    the fragment to the Price theme id with both themes still counted. Nothing there can
    pass against a shape R does not emit. (It calls `openxlsx::saveWorkbook` directly,
    which the module guide forbids, but two existing helpers in the same file already do,
    and the fixture is a tempfile read back in the same session.)
14. **Performance is a non-issue.** The live SACS appendix reads in 0.41 s with no
    extracts sheet and 0.38 s with a 56-row one, and theme labels containing `&`
    ("Growth & Development", "Workload & Burnout") parse correctly through the `;` split.
    Comment 213 attached five fragments, one per coded theme, which is the migration's
    pre-fill shape.
15. **Minification and hardening need nothing.** `modules/shared/lib/minify_profile.json`
    sets `renameProperties: false` and terser runs `--no-mangle-props`, and there is no
    island-field whitelist anywhere in `scripts/` or `modules/shared/lib/`. The four new
    fields are ordinary property accesses and travel through untouched.
16. **`styles.css` really was avoided,** and both reused classes exist at `:1009` and
    `:1024`.
17. **No em dash was introduced.** One pre-existing `—` sits at
    `27q_qualitative.js:2035`, in the pin text line. It predates this branch, so it is out
    of scope here, but it does reach a reader and is worth a separate one-line fix.
18. **The analyst-facing docs are accurate** on the three Theme states, the archive rule,
    the Lead column and the refusal set, with one exception: they promise a refusal when
    "the ID does not exist", which C6 shows is not always true.

## Not checked, and why

- **Nothing was rendered in a browser.** Per the module guide, Duncan regenerates through
  `launch_turas()`. Every JS finding above comes from executing the module in node against
  the committed island or a hand-built one, never from a rendered page.
- **No report was regenerated and no deck was built.** Same reason.
- **No cube deliverable was built** (S2).
- **The SACS migration script (stage 5) does not exist yet,** so there was nothing to
  review there.
- **`qual_quant_layer.R` and `ai_insights_step.R`** were taken as out of scope on the
  plan's claim that no qual verbatim path exists in them; I did not re-verify it.

---

## Verdict

**MERGE WITH FIXES.**

The frame is right and the hard part is right. Extracts obey the confidentiality dial
everywhere I could reach, the release audit's declared-mode shortcut stays honest, the
island is genuinely unchanged for records without extracts, unions carry fragments through
by label so they cannot land on the wrong theme, the refusal set is strict where the spec
says it must be, and both suites are load-bearing rather than decorative. I found no path
by which fragment text reaches a file that declares `hidden` or `redacted`, and no path by
which a hide-marked or scope-withheld comment leaks a fragment.

One finding is CRITICAL and one is HIGH, and both must land before this merges. I still
say MERGE WITH FIXES rather than DO NOT MERGE because neither is a design fault: C1 is a
missing argument on one line and C2 is a condition on one expression. Nothing in the
architecture has to change.

1. **C1, CRITICAL.** Pass `themeId` from `exportXlsx` to `exportRows`, and make test 11
   drive the wiring rather than the function.
2. **C2, HIGH.** Stop theme-keying reader marks for comments that have no extracts, and
   add a check that seeds a bare key and reads it back on a theme page.

Four should be fixed in the same pass, being small and each one a statement the report
makes that is not true:

3. **C3** gate `hasExtracts` on the text mode.
4. **C5** compute the elsewhere count on the same pool as the number beside it.
5. **C6** refuse a blank-ID extracts row.
6. **C7** carry the extract flag onto the quote payload so a pin, the priority block and
   the deck say what the drawer says.

The rest (C4, C8 to C13) are worth doing but do not block. C4 is the one I would not
leave for long: the gate is the mechanism that is supposed to stop this bug coming back,
and today it stops one spelling of it.

After the fixes, Duncan still owes the `launch_turas()` regeneration and an eyeball of a
theme page, which is the only verification this review could not do.

---

# Response, 17 Sep 2026

All thirteen confirmed findings are fixed. Every fix was mutation-checked: the fix was
reverted and the suite had to go red, because three of the tests written alongside the
first attempt at these fixes passed against the reverted code and were rewritten.

| # | Fix | Where | Test that goes red without it |
|---|---|---|---|
| C1 | `exportXlsx` passes `themeId` to `exportRows` | `27q:1185` | JS 11b, which drives `exportXlsx` with a stubbed `TR.xlsx.download` instead of calling the row builder |
| C2 | A key is per theme only when the fragment shown there really differs from the comment's unscoped text | `hlKeyFor` | JS 13b, seeding a bare key exactly as an older build wrote it and reading it back on a theme page |
| C3 | `hasExtracts` is gated on fragment text having survived the dial | `qual_island_builder.R` | R "hidden mode ships no extracts FLAG either" |
| C4 | The gate matches any receiver, allows the payload objects by name, reads the whole file, and flags a parenthesised receiver | `qual_extracts_tests.mjs` | all eight planted spellings now go red, verified one at a time; `qt.text` correctly stays green |
| C5 | The chip counts over the same chain the list counts, extracts rule excluded | `elsewhereChip` | JS 19c, with a tier-0 comment the filter removes for an unrelated reason |
| C6 | A blank ID refuses before the `match` | `qual_attach_extracts` | R "an extract row with no ID refuses" |
| C7 | The note is plain text on the payload (`extract`), rendered in the priority block, the hub exhibit cite and lines, the deck's quote slide and the PNG quote card | `27q`, `29_export.js` | JS 19d, asserting the payload a pin freezes AND the rendered block |
| C8 | A sheet is routed to the extracts parser only when its name points at a sheet that exists or it is shaped like extracts | `qual_workbook_io.R` | R "a question sheet whose name ends in 'Extracts' is read as a question", plus one that a MISNAMED extracts sheet still refuses |
| C9 | `^lead` rather than `^lead$`, and the console reports extract rows and Lead marks per sheet | `qual_workbook_reader.R`, `qual_workbook_io.R` | R "a Lead-ish header still reads the Lead marks", over four spellings |
| C10 | The literal `" ... "` is asserted | test | R "the join is literally ' ... '" |
| C11 | The guard is asserted on a hand-built withheld record that carries fragments | test | JS 8b |
| C12 | Theme labels match on a normalised key (U+00A0 to space, whitespace collapsed), and are stored under the CODED spelling | `qual_attach_extracts` | R "a theme label matches across a non-breaking space" |
| C13 | The chip's tooltip states that the list, its counts and the sentiment filter describe the comments quoted here | `elsewhereChip` | JS 19, asserting that sentence |

Two notes on the fixes themselves.

**C2 is narrower than the review's suggested fix.** The suggestion was
`themeId == null || !rec.hasExtracts`. That still gives a per-theme key to an `all`
fragment and to a fragment that IS the comment's unscoped text, both of which show the
same string everywhere, so a mark made on the theme page would not be the same mark as
one made in the all-comments list. The condition is therefore on the string: a key is per
theme only when `textFor(rec, theme)` differs from `rec.text`.

**The island fixture gained a third Q3 record** (respondent 8, a different fragment for
each of its two themes). Without it no fixture record could distinguish a correct
per-theme key from a wrong one, which is why three of the first attempt's tests were
blind. Regenerated, and the R drift gate asserts the new record.

Evidence after the fixes: the whole tabs R suite, 79 files, 6,125 checks, 0 fail, 1 skip.
All 49 JS suites, 1,192 checks, 0 fail, every suite exiting 0. The extracts JS suite is
28 checks.

On the SUSPECTED findings: S1 (a story pin frozen before an extracts sheet was added
stops rendering) is inherent and already handled by `textPublished`, which refuses to
render a pin whose text the island no longer publishes rather than showing withheld text.
That is the designed behaviour for any change to what ships, not a defect of this feature,
and it is now stated in the plan. S2 and S3 were checked as part of C7 and the delivery
dials and need no change.

One correction to the stage-4 log, found while re-counting: the JS tests directory holds
50 `.mjs` files, one of which (`_text.mjs`) is a shared helper rather than a suite, so the
count is 49 suites, not 50.
