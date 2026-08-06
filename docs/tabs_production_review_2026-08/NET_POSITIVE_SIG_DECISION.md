# NET POSITIVE significance: the decision

**Decided:** 2026-08-06 (Fable, briefed with `NET_POSITIVE_SIG_QUESTION.md`
only, per that document's instruction).
**IMPLEMENTED:** 2026-08-06 (Opus, same session). Local `main`, **uncommitted
and unpushed** — Duncan verifies via `launch_turas()` and regenerates
deliverables himself.

All variance formulas below were derived by hand, not recalled, and the
straddling p-values are confirmed against base R's `pt()` inside the tests
rather than against the code under test.

## Decision: Option 3 — score the respondents, test the mean

Score each respondent +100 if in the top box, −100 if in the bottom box, 0
otherwise. The weighted mean of that score IS the printed NET POSITIVE, and the
existing `weighted_t_test_means()` path (weights, Kish effective n, FPC via
`fpc_mul1`/`fpc_mul2`, dual alpha, min-base gate — all already handled) tests
it directly.

## Why: Options 2 and 3 are the same test

This is the fact that settles it. For one column under the multinomial, with
`t = p_top`, `b = p_bottom`, `d = t − b`, `Cov(p_t, p_b) = −t·b/n`:

```
Var(d) = Var(p_t) + Var(p_b) − 2·Cov(p_t, p_b)
       = [ t(1−t) + b(1−b) + 2tb ] / n
       = [ t + b − (t − b)² ] / n            ... Option 2's formula (brief's
                                                 recalled version: confirmed)
```

Now the Option 3 score, X ∈ {+1, 0, −1} (the ×100 scaling cancels in a
t-statistic):

```
E[X]  = t − b = d
E[X²] = t + b
Var(X) = E[X²] − E[X]² = t + b − (t − b)²    ... identical numerator
```

So the score-mean's variance is *exactly* the correlated-difference variance —
the multinomial covariance the brief warns about is baked into the score
automatically. Option 2 would mean deriving, implementing, and maintaining a
new z-variant in **both** engines to produce numbers asymptotically identical
to what Option 3 gets by reusing an already-tested path. (Residual differences:
Option 3 uses the sample variance with n−1 and Welch df rather than the plug-in
z — the same trade already accepted for NPS.) Option 2 loses on engineering,
not statistics.

Option 1 loses because Job I-stats already committed the platform's answer for
NPS: a net row's letters test the printed net. A report carrying both an NPS
row (letters test the net) and a NET POSITIVE row (letters test the top box)
has two rows of the same kind whose letters mean different things, and the
brief's two failure modes are ordinary data, not corner cases. A footnote can
label the inconsistency; it can't remove it.

The M-B zero-variance trap (every respondent in one box → no letter) is **not**
a differentiator: under Option 2, a column with t=1, b=0 gives
Var = (1 + 0 − 1)/n = 0 — the same degeneracy. It is inherent to testing the
net and stays with open finding M-B.

## Worked example (calculator-checkable, n = 100 per column, unweighted)

**Brief's false-negative case** — A: top 60%, bottom 10% (NET +50);
B: top 60%, bottom 40% (NET +20).

- Today: z-test of 0.60 vs 0.60 → z = 0. Thirty printed points apart, never a
  letter.
- Decided test: Var_A = (0.6 + 0.1 − 0.5²)/100 = 0.0045;
  Var_B = (0.6 + 0.4 − 0.2²)/100 = 0.0096;
  SE = √0.0141 ≈ 0.11874; z = 0.30 / 0.11874 ≈ **2.53**, two-sided
  p ≈ 0.011 → letters at α = 0.05. (The t-statistic matches to the shown
  precision at these bases.)

**Brief's false-positive case** — A: top 60%, bottom 30% (+30);
B: top 45%, bottom 15% (+30).

- Today: z-test of 0.60 vs 0.45: SE = √(0.6·0.4/100 + 0.45·0.55/100)
  ≈ 0.07053; z ≈ **2.13**, p ≈ 0.033 → draws a letter under a pair of
  identical printed values.
- Decided test: difference of nets = 0 → z = 0 → no letter.

Both published-letter changes are in the direction a reader would call a
correction.

## Declaration line (new entry, added when `show_net_positive` is on)

Modeled on the `NPS significance` entry at `stats_diagnostics.R:148`:

> **NET POSITIVE significance:** Tested on a per-respondent net score (+100
> top box, −100 bottom box, 0 otherwise), whose weighted mean is the published
> NET POSITIVE. Letters therefore answer 'do these nets differ', not 'do the
> top boxes differ'.

## v2 JS engine: yes, in the same change

`21_stats.js` / `22_model.js` must move NET POSITIVE letters to the same
score-mean t-test in the same commit, or the two engines letter the same table
differently. Gate it exactly as Job I-stats gated NPS: extend the parity
fixture (`show_net_positive = "TRUE"`, a question with both BoxCategories — Q4
is the worked example of how) so `test_cross_engine_stats.R` +
`parity_stats_tests.mjs` cover the row.

## Implementation notes for the executing session (an Opus session is fine —
the statistics above are settled; what remains is careful plumbing)

1. Test first, prove it fails by revert-run-restore (house rule). The failing
   test: the false-negative pair above must letter, the false-positive pair
   must not.
2. Reuse `nps_bucket_score`'s shape: NET POSITIVE's box membership already
   flows through `score_utils.R` (`derive_net_diffs`, box-category
   favourability ordering) — score +100/−100/0 off the same box definitions
   the printed row uses, including multi-category boxes (Top 2 / Bottom 2:
   any category in the box carries the box's score).
3. ~~Respondents outside the base (NA on the question) stay NA in the score, as
   NPS does~~ — **wrong, corrected during implementation.** A non-answerer
   scores **0**, not NA. NPS can drop NAs because its published value is
   percentaged on the answered base; the NET POSITIVE row divides by the
   column's base-filtered base, so dropping non-answerers would test a
   different number from the one printed. See "What was built" below.
4. `add_net_positive_significance()` and its `run_net_difference_tests()` call
   are replaced by the means path; `add_net_significance_rows()` (the Top/
   Bottom Box rows themselves) is correct and untouched.
5. Full-census columns: `fpc_mul = Inf` → excluded from pairing, same as
   everywhere else post-I-stats.
6. Diff the parity fixture before/after and record the letter changes in the
   handover; add the Declaration line above; note the behaviour change in the
   stats pack the way I-stats did for NPS.
7. Baseline to hold: tabs R 4,160/0/0/0, 29 JS suites, root suite 571/3
   (documented non-tabs failures).

---

## What was built (verified this session)

| Piece | Where |
|---|---|
| `net_positive_scores()` — the +100/−100/0 per-respondent score | `modules/tabs/lib/score_utils.R` (beside `nps_bucket_score`) |
| `add_net_positive_significance()` rewritten onto the means path | `modules/tabs/lib/standard_processor.R` |
| Declaration line, emitted only when `show_net_positive` is on | `modules/tabs/lib/stats_diagnostics.R` |
| `stats.netScoreMeans()` + NET POSITIVE letters on the computed path | `assets/js/21_stats.js`, `22_model.js` |
| Q5, the fixture's NET POSITIVE question | `tests/fixtures/parity_project/generate_parity_project.R` |
| Unit tests (34) | `tests/testthat/test_net_positive_significance.R` |
| Parity gate R-6 / JS-5 | `test_cross_engine_stats.R`, `parity_stats_tests.mjs` |

The significance function now hands per-column `values`/`weights` to
`add_significance_row(..., "mean", ...)` — the same wrapper every other mean row
in the report goes through — so the Kish effective base, the FPC (including the
`Inf` census exclusion), the min-base gate, the per-group Bonferroni divisor and
dual alpha are all inherited rather than reimplemented. `run_net_difference_tests()`
is untouched and still serves the Top/Bottom Box rows, which are genuine column
proportions.

**One decision worth knowing about:** the score covers EVERY row in the column,
including respondents who did not answer — they score 0. The published row
divides by the column's base (base-filtered, not answered-base), so the score
has to share that denominator or the tested quantity would not be the printed
one. A test pins `mean(score) == printed net` in every column.

## What it did to letters on the parity fixture

Q5 was added to the fixture to carry a NET POSITIVE row (the fixture had none —
`show_net_positive` was `"FALSE"` and no question declared two boxes). Its
distribution puts both failure modes on one table:

| Column | n | top | bottom | top% | bottom% | NET |
|---|---|---|---|---|---|---|
| Alpha (census) | 40 | 16 | 8 | 40% | 20% | +20 |
| Beta | 60 | 12 | 0 | 20% | 0% | +20 |
| Gamma | 50 | 30 | 20 | 60% | 40% | +20 |
| Delta | 50 | 10 | 40 | 20% | 80% | −60 |

Captured by regenerating the island against the pre-fix engine and again against
the new one (revert-run-restore), unweighted and weighted alike:

```
before   Total .   Alpha .   Beta .    Gamma BD   Delta .
after    Total .   Alpha .   Beta D    Gamma D    Delta .
```

- **Gamma loses "B".** Gamma and Beta print the identical +20; the old test
  lettered Gamma over Beta on a 60%-vs-20% top-box gap. A letter under two
  identical printed numbers.
- **Beta gains "D".** Beta and Delta have the identical 20% top box, so the old
  test saw z = 0 and could never letter them — while the page showed +20 against
  −60. New t = 6.598.
- Gamma keeps "D" (t = 4.427), and Alpha, the census column, letters nothing
  either way.

Both changes are corrections a reader would want. Any live report with a NET
POSITIVE row will move in the same two ways.

## Suites (run this session)

| Suite | Result |
|---|---|
| tabs R (`modules/tabs/tests/testthat`) | **4,274 / 0 / 0 / 0** (baseline 4,160 + 114 new) |
| JS, all 29 suites | **all green**, 0 failing |
| project root (`tests/testthat`) | **571 pass / 3 fail** — the documented non-tabs baseline, unchanged |

The new unit tests were written first and shown to fail against the pre-fix
engine (`B's NET POSITIVE cell must not letter against A, got 'AC'`).

## Not done

- The v2 **computed** path (filters / custom banners) previously showed NO
  letters at all on a NET POSITIVE row; it now scores and letters them. The
  published path carries R's letters as before. One caveat inherited, not
  introduced: `boxCounts()` uses the ANSWERED base where R uses the
  base-filtered column base, so a question with non-answerers can print a
  slightly different net under a filter than in the published table. That
  predates this work and is untouched.
- The Rao–Scott chi-square question (`NET_POSITIVE_SIG_QUESTION.md` §"Related")
  is deliberately still open.
