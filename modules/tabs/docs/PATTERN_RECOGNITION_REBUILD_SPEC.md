# Pattern recognition — rebuild spec (reader-first, tension-led)

**Status:** SPEC, not started. Decided 2026-06-28 with Duncan after reviewing the
current tab on three live reports (SACAP Climate, SACAP Student, CCPB). This is a
**rebuild**, not a wording patch — the deepest faults are in what each card chose
to *compute*, not how it reads.

**Prerequisite — DONE:** the cross-report localStorage leak (a CCPB headline
showing on SACAP) is fixed. All per-report stores (`turas_v2_takeout`,
`_insights`, `_annotations`, `_story`, `_report`, `_banners`, `_composites`) now
scope their key per project via `d2.storeKey` (20_data.js). Each report is
discrete after a regen.

**ctree / multi-way discovery is explicitly phase 3 — designed-for here, built
later.** Key-driver stays "call the existing keydriver/catdriver module when
needed", per Duncan.

---

## 1. What the tab is for (the 10-second job)

A reader opening Patterns should, in ten seconds, get the **gist beyond the
Dashboard** and be pointed at the **hidden story** — the things you miss reading
one question at a time. Duncan's own target output:

> "Cape Town takes strain on most engagement metrics but believes its co-workers
> are committed to quality more than any other big campus — what a tension that
> produces."
> "Marketing is low on satisfaction, person-centredness and recognition but high
> on results-orientation."

The unit of insight is a **group's character expressed as a contrast** — its lows
and highs in the same breath. The tab is a GPS to those contrasts.

## 2. Why the current tab misses (diagnosis, from the real reports)

- **Invents numbers that reconcile to nothing.** Campus "4.4 / 3.7" (average index
  across all questions), area "Overall perceptions 40.8", call-centre "7.5" —
  synthetic aggregates shown without a source; a researcher can't trace them, so
  they don't trust them.
- **Averages across incompatible scales.** "Overall perceptions" blends an
  NPS-type 0–100 ("recommend" 45.0), value-for-money (68.7) and trust on a 0–10
  (8.6) into one number. NPS must never be folded into an index.
- **Negative-biased.** Every card leads with the bad news; the positive is a grey
  one-liner. Reads as alarmist.
- **Opaque / arbitrary selection.** "Group under strain" implies one group when
  there are several and isn't the worst by eye (it ranks by a *base-weighted* gap,
  invisibly); "why these 4 questions" is unexplained; the co-moving anchor pair is
  near-arbitrary.
- **A non-pattern presented as a pattern.** Co-movement fires on most of the
  survey (26 of ~30 on CCPB) — that's the general satisfaction halo, not a finding.
- **Jargon and empty cards.** "survives correction"; cryptic confident-null text.

## 3. Three reader contracts (every card must pass all three)

1. **Traceability** — every number shown is a real cell the reader can find in the
   crosstabs (a group's value and the rest's value on a *specific* question). No
   synthetic aggregate unless its working is shown and links to its rows.
2. **Commensurability** — never average or compare across different scales. NPS,
   index and 0–100 each stay in their own lane. Aggregation only within one scale
   family.
3. **Balance + plain language** — lows and highs get equal billing and equal
   visual weight; no statistician jargon on the face of a card; nulls read like a
   human or aren't drawn at all.

## 4. Centrepiece — group portraits built around tension

For each group worth profiling, read its **group-vs-the-rest** result on every
question (the same disjoint vs-rest test built for composite banners and used by
the Differences tab — see §9). From that set of findings:

- **lows** = questions where the group is significantly *below* the rest;
  **highs** = significantly *above*. Each carries the group value, the rest value,
  the gap, and a comparable effect size.
- **lean** = which direction dominates, and how strongly:
  `leanScore = |Σe_low − Σe_high| / (Σe_low + Σe_high)` ∈ [0,1].
  Majority direction = the bigger side; minority = the other.
- **counter-spike** = the strongest finding in the *minority* direction (the high
  for a strained group; the low for a thriving one); 0 if none.
- **tensionScore** = `leanScore × counterSpike`. High when a group leans hard one
  way **and** breaks its own pattern sharply the other way — that contrast is the
  story.
- **characterScore** = `max(Σe_low, Σe_high)` — so a group that's uniformly low
  (no counter-spike, tensionScore≈0) still earns a portrait, just ranked below the
  tension stories.

Rank groups by tensionScore, then characterScore. The card shows: the subject, a
plain tension sentence, its top ~3 lows and top ~3 highs (balanced), a one-line
"why this group" (the selection rule, stated), and the most-positive/most-negative
framing folded in (this replaces both the old "group under strain" and the grey
"most positive group" line). Caps keep it honest: top N portrait cards, top 3
each side, all behind the existing FDR gate and low-base guard.

Effect size for ranking (not for display) reuses the takeout engine's
`cohenH` (proportions) and standardized mean difference (means) so proportion and
mean findings rank on one comparable scale. **Display always shows the raw cell
values**, never the effect size.

## 5. The 10-second GPS line

The single sharpest tension, written as one or two plain sentences from the top
card's *real* cells — e.g. "Cape Town carries a quiet tension: strained on
engagement but proud of its people's quality." This replaces the auto-headline
that was leaking. Editable inline (now scoped per report, so no cross-report
leak). When no group shows real character, it states that plainly rather than
manufacturing a headline.

## 6. Tier 1.5 — widen the scan beyond banners (cheap discovery)

The microdata island carries *every* question, not just banner variables. Run the
same vs-the-rest portrait scan over any **categorical / profile** variable's
levels (not only the banner columns), so a subgroup you never crossed-by can still
surface as a standout. JS-only, fully traceable, behind the same FDR gate. It
finds **single-cut** surprises ("you didn't look here, but you should have"); it
cannot find combinations — that's ctree (phase 3). Candidate cut-variables: single
/ multi categorical questions with adequate base, excluding the outcome questions
themselves; optionally narrowed by a config `segment`-eligible tag (§8).

## 7. Shared card grammar (so ctree slots in unchanged)

Every surfaced finding — banner portrait, single-variable surprise, or (later) a
ctree segment — is the **same object**:

```
{
  subject:    "Cape Town Campus" | "Women · Gauteng · 5y+" (ctree),
  frame:      banner/variable label | "discovered segment",
  source:     "banner" | "variable-scan" | "ctree",
  lean:       "strained" | "thriving" | "mixed",
  lows:  [ { question, value, rest, gap, sig } ],   // real cells
  highs: [ { question, value, rest, gap, sig } ],   // real cells
  tension:    plain-English sentence,
  why:        the selection rule, in one line,
  base:       n (for the low-base guard / display)
}
```

One renderer draws all three. Adding ctree later = a new R-computed island that
emits this shape; **no renderer change**.

## 8. Keep / reframe / cut (fate of every current pattern)

- **Group under strain + Most positive group → REPLACED** by the tension portrait
  (§4), which carries both directions in one balanced card.
- **Which split matters most → KEEP, reframed.** Drop the synthetic average-index
  ("4.4 / 3.7"). Instead: "the most and widest significant differences run by
  *Campus* — start there", counting real significant vs-rest findings per banner.
  A pure navigation pointer, fully traceable.
- **Weakest / strongest area → KEEP only when commensurable.** Show a theme only
  if its questions share a scale family (auto-detected from `type`/`scale_max`
  first; config `Scale_Family` tag as override — §8/config). Show the theme's real
  member values, never a cross-scale average. If not commensurable, don't draw it.
- **Co-movement → RETIRE for v1.** On these surveys it is the satisfaction halo,
  not a pattern. Optionally, the rigor footer notes "responses are dominated by a
  single overall sentiment" when ≥X% of pairs cohere. A future, inverted version
  ("the few questions that move *independently* of the halo") may earn a card —
  not now.
- **Odd-one-out / Hidden disagreement → DEMOTE to a quiet rigor footer.** No empty
  cards. One human line: "We also checked every group for a true exception and a
  hidden two-camp split — nothing held up beyond chance." (Keeps the never-cry-wolf
  proof without the cryptic empty card.)
- **Movement (waves) → KEEP as-is** (trackers); already traceable.

## 9. Comparison frame (decided)

**vs the rest** is the spine — each group/segment against everyone not in it,
disjoint by construction, every number a real cell. Where a **peer set** is
defined (e.g. "big campuses"), add the peer annotation as extra punch — "and the
highest of its peer group". vs-rest first, peer-relative as a sharpening overlay.

## 10. Config additions (optional; degrades gracefully to good)

The engine runs zero-config off the existing islands. Config only sharpens it; an
untagged project still gets tiers 1 and 1.5.

- **`Scale_Family`** (per question) — groups questions that share a scale so areas
  aggregate safely and NPS never mixes with index. Auto-detected where possible;
  this is the explicit override.
- **Headline metric** — already exists as `project.takeout_headline` (27f); reuse
  to lead the GPS line.
- **`segment`-eligible / peer-set** (per banner/variable) — which variables are
  sensible cuts for tier 1.5, and which groups form a peer set for §9. Sensible
  default: categorical questions with adequate base, excluding outcomes.

## 10b. Curation & never-cry-wolf (carried over unchanged)

The FDR / Benjamini-Hochberg trust-gate, the low-base guard, and the caps stay —
they are the reason the current engine never cries wolf, and that discipline is
the point. The rebuild changes *what is surfaced and how it reads*, not the
statistical gate underneath.

## 11. Reuse map (build on, don't reinvent)

- `TR.stats` vs-rest primitives: `columnsFor`, `tabulate`, `netCounts`,
  `boxCounts`, `indexMeans`, `propZ`, `meanZ`, Kish `effectiveBase` (21_stats.js).
- `27d_diffs.js` `collectFindings` / `restPct` already computes per-group,
  per-question vs-rest findings with direction + effect — the tension engine
  assembles **portraits** from this finder rather than re-deriving it.
- `27da_takeout_stats.js` `cohenH` / `effectSize` for comparable ranking.
- The FDR gate + CONST thresholds in `27e_takeout_engine.js`.

## 12. Integration per file

- `27e_takeout_engine.js` — replace `groupPattern`/`splitPattern`/`areaPatterns`/
  `comove`/`oddOne`/`bimodal` assembly with: `portraits()` (tension engine, §4),
  `variableScan()` (tier 1.5, §6), reframed `splitPointer()` (§8), commensurable
  `areaPattern()` (§8), and a `rigorFooter()` (§8). Keep `movement`.
- `27g_takeout_components.js` — one `portraitCard()` for the shared grammar (§7);
  delete the per-pattern card variants; `gpsLine()` for §5; drop the
  "survives correction" chip from the face (tooltip only).
- `27f_takeout_data.js` — curation/apex/veto keyed to the new portrait ids;
  storage already scoped.
- `27h_takeout_read.js` — render the GPS line + the portrait grid + the rigor
  footer from the new objects.
- `styles.css` — balanced two-direction card (lows and highs equal weight);
  retire the strain-dominant styling.

## 13. Verification (node harness, like composite_tests.mjs)

A `vm` harness over a hand-built fixture:

- A planted group with a clear lean + a sharp counter-spike → assert the tension
  is detected, the right lows/highs surface, the tension sentence names both
  sides, and **every displayed value equals a real cell** (no synthetic numbers).
- A uniformly-low group → portrait with no tension, ranked below a tension group.
- A commensurable theme renders an area; a mixed-scale theme does **not**.
- Tier 1.5: a standout on a non-banner categorical variable is found and carries a
  real base; an outcome variable is excluded as a cut.
- The FDR/low-base gate still suppresses noise (a planted thin/near-tie cell does
  not fire).

Then the suites: `takeout_tests.mjs`, `test_report_v2_bundler.R` (25),
`test_html_report.R` (87), full 38-module `vm` load.

## 14. Build order

- **Phase 0 — DONE.** Per-report storage scoping (leak fix).
- **Phase 1.** Card grammar + tension portraits on banners (§4, §7) + GPS line
  (§5); reframe the split pointer; make areas commensurable-only; demote nulls to
  the rigor footer; retire co-moving; balance the styling. Node harness.
- **Phase 1.5.** Widen the scan to all categorical/segment-eligible variables
  (§6), same cards, same gate.
- **Phase 2.** Config fields (`Scale_Family`, `segment`/peer-set) to sharpen areas
  and peer annotations; auto-detection first, config as override.
- **Phase 3 — LATER (separate project).** ctree multi-way discovery: an R module
  (partykit, weights, minbucket, NA-as-level, trivial-truth/collinearity guard),
  a precomputed subgroup island, rendered through the existing card grammar (§7).
  This is the only piece that moves computation into the R pipeline, so it carries
  the most per-project robustness risk — scope it to the headline outcomes and
  hold it to the same three contracts (§3).
