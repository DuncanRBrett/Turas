# Pattern recognition — advanced patterns, empirically-grounded design

Status: DESIGN · 2026-06-28 · branch `feature/tabs-executive-takeout`

Companion to [PATTERN_RECOGNITION.md](PATTERN_RECOGNITION.md). This file holds the
**implementation-ready statistical design** for the advanced patterns, every
number measured on the **real SACS-2025** data (n=167, 20 rated 5-pt questions
Q05–Q28, banners Campus/Department/Tenure) via the headless real-engine harness —
never reasoned. The two promises stand: *find what a question-by-question read
misses*, and *never cry wolf*.

The work was scoped by a multi-agent design pass that empirically probed the live
SACS islands. Two designs are complete and validated below; two probes did not
finish (session limit) and are flagged for a re-run.

---

## A. Multiple-comparison correction (FDR) — the cross-cutting anti-shadow gate

**Status: designed + validated; implement with an adversarial pass (it touches the
verified-good group/split behaviour).**

### What the real data showed
The implicit family on SACS is **380 cells** = 19 reportable breakout groups (each
with ≥ the census floor of 5 responses) × 20 rated questions. Multiplicity *is*
biting: a naive p<.05 scan lights up **41–42 of 380** cells when the global-null
expectation is **19.0** — roughly half the naive hits are plausibly noise.

But the dominant cry-wolf source here is **not** raw multiplicity — it is **tiny
homogeneous census cells**. "Registrars Office" has n=5 and all five answered "5"
on Q16 → zero within-group variance → Welch SE collapses → t=10.9 → **p=8.8e-21**,
the single top-ranked cell in the whole survey, a pure shadow. 60/380 cells sit on
bases of 5–9; 2 cells have literal zero variance.

### Design (decisive — no menu of options)
1. **Derive p-values in JS** (the R z-test letters expose no p-values): a
   **weighted Welch two-sample mean test**, group-vs-rest within each banner,
   Kish-weight-aware (SACS weights = 1 ⇒ reduces to the plain test). Source:
   `TR.MICRO.scores[q]` + `TR.MICRO.banner_vars[b]` + `TR.MICRO.weights`.
2. **Scale-aware variance floor** on every arm before the SE:
   `VARIANCE_FLOOR = (scaleRange * 0.1)^2` (= 0.25 on a 1–5 Likert; half a
   scale-point sd). *The single most important guard.* It drops Registrars/Q16
   from p=8.8e-21 to p=6.4e-3 and out of the survivor set, without weakening any
   real signal.
3. **Benjamini-Hochberg, NOT Benjamini-Yekutieli.** The empirical correlation
   structure is all-positive (190/190 pairs positive, mean r=0.38) ⇒ PRDS, the
   textbook condition under which BH controls FDR. BY's c(m)=6.52× penalty is
   unjustified over-correction (it crushes 4 real findings to 1).
4. **Do NOT put the FPC inside this test.** Applied to group-vs-rest mean tests it
   shrinks SEs toward zero as an arm nears its population, *manufacturing*
   significance (BH survivors balloon 4 → 89). FPC stays in the reporting-base /
   reliability layer only (deciding whether a base is reportable).
5. **Two guards for two pattern shapes** (the decisive architectural call):
   - **(a) Per-cell BH** on the 380-cell family → flags/ranks *single-striking-cell*
     claims (the odd-one-out) and badges evidence rows ("survives correction").
   - **(b) A directional-consistency test** — one sign-test / aggregate net-gap z
     **per group** (inherently multiplicity-safe) → gates the **group-under-strain**
     and **which-split** patterns, because those are about *consistency across
     cells*, not any one cell. This is what **preserves Cape Town**: it has **zero**
     individually-BH-significant cells, yet 18/20 questions below the rest gives a
     sign-test **p=2.0e-4**. Gating group on per-cell BH would *delete the
     verified-good baseline* — the key trap.

### Expected SACS result
Per-cell BH (variance-floored, no FPC) survivors = **4**: Head Office/Q11 (n=62,
diff +0.79, p=1.5e-5) and Less-than-a-year/Q13,Q25,Q28 (n~21, diff ~+0.62) — the
new-staff-thriving signal. Group/split unchanged (gated by the consistency test).

### Provenance / confident-null wording
> no AI · scanned N groups × M questions = K cells · corrected for multiplicity
> (Benjamini-Hochberg) · X stand-alone differences survive — the rest is
> consistency, not single cells.

When X=0 **and** no consistent group: *"nothing survives correction — and that's
the headline."*

### CONST additions
`VARIANCE_FLOOR_FRACTION = 0.1`, `FDR_ALPHA = 0.05`, `FDR_METHOD = "BH"`.

---

## B. Questions that move together  ·  IMPLEMENTING

**Status: designed + validated; building now (greenfield — no existing behaviour
at risk).**

### What the real data showed
The cry-wolf trap is real and severe. Across all **190 pairs** the mean inter-item
Pearson **r = 0.381**, with **zero** negative pairs (classic acquiescence /
common-method variance). The single-factor signature is overwhelming (mean
item-to-global-mean r = 0.641). **Naive thresholds collapse the survey:** r≥0.5
merges 16/20 questions into one bundle; r≥0.3 merges all 20. Naive significance is
just as useless — 178/190 pairs are p<.05 and **all 178 survive BH-FDR**, because
with this much shared variance virtually every pair is "real". *Multiplicity
correction on raw r does nothing; the problem is the global factor.*

### Design
1. **Pairwise-complete, weight-aware Pearson** over `TR.MICRO.scores` (support
   weights; SACS = 1).
2. **Control for the global factor** — the fix that works on this data. Form each
   respondent's overall mean across answered rated items (the global factor g) and
   take the **partial correlation**:
   `partial_r(a,b | g) = (r_ab − r_ag·r_bg) / sqrt((1−r_ag²)(1−r_bg²))`.
   This drops mean partial r to −0.050 and leaves only 62/190 positive.
3. **Three joint gates** to keep an edge:
   - **Strength** — `partial_r ≥ 0.20` **AND** the candidate bundle's within-bundle
     mean *raw* r is **above the live acquiescence floor** (the survey's own mean
     inter-item r, = 0.381 here). A bundle must cohere *above baseline*, not merely
     positively.
   - **Stability / multiplicity** — **BH-FDR at .05** across all C(k,2)=190 pairs,
     keeping only **positive** partial edges (18 survive); require a minimum
     pairwise base (≥30, comfortably met at ~150).
   - **Structure** — connected components on the surviving edges; report bundles of
     **≥2** questions, each annotated with within-bundle mean r vs the floor and its
     **anchor edge** (strongest, most stable) as headline evidence.
4. **Confident null** when no bundle clears floor + FDR.

### Expected SACS result (the known-answer pin)
**3 face-valid bundles** the method discovered from co-movement alone:
1. **Organisational-values perception** (9 Q): the six SACAP values Q18–Q23 +
   values-fit Q25 + mission Q12 + co-worker quality Q13. Within-bundle raw r = 0.49.
2. **Manager support / development** (Q08 recognition, Q10 encourages development,
   Q15 spoke about progress). r = 0.53.
3. **Role basics** (Q05 know what's expected, Q06 right materials). r = 0.46.

Anchor edges bootstrap-stable: Q18~Q19 100%, Q18~Q25 99%, Q19~Q23 95%, Q10~Q15 90%.

### Caption (shows the working)
> scanned 190 question pairs · controlled for the survey-wide tendency to agree ·
> only sub-groups that cohere beyond that baseline survive.

### CONST additions
`COMOVE_MIN_PARTIAL = 0.20`, `COMOVE_MIN_BASE = 30`, `COMOVE_ALPHA = 0.05`
(BH-FDR), `COMOVE_MIN_BUNDLE = 2`. The acquiescence floor is computed live, not a
constant.

---

## C. The odd one out  ·  PROBE INCOMPLETE

Design intent in [PATTERN_RECOGNITION.md](PATTERN_RECOGNITION.md) §6: a group that
breaks its OWN pattern — residual of its gap on a question vs its average gap,
large relative to the group's own spread, on a reliable base, corrected for the
(group × question) residuals scanned (ties into FDR guard (a) above). The empirical
probe did not finish (session limit). **Re-run the design workflow after the 12pm
reset** to ground thresholds and confirm whether SACS has a real odd-one-out or
warrants a confident null.

## D. Hidden disagreement (bimodality)  ·  PROBE INCOMPLETE

Design intent §7: Sarle's bimodality coefficient `b = (g²+1)/(k + 3(n−1)²/((n−2)(n−3)))`
plus a direct polarisation measure, flagging only questions whose **mean looks
calm** while the **distribution splits**. Probe did not finish. **Re-run after
reset.**

---

## Build order (revised)
1. **BH-FDR primitive** in the engine (pure, reusable) + variance-floored Welch
   p-values — small, testable, used by both B and A.
2. **Questions that move together** (B) — greenfield, highest "human-can't-see"
   value, validated.
3. **FDR gate + provenance** (A) — with an adversarial pass, since it touches
   group/split.
4. **Odd one out** (C) and **Hidden disagreement** (D) — after the workflow re-run.

Each ships with known-answer tests **and** a real-engine harness check before it is
called done.
