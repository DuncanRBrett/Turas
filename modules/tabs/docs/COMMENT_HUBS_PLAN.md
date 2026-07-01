# Comment Hubs — feature plan

**Status:** design locked; not built. Planning session Duncan + Claude, 2026-07-01.
**Type:** software feature — tabs v2 Qualitative tab.
**Regen/verify:** Duncan via `launch_turas` (never `preview_start`).

---

## 1. Problem & concept

A reader can already highlight excerpts and shortlist (★) comments while reading the
Qualitative tab, but there's no way to see those marks in one place or organise them.
Duncan wants **named collections** — "Masters students", "Psychology", "1st years",
"account issues" — that gather the relevant highlights/comments, labelled with question
and theme, so he (or the client) can examine one audience's or one issue's voice across
the whole survey.

Key realisation from the discussion: a "hub" and a "qual story" are **one idea, not two**.
A hub is a named collection drawn from the pool of marks. A hub that carries a one-line
analyst finding on top and is promoted into the report *is* the qual story. So the feature
is: **comment hubs, some of which you elevate into the narrative.**

## 2. Two-layer model — this is what guarantees "nothing is lost"

- **The pool** — every highlight and every shortlisted comment. The durable base. It
  already persists (localStorage + saved-copy slices) and survives Save-copy. Nothing
  above it may ever mutate it.
- **Hubs** — named lenses over the pool. A hub is a **view, not a container**: adding a
  comment to a hub, or deleting a hub, never touches the underlying mark. The same mark
  can sit in several hubs. Deleting a hub frees only the hub definition.

This is the core requirement behind Duncan's "highlights and shortlist must not be lost."

## 3. Two hub origins — this is "all readers can use, both me and the client"

- **Authored hubs** (Duncan's) ride inside the delivered report as a saved-copy island
  slice, like the Story pins. Privacy-cleared **once, at the moment Duncan saves the
  copy**. Clients see them read-only (browse, clone, but not overwrite).
- **Reader hubs** — any reader (Duncan or client) builds their own in their browser
  (localStorage, scoped per report via `d2.storeKey`), exactly like highlights/shortlist
  today. Gated **live** as they build. Never shipped unless that reader saves their own
  copy (then cleared at that save, same rule).

The UI stacks both: a "Curated · travels with the report" group above the reader's
"Your hubs".

## 4. Privacy rules — reuse the disclosure control, no new model

Everything inherits `TR.disclosure` / `min_reporting_base` / `qual_demographic_cuts` /
`qual_confidentiality_mode`. The precise behaviour agreed:

- The comment **text** is never the confidential thing. It's governed by
  `qual_confidentiality_mode` and stays reachable in its own question and in any large,
  safe hub.
- What the threshold protects is a small **demographic** cut being isolated with
  identities attached.
- **Gate on the distinct-respondent count of a hub's contents vs k.**
- **Topic hub** (no demographic label, e.g. "account issues") below k: keep the comments,
  **drop the per-comment demographic tags**. The comment is there, just not stamped with
  who said it.
- **Demographic-intersection hub** (its *name* is the small cut, e.g. "Cape Town 1st
  years", n < k): **collapse to name + count**. Stripping per-comment tags isn't enough,
  because the hub's own name re-attaches the cohort to every verbatim in it. The comments
  remain in their questions and in the large "1st years" hub; only this named collection
  is withheld.
- The gate fires at **render AND at save/export** (hubs persist).
- Granular demographic tags are acceptable and standard practice (a compact code under
  the quote, e.g. "Master's · 2nd yr · Online").

## 5. Design & experience (the agreed mockup)

Placement: hubs live in the **Qualitative tab**. A "Promote to story" action bridges a
hub into the **Story tab** (reuse the existing pin-to-story path).

The view:
- **Hub selector** — Curated group (flagged, travels with report) + Your hubs group (+ New).
- **Selected hub** — name + "curated" badge + an optional one-line **analyst headline**
  (the finding — reuse the insight-note pattern) + a **coverage line** ("illustrating 8 of
  47 Master's students · 6 highlights, 2 shortlisted") + a **group-by [Question | Theme]**
  toggle + **Promote to story**.
- **Quote cards** — a **sentiment cue** (pos/mixed/neg dot, from existing valence), the
  excerpt (highlighted span shown) or a shortlisted marker, a **theme chip** if any, a
  compact **demographic tag** (gated), an "also in [hub]" **overlap** line, and an
  **add-to-hub (+)** control.
- Below-threshold demographic hub: the **withheld note**.

Design decisions grounded in research (landscape pass):
- Hub-as-insight — a claim + its evidence, not a bucket (Dovetail).
- Sentiment cue + quote-as-hero for scannability (~84% of readers scan) (Toptal).
- Group-by theme as well as question (Reframer affinity grouping).
- Honest coverage line to avoid the cherry-pick pitfall (verbatim-in-reports best
  practice; that source also validates the compact demographic code under a quote).

## 6. Existing infrastructure to reuse

- **Highlights** — per-comment, localStorage `qualHighlights` + saved-copy slice. *Keyed
  per `qcode#idx` today — see Risk 1: must move to a stable ResponseID key.*
- **Shortlist (★)** — `qualSaved` island slice.
- **Composite audience filter** — the audience definition for an audience-scoped hub
  (`TR.stats.mask`; ANDs across / ORs within).
- **Disclosure control** — `21d_disclosure.js` (`TR.disclosure`, `audienceTooSmall`,
  `minBase`); config `min_reporting_base` + `qual_demographic_cuts` +
  `qual_confidentiality_mode`.
- **Pin-to-story** — `24_shell` `snapshotCard`/`snapshotLines` → `32_report`; the promote
  path reuses it.
- **Qual island** — `DATA_QUAL` records (`demos`, `themeVals`, `text`) keyed by anon idx,
  joined to the host by ResponseID.

## 7. Growth path

- MVP: audience-scoped **reader** hubs in the Qual tab.
- Next: authored hubs baked + cleared at save; hub headline + coverage + promote-to-story.
- Then: sentiment cues, overlap chips, multi-select add.
- Then: topic/issue **tags** (free-text) so hubs can be issue-scoped ("account issues"),
  not just audience-scoped.
- Later: AI-suggested hubs (cluster the marks); cross-report hub templates.

## 8. Risks

1. **Marks lost (main engineering risk).** If hubs and marks key off a volatile row index,
   a re-run or re-code orphans them. Mitigation: key everything off the stable ResponseID;
   round-trip **both** the pool and the hub definitions in the saved copy; every hub op
   non-destructive by construction. Test hardest here.
2. **Privacy leak by aggregation (main ethics risk).** Individually-safe comments can
   triangulate when pooled under a small demographic label. Mitigation: the
   distinct-respondent k-gate per hub, at render AND save/export, per §4.
3. **Density / clutter.** Sentiment dots + group-by + coverage could over-decorate.
   Mitigation: quote stays the hero, metadata muted, cues subtle.

## 9. Quality bar

- Non-destructive by construction; the pool is the single source of truth.
- Privacy gate proven with a test that a below-k demographic hub withholds at render **and**
  in the saved copy.
- Round-trip test: pool + hub definitions survive Save-copy and re-open.
- Unweighted / no-qual reports byte-identical (feature is additive, gated on the qual island).
- Client-facing: transparent (coverage shown), no dark patterns.

## 10. Build order (first cut)

1. **Collection view in the Qual tab** — aggregate the pool, group by question (+ theme
   toggle), honour the global filter, tags gated by disclosure, reader hubs in localStorage,
   add-to-hub. → delivers "all my highlights in one place" AND "Master's reactions across
   questions" (just apply the filter).
2. **Authored hubs** → saved-copy island slice + privacy-clear at save.
3. **Hub headline + coverage + promote-to-story** bridge.
4. **Sentiment cues, overlap chips, multi-add.**
5. **Topic/issue tags.**
