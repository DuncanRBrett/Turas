# Qualitative Comment Appendix — setup & tabs integration

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
  --columns "Q1Comment,Q2Comment,…"     # or --columns-file / --pattern / --auto
```

Put the appendix in the project's data folder, next to the survey data. Full script
reference (column-detection modes, flags): `scripts/README_comment_appendix.md`.

It is **incremental and non-destructive** — re-run it whenever new interviews land and it
appends only new respondents (matched by ResponseID), preserving all coding below. Each
sheet looks like:

| Col | Header | Filled by |
|-----|--------|-----------|
| A | `ResponseID` (or `ID`) | the script (join key) |
| B | `Noteworthy` | you (tier code — see step 2) |
| C | *the verbatim* | the script (comment text) |
| D | `Overall Sentiment` | you (`1` pos / `2` mixed / `3` neg) |
| E+ | *your theme columns* | you (`1`/`2`/`3` per theme) |

---

## 2. Code the comments (analyst)

Open each sheet and code by hand. Everything here survives every re-run of the builder.

- **Noteworthy tier** — put one code in the `Noteworthy` column (case-insensitive):
  `n` = Noteworthy · `m` = Must-read · `p` = Priority ("lead with in a presentation").
  Any other non-blank mark counts as Noteworthy. Blank = ordinary comment.
- **Overall Sentiment** — `1` positive / `2` mixed / `3` negative (legend sits above the header).
- **Themes** — add a column per theme to the **right of the verbatim** (from col E), header =
  the theme name, and code `1`/`2`/`3` per comment. The prevalence board and theme filters
  build from these.

In the report the tiers give each comment a star, a `Noteworthy+ / Must-read+ / Priority`
filter, and — highest tier first — the order comments are listed and exported.

---

## 3. Wire it into the crosstab config

Two sheets in the project's `*_Crosstab_Config.xlsx`.

### Settings sheet

| Setting | Value | Notes |
|---------|-------|-------|
| `qual_workbook` | `02 Data/<project> Comment Appendix.xlsx` | Path **relative to the config file** — include the subfolder, or it won't be found. |
| `qual_confidentiality_mode` | `redacted` | **Default is `hidden`, which shows NO verbatims.** Use `redacted` (auto-scrubs names/emails/numbers) or `full` to display the text. |
| `qual_demographic_cuts` | `allow` | Disclosure of demographic tags: `allow` / `safe` (k-anonymised) / `block`. |
| `qual_noteworthy_default` | `all` | Which tier the filter opens on: `all` / `noteworthy` / `must_read` / `priority`. |
| `min_reporting_base` | `1` | Disclosure k-gate: audiences below this hide the comment list. |
| `qual_join_id_column` | *(blank)* | Only set if the respondent-id column doesn't auto-detect. |

### Selection sheet (per open-end row)

| Column | Value | Notes |
|--------|-------|-------|
| `CommentSheet` | the appendix sheet name for this question (e.g. `Q06Comment`) | Links the question to its comments. Leave blank for closed questions. |
| `CommentLink` | the closed question/composite the open-end explains (e.g. `Q_Engage`) | Optional — enables the closed→comments jump. Blank for a standalone open-end. |

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
the Excel error log — so a clean-looking run can still have dropped the comments. Check, in
order:

1. **`qual_confidentiality_mode`** isn't left at the `hidden` default (that hides all text).
2. **`qual_workbook`** path includes the subfolder and points at a file that exists.
3. The appendix **`ResponseID` values match the data's id column**. Alchemer exports can
   prefix the first header with an invisible BOM (`Response ID`); the data loader strips a
   leading BOM on load, but if you built the appendix from a stale export, rebuild it.
4. The data file is **fully synced** (OneDrive mid-sync can serve raw/unmapped headers; the
   builder refuses safely in that state — re-run once synced).

---

## Appendix — how surveys have organised this

- **By question column** (CCPB) — one sheet per open-end field. This is what the builder
  produces automatically.
- **By theme** (SACS) — one open-end's verbatims split across theme sheets (Culture,
  Satisfaction…). That split is an analyst coding decision, not derivable from the data;
  build the by-question appendix and add theme columns/sheets as your coding on top.

The reader (`qual_workbook_reader.R`) copes with both: it anchors the header row on the
id column, finds the verbatim as the longest-text column, reads `Noteworthy`, and treats
`1/2/3`-coded columns to the right of the verbatim as sentiment/themes.
