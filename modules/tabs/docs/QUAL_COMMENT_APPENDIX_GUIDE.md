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
- **Hide a comment** — the one reserved word `hide` (or `hidden`) in the same
  `Noteworthy` column withholds *that comment's* text from the report while still
  counting it in the theme distribution. It is not noteworthy (it's the opposite),
  so it never counts as a tier mark. Use it to drop an uninformative or identifying
  comment without distorting the numbers. See `qual_verbatim_scope` in §3 for
  showing only the noteworthy comments across the whole report.
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
| `qual_demographic_cuts` | `allow` | Disclosure of demographic tags: `allow` / `safe` (k-anonymised) / `block`. **Use `safe` for any client-facing report that carries tags** (see §5). |
| `qual_noteworthy_default` | `all` | Which tier the filter opens on: `all` / `noteworthy` / `must_read` / `priority`. |
| `qual_verbatim_scope` | `all` | Which comments ship readable text (build-time curation). `all` = every comment except those marked `hide`. `noteworthy` = only tier 1+ comments are readable; the rest are counted but not shown. **Theme all, show some** — use `noteworthy` to ship a curated handful of quotes from a large body of comments while the numbers reflect them all. |
| `min_reporting_base` | `1` | Disclosure k (used by both the audience gate and the `safe` tag k-anonymisation). `1` = off. Set a real floor (e.g. `30`, matching `significance_min_base`) for a client-facing report with tags. |
| `qual_tag_dimensions` | *(blank)* | Comment tags from the **host survey** (see §5): a comma list of `Column` or `Column:Label`, e.g. `S03:Centre, S11:Channel`. Blank = only the comment workbook's own demographic columns are tagged. |
| `qual_join_id_column` | *(blank)* | Only set if the respondent-id column doesn't auto-detect. |

### Selection sheet (per open-end row)

| Column | Value | Notes |
|--------|-------|-------|
| `CommentSheet` | the appendix sheet name for this question (e.g. `Q06Comment`) | Links the question to its comments. For a band-split open-end, list several sheets as `Sheet:Band; …` (see §5). Leave blank for closed questions. |
| `CommentLink` | the closed question/composite the open-end explains (e.g. `Q_Engage`) | Optional — enables the closed→comments jump. Blank for a standalone open-end. |
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

## 5. NPS "why?" split + host-survey tags (advanced)

Two optional capabilities for comment questions. Both ride the same respondent-id join and
the same disclosure gate as everything above. Design detail: `COMMENT_ATTRIBUTES_PLAN.md`.

### 5a. One question from several band sheets (the NPS "why?" case)

An NPS "how likely to recommend" follow-up is usually routed into **three** comment sheets —
detractors, passives, promoters — so the builder emits three sheets that can't otherwise be
tied to the one question. List them in a single `CommentSheet` cell, each tagged with its band:

```
CommentSheet = DetractorComment:Detractor; PassiveComment:Passive; PromoterComment:Promoter
CommentLink  = Q79            # the closed NPS card the comments attach to
SplitDimension   = NPS band   # optional (this is the default)
NpsScoreQuestion = Q79        # optional; defaults to the CommentLink target
```

The three sheets reassemble into **one** reported question. Each comment's band is **derived
from the 0–10 recommend score** (9–10 Promoter / 7–8 Passive / 0–6 Detractor) — the score
wins over which sheet the text happened to land in, and any disagreement is counted to the R
console. In the report the question gets an **All / Detractors / Passives / Promoters**
segmented control that re-slices the verbatims, the prevalence board and the export.

*(`:` is the sheet→band separator — safe because Excel forbids `:` in a sheet name. A single
sheet name in `CommentSheet` behaves exactly as before.)*

### 5b. Tag comments with host demographics (centre, channel …)

The comment workbook often carries no demographics, but the join makes every host-survey
variable reachable per comment. `qual_tag_dimensions` turns chosen host columns into tags:

```
qual_tag_dimensions = S03:Centre, S11:Channel     # Column:Label, comma-separated
```

Each comment then shows `Centre: Worcester DC · Channel: Presell`. In the report a **🏷 Tags**
control lets the reader hide all tags or toggle a single dimension (it can only *hide* — never
reveal more than the analyst allowed).

### 5c. Confidentiality with tags (important on small bases)

Tags multiply re-identification risk — a detractor tagged with centre + channel on a base of
8 could be one person. The controls, in increasing strictness:

- `qual_demographic_cuts = block` — **no tags at all** (Total-only). The setting for a
  confidential low-sample survey.
- `qual_demographic_cuts = safe` — **recommended for client-facing.** k-anonymises tag
  *combinations* against `min_reporting_base`, and does so **within each band**, so a tag that
  is common overall but unique among (say) the detractors is suppressed for them.
- `qual_demographic_cuts = allow` — every tag; **internal use only.**

Plus the audience k-gate (`min_reporting_base`) withholds a whole comment list when a filtered
cut falls below k. Rule-based scrubbing + k-anon handle direct identifiers and small cells, not
*contextual* ones ("the only male teller at Newlands") — so default to `safe`, `block` for the
most sensitive, and set `min_reporting_base` to a real floor (30 is a common choice).

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
