# Per-Comment Attributes — NPS split + demographic tagging

**Status:** Planning (pre-build) · **Date:** 2026-07-15 · **Owner:** Duncan Brett
**Module:** `tabs` (qualitative comment reporting in `html_report_v2`)
**Supersedes nothing; extends** `QUALITATIVE_TAB_PLAN.md` §3 (line 83 split-sheet
spec) and §10 (confidentiality dials), and reuses the Phase-2 join from
`QUALITATIVE_PHASE2_HANDOVER.md`.

> This doc plots the long-term-stable approach for two concrete asks:
> **(1)** the CCPB Q79 "how likely to recommend" comments arrive in three
> columns (detractor / passive / promoter) and can't currently be tied to one
> question; **(2)** we want to tag comments with demographics/firmographics
> (which centre, which channel), toggleable on/off, with a way to limit or
> prevent tagging on confidential low-sample surveys. Everything below is
> grounded in the current code — file:line references are to the tree as of
> this date. Items marked *(to confirm)* are assumptions I have not verified
> against client data.

---

## 1. The realization that shapes both features

Both asks are the **same underlying thing**: a *structured attribute attached to
a comment*. One is a categorical band (NPS: detractor/passive/promoter); the
other is a demographic value (centre, channel). The qual tab already carries
per-comment attributes and already knows how to filter, display, and
disclosure-gate them. So neither feature is a from-scratch build — both are new
**sourcing** and new **surfacing** of an attribute channel that exists.

What already exists (verified in code):

| Capability | Where | State |
|---|---|---|
| Comment → respondent join by **ResponseID**, re-keyed to the host MICRO row index `idx` | `qual_assemble.R:207` `qual_resolve_against_survey()` | **Built.** A comment shares one anonymous `idx` with that person's closed answers, so *any* host per-respondent value is reachable at the comment level. |
| Per-comment attributes on the record | `qual_island_builder.R:85` → `r.demos`, `r.rating`, `r.sentiment`, `r.tier` | **Built.** Emitted into `TR.QUAL.questions[].records[]`. |
| Demographic chips on the comment card | `27q_qualitative.js:1478-1490` `quoteCard()` (`.ql-tags`/`.ql-tag`) | **Built + disclosure-gated.** Sourced from the *workbook's own* demo columns today. |
| Filter comments by a cut (incl. an NPS box like "Promoter") | `26_filter.js:131-268` (box machinery) → `27q:208` `qual.maskFilter()` | **Built.** The global filter narrows the whole report, comments included. |
| Confidentiality: `block`/`safe`/`allow` + verbatim text mode + audience k-gate + **k-anonymity on tag combinations** | `qual_island_builder.R:123` `qual_kanon_tags()`, :212 `qual_build_data_qual()`; `21d_disclosure.js` `TR.disclosure` | **Built + robust.** "safe" keeps only the broadest tag-combination covering ≥ k respondents. |
| NPS scoring + Promoter/Passive/Detractor box grouping on the closed side | `score_utils.R:44` `nps_bucket_score()`; BoxCategory `generate_config_templates.R:1005,1048`; `25_cards.js`, `21_stats.js:218` | **Built.** Yields a score/box, not a per-comment tag. |

What is genuinely new:

- **Feature 1:** union several source sheets/columns into **one reported
  question**, stamp each comment with its band, and let the reader view by band.
  The reader is strictly one-sheet→one-question today (`qual_classify_sheet`),
  and `qual_build_links()` overwrites by target — so the union is real new work.
  *(Spec already sketched at `QUALITATIVE_TAB_PLAN.md` §3 line 83 — unbuilt.)*
- **Feature 2:** source tags from the **host survey microdata** (centre,
  channel — not in the comment workbook) via the join, and add a **reader-facing
  on/off + field-pick toggle**. Display + gate exist; host-sourcing and the
  toggle do not.

---

## 2. The long-term-stable spine: a per-comment attribute model

Rather than build NPS-band and demographic-tags as two bespoke features, formalise
one **attribute model** that both ride, so the next request (region, wave, sub-brand,
tenure) is config, not code.

An **attribute** attached to a comment has three independent properties:

**A. Source** — where the value comes from:
- `workbook` — a column in the coded comment workbook (today's `r.demos` path).
- `host` — a banner/derived variable in the main survey, attached via the
  ResponseID join (`idx` → host microdata). *(new)*
- `derived` — computed from a host variable by a named rule; the first rule is
  `nps_band` (0–6 Detractor / 7–8 Passive / 9–10 Promoter from the recommend
  score, reusing `nps_bucket_score()` thresholds). *(new)*

**B. Usage** — how it may be used (config flags per attribute):
- `filter` — narrows the audience (already the global-filter/mask path).
- `split` — offers a view-by segmented control on the question (Feature 1's band).
- `tag` — renders as a chip on the comment (Feature 2).

**C. Disclosure policy** — every attribute, whatever its source or usage, passes
through the **same** gate: `qual_kanon_tags()` (k-anonymity on the *combination*
of shown attributes) + the audience k-gate + the `block`/`safe`/`allow` dial.
This is the property that makes the model safe by construction: adding the NPS
band as an attribute means it is automatically k-anonymised alongside centre and
channel — three quasi-identifiers on one verbatim can't silently triangulate a
person, because the combination is what's gated, and that logic already exists.

The whole plan is: **implement `host` and `derived` sources, add the `split` and
`tag` usage flags, and route everything through the existing disclosure gate.**

---

## 3. Feature 1 — NPS comments: three columns → one question, view by band

### 3.1 The problem, precisely located

CCPB Q79 ("how likely to recommend") routes its follow-up "why?" into three
survey columns by band, so the export — and the Comment Appendix builder, which
emits **one sheet per open-end column** (`scripts/build_comment_appendix.py`) —
produces three sheets. The report can't present them as one question because:
- the reader derives the question code from the sheet name, one question per
  sheet (`qual_workbook_reader.R` `qual_classify_sheet`);
- `qual_build_links()` maps one closed target → one comment sheet, overwriting
  (`qual_report.R:185`).

*(The exact CCPB column/sheet names are not verified here — to confirm against
the live config. The three-band shape is stated in `QUALITATIVE_TAB_PLAN.md`
§3 line 62.)*

### 3.2 Recommended approach — in-engine union (honours §3 line 83)

Declare in config that **N source sheets union into one reported question**, each
source stamped with a **band label**, and the band becomes a first-class `split`
attribute on every record. Concretely:

1. **Config contract (Selection sheet, the open-end row).** Extend `CommentSheet`
   to accept a *mapping* rather than a single sheet, e.g.
   `CommentSheet = "Q79_det:Detractor; Q79_pas:Passive; Q79_pro:Promoter"`
   (single-sheet strings keep working unchanged — backward compatible). Add an
   optional `SplitDimension` label (default `"NPS band"`) and `SplitOrder`
   (display order of the bands).
2. **Reader/assemble.** A new union step reads each mapped sheet, tags each
   record with its band, and merges them into one question keyed to the closed
   target. This is the §3-line-83 "reassemble at build into ONE question" step;
   `qual_collect_ids()` already unions respondents across sheets, so the
   respondent-master seam is in place.
3. **Links.** `qual_build_links()` maps the closed NPS target → the single
   unioned question (no more overwrite loss), so the existing "💬 N comments"
   jump lights up on the Q79 card.
4. **Island.** The band rides as a `split` attribute on each record (same channel
   as `r.demos`, so it inherits `qual_kanon_tags`).

**Theme harmonisation across the union (implementation watch-point).** The three
band-sheets will usually carry *different* theme frames — promoters' themes
("great service") aren't detractors' ("poor service"). When the sheets union into
one question, the question's theme set becomes the union of the three, and the
prevalence board shows each theme's salience with per-band valence (which is
exactly what you want: the segmented control then reads "promoters raised X,
detractors raised Y"). But if the same underlying theme was labelled differently
per band, it will double-count until the labels are harmonised — and cross-sheet
theme-label merging is an explicit *unbuilt* refinement today
(`qual_assemble.R:19-21`). So the union step needs a `theme_aliases`/label-merge
pass (sketched at `QUALITATIVE_TAB_PLAN.md` §3 line 81) or a documented
assumption that the coded workbook uses one theme frame across the bands. Flag,
don't silently merge.

### 3.3 Where the band label comes from — derive *and* validate

Prefer **deriving** the band from the host recommend score, with sheet-of-origin
as fallback and a reconciliation flag:

- **Primary:** derive each respondent's band from the host NPS question via the
  join (`idx` → NPS box membership; thresholds from `nps_bucket_score()`). This
  is self-correcting and independent of which sheet the text happened to land in.
- **Fallback:** if the recommend score isn't identified in config, use
  sheet-of-origin (the `CommentSheet` mapping label).
- **Reconciliation (cheap QA, high honesty value):** when both are available and
  disagree (a comment in the "promoter" sheet whose score is 6), flag it — a
  build-time count in the console (TRS-style) and an optional per-comment marker.
  This catches routing/coding drift for free because the join is already there.

Config to identify the score: reuse `CommentLink` (the closed target is the NPS
question) or a `NpsScoreQuestion` key; no `Q79` hardcoding — generic by
`Variable_Type = "NPS"`.

### 3.4 "View by band" UX — a segmented control on the question

Add an `All / Detractors / Passives / Promoters` segmented control at the top of
the question's drawer that filters the record list by the band attribute —
**local to the question**, mirroring the existing `sentimentFilter`
(`27q:178`) and `tierFilter` (`27q:33`) patterns exactly. Low-risk, established
pattern, and it reads naturally ("show me the promoters' reasons").

This is deliberately separate from the **global** filter, which can already cut
the *whole report* by an NPS box (`26_filter.js pickBannerMode`). Both stay
available: the segmented control answers "within this question, by band"; the
global filter answers "everything, for promoters only". The themed prevalence
board and the diverging-sentiment chart then recompute per band for free
(they already recompute on the visible record set).

### 3.5 Why not the alternative insertion points

- **Upstream in the Python builder** (emit one sheet with a band column instead
  of three): faster, no R change, and the band column already flows as a
  workbook demographic (proven by `test_qual_workbook_reader.R:221-239`). But it
  bakes the combination into a side tool on an unmerged branch
  (`feature/comment-appendix-builder`), the band is then "just a demographic" not
  a first-class split, and every study must run the builder correctly. **Viable
  interim; not the stable home.** If Duncan wants Q79 working this week, this is
  the shortcut — but §3.2 is where it should live long-term.
- **Pure global-filter-by-box** (no union): doesn't solve the ask — the three
  sheets remain three questions; you'd still can't present "Q79 comments" as one.

---

## 4. Feature 2 — demographic / firmographic tagging

### 4.1 What's already there

Comment cards already render demographic chips (`quoteCard` `27q:1478-1490`),
already gated, already exported and fed into hubs — **sourced from the comment
workbook's own demographic columns** (the columns the reader finds between the ID
and the verbatim, `qual_demo_columns`). A demographic becomes a curated banner
dimension only if it appears in ≥50% of sheets (`qual_banner_dimensions`).

### 4.2 The new capability — host-sourced tags

"Which centre / which channel" usually live in the **main survey**, not the
comment workbook. The join makes them reachable per comment; the work is to
attach them:

- **R-side attach (recommended).** In `build_integrated_qual_island()`
  (invoked `run_crosstabs.R:820-889`, where `survey_data` and the config are both
  in scope), for each comment record look up the chosen host banner values at
  that respondent's row and add them to the record's attribute bag, then fold
  them through `qual_kanon_tags()` with the rest. Disclosure stays in one place
  (R), the JS is unchanged, the emitted island is already safe.
- **Not JS-side.** Reading `TR.MICRO[qcode][r.idx]` in the browser would force us
  to re-implement k-anonymity in JS — the gate lives in R and must stay there.

**Config:** a Settings key `qual_tag_dimensions` listing which host banner
dimensions are taggable (e.g. `"Centre, Channel, Region"`). Empty/absent = today's
behaviour (workbook demos only). The listed dimensions join the attribute set and
are governed by the same `demographic_cuts` dial.

### 4.3 The reader-facing toggle — bounded so it can only restrict

Add a control (qual-tab header) to **show/hide tags** and **pick which fields**
show, with state in `userState` so it survives "Save copy" (same mechanism as
highlights/shortlist). The safety invariant:

> The reader toggle is purely **subtractive on an already-gated set**. It can
> hide fields the analyst emitted; it can never add a field, reveal a value the
> `demographic_cuts` dial suppressed, or lower k. Because the emitted island is
> already k-anonymised and gated in R, anything the toggle can turn *on* was
> already cleared for display.

This is the whole reason the toggle is safe: the analyst's dial is the ceiling;
the reader only chooses how much of the cleared set to look at.

Minor polish: chips render **value-only** today (`esc(r.demos[k])` → "Sandton").
For "which centre" clarity when several dimensions show, render `label: value`
("Centre: Sandton · Channel: App") — small change in `quoteCard`, or a compact
`Centre ▸ Sandton` form.

---

## 5. Confidentiality & disclosure (the crux — spans both features)

Duncan's question — *should we limit or prevent tagging on confidential
low-sample surveys?* — is **already answered by the built engine**, and the
attribute model extends that answer to the new sources without new risk.

The three dials, and how to set them:

- **`demographic_cuts = "block"`** — no tags at all; the tab is Total-only. This
  is the "prevent tagging" setting for a confidential survey. Use for the most
  sensitive / smallest studies.
- **`demographic_cuts = "safe"`** — k-anonymise tag combinations against
  `min_reporting_base` (k). Shows "Admin" when 70 share it, hides "Admin + <1yr"
  when only 3 do. **Recommended default for any client-facing report.**
- **`demographic_cuts = "allow"`** — every tag; internal use only.
- **Audience k-gate** (`TR.disclosure.audienceTooSmall()`, fails closed) — when
  the filtered audience is below k the whole comment list is withheld, tags,
  quotes and even the count. Independent of the above; always on when k > 1.

Consequences for the two features, by design:

- The **NPS band** is an attribute, so it is k-anonymised in combination with
  the demographics — you can't get "Promoter + SmallBranch + App" narrowing to
  one person, because the combination is gated. Adding the band costs no new
  disclosure logic.
- **Host-sourced tags** pass through the same `qual_kanon_tags()` as workbook
  tags — one gate, one code path.
- The **reader toggle** cannot breach any of this (§4.3 invariant).

Recommended defaults to bake into the config template and docs: client-facing
report → `demographic_cuts = "safe"`, `min_reporting_base = 30` *(to confirm the
number with Duncan — 30 is a common cell floor, not a verified house rule)*,
verbatim `text_mode = "redacted"`; confidential/small study → `"block"`.

**Honest limit (carry into the methodology note):** rule-based scrubbing +
k-anon handle direct identifiers and small cells, not *contextual* ones — "the
only male teller at the Newlands branch" can still self-identify from an
un-tagged verbatim. This is already documented in `QUALITATIVE_TAB_BUILD_NOTES.md`
§D; tagging raises the stakes, so the safe default and the block escape hatch
matter more, not less.

---

## 6. Config schema — everything new in one place

| Sheet | Key/Column | New? | Meaning |
|---|---|---|---|
| Selection | `CommentSheet` | extend | Accept `sheet:Band; sheet:Band; …` mapping (single-sheet strings unchanged). |
| Selection | `SplitDimension` | new | Label for the split (default `"NPS band"`). |
| Selection | `SplitOrder` | new | Band display order. |
| Selection | `NpsScoreQuestion` | new (optional) | Host NPS question to derive the band from; else `CommentLink` target; else sheet-of-origin. |
| Settings | `qual_tag_dimensions` | new | Host banner dims to expose as tags, e.g. `"Centre, Channel"`. |
| Settings | `demographic_cuts` | exists | `allow`/`safe`/`block` — the tagging ceiling. |
| Settings | `min_reporting_base` | exists | k for k-anon + audience gate. |
| Settings | `qual_confidentiality_mode` (text_mode) | exists | `hidden`/`redacted`/`full` verbatim scrub. |

No `Q79`, no CCPB, no client specifics in code — all config.

---

## 7. Build phasing (risk-descending, each stage verifiable)

1. **Attribute model refactor (internal, no behaviour change).** Generalise the
   record's `demos` bag into an attribute set carrying `{source, usage,
   disclosure}` — keep `r.demos` as the serialised shape for JS back-compat.
   *Verify:* full qual suite green, island byte-identical on a workbook-only
   study (`test_qual_island_builder.R`, `qual_tests.mjs`).
2. **Feature 2a — host-sourced tags.** Attach `qual_tag_dimensions` host values
   in `build_integrated_qual_island`, folded through `qual_kanon_tags`.
   *Verify:* known-answer R test — a host dim appears as a tag, k-anon suppresses
   a below-k combination; audience gate still withholds below k.
3. **Feature 2b — reader toggle.** Show/hide + field-pick in `userState`;
   assert the subtractive invariant in a JS test (toggling can't reveal a
   suppressed field). *Verify:* `qual_tests.mjs`, Save-copy round-trip.
4. **Feature 1a — sheet union + band attribute.** Config parse, union step,
   `qual_build_links` one-target→one-unioned-question. *Verify:* three synthetic
   sheets → one question; band present per record; jump lights up.
5. **Feature 1b — derive + reconcile + segmented view.** Derive band from host
   NPS, reconciliation flag, `All/Det/Pas/Pro` control mirroring `sentimentFilter`.
   *Verify:* derived band matches `nps_bucket_score`; mismatch flagged;
   prevalence/sentiment recompute per band.
6. **Docs + template.** Update `QUAL_COMMENT_APPENDIX_GUIDE.md`, the config
   template generator (note: template `.xlsx` corrupts on openxlsx round-trip —
   edit the generator, not the binary), methodology-note copy.

Testing is non-negotiable per house rule: synthetic fixtures for the union, the
derive, the host-attach, the k-anon-with-band, and the toggle invariant. No stage
ships without its test. Duncan regenerates the real SACS/CCPB report via
`launch_turas` and eyeballs — the pipeline is never headless-run on his data.

---

## 8. Open decisions for Duncan (each with a lean)

1. **Feature 1 home — in-engine union (§3.2) vs upstream Python builder (§3.5).**
   *Lean: in-engine* for the stable solution; use the builder only if Q79 is
   needed before the engine work lands.
2. **Band source — derive-from-score (self-correcting) vs trust-the-sheet.**
   *Lean: derive + validate against sheet-of-origin*, flag mismatches. Needs the
   recommend score identified in config.
3. **Client-facing disclosure defaults — the actual k.** *Lean: `safe` +
   `min_reporting_base = 30` + `text_mode = redacted`*; confirm the number (30 is
   a common floor, not a verified TRL rule).
4. **Tag default — on or off for the reader.** *Lean: off by default*, reader
   opts in — least busy, and consistent with "prevent getting too busy".

---

## 9. What I did not verify (assumptions to confirm)

- The exact CCPB Q79 sheet/column names and that it is three-band (stated in the
  plan doc §3 line 62; not checked against live CCPB config/data — client data is
  gitignored/OneDrive).
- That the CCPB config identifies a 0–10 recommend score usable for derivation
  (needed for §3.3 primary path; sheet-of-origin fallback covers its absence).
- The house cell-size floor `k` (§8.3) — used 30 as a placeholder.

Everything else references code read this session; no behaviour is claimed
"working" — this is a design, to be verified stage by stage in §7.
