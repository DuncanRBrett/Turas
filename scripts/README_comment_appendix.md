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

## Choosing the comment columns

In priority order — the tool always prints the resolved columns with per-column counts,
so you can confirm before it writes:

| Flag | Use when |
|------|----------|
| `--columns "a,b,c"` | you know the columns (**most reliable**) |
| `--columns-file FILE` | same, one column per line (`#` and blanks ignored) |
| `--pattern REGEX` | comment columns share a naming pattern (default `comment\|verbatim\|feedback`) |
| `--structure FILE.xlsx` | the Survey_Structure tags open-ends as `Variable_Type = Open_End` |
| `--auto` | headers are question wording (SACS-style); prints picks, needs `--yes` to write |

**Note on `--auto`:** it detects free-text columns by length + uniqueness. It works well
for a survey with one long open-end, but **under-detects on surveys with many short/sparse
comment columns** (e.g. CCPB, where it finds only a few). For those, use `--columns` /
`--columns-file`. Because `--auto` prints its picks and needs `--yes`, an incomplete guess
can't slip through silently.

## Examples

```bash
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
