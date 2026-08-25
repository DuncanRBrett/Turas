# Differences ranking — item 3 design (balanced score + decision E)

*Written 24 August 2026. This is the design for the last open item of
`DIFFERENCES_TAB_SCOPE.md` — item 3 (score comparability) and decision E (the
two-level proportion gate). Items 0, 2, 1 and 4 are already on main. Everything
below was checked against the code this session; file references are to
`lib/html_report_v2/assets/js/` unless said otherwise.*

---

## Decision E — DECIDED: open the gate, two-level banners only

**A two-level banner now admits proportion findings when the group beats its
single sibling** (one uppercase letter at 95%; in dual mode one lowercase
letter makes a soft finding). Banners with three or more levels keep the
existing ≥2-letters rule unchanged. Taken as a straight behaviour change, like
item 1 — no setting.

Why open it:

- The ≥2 rule is a *breadth* filter, not a validity filter: beating one of
  many siblings is a weak pairwise result, so the tab demands two. On a
  two-level banner the single sibling **is** all the siblings — beating it is
  the strongest breadth statement the banner allows. The current gate is not a
  considered decision about two-level cuts; it is an artifact that makes the
  tab structurally silent about "who buys what" on Gender and every other
  yes/no cut, which is the symptom that started this whole review.
- The mean path already runs exactly this comparison on two-level banners: one
  group against the rest (= the other level), one planned test at
  `zPrimary(1)`. The proportion letters on a two-level banner are likewise a
  single comparison — the Bonferroni divisor `k(k−1)/2` is 1 there — so the
  two pathways sit at the same evidential standard. Admitting one and not the
  other is the inconsistency, not the fix.
- Risk is contained: nothing changes on 3+-level banners, and item 1's
  reciprocal collapse has already halved two-level pages, so the new class of
  finding lands on a page with room for it.

**Considered and deferred**: generalising the gate to "beat two siblings, or
all of them when fewer than two are testable" (`required = max(1, min(2,
testableSiblings))`). A 3-level banner with one below-threshold column is
Gender in practice — its testable sibling count is 1, and today it can never
show a proportion finding either. But that generalisation silently changes
3+-level banners, which decision E does not authorise, and "testable" inferred
at the renderer from `base >= threshold` can drift from the model's actual
letter-assignment gate on weighted / disclosure-gated reports. If a real study
hits this, reopen it as its own decision.

Implementation: in `collectFindings` (27d_diffs.js), the required letter count
becomes structural — `model.columns.length === 3` (Total + two levels) → 1,
otherwise 2. No microdata is needed to know the level count, so the rule holds
on aggregate-only reports too. Proportion findings cannot mirror (letters are
directional), so item 1's collapse is unaffected.

Strings that go stale with the gate and are updated in the same commit: the
empty-state line ("No group is significantly ahead of **two or more others**…"
→ "No group stands significantly apart on this banner."), the file-header
comment ("beats 2+ siblings"), and the rationale comment on test 30b (its
assertion survives — an excluded question raises nothing regardless — but its
"a proportion needs 2+ siblings" explanation no longer holds on two levels).
The authored `diffs.intro` text was checked in the callout registry and does
not describe the gate, so it stays.

---

## The balanced score — a second ranking, offered as a sort option (decision C)

The default sort ("Biggest differences first") and its scores are **unchanged**.
A third sort option, **"Biggest differences first (balanced)"**, ranks by a new
`scoreBalanced` computed on every finding. Per decision C the default stays put
until the balanced sort has been watched on at least two studies with
different banner shapes; the findings *set* is identical under every sort —
decision E is unconditional — so the "top N of M" note stays honest when the
reader switches sort. There is deliberately **no config / R plumbing**: the
sort is a page-local control like the existing two, so there is no
`config_obj` key to wire (nothing for the build_config_object whitelist).

### What is wrong with the current score, precisely

Both formulas already try to standardise; they fail against each other at the
edges (scope doc §3, second review):

- A mean's multiplier `|z|/Z95` is **unbounded**. On n≈1,100, a spend
  variable's Welch z runs to 5–25× the critical value, so derived rand
  measures crowd out everything regardless of how big the difference actually
  is. A proportion's multiplier (letters beaten) caps at columns − 1.
- A mean's gap is normalised by the **observed min–max** of its scores. On an
  unbounded rand scale one big spender stretches the range and deflates every
  spend finding's score — the normalisation is at the mercy of a single
  respondent.
- The two effect terms are different currencies (pp of a 0–100 scale vs
  fraction of an observed range) glued together by incomparable multipliers.

### The balanced formula

For every finding: `scoreBalanced = strength × effect × 100`, both factors on
0..1.

**strength — bounded evidence, 0..1:**

- *Mean / index / NPS*: `min(|z| / zHi, 3) / 3`, where `zHi = zPrimary(1)` —
  the same configured critical value that gated the finding (the legacy score
  keeps its fixed `Z95` constant untouched). Beyond three times the critical
  value, more certainty says nothing more about size. A just-significant mean
  scores ⅓.
- *Proportion*: `min(1, letters / (columns − 2))` — the share of siblings
  beaten, with the same structural denominator as the gate. On a two-level
  banner one letter is all of them: strength 1. Low-base siblings sit in the
  denominator but can never be beaten, so proportion strength is understated
  on banners that have them — same conservative direction as the gate itself.

The boundary asymmetry is deliberate and should be named: a just-significant
proportion on a two-level banner gets strength 1.0 while a just-significant
mean gets ⅓. That tilts the balanced sort toward incidence findings — the
motivating complaint was that they never surface — and the mandated two-study
before/after is the check on over-rotation.

**effect — size on the measure's own scale, 0..1:**

- *Proportion*: `min(1, |Cohen's h| / 0.8)` between the group share and its
  baseline (the rest, or overall when no rest is computable — the same
  baseline the gap already uses). This is **the same effect currency the
  Executive Takeout already uses** (`takeout.effectSize`,
  27e_takeout_engine.js: h against `COHEN_H_REFERENCE = 0.8`, Cohen's
  "large"), so the two halves of the report now agree on what a big
  percentage difference is. The small `cohenH` helper is duplicated into
  27d rather than imported: the diffs module and its test sandbox do not load
  the takeout chain, and the SIZE-EXCEPTION note argues for keeping the
  finding contract self-contained.
- *Mean / index / NPS*: `min(1, |gap| / robustRange)` — as the Takeout does,
  but with the range made robust (below).

### The robust range

Computed once per question in `meanFindings`, alongside the existing lo/hi
scan, over the same population (the full unfiltered scores vector), unweighted,
nearest-rank percentiles — deterministic on rebuild.

- **Designed scales stay full-range.** If the non-null scores hold ≤ 12
  distinct values, this is a rating scale by construction (widest in the
  platform is 0–10 → 11 points; NPS index scores are −100/0/+100 → 3) and
  outliers are impossible: robust range = the existing anchored min–max.
  The `q.index_scores` fallback path (declared label scores, no microdata
  vector) is designed by definition and also keeps min–max.
- **Observed numeric scales get percentiles.** More than 12 distinct values
  (spend in rand, counts, imputed measures): robust bounds are the
  nearest-rank p5 and p95 of the non-null values, anchored at 0 exactly as
  the full range is (`min(0, p5)`..`max(0, p95)`), so one big spender no
  longer sets the denominator for every spend finding.
- **Fallback chain, in code**: robust range → if zero (e.g. ≥95% zeros makes
  p5 = p95 = 0) fall back to the full min–max range → if that is zero too,
  1 — the existing guard.
- A group's mean can sit outside the percentile bounds, so the effect term is
  clamped at 1 rather than allowed past it.
- **Known edge, accepted**: a composite index carries continuous
  per-respondent scores (a 0–100 measure with many distinct values), so the
  heuristic treats it as observed and its balanced effect is measured against
  the p5–p95 spread rather than the designed 0–100. That mildly flatters
  composites relative to a theoretical-range normalisation, uniformly across
  composites, on the opt-in sort only. Fixing it would need a declared-bounds
  signal that does not exist on this path; revisit if the two-study
  before/after shows composites over-ranking.

**Invariant: `f.scaleMin` / `f.scaleMax` are untouched.** They drive the
comparison bars *and* the Takeout's `effectSize`; the robust bounds are used
only inside `scoreBalanced` and are not stored on the finding. If the Takeout
should ever inherit the robust range, that is its own decision, not a side
effect of this one.

### Sorting and tiers

`rankedFindings(banner, sortKey)`: after the reciprocal collapse, sortKey
`"balanced"` re-sorts by (solid before soft, then `scoreBalanced`
descending) — the same tier rule the default sort applies to `score`, so a
soft finding still never outranks a solid one. `"question"` behaves as today
(cut by the default ranking, cards then ordered by code). The MAX_FINDINGS cut
runs after the sort, so each sort surfaces its own top 80.

---

## What this changes on a delivered report

- **Two-level banners** (Gender, yes/no cuts): proportion cards appear for the
  first time, under every sort. Card counts rise toward parity with
  multi-level banners (scope doc item 5's asymmetry shrinks). This is the
  headline behaviour change — it lands before Duncan's regen, which is the
  veto point.
- **All banners**: a new sort option in the scope bar. Default ranking
  byte-identical to today.

## Verification

- New `diffs_tests.mjs` cases: the two-level one-letter finding at 95% (placed
  beside test 5, which pins 3-level = 2 required); the two-level
  lowercase-only soft finding in dual mode; `scoreBalanced` capped under a
  huge-z mean while the legacy `score` stays unbounded; an outlier vector
  scoring by percentile range vs a designed-scale vector keeping full range;
  the degenerate zero-inflated fallback; balanced sort ordering through
  `rankedFindings(banner, "balanced")` on a fixture where the two rankings
  disagree; the sort control carrying the third option.
- All 38 JS suites from `lib/html_report_v2/` (no R file changes — the R
  suites are untouched by construction).
- **Live gates that remain open after this lands**: Duncan's `launch_turas`
  regen, and the before/after on two studies with different banner shapes
  that the scope doc mandates for items 1–3.
