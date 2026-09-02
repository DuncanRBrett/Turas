# Qualitative Comment Appendix. Setup & tabs integration

End-to-end guide for adding coded open-end comments to a Turas tabs report on a new
project: build the appendix from the survey data, code it, wire it into the crosstab
config, and see it in the report's Qualitative tab.

There are four steps: **Build → Code → Wire → Run**.

---

## 1. Build the appendix from the data

The appendix is a workbook with one worksheet per open-end (verbatim) column. Build it
with the reusable script instead of by hand:

```bash
python3 scripts/build_comment_appendix.py \
  --data   "…/<project> data.xlsx" \
  --appendix "…/<project> Comment Appendix.xlsx" \
  --config "…/<project>_Crosstab_Config.xlsx"   # or --columns / --columns-file / --pattern / --auto
```

`--config` reads the Selection sheet: every row with a `CommentSheet` is an open-end,
and that cell is the sheet its comments go to. Use it on an existing project. It is
the same declaration the report reads, so the two cannot drift. Reach for `--columns`
only when there is no config yet. If your appendix names its sheets for the topic
(`Engagement`, `Values`) rather than the question code, the mapping is what stops the
builder creating a second, empty set of sheets.

Put the appendix in the project's data folder, next to the survey data. Full script
reference (column-detection modes, flags): `scripts/README_comment_appendix.md`.

**Or run it from Turas.** `launch_turas()` → **Project Steps** wraps the same script in a
form, build/update, report changed comments, and apply approved changes, with the output
shown on the page and failures reported as TRS refusals. Same script, same result; nothing to
remember at the terminal. See `modules/steps/README.md`.

It is **incremental and non-destructive**. Re-run it whenever new interviews land and it
appends only new respondents (matched by ResponseID), preserving all coding below. Each
sheet looks like:

| Col | Header | Filled by |
|-----|--------|-----------|
| A | `ResponseID` (or `ID`) | the script (join key) |
| B | `Noteworthy` | you (tier code, see step 2) |
| C | *the verbatim* | the script (comment text) |
| D | `Overall Sentiment` | you (`1` pos / `2` mixed / `3` neg) |
| E+ | *your theme columns* | you (`1`/`2`/`3` per theme) |

---

## 2. Code the comments (analyst)

Open each sheet and code by hand. Everything here survives every re-run of the builder.

- **Noteworthy tier**. Put one code in the `Noteworthy` column (case-insensitive):
  `n` = Noteworthy · `m` = Must-read · `p` = Priority ("lead with in a presentation").
  Any other non-blank mark counts as Noteworthy.
- **Blank is a valid, deliberate state, and it is the normal one.** A blank
  `Noteworthy` cell means "an ordinary comment": not flagged, but **its text still
  shows** in the report. Most comments should end up blank. An unremarkable but
  genuine answer ("We order weekly, so we seldom run short", "The service is good")
  belongs here, *not* in `hide`.
- **Hide a comment**. The one reserved word `hide` (or `hidden`) in the same
  `Noteworthy` column withholds *that comment's* text from the report while still
  counting it in the theme distribution. It is not noteworthy (it's the opposite),
  so it never counts as a tier mark. Reserve it for comments that are **not a real
  answer**. Non-answers ("No.", "Not sure", "Don't know"), gibberish, blank-ish
  punctuation, or for text that would identify someone. See `qual_verbatim_scope`
  in §3 for showing only the noteworthy comments across the whole report.

> **The distinction that catches people:** blank and `hide` both mean "not
> noteworthy", so it is tempting to treat them as the same thing. They are not.
> Blank still publishes the verbatim; `hide` suppresses it. Coding every dull
> comment as `hide` silently strips the ordinary voice out of the report and leaves
> only the complaints and the raves. If in doubt, leave it blank. That is what
> `qual_verbatim_scope = noteworthy` is for when you want a curated few.
- **Overall Sentiment**, `1` positive / `2` mixed / `3` negative (legend sits above the header).
- **Themes**. Add a column per theme to the **right of the verbatim** (from col E), header =
  the theme name, and code `1`/`2`/`3` per comment. The prevalence board and theme filters
  build from these.

In the report the tiers give each comment a star, a `Noteworthy+ / Must-read+ / Priority`
filter, and, highest tier first, the order comments are listed and exported.

---

## 3. Wire it into the crosstab config

Two sheets in the project's `*_Crosstab_Config.xlsx`.

### Settings sheet

| Setting | Value | Notes |
|---------|-------|-------|
| `qual_workbook` | `02 Data/<project> Comment Appendix.xlsx` | Path **relative to the config file**. Include the subfolder, or it won't be found. |
| `qual_confidentiality_mode` | `redacted` | **Default is `hidden`, which shows NO verbatims.** Use `redacted` (auto-scrubs names/emails/numbers) or `full` to display the text. |
| `qual_demographic_cuts` | `allow` | Disclosure of demographic tags: `allow` / `safe` (k-anonymised) / `block`. **Use `safe` for any client-facing report that carries tags** (see §5). |
| `qual_noteworthy_default` | `all` | Which tier the filter opens on: `all` / `noteworthy` / `must_read` / `priority`. |
| `qual_verbatim_scope` | `all` | Which comments ship readable text (build-time curation). `all` = every comment except those marked `hide`. `noteworthy` = only tier 1+ comments are readable; the rest are counted but not shown. **Theme all, show some**. Use `noteworthy` to ship a curated handful of quotes from a large body of comments while the numbers reflect them all. |
| `min_reporting_base` | `1` | Disclosure k (used by both the audience gate and the `safe` tag k-anonymisation). `1` = off. Set a real floor (e.g. `30`, matching `significance_min_base`) for a client-facing report with tags. |
| `qual_tag_dimensions` | *(blank)* | Comment tags from the **host survey** (see §5): a comma list of `Column` or `Column:Label`, e.g. `S01:Centre, S09:Channel`. Values show as their Survey_Structure DisplayText; the Label is unchecked, so verify it against the Questions sheet. Blank = only the comment workbook's own demographic columns are tagged. |
| `qual_join_id_column` | *(blank)* | Only set if the respondent-id column doesn't auto-detect. |

### Selection sheet (per open-end row)

| Column | Value | Notes |
|--------|-------|-------|
| `CommentSheet` | the appendix sheet name for this question (e.g. `Q06Comment`) | Links the question to its comments. For a band-split open-end, list several sheets as `Sheet:Band; …` (see §5). Leave blank for closed questions. |
| `CommentLink` | the closed question/composite the open-end explains (e.g. `Q_Engage`) | Optional. Enables the closed→comments jump. Blank for a standalone open-end. |
| `SplitDimension` | the split axis label (e.g. `NPS band`) | Band-split open-ends only. Optional; defaults to `NPS band`. |
| `NpsScoreQuestion` | the 0–10 recommend question (e.g. `Q79`) | Band-split open-ends only. Optional; the band is derived from this score. Defaults to the `CommentLink` target. |

The comments are joined into the main report **by respondent id** (the appendix's
`ResponseID`/`ID` values must match the data's id column). If the join can't resolve, a
standalone `*_qual_report.html` is emitted as a fallback.

---

## 4. Run & verify

Regenerate the report via `launch_turas` (the interactive V2 report is the default). The
**Qualitative** tab appears with the comment drawer, prevalence board, tier filters and
sentiment controls. Re-run the builder + regenerate whenever fieldwork grows.

### If the Qualitative tab is empty or comments don't show

The qual join's failure messages print to the **R console** (where launch_turas runs), not
the Excel error log, so a clean-looking run can still have dropped the comments. Check, in
order:

1. **`qual_confidentiality_mode`** isn't left at the `hidden` default (that hides all text).
2. **`qual_workbook`** path includes the subfolder and points at a file that exists.
3. The appendix **`ResponseID` values match the data's id column**. Alchemer exports can
   prefix the first header with an invisible BOM (`Response ID`); the data loader strips a
   leading BOM on load, but if you built the appendix from a stale export, rebuild it.
4. The data file is **fully synced** (OneDrive mid-sync can serve raw/unmapped headers; the
   builder refuses safely in that state. Re-run once synced).

---

## 4b. Keeping it current (new interviews + backcheck edits)

Two different things change after the first build, and they are handled differently.

**New interviews.** Just re-run the builder. It appends only respondents it hasn't seen
(matched by ResponseID) and never touches an existing row, so all your coding survives:

```bash
python3 scripts/build_comment_appendix.py --data DATA.xlsx --appendix APX.xlsx --columns "…"
```

Close the appendix in Excel first, and let OneDrive finish syncing afterwards. If it's
open, Excel's copy overwrites the update the next time it saves.

**A comment's text changed** (a backcheck correction, say). The builder deliberately does
*not* rewrite existing rows, so these never flow through on a normal run. Handle them in
two steps, because a difference can run either way: the data may hold a correction, or
your appendix may hold text you cleaned by hand, and only you can tell which should win.

```bash
# 1. see what differs. Writes a review list, changes nothing
python3 scripts/build_comment_appendix.py … --report-changes

# 2. open that list, mark 'y' under "Apply? (y)" on rows where the DATA should win
#    (leave blank to keep your version), then apply just those:
python3 scripts/build_comment_appendix.py … --apply-changes "… changes 20260719_092150.xlsx"
```

The review list gives you Question, ResponseID, your current text and the new text side by
side. Applying rewrites **only the verbatim cell** on rows you approved. Noteworthy,
Overall Sentiment and every theme column are left exactly as they are, and it writes a
backup first.

One judgement it can't make for you: where a comment was *materially* reworded, your
existing sentiment/theme coding may no longer fit. Treat the review list as a prompt to
re-check the coding on those rows, not just a text swap.

---

## 5. NPS "why?" split + host-survey tags (advanced)

Two optional capabilities for comment questions. Both ride the same respondent-id join and
the same disclosure gate as everything above. Design detail: `COMMENT_ATTRIBUTES_PLAN.md`.

### 5a. One question from several band sheets (the NPS "why?" case)

An NPS "how likely to recommend" follow-up is usually routed into **three** comment sheets,
detractors, passives, promoters, so the builder emits three sheets that can't otherwise be
tied to the one question. List them in a single `CommentSheet` cell, each tagged with its band:

```
CommentSheet = DetractorComment:Detractor; PassiveComment:Passive; PromoterComment:Promoter
CommentLink  = Q79            # the closed NPS card the comments attach to
SplitDimension   = NPS band   # optional (this is the default)
NpsScoreQuestion = Q79        # optional; defaults to the CommentLink target
```

The three sheets reassemble into **one** reported question. Each comment's band is **derived
from the 0–10 recommend score** (9–10 Promoter / 7–8 Passive / 0–6 Detractor): the score
wins over which sheet the text happened to land in, and any disagreement is counted to the R
console. In the report the question gets an **All / Detractors / Passives / Promoters**
segmented control that re-slices the verbatims, the prevalence board and the export.

*(`:` is the sheet→band separator, safe because Excel forbids `:` in a sheet name. A single
sheet name in `CommentSheet` behaves exactly as before.)*

### 5b. Tag comments with host demographics (centre, channel …)

The comment workbook often carries no demographics, but the join makes every host-survey
variable reachable per comment. `qual_tag_dimensions` turns chosen host columns into tags:

```
qual_tag_dimensions = S01:Centre, S09:Channel     # Column:Label, comma-separated
```

Each comment then shows `Centre: Metro South · Channel: 11 - Spaza`. In the report a **🏷 Tags**
control lets the reader hide all tags or toggle a single dimension (it can only *hide*, never
reveal more than the analyst allowed).

Values are shown as the column's **DisplayText** from Survey_Structure, matched on trimmed
OptionText exactly as the crosstab processors match, so a column storing codes (`11`, `12`)
tags with the words the crosstab row uses, not the code. A value with no option in the
structure is tagged raw and named in a console warning, which is usually the first sign of
structure/data drift.

**The Label is only what the chip says.** Nothing checks it against the Questions sheet, so
`S11:Channel` will cheerfully print "Channel: Presell" over a Sales Method column. Read the
label back off the Questions sheet before you ship the report.

### 5c. Confidentiality with tags (important on small bases)

Tags multiply re-identification risk. A detractor tagged with centre + channel on a base of
8 could be one person. The controls, in increasing strictness:

- `qual_demographic_cuts = block`, **no tags at all** (Total-only). The setting for a
  confidential low-sample survey.
- `qual_demographic_cuts = safe`, **recommended for client-facing.** k-anonymises tag
  *combinations* against `min_reporting_base`, and does so **within each band**, so a tag that
  is common overall but unique among (say) the detractors is suppressed for them.
- `qual_demographic_cuts = allow`. Every tag; **internal use only.**

Plus the audience k-gate (`min_reporting_base`) withholds a whole comment list when a filtered
cut falls below k. Rule-based scrubbing + k-anon handle direct identifiers and small cells, not
*contextual* ones ("the only male teller at Newlands"), so default to `safe`, `block` for the
most sensitive, and set `min_reporting_base` to a real floor (30 is a common choice).

---

## Appendix. How surveys have organised this

- **By question column** (CCPB): one sheet per open-end field. This is what the builder
  produces automatically.
- **By theme** (SACS): one open-end's verbatims split across theme sheets (Culture,
  Satisfaction…). That split is an analyst coding decision, not derivable from the data;
  build the by-question appendix and add theme columns/sheets as your coding on top.

The reader (`qual_workbook_reader.R`) copes with both: it anchors the header row on the
id column, finds the verbatim as the longest-text column, reads `Noteworthy`, and treats
`1/2/3`-coded columns to the right of the verbatim as sentiment/themes.
