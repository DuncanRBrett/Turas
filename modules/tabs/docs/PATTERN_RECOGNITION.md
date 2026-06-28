# Turas pattern recognition — what it looks for, and how it avoids false alarms

Status: PLAN · 2026-06-28 · branch `feature/tabs-executive-takeout`

The Executive Takeout is being repositioned as **pattern recognition** — a core
Turas strength. Two promises, held in tension on purpose:

1. **Find what a person would miss.** A human reading the tables catches the
   biggest number and the sharpest gap. They miss what is only visible across the
   whole grid of questions and breakouts.
2. **Never cry wolf.** With dozens of questions and dozens of breakouts there are
   hundreds of cells, and some will look striking by pure luck. A tool that points
   at those teaches people to chase shadows and loses trust. Turas has to be the
   most sceptical reader in the room — and comfortable saying "there is nothing
   real here."

The second promise is the rarer and more valuable one.

All of this is deterministic — no AI. Every claim is auditable and reproduces
exactly on a re-run.

---

## The patterns it looks for

Each is something a person scanning the report would usually miss. For each: what
it finds, how it is computed, and the rule that stops it firing on noise.

### 1. The group under strain  ·  BUILT
- **Finds:** the breakout group sitting consistently below the overall across the
  whole survey — even when no single question screams (e.g. Cape Town).
- **How:** each group's index on every rated question vs the overall; rank by the
  average gap, discounted by how reliable the group's base is.
- **Guard:** ignores groups below the reporting floor (census-aware); needs to be
  below on several questions AND by a meaningful amount; one sharp cell on a tiny
  group cannot win.

### 2. Weakest / strongest area  ·  BUILT
- **Finds:** the theme (cluster of tagged questions) that is lowest / highest.
- **How:** average the index of the questions in each theme; rank.
- **Guard:** a theme needs at least two questions; needs tagging (falls back
  cleanly when untagged).

### 3. What moved  ·  BUILT
- **Finds:** the headline metric that rose or fell most since last wave (both
  directions).
- **How:** wave-on-wave change on the headline metrics.
- **Guard:** must be both statistically real AND a meaningful size (a 0.1 is not a
  move); otherwise reports "broadly stable".

### 4. Which split matters most  ·  BUILT
- **Finds:** whether the real differences run by campus, department or tenure — so
  you look at the breakdown that matters instead of all of them.
- **How:** for each breakout, how spread out its groups are around the overall,
  averaged across questions (variance explained); rank the breakouts.
- **Guard:** only counts reliable groups; the top breakout must lead the others by
  a clear margin, else "no single split dominates".

### 5. Questions that move together  ·  BUILT
- **Finds:** groups of questions that rise and fall as a set across people — a sign
  they share one underlying cause you can act on once, not three separate ones.
- **How:** correlate the per-respondent scores across questions; group the ones
  that strongly co-move.
- **Guard:** only strong, stable correlations on adequate bases; small or weak
  links are not reported.

### 6. The odd one out  ·  BUILT
- **Finds:** a group that is low on almost everything but unexpectedly high on one
  thing (or the reverse) — the exception worth explaining.
- **How:** for a group, compare each question to that group's OWN average; flag the
  question that breaks its pattern.
- **Guard:** the exception must be large relative to the group's usual spread, on a
  reliable base.

### 7. Hidden disagreement  ·  BUILT
- **Finds:** questions where the average looks calm but people are really two camps
  (lots of highs and lows, few in the middle) — the average hides it.
- **How:** measure how split each question's answers are (bimodality of the
  distribution).
- **Guard:** only flag clearly split distributions, not mild spread.

### 8. Direction reversal (Simpson's)  ·  LATER
- **Finds:** the overall moves one way while every subgroup moves the other —
  genuinely invisible by eye, usually important.
- **How:** compare the overall trend to the within-group trends.
- **Guard:** only when the reversal is consistent and material.

---

## The rules that stop false patterns ("never cry wolf")

These apply to every pattern above.

- **Size before certainty.** Rank by how big a difference is, not how
  statistically significant — significance alone, on a big base, flags trivia.
- **Materiality floors.** A change or gap below a set fraction of the scale is not
  reported (a 0.1 is not a move; a 2%-of-scale gap is not strain).
- **Reliable, coverage-aware bases.** A small group in a census is fine (it is most
  of its own population); a small group in a large sample is not. Bases are judged
  the right way for the study type.
- **Consistency.** A real pattern repeats — across the questions in a theme, or
  across related groups. A lone striking cell is treated as noise.
- **Correct for how much we looked at.**  ·  BUILT (FDR trust-gate). The more cells
  we check, the more will look surprising by luck. Single-cell claims must survive
  Benjamini-Hochberg correction across the whole grid (a variance-floored Welch test,
  so a homogeneous census cell can't fake significance); consistency claims (a group
  under strain, the split that matters) are judged by a per-group directional
  sign-test instead, because a genuinely consistent group can have no single
  significant cell. See [PATTERN_RECOGNITION_DESIGN.md](PATTERN_RECOGNITION_DESIGN.md) §A.
- **A confident null.** When nothing clears the bar, the page says so plainly
  ("no clear pattern stands out — and that's the headline"), rather than inventing
  something.

The page always shows its working: "no AI · scanned N breakouts and M questions ·
only what survives the tests."

---

## Presentation rules

- **Wrap, never ellipsis.** Question and group labels are shown in full and always
  wrap; they are never clipped to "…". A truncated label hides which question a
  pattern rests on, which is exactly the evidence the reader needs to trust it.
  Implemented by putting the label on its own line above the bar/value
  (`.tko-rl { white-space: normal; overflow-wrap: anywhere; }`), not in a fixed-
  width nowrap cell. Applies to every row in the tab.
- **One Read view.** The tab is a single scannable page (the "Present"/Wrapped
  sequence was removed — it added nothing over the Read view). The id stays
  `takeout`; the visible tab label is "Patterns".
- **Caption every number whose units aren't obvious.** E.g. the split card states
  that its rows are each group's average index across all rated questions, out of
  the scale maximum.

---

## Build order

1. ~~Add the "raise the bar by how much we looked at" rule (the FDR trust-gate).~~ **DONE**
2. ~~Which split matters most.~~ **DONE**
3. ~~Questions that move together.~~ **DONE**
4. ~~The odd one out.~~ **DONE**
5. ~~Hidden disagreement.~~ **DONE**
6. Direction reversal / Simpson's (later — needs wave-by-subgroup data).

Each shipped with known-answer tests and was verified against a real report engine
run (the `run_real_engine` harness on the live SACS crosstab report) before being
called done. Full statistical spec: [PATTERN_RECOGNITION_DESIGN.md](PATTERN_RECOGNITION_DESIGN.md).
