# Pattern recognition — advanced patterns, empirically-grounded design

Status: **ALL BUILT** · 2026-06-28 · branch `feature/tabs-executive-takeout`

Companion to [PATTERN_RECOGNITION.md](PATTERN_RECOGNITION.md). This file holds the
**statistical design** for the advanced patterns, every number measured on the
**real SACS-2025** data (n=167, 20 rated 5-pt questions Q05–Q28, banners
Campus/Department/Tenure) via the headless real-engine harness — never reasoned.
The two promises stand: *find what a question-by-question read misses*, and *never
cry wolf*. Each pattern was designed by a multi-agent pass (empirical probe → three
independent design lenses → judge → adversarial verification → synthesis) and is
backed by known-answer tests + a real-engine harness check.

## As-built summary

| Pattern | Commit | Result on real SACS |
|---|---|---|
| Which split matters most | `6346e42f` | Campus (Durban 4.39 / Cape Town 3.70) |
| Questions that move together | `5dddd312` | 3 bundles (values battery / manager-support / role-basics) above the 0.38 acquiescence floor |
| FDR multiple-comparison trust-gate | `855e2eac` | 380 cells scanned; **4** badged (Head Office/Q11, new-staff Q13/Q25/Q28); Cape Town kept via the sign-test (signP 4e-4) |
| The odd one out | `49dbc028` | **confident null** — 0 of 380 (every striking cell is a same-direction extreme) |
| Hidden disagreement (bimodality) | `49dbc028` | **confident null** — 0 of 20 (every distribution single-peaked) |

The confident nulls are a feature, not a gap: each renders a compact "we checked,
nothing real" card that shows its working — the visible never-cry-wolf proof.
**Still later:** Direction reversal / Simpson's (needs wave × subgroup data).

The fully reconciled, as-built statistical spec (the synthesis the multi-agent pass
produced, with every adversarial fix folded in) is preserved verbatim in the
**Appendix** at the foot of this file. The sections below are the original
empirically-grounded design notes, kept for the measured numbers.

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


---

# Appendix — as-built statistical spec (multi-agent synthesis, adversarial fixes folded in)

# Pattern Recognition v2 — Implementation Spec: FDR Trust-Gate, Odd-One-Out, Hidden Disagreement

**Status:** all three families survived adversarial verification. Required fixes from the verdicts are folded in below and marked **[FIX]**. Everything is deterministic, no-AI, reproduces exactly on re-run, and reuses the shipped primitives (`_normalCdf`, `_partialCorr`, `_corrPValue`, `_bhFDR`). Co-movement is untouched.

**Build order (load-bearing):** FDR family `gatherCellFamily` → FDR gate → odd-one-out (consumes the *same* family object). Bimodality is independent and greenfield. **One** Welch computation and **one** per-cell BH pass are shared between FDR gate-A and odd-one-out — never two families.

**Page order (unchanged spine, two inserts):**
`apex → group (now gated) → split (now gated) → comove → ODD → weak/strong area → moved → BIMODAL? → provenance (FDR-stamped)`

Bimodality sits with the within-question diagnostic reads. Per the design it is inserted **after comove and before areaPatterns** in `buildPatterns`; in the read view it renders after the area cards. Either placement is acceptable since it is additive; the engine push position (after comove) is what is pinned by tests.

---

## Family 1 — FDR multiple-comparison trust-gate (cross-cutting)

### Purpose (the human-missed insight)
Two distinct things a question-by-question reader gets wrong, fixed by two distinct guards:
- **Single striking cells lie.** Scanning 19 groups × 20 questions = 380 cells, ~19 will clear p<.05 by chance; the loudest cell on real SACS (Registrars Office n=5, all answered "5" on Q16, t=10.9, p=8.8e-21) is a zero-variance census artefact, not a finding. **Guard A** (per-cell variance-floored Welch Student-t, BH-corrected) ranks/badges single-cell claims and seeds odd-one-out.
- **Consistency is invisible to per-cell tests.** Cape Town (the verified-good strain group) is below on 18/20 questions yet has **zero** individually-significant cells. **Guard B** (per-group directional sign-test, BH-corrected across groups) is what proves Cape Town is genuinely consistent and gates the group/split patterns. **Gate on B's set D, never on A's per-cell set S** — that is the Cape-Town-safe contract.

This is not a card. It badges, gates, and supplies the provenance / confident-null line. It never re-orders or deletes the verified-good baseline.

### Formula, estimator, decision rule

**New pure fns in 27e** (all reuse `_bhFDR`; add a Student-t tail):

`_studentT(t, df)` — two-sided Student-t tail = `I_{df/(df+t²)}(df/2, 1/2)` via regularised incomplete beta (Lentz continued fraction + log-gamma).
- **[FIX, required] Guard non-finite t → return 1** (not 0). A degenerate SE yielding NaN t must give p=1, never p=0. Order of guards: `if (!isFinite(t)) return 1; if (df <= 0) return 1;` then clamp `|t|` to a large finite bound (e.g. 1e6) before the beta call.
- Known-answers (pinned): `_studentT(3,50)≈0.00420`, `_studentT(3,5)≈0.0301`, `_studentT(0,10)=1.0`, `df≤0→1`.

`_welchTest({gx, gw, rx, rw, vfloor})` → `{diff, t, df, p, nG, nR, flooredG}`:
- Weighted moments per arm: `sw=Σw; mean=Σw·x/sw; ss=Σw·(x−mean)²`; Kish `n_eff=(Σw)²/Σ(w²)` (=n at w=1).
- Weighted variance `var = (ss/sw)·(n_eff/(n_eff−1))`.
- Variance floor `vfloor=(R·VARIANCE_FLOOR_FRACTION)²` where `R`= scale **span** `= scaleMax − scaleMin` (=4 on 1..5 ⇒ vfloor=0.16). `vG=max(var_g,vfloor); vR=max(var_r,vfloor); flooredG=(var_g<vfloor)`.
- `SE=sqrt(vG/n_effG + vR/n_effR); diff=mean_g−mean_r; t=diff/SE`.
- Welch–Satterthwaite `df = (vG/n_effG + vR/n_effR)² / [ (vG/n_effG)²/(n_effG−1) + (vR/n_effR)²/(n_effR−1) ]`.
- `p = _studentT(t, df)`. **The Student-t tail is load-bearing, not the floor alone:** under `2·_normalCdf(−|t|)` the homogeneous Registrars/Q16 cell stays a BH survivor (8–9 survivors); under `_studentT` BH returns exactly 4.
- **[FIX, required]** Caller must enforce `nG≥CENSUS_FLOOR` and `nR≥CENSUS_FLOOR` (CENSUS_FLOOR=5≥2) **before** calling, so an n=1 arm (df=0) is never passed; `df≤0→p=1` is a backstop, not the primary guard.

`_signTest(below, above)` → `{p, k, n, dir}`:
- `n=below+above` (exact ties excluded); `k=min(below,above)`.
- Two-sided exact binomial at p=0.5: `p=min(1, 2·Σ_{i=0..k} C(n,i)·0.5ⁿ)` using log-gamma for `C(n,i)` (numerical safety; ~20 terms).
- `dir = below>above ? 'below' : 'above'`.
- Known-answers (pinned): `_signTest(18,2)=4.02e-4`, `_signTest(2,18)=4.02e-4`, `_signTest(13,7)=0.263`, `_signTest(10,10)=1.000`, `_signTest(19,1)=4.0e-5`.

`_fdrGate(fdr, opts)` — consumes the shared family object built by `gatherCellFamily` (§ data source) and returns the `fdr` output object:
- **Layer A (per-cell):** `bhAll = _bhFDR(cells.map(c=>c.welchP), FDR_ALPHA)` → full keep set (seeds odd-one-out). `badge = bhAll ∩ {nG ≥ BADGE_MIN_BASE} ∩ {!flooredG}`. On SACS badge == bhAll (all 4 survivors nG≥12, unfloored) — belt-and-braces guarantees a tiny/homogeneous cell can never earn the chip on a future dataset.
- **Layer B (per-group):** for each reportable group, `_signTest(below, above)` over the rated Qs using the *same unfloored* `diff` signs; `signGate = _bhFDR(signPs, SIGN_ALPHA)` → survivor set **D**. A group is "genuinely consistent" iff `g ∈ D`.

**No FPC in either statistic.** Verified: FPC-in-the-SE balloons BH survivors (4 → far more). FPC stays in the reliability layer only.

**Correction = BH, not BY.** Inter-item r all-positive (190/190, mean 0.38 ⇒ PRDS), so BH controls FDR; BY's ~6.5× penalty crushes the 4 real findings to ~1.

### Data source

`gatherCellFamily(views)` (new, in 27f) builds the **one** shared family:
- Reportable groups = `TR.AGG.banner_groups` `[{id,name}]` × distinct positive `TR.MICRO.banner_vars[bid]` codes whose arm n ≥ CENSUS_FLOOR. SACS = 19 groups.
- **Code→label join (verified):** `banner_vars` hold survey **option values**, not positions. Sort the distinct non-negative codes ASCENDING and align positionally to `views._modelFor(qcode, bid).columns.slice(1)` (non-Total columns).
- **[FIX, required]** Assert `count(distinct positive codes) === columns.length − 1` (a label-count/order check). On mismatch, **skip that banner** (degrade, console TRS-style note) — never mislabel. Do **NOT** assert base-equality: model base is per-question non-null while micro code-count is raw group size (3 off-by-one cases exist on SACS: Head Office 63/62, Operations 20/19, 5y+ 43/42). Use a tolerance check `|nIn − column.base| ≤ 2` only as a secondary sanity-skip on individual cells.
- Per (group × rated qcode with `TR.MICRO.scores`): build arms from `scores[q]` split by `banner_vars[bid]===code`, dropping null score **or** code<0 on both arms; `weights` from `TR.MICRO.weights` (SACS=1). Run `_welchTest` (NO FPC). Carry `nIn`, `diff`, `flooredG`, `welchP`, and the title (via `views.indexQuestions()`).
- Composites (`Q_*` with no `scores` key) carry no per-respondent vector → excluded. Family = 20 rated Qs × 19 groups = **380** testable cells.
- Scale span `R` per question from the index scale (`touchpointMax(q) − scaleMin`, =4 here). CENSUS_FLOOR = `project.min_report_base || MIN_CENSUS_BASE(5)`.
- Return `{ cells:[...], groups:[{banner,group,base,below,above,qn,netGap,signP,dir}], K, groupCount, questionCount, floor }`. Wrap in try/catch → null (no microdata).

### Guard thresholds (CONST additions in 27e)
```
VARIANCE_FLOOR_FRACTION = 0.1   // sd floor at 10% of scale SPAN; (span·0.1)² = 0.16 on 1..5
FDR_ALPHA              = 0.05   // BH level, both families
FDR_METHOD             = 'BH'   // PRDS-justified; NOT Benjamini-Yekutieli
BADGE_MIN_BASE         = 12     // a cell earns 'survives correction' only on group arm ≥12
SIGN_ALPHA             = 0.05   // BH level for the per-group sign-test family (gates group/split)
SPLIT_MIN_CONSISTENT   = 2      // winning banner must contain ≥2 sign-test-consistent groups
// CENSUS_FLOOR reused from 27f's MIN_CENSUS_BASE(5) / project.min_report_base
// Badge not-floored rule: drop any BH survivor whose GROUP arm was variance-floored (no constant)
```
**[FIX, doc]** SPLIT_MIN_CONSISTENT=2 is an additive **veto floor**, not a selector — on SACS all three banners clear it, so banner choice still rests on the existing `SPLIT_LEAD_RATIO=1.25` on directional spread. Document this so the next implementer is not surprised.

**[FIX, doc]** The sign-test treats questions as independent Bernoulli; positive inter-item r (0.38) makes the true null variance larger than np(1−p), so signP is mildly anti-conservative. Safe here — it is a relative BH-gated rank and SACS margins (4e-4) are far from the boundary. Flag in a code comment.

Reuse unchanged: `STRAIN_RELIABLE_BASE=30`, `MIN_GROUP_HITS=2`, `MIN_STRAIN_GAP=0.02`, `MIN_SPLIT_DIFF=0.02`, `SPLIT_LEAD_RATIO=1.25`. The gate is an **additive veto** layered on these existing selectors.

### Emitted object + wiring (the two-guard wiring that preserves Cape Town)
`buildPatterns` attaches a provenance object (not a card):
```
result.fdr = {
  kind:'fdr', K:380, groupCount:19, questionCount:20, alpha:0.05, method:'BH', floor:0.16,
  badge:{ count, cells:[{banner,group,q,qtitle,nG,diff,p}] },   // strict survivors
  bhAll:[...same shape...],                                      // full BH-keep (seeds odd-one-out)
  groups:[{banner,group,base,below,above,qn,netGap,signP,dir,consistent}],
  cellSurvivorCount, dirSurvivorCount
}
```
In `buildPatterns`, after computing `group`/`split` but **gating on `gate.groups` (set D), NEVER on `gate.badge`/`bhAll`**:
- `group.consistent = (subject group ∈ D AND dir==='below')`; **only push `group` when `consistent`**.
- `split.consistent = (top banner has ≥SPLIT_MIN_CONSISTENT groups ∈ D AND existing lead/diff tests pass)`; **only push `split` when `consistent`**.
- Each group-evidence row: `evidence[i].survives = ((group,q) ∈ gate.badge)` → renders a text+colour "survives correction" chip (never colour alone).
- **When `inputs.fdr` is null (no microdata): SKIP the gate entirely**; group/split fall back to today's `MIN_GROUP_HITS`/`MIN_SPLIT_DIFF` behaviour unchanged.

### Cry-wolf gate
On a structureless study **both guards fall silent together**. Verified on synthetic independent-uniform-Likert null (160 resp, 19 groups, 20 Qs, 20 seeds): per-cell BH survivors avg 0.15 (FDR-controlled), badged avg 0.10, per-group sign-test survivors (D) = **0.00 across all 20 seeds**. So on noise `badge.count→0` AND no consistent group ⇒ the page prints the confident-null line deterministically. (Permuting real SACS vectors is NOT a valid null — it preserves acquiescence; the synthetic independent generator is the correct probe.)

### Expected real-SACS result (measured)
- K = 380; 60/380 on bases 5–9; 2 arms zero-variance. Naive p<.05 = 41–42 (vs global-null 19.0).
- **Variance-floored Welch Student-t BH = exactly 4**, badged = same 4 (all nG≥12, unfloored):
  - Head Office / Q11 (n=62, +0.79, p=1.5e-5)
  - Less-than-a-year / Q13 (n=21, +0.61, p=3.2e-5), Q25 (n=21, +0.62, p=1.1e-4), Q28 (n=20, +0.63, p=2.7e-4) — the new-staff-thriving signal.
  - Registrars/Q16,Q12 (n=5) and Finance/Q14 (n=10) correctly drop out (t-tail demotes below BH line).
- **Sign-test preserves the baseline:** Cape Town 18/20 below ⇒ signP=4.0e-4 (∈ D, consistent) with **0 per-cell BH survivors**. Campus split: Head Office/Cape Town/Durban/Online all ∈ D and Campus leads on directional spread ⇒ Campus stays the winning split.
- Provenance: `"no AI · scanned 19 groups × 20 questions = 380 cells · corrected for multiplicity (Benjamini-Hochberg) · 4 stand-alone differences survive — the rest is consistency, not single cells."` When badge.count=0 and no consistent group: `"nothing survives correction — and that's the headline."`

### Test cases (known-answer + null)
- `_studentT(3,50)≈0.0042`; `_studentT(3,5)≈0.030`; `_studentT(0,10)=1.0`; `df≤0→1`; **non-finite t → 1** (regression guard for the NaN trap).
- Welch known-answer: group 4.0/var .64/n20 vs rest 3.4/var 1.0/n130, floor .16 → t≈3.01, se≈0.199, df≈26, p≈0.0057.
- Variance-floor + t-tail shadow-kill: five 5's (var 0→.16) vs rest 3.97/var~.6/n149 → df≈6.5, t≈5.1, p≈1.7e-3; `flooredG=true` ⇒ badge-excluded.
- **Normal-vs-t contrast (regression guard):** same Registrars/Q16 arms → `2·_normalCdf(−|t|)`≈2e-5 (would survive BH) vs `_studentT`≈1.7e-3 (out). Asserts the t-tail is load-bearing.
- `_signTest`: (18,2)→4.02e-4; (2,18)→4.02e-4; (13,7)→0.263; (10,10)→1.000; (19,1)→4.0e-5.
- `_bhFDR([.001,.008,.039,.041,.9],.05)→{0,1}`; all-null `[.4,.5,.6,.7,.8]→[]` ⇒ confident-null path.
- Badge guard on real SACS: BH-keep 4 → badge 4; labels golden = {Head Office/Q11, Less-than-a-year/Q13,Q25,Q28}.
- **Cape Town gate:** groupPattern sets subject='Cape Town Campus', consistent=true (∈ D), evidence rows carry `survives=false` (0 per-cell survivors) — proves consistency-gating keeps it.
- Census-floor: arm n=4 produces NO cell, excluded from that group's sign-test qn.
- Code→label join: Department distinct codes sorted [7..19] align to non-Total columns; assert `count===columns.length−1` or skip-and-warn.
- **NULL (synthetic, seeded):** 160×19×20 independent uniform-Likert → per-cell BH survivors ≤1 avg AND sign-test survivors=0 → badge.count 0 + no consistent group → confident-null line.

### Integration per file
- **27e:** add `_studentT`, `_welchTest`, `_signTest`, `_fdrGate`; CONST above. In `buildPatterns`: `if (inputs.fdr) { var gate=_fdrGate(inputs.fdr); result.fdr=gate; }` then gate group/split on `gate.groups` (D) and tag evidence `.survives` from `gate.badge`. Expose `takeout._fdrGate`, `takeout._studentT`, `takeout._welchTest`, `takeout._signTest`.
- **27f:** add `gatherCellFamily(views)`; wire into `gather()` as `inputs.fdr` (try/catch→null).
- **27g:** add `ui.survivesChip(on)` → `'<span class="tko-badge tko-survives">survives correction</span>'`; extend `ui.groupRow` to append when `e.survives`.
- **27h:** `provHtml(t)` reads `t.fdr` for the live K/groupCount/badge.count line; when `t.fdr && t.fdr.badge.count===0 && no consistent group`, render `"nothing survives correction — and that's the headline."`. Page order unchanged; provenance now FDR-stamped. FPC stays in `21c_confidence` reliabilityRibbon — explicitly NOT inside `gatherCellFamily`.

---

## Family 2 — The odd one out

### Purpose (the human-missed insight)
A breakout group that is LOW (or HIGH) on almost everything yet **unexpectedly the reverse on one question** — a sign-flip against the group's own direction; the exception worth explaining. This is distinct from "group under strain" (the group's general *level*) and from a same-direction extreme (its strongest point in the *same* direction, already implied by the strain/thriving signal). On SACS it returns a **confident null**.

### Formula, estimator, decision rule
Per group g (each reportable column from `gatherColumnStrain`) with gaps `gap_q = value_q − total_q` across its k rated questions:
- `meanGap_g = mean_q(gap_q)` [direction]; `dir_g = sign(meanGap_g)`; `sdGap_g = popSD_q(gap_q)` **[DISPLAY/RANK ONLY — never a gate]**.

A cell (g,q) is an odd-one-out candidate iff **ALL**:
1. **Sign-flip:** `gap_q ≠ 0 AND sign(gap_q) ≠ dir_g`.
2a. **Absolute materiality:** `|gap_q| ≥ ODD_MIN_GAP` (0.20 scale pts).
2b. **Residual materiality:** `|gap_q − meanGap_g| ≥ ODD_MIN_RESID` (0.30 scale pts). Required to reject gap-vs-total contamination (one extreme group drags the total, flipping others slightly); verified to reject all contamination flips while keeping a planted break.
3. **Respondent significance** via the **shared** variance-floored weighted Welch from FDR gate-A (`_welchTest`, NO FPC) AND sign-consistency `sign(welchDiff) === sign(gap_q)` (drops base-composition reversals, e.g. Pretoria gap +0.35 but Welch −0.66).
4. **Survives** the **single shared** per-cell BH-FDR pass (`fdr.survivors`) — do NOT build a second family.
5. **Test-arm base floor** `nIn ≥ ODD_MIN_TEST_BASE` (8) — soft belt-and-braces so a flip cannot rest on a 5–7-person homogeneous census cell; deliberately NOT the n≥30 sample frame.

Rank survivors by `|resid|` (display); emit the largest as THE odd one out, with up to `EVIDENCE_MAX` runner-ups. Return a typed null marker when none survive.

**[FIX, required] Use the Welch-Satterthwaite Student-t p (`_studentT`), not `2·_normalCdf(−|t|)`.** The shared family must be identical to FDR gate-A's; the t-distribution yields the 4 BH survivors gate-A predicts (the normal-approx gives 10 and is anti-conservative on small bases). The SACS odd-null is invariant (0 flip survivors either way), so zero downside.

**[FIX, doc] Strike "gaps read from `row.cells[i].mean` at full precision."** Agg `cell.mean` is rounded to 2dp (4.47 vs micro 4.468). Immaterial to the 0.20/0.30 thresholds, and the Welch uses full-precision micro — but state that gaps come from the rounded display means and that this is acceptable given the threshold margins.

**[FIX, doc/impl] `meanGap`/`dir`:** compute as `mean(gap/scaleMax)` to match `groupPattern`'s normalization (it uses `gap/scaleMax`), OR document that odd-one-out assumes a single `scaleMax` per banner and guard accordingly. On SACS (uniform scaleMax=5) the two agree in sign; for a mixed-scale banner they could disagree.

### Data source
- `gatherColumnStrain(views)` → per-column gaps (census floor 5 already applied) for `meanGap`/`dir`/`resid`/flip detection.
- The shared **`gatherCellFamily`** object (§ Family 1) supplies `welchDiff/welchP/nIn/flooredG` per (column × rated qcode) and the BH survivor set. **Exactly one Welch computation, one BH pass** shared with FDR gate-A. Build order: `gatherCellFamily` → `oddOnePattern`.
- **[FIX, impl]** Gaps carry **title only**, not qcode — add the explicit title→qcode join via `views.indexQuestions()` in 27f so each gap maps to a `scores` vector. Composites (2 cells) lack scores → in the 418-cell display scan but not the 380-cell FDR family; add a one-line comment so a future reader doesn't "fix" the 418-vs-380 discrepancy.
- Positional column-label→banner-code join as in Family 1, with the same `count===columns.length−1` assert and per-cell `|nIn − column.base| ≤ 2` sanity-skip (set `welchP=null` on mismatch rather than mis-attribute).
- FPC kept OUT of the Welch; stays in the reliability layer.

### Guard thresholds (CONST additions in 27e)
```
ODD_MIN_GAP        = 0.20   // |gap| floor, scale pts (~5% of 4-pt range)
ODD_MIN_RESID      = 0.30   // |gap − meanGap| floor (break from the group's OWN pattern)
ODD_MIN_TEST_BASE  = 8      // soft nIn floor (census-aware; NOT the n≥30 sample frame)
ODD_RANK_BY        = 'resid'// own-SD z for DISPLAY only, NEVER a gate (ceilings at (k-1)/√k=4.48)
// reuses VARIANCE_FLOOR_FRACTION, FDR_ALPHA, FDR_METHOD from FDR gate-A
```

### Emitted object + takeaway/badge
Firing pattern (pushed only when a survivor exists):
```
{ id:'odd', kind:'odd', subject:<column label>, group:<banner name>, column:<column label>,
  flip:{ qcode, title, gap, meanGap, resid, z, value, total, welchDiff, welchP, nIn, scaleMax },
  direction:(meanGap<0 ? 'low-but-high' : 'high-but-low'),
  secondary:[ up to EVIDENCE_MAX runner-up flips ],
  evidence:[ exception row (groupRow shape, isMean:true) + 2–3 same-direction context rows ],
  familyCells:380, survivors:<count> }
```
Confident-null marker (the SACS case): `{ id:'odd', kind:'odd', nullResult:true, familyCells:380, survivors:0 }`.

`PATTERN_META.odd = { tag:'The odd one out', cls:'odd' }`.

**Takeaway (firing):** `"<Group> runs <below|above> the overall almost everywhere — yet on '<title>' it is unexpectedly <higher|lower> (<value> vs <total>, +<gap> against its usual <meanGap>)."` Badge on a surviving flip: `"exception · survives multiplicity correction"`.

**Confident-null line (SACS):** `"No group breaks its own pattern — every exception is either too small to matter or sits on a census cell too thin to trust."` Caption: `"scanned 19 groups × 20 rated questions = 380 cells · corrected for multiplicity (Benjamini-Hochberg) · an exception must oppose the group's own direction, clear 0.30 scale points, and survive correction · 0 survive."`

### Cry-wolf gate
A cell must be a sign-flip against `meanGap` direction AND survive BH over the shared 380-cell family. Verified: of the per-cell BH survivors on SACS, **zero are flips** (all same-direction extremes — Head Office/Q11 meanGap +0.14 is its strongest *same*-direction point; Less-than-a-year survivors all upward; Registrars n=5 same-direction). The flip∩BH intersection is empty *before* materiality. Adding materiality + welch sign-consistency + nIn≥8 hardens it: 89–92 sign-flips exist, the largest material (Cape Town +0.22 on co-workers-committed, resid +0.57) is Welch p=0.258 (noise), every material flip sits on base<30. SACS survivor count = **0 across the full grid `resid∈{0.20,0.25,0.30,0.40} × nIn∈{0,8,30}`**. The detector is alive: planted synthetic flip (n=40, gap +0.60, resid +1.08) → exactly 1 ODD survivor, p≈1.7e-24, in BH; 9–13 contamination flips all rejected by `ODD_MIN_RESID=0.30`.

### Expected real-SACS result
**Confident null** — `oddOnePattern` returns the typed null marker; no firing `{id:'odd'}`. Naive own-SD `|z|≥2` would fire ~18–20 cells (incl. Q11 #1-dispersion double-counted across 4 groups); the guarded detector flags none. Does NOT promote Head Office/Q11 (same-direction extreme) nor any tiny-cell flip.

### Test cases
- **NULL (real SACS):** `oddOnePattern(columns, fdr) → {nullResult:true, familyCells:380, survivors:0}`; assert no firing `id==='odd'` and read view contains "No group breaks its own pattern". (0 survivors across resid{0.20–0.40} × base{0,8,30}.)
- **Synthetic positive:** group 'Odd' n=40 low (meanGap −0.39) on 19 Qs, planted high (4.85) on Q20 → gap +0.63, resid +1.02, Welch p≈1.3e-17, survives BH, nIn=40 → exactly ONE survivor {column:'Odd', q:Q20}; contamination flips (|resid|<0.30) rejected.
- **Divisive-question rejection:** Head Office/Q11 (gap +0.47, meanGap +0.14, same sign) → rejected by gate (1).
- **Tight-spread rejection:** sdGap=0.08, own-SD z=2.9 but |gap|=0.15<0.20 → rejected by gate (2a).
- **Residual-gate unit:** gap −0.22, meanGap +0.02 (flip, |gap|≥0.20) but |resid|=0.24<0.30 → rejected by (2b).
- **Tiny-census rejection:** flip |resid|=0.80 on nIn=5, Welch p≈0.37 → rejected by (5) AND (3).
- **Base-composition reversal:** gap +0.35 but welchDiff −0.66 → rejected by sign-consistency.
- **Primitives:** `_bhFDR([0.001,0.2,0.5,0.9],0.05)→[0]`; both-arms-constant Welch returns finite p via the 0.16 floor, never Inf/NaN.
- **Degenerate:** `columns=[]` or no MICRO → typed null, no crash.

### Integration per file
- **27e:** CONST `ODD_MIN_GAP=0.20`, `ODD_MIN_RESID=0.30`, `ODD_MIN_TEST_BASE=8` (reuse `VARIANCE_FLOOR_FRACTION`/`FDR_ALPHA`/`FDR_METHOD`). Add pure `oddOnePattern(columns, fdr)` — filters `fdr.cells` to `isFlip AND |gap|≥ODD_MIN_GAP AND |resid|≥ODD_MIN_RESID AND welchAgrees AND nIn≥ODD_MIN_TEST_BASE AND fdr.survivors.has(idx)`; ranks by `|resid|`; returns firing pattern or null marker. In `buildPatterns` after comove: `var odd=oddOnePattern(inputs.columns, inputs.fdr); if (odd) patterns.push(odd);`. Expose `takeout._oddOnePattern`. **Reads the shared family; NEVER feeds back into group/split gates.**
- **27f:** `gatherCellFamily` (shared) carries `gap/meanGap/resid/dir/isFlip/welchDiff/welchP/nIn/flooredG` + the title→qcode join. `inputs.fdr` already wired.
- **27g:** `PATTERN_META.odd`; `ui.patternSeed` case `'odd'` (firing + null phrasing); `ui.oddRow(flip)` (full-wrap label, bar + cell value vs its own-pattern expectation).
- **27h:** `headHtml/bodyHtml/footHtml` branch for `kind==='odd'` — exception row via `ui.groupRow` + same-direction context rows + working caption; when `nullResult`, render the confident-null line + "0 survive" caption rather than an empty card.

---

## Family 3 — Hidden disagreement (bimodality)

### Purpose (the human-missed insight)
A rated question whose **mean looks calm** (mid-scale) yet the distribution splits into **two genuine end-camps** with a middle trough — a split the average hides and a question-by-question read misses. Additive/greenfield like co-movement; touches no existing pattern. On SACS: a **confident null** (every distribution is a single-peaked left-skew ceiling).

### Formula, estimator, decision rule
Pure helper `_bimodalStat(counts, K)` on a per-question weighted category-count vector `counts[0..K-1]` (weight 1 absent; null scores skipped). `n=Σcounts`. If `n<4` return null.

**Sarle's b, SAS bias-corrected** (do NOT double-correct the denominator):
```
mean = Σ counts[k]·(k+1)/n;  d=(k+1)−mean;  m2,m3,m4 = Σ counts[k]·d^p/n;  sd=√m2
if (sd < 1e-9) b = 0                                   // zero variance → not bimodal
g1 = m3/sd³;  g2 = m4/m2² − 3
G1 = g1·√(n(n−1))/(n−2)
G2 = ((n−1)/((n−2)(n−3)))·((n+1)·g2 + 6)
b  = (G1² + 1) / (G2 + 3(n−1)²/((n−2)(n−3)))           // b ∈ (0,1]
```

**Bands (general K via floor(K/2)):** bottom = first `h=floor(K/2)` cats, top = last `h`, middle = remainder (K=5 → bottom{1,2} mid{3} top{4,5}). `bMax/tMax/mMax` = max of each band. `bottomTwo=(counts[0]+counts[1])/n; topTwo=(counts[K-1]+counts[K-2])/n; minCamp=min(bottomTwo,topTwo); calmFrac=|mean−(K+1)/2|/((K−1)/2); dipFrac=(min(bMax,tMax)−mMax)/n`.

**Flag iff ALL** (logical AND):
1. `gB`: `b > BIMODAL_B`.
2. `gShape`: **end-peaked** — `bMax>mMax AND tMax>mMax` (a peak in each end band, antimode in the middle). Even K → `bMax>0 AND tMax>0`. This hardened band test (not "any two local maxima") robustly rejects Q08's central-mode shape.
3. `gDip`: `dipFrac ≥ BIMODAL_MIN_DIP` (central trough ≥5pp below the lower end-peak; rejects thin-tail blips). Even K → reduces to "both ends carry mass" (deferred to gCamp).
4. `gCalm`: `calmFrac ≤ BIMODAL_CALM_FRAC` ⇒ |mean−mid| ≤ 0.5 on 1..5.
5. `gCamp`: `minCamp ≥ BIMODAL_MIN_CAMP` (each end-camp carries real mass).
6. `gBase`: `n ≥ BIMODAL_MIN_BASE`.

**No per-question BH/FDR** — the false positives are *systematic* (ceiling skew inflates b on every question), not random noise; the structural gate IS the multiplicity-safe, scan-size-invariant correction. Do NOT route through `_bhFDR`.

`bimodalityPattern(bm)` maps each question through `_bimodalStat` + the 6 gates, keeps survivors, sorts by `dipFrac` desc, returns null when none flag.

**[FIX, required] gB threshold mismatch.** The code computes SAS-corrected b but 0.5556 = 5/9 is the uniform reference for the *uncorrected* moment-form b; a true uniform passes gB (gB is near-inert, n-dependent). Either (a) **threshold the moment-form `(g1²+1)/(g2+3)` against 0.5556** for a scan-size-invariant, correctly-rationalised filter, OR (b) keep SAS b but raise/justify the threshold and delete the false "Sarle uniform reference 5/9" rationale. **Recommend (a)** — it makes gB genuinely mean "possibly bimodal." Pin a known-answer test that a large-n uniform is REJECTED by the gate.

**[FIX, doc/test] Correct two false claims:** SACS Q08 `index_scores` are **ascending** (1=Strongly Disagree…5=Strongly Agree), not reversed `[5,4,3,2,1]`; and SACS Q08 SAS b = **0.5436** (already <0.5556, rejected by gB outright), not "near the line, rescued by gShape." Keep band-on-raw-micro + K-from-`scale_max` (correct), and add a deliberately-reversed-scale guard test since no real reversed scale exists in SACS to exercise it.

### Data source
`gatherBimodality(views)` (new, in 27f), mirroring `gatherComovement`:
- Iterate `views.indexQuestions()`, keep questions whose code carries `micro.scores`.
- **[FIX, impl]** Accumulate **genuinely weighted** category counts (`micro.weights` is PRESENT on SACS = all-ones, not absent): `counts[round(score)−1] += weight`, skipping null scores. `n` = non-null count.
- **[FIX, impl]** `K = touchpointMax(q)` — call the **local** `touchpointMax` inside 27f; do **NOT** call `takeout.touchpointMax` (private to the 27f IIFE, undefined on the namespace).
- Band on the **raw ascending 1..K** `micro.scores` (verified distinct={1..5} ascending), derive K from `scale_max`; never key off `index_scores` order.
- Runs only on the OVERALL distribution (never subgroup cuts), so base is full ~154 and `BIMODAL_MIN_BASE=30` never bites. Uses a dedicated shape floor (30), NOT the census report floor (5): a 5-person cell can be reported for a mean but cannot evidence a two-camp shape.
- Return `{ questions:[{code,title}], counts, scaleMax:K }` or null when MICRO absent / <1 rated Q. Wire into `gather()` as `inputs.bimodal` (try/catch→null).

### Guard thresholds (CONST additions in 27e)
```
BIMODAL_B          = 0.5556  // [FIX] threshold the MOMENT-FORM b; uniform reference 5/9
BIMODAL_CALM_FRAC  = 0.25    // |mean−mid| ≤ 0.25·(K−1)/2 = 0.5 on 1..5
BIMODAL_MIN_CAMP   = 0.20    // each end-camp ≥20% mass (fraction)
BIMODAL_MIN_DIP    = 0.05    // central trough ≥5pp below the lower end-peak
BIMODAL_MIN_BASE   = 30      // shape-claim floor; distinct from census floor (5); plus hard n≥4 in _bimodalStat
```

### Emitted object + takeaway/badge
```
{ id:'bimodal', kind:'bimodal', subject:'Hidden disagreement', scanned:Number, flaggedCount:Number,
  questions:[ { code, title, b, mean, scaleMax:K, dipFrac, antimode:Number,
               camps:{bottom:bottomTwo, top:topTwo}, dist:[pct1..pctK] } ] }   // sorted by dipFrac desc
```
or `null` (confident null → no card; read view shows the explicit scanned-N confident-null block).

`PATTERN_META.bimodal = { tag:'Hidden disagreement', cls:'bimodal' }`. Card heading: `flaggedCount + ' question(s) split into two camps'`. Per-question row via `ui.bimodalRow(q)`: full label (wrap, never ellipsis) + mini three-segment bar (low | middle | high) + `'X% low · Y% high · mean Z (looks calm)'`. `antimode` rendered in scale terms (the middle of 1..K), not a raw index.

Caption: `"scanned N questions for hidden disagreement · flags only a genuine two-camp split (peaks at both ends, a calm average, real mass in each camp) — not mere spread or skew"`.

**Confident-null line (SACS):** `"no AI · scanned 20 questions for hidden disagreement · every distribution is single-peaked, not two camps — no split hides behind a calm average."` Must render as an explicit scanned-N provenance line, visibly distinct from a pattern-not-computed omission.

### Cry-wolf gate
The decisive conjunction: CALM-MEAN (`calmFrac≤0.25`) AND BALANCED-CAMPS (`minCamp≥0.20`) AND END-PEAKED-WITH-DIP (peak in each end band, antimode, dip≥5pp). On SACS: **0 of 20** (verified). Proof it is not always-off: synthetic 40/8/4/8/40 (b≈0.83) and milder 28/14/12/14/32 (b≈0.69) both pass. Naive Sarle b>0.5556 fires 11/20 SACS ceilings; the structural gate takes 11→0 with NO FDR. Q08 rejected on gShape (central mode) AND gB (real b=0.5436) — robust, not razor-thin.

**[FIX, doc — sensitivity caveat before any non-SACS dataset]** `MIN_DIP=0.05` (5pp antimode) is a fairly low bar; on a genuinely polarised survey a shallow ripple like 30/22/18/22/28 (dip 8pp) would flag as "two camps" where a human might call it "spread." Acceptable for SACS (0/20). Re-confirm sensitivity (and pin a synthetic **weighted** test using Kish n_eff for `BIMODAL_MIN_BASE`, plus a 4-pt/7-pt fixture) before claiming weighted/scale generality.

### Expected real-SACS result
**Confident null** — 0 of 20 flagged. Naive Sarle b>0.5556 would fire on 11/20 (all ceilings, means 3.72–4.51); guarded flags none. Closest-to-calm Q08 (mean 3.44, dist 12/10/28/20/29) peaks in the MIDDLE → rejected. Engine emits no card; read view renders the scanned-20 confident-null block.

### Test cases
- **SACS overall (20 rated Qs):** `bimodalityPattern → null`; no `'bimodal'` card; read view shows scanned-20 confident-null block. Pin via the real-engine harness.
- `_bimodalStat([40,8,4,8,40],5)`: mean 3.00, all 6 gates true → FLAGGED (calmFrac 0.00, minCamp 48%).
- `_bimodalStat([28,14,12,14,32],5)`: mean 3.08, all gates true → FLAGGED (calmFrac 0.04, minCamp 42%).
- Q09 ceiling `[3,3,12,19,63]` (mean 4.36) → REJECTED: gCalm false (0.68), gCamp false (6%), gShape false.
- Q08 `[12,10,28,20,29]` (mean 3.44) → REJECTED on gShape (central mode) AND gB (b=0.5436). Pin Q08=REJECTED to catch estimator drift.
- **Uniform `[20,20,20,20,20]`** → REJECTED on gShape (flat). **[FIX]** add: assert a large-n uniform is rejected *by the gate as a whole*, documenting that gB alone may let it through under the chosen b-form.
- Neutral peak `[10,15,50,15,10]` → REJECTED (gB, gShape).
- Zero-variance `[0,0,100,0,0]` → b=0 → REJECTED.
- `n<4` → `_bimodalStat` null, skipped (no crash).
- 4-pt two-camp `[40,10,10,40]` → FLAGGED (even-K end-peaked); 4-pt skew `[5,10,30,55]` → REJECTED on gCalm (0.57).
- **[FIX]** Reversed-scale guard: a deliberately high-skew reversed-scale Q is still rejected (proves band-on-raw-micro).

### Integration per file
- **27e:** CONST above. Add `_bimodalStat(counts,K)` and pure `bimodalityPattern(bm)`; expose `takeout._bimodalStat`, `takeout._bimodalityPattern`. In `buildPatterns` **after `comovementPattern`, before `areaPatterns`**: `var bimodal=bimodalityPattern(inputs.bimodal); if (bimodal) patterns.push(bimodal);`. NOT routed through `_bhFDR` — cannot perturb the FDR path that gates Cape Town.
- **27f:** `gatherBimodality(views)` (local `touchpointMax`, weighted counts); wire into `gather()` as `inputs.bimodal` (try/catch→null).
- **27g:** `PATTERN_META.bimodal`; `ui.bimodalRow(q)` (full wrapping label + low|middle|high bar + summary line); `ui.patternSeed` branch for `id==='bimodal'` (flagged vs confident-null wording).
- **27h:** `headHtml/bodyHtml/footHtml` branches for `kind==='bimodal'` (heading 'N question(s) split into two camps'; body = `bimodalRow` per question + caption; foot deep-link `bimodal:['crosstabs','see the distributions →']`); when absent, surface the explicit scanned-N confident-null line in `provHtml`/empty wording. Add CSS `.tko-bimodal` for the bar colour.

---

## Cross-cutting required-fix summary (all folded above)

1. **`_studentT` non-finite t → return 1** (not 0) — both FDR gate-A and odd-one-out depend on it.
2. **Code→label join asserts count, not base-equality** (3 off-by-one base cases on SACS); skip-and-warn on count mismatch.
3. **Enforce CENSUS_FLOOR (≥2, =5) on both arms before `_welchTest`** (n=1 → df=0).
4. **Odd-one-out uses the Student-t p**, not normal-approx (gives gate-A's 4 survivors, not 10).
5. **Bimodality gB:** threshold the moment-form b against 5/9; delete the false SAS-uniform-5/9 rationale; correct the Q08 ascending-scale and b=0.5436 facts; add a reversed-scale guard test; pin a large-n-uniform rejection test; pin a weighted + 4-pt/7-pt test before non-SACS use.
6. **Docs:** SPLIT_MIN_CONSISTENT is an additive veto floor not a selector; sign-test is independent-Bernoulli (mildly anti-conservative); odd-one-out gaps are rounded display means; meanGap normalization matches `groupPattern` (or guard single-scaleMax); composite 418-vs-380 one-line comment.

All three families survive; none needs deferral. Each returns a **confident null on real SACS** (FDR badges 4 cells but the headline is "the rest is consistency"; odd-one-out = 0 survivors; bimodality = 0 of 20) while the verified-good Cape Town strain / Campus split / new-staff-thriving / co-movement baseline is untouched — the gate badges and vetoes, it never re-orders or deletes.

**Relevant files:**
- Engine: `/Users/duncan/Dev/Turas/modules/tabs/lib/html_report_v2/assets/js/27e_takeout_engine.js`
- Gather: `/Users/duncan/Dev/Turas/modules/tabs/lib/html_report_v2/assets/js/27f_takeout_data.js`
- Render: `/Users/duncan/Dev/Turas/modules/tabs/lib/html_report_v2/assets/js/27g_takeout_components.js`, `/Users/duncan/Dev/Turas/modules/tabs/lib/html_report_v2/assets/js/27h_takeout_read.js`
- Harness: `/private/tmp/claude-501/-Users-duncan-Dev-Turas/5dc50aea-37bb-4c6f-9a2a-31df9672e479/scratchpad/run_real_engine.mjs`
- Specs: `/Users/duncan/Dev/Turas/modules/tabs/docs/PATTERN_RECOGNITION.md`, `/Users/duncan/Dev/Turas/modules/tabs/docs/PATTERN_RECOGNITION_DESIGN.md`
