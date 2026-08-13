# Comment Appendix builder

`scripts/build_comment_appendix.py` turns a survey's open-end (verbatim) columns into
the **coded-comment workbook** that the Turas qualitative tab reads — and it does so
**incrementally and non-destructively**, so you can re-run it as fieldwork grows without
losing any coding you have done.

It generalises the hand-built appendices used on **SACS** and **CCPB** into one reusable
tool. (Before this, each survey's appendix was built by hand.)

> **Setting up a new project?** For the full end-to-end workflow — build → code → wire into
> the crosstab config → see it in the report — see
> [`modules/tabs/docs/QUAL_COMMENT_APPENDIX_GUIDE.md`](../modules/tabs/docs/QUAL_COMMENT_APPENDIX_GUIDE.md).
> This README is the script reference only.

## What it produces

One worksheet per comment column (sheet name = the column name), in the Turas layout:

| Col | Header | You fill in |
|-----|--------|-------------|
| A | `ResponseID` (or `ID`) | — (join key, written for you) |
| B | `Noteworthy` | tier code: **`n`** Noteworthy · **`m`** Must-read · **`p`** Priority |
| C | *the verbatim* | — (comment text, written for you) |
| D | `Overall Sentiment` | `1` positive · `2` mixed · `3` negative |
| E+ | *your theme columns* | `1`/`2`/`3` per theme |

A sentiment legend sits above the header row. Columns B, D and E+ are yours to code; the
tool never touches them once written.

## Safe to re-run

Matching is by respondent id. On each run, for every sheet that already exists the tool:
finds the header row, reads the ids already listed, and **appends only respondents that
are new** (have a comment, not already present). It **never edits or reorders existing
rows**, so all Noteworthy/Must-read/Priority marks, sentiment codes and theme columns
survive. It writes a **timestamped backup** before saving, skips the save entirely on a
no-op run, and **refuses (touching nothing)** if it cannot find the comment columns.

## Updating: new interviews vs changed comments

**New interviews** — just re-run. It appends only respondents it hasn't seen and never
touches an existing row.

**A comment's text changed in the data** (e.g. a backcheck correction) — the builder does
not rewrite existing rows, so use the two-step review:

| Flag | What it does |
|------|--------------|
| `--report-changes [FILE]` | Writes a review list of every comment whose text differs between the data and the appendix — Question, ResponseID, current text, new text, and a blank `Apply? (y)` column. Changes nothing. Defaults to `<appendix> changes <timestamp>.xlsx`. |
| `--apply-changes FILE` | Rewrites the verbatim **only** on the rows you marked in that file. Every coding column (Noteworthy, Overall Sentiment, themes) is untouched. Backs up first. |

Why two steps: a difference can run either way — the data may carry a backcheck
correction, or the appendix may hold text you cleaned by hand (stray question-number
prefixes, typos). A blanket "data wins" would silently undo that cleanup, so approval is
per row. Both modes are surgical: neither appends new respondents.

Where a comment was *materially* reworded, re-check that row's sentiment/theme coding —
the text changed, so your coding of it may no longer fit.

## Choosing the comment columns

In priority order — the tool always prints the resolved columns with per-column counts,
so you can confirm before it writes:

| Flag | Use when |
|------|----------|
| `--config FILE.xlsx` | the crosstab config already declares the open-ends (**best for an existing project**) |
| `--columns "a,b,c"` | you know the columns (**most reliable** when there is no config) |
| `--columns-file FILE` | same, one column per line (`#` and blanks ignored) |
| `--pattern REGEX` | comment columns share a naming pattern (default `comment\|verbatim\|feedback`) |
| `--structure FILE.xlsx` | the Survey_Structure tags open-ends as `Variable_Type = Open_End` |
| `--auto` | headers are question wording (SACS-style); prints picks, needs `--yes` to write |

**Note on `--auto`:** it detects free-text columns by length + uniqueness. It works well
for a survey with one long open-end, but **under-detects on surveys with many short/sparse
comment columns** (e.g. CCPB, where it finds only a few). For those, use `--columns` /
`--columns-file`. Because `--auto` prints its picks and needs `--yes`, an incomplete guess
can't slip through silently.

## Where each column's comments go

By default a sheet is named after its data column — `Q17` writes to a sheet called
`Q17`. Hand-built appendices are usually named for the **topic** instead
(`Engagement`, `Values`, `Culture`), and without a mapping the builder would create a
second set of column-named sheets and leave the coded ones empty. That run looks
successful and loses nothing, but produces an appendix the report cannot use.

| Flag | Mapping |
|------|---------|
| *(nothing)* | sheet name = column name |
| `--config FILE.xlsx` | from the Selection sheet's `CommentSheet` column |
| `--sheet-map "Q17=Engagement,Q24=Values"` | explicit; overrides `--config` for the columns it names |

`--config` is the one to reach for. `CommentSheet` is the same declaration the report
reads to find a question's comments, so the builder and the report cannot drift apart —
and the config supplies the column list at the same time, so one flag answers both
"which columns" and "which sheet".

A **band-split** declaration (`DetractorComment:Detractor; PromoterComment:Promoter`,
one open-end spread across sheets by score band) is **refused**, naming the question.
Filing those correctly needs each respondent's band; guessing would put comments under
the wrong band and silently corrupt a hand-coded workbook. Build those sheets by hand.

## Examples

```bash
# An existing project: the config knows which columns are open-ends AND what each
# one's sheet is called. Nothing else to type.
python3 scripts/build_comment_appendix.py \
  --data     "…/SACS-2026_Data.xlsx" \
  --appendix "…/2026 SACS Comment Appendix.xlsx" \
  --config   "…/SACS-2026_Crosstab_Config.xlsx" --dry-run

# CCPB — 39 known columns (from a columns file next to the data)
python3 scripts/build_comment_appendix.py \
  --data "…/CCPB_CSAT_2026.xlsx" \
  --appendix "…/CCPB_CSAT_2026 Comment Appendix.xlsx" \
  --columns-file "…/ccpb_comment_columns.txt"

# A survey whose comment columns all contain "comment" or "verbatim"
python3 scripts/build_comment_appendix.py --data DATA.xlsx --appendix APX.xlsx --pattern "comment|verbatim"

# SACS-style single open-end with a question-wording header — preview, then write
python3 scripts/build_comment_appendix.py --data DATA.xlsx --appendix APX.xlsx --auto            # preview
python3 scripts/build_comment_appendix.py --data DATA.xlsx --appendix APX.xlsx --auto --yes      # write

python3 scripts/build_comment_appendix.py ... --dry-run     # report only, never write
```

Other flags: `--id-header` (header for new sheets; default `ResponseID` — the reader also
accepts `ID`), `--no-backup`.

## A note on layout across surveys

The appendix format has been applied two ways. **CCPB** is organised **by question column**
(one sheet per comment field) — this tool builds that automatically. **SACS** is organised
**by theme** (Culture, Satisfaction…), where one open-end's verbatims are split across theme
sheets. That theme-split is an **analyst coding decision**, not something derivable from the
data, so the tool gives you the by-question starting point; splitting/adding theme columns is
your coding on top (which it then preserves on every re-run).

## Tests

```bash
python3 scripts/test_build_comment_appendix.py
```

Known-answer tests: column detection (explicit / pattern / auto), the non-destructive
incremental update (preservation + idempotency + new-record append), id-header handling
(`ID` vs `ResponseID`), and the empty/guard cases.
