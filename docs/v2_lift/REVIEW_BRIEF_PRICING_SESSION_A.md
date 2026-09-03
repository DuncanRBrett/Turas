# Pricing Session A. Independent review brief

**Written:** 2026-09-03, by the session that built Session A, for a session that did not.

**You are independent of the implementation.** The work under review was written by a
different session and merged to main before anyone else looked at it, at Duncan's
request, so that the Karoo example could be run from the launcher. Duncan has run it
once and it completed. Nothing else has been checked by anyone but its author,
including its tests. Treat the code as a claim, not as a starting position, and treat
this brief as scoping only. Where the author's reasoning appears below it is there to
be falsified, not adopted. Do not read `SESSION_A_NOTES_PRICING.md` until section 4 of
your own review is written; it is the author's account of the author's work.

---

## 0. What you are being asked

Four questions.

1. **Are the numbers right where they were wrong before?** Three CRITICALs were
   silently wrong client-facing numbers: weighted Van Westendorp points that were
   unweighted, stop-early Gabor-Granger ladders that inflated demand, a confidence
   table around a different estimator than the headline. Verify each by execution,
   not by reading the diff. The Karoo example and the module's own fixtures exist
   for this.
2. **Are the new refusals calibrated for real studies?** Several runs that used to
   complete now stop: unequal rung bases, 1/2-coded intent, ties in the four VW
   answers under the default `drop`, grossing weights, `Min_Sample`, retired and
   duplicated settings. Each is defensible. Would any of them block a legitimate
   study, and does each refusal tell the analyst what to do?
3. **What should have been tested and was not?** The suite grew from 845 to 997
   passing expectations, all written by the author. The July review said the old
   green was structural (`skip_if(!exists())` everywhere, no golden values). Is the
   new green earned? In particular: is any new test asserting what the code does
   rather than what is correct?
4. **Did anything that worked stop working?** The config loader, the template, the
   GUI's console capture, the stats pack, the Excel writer and the classic HTML
   report all changed shape. The classic report is scheduled for deletion in
   Session B but is still the shipped report today.

### Out of scope, do not re-open

- **The decisions in `HANDOVER_PRICING_V2_FOR_OPUS.md` section 1** (weighted VW via
  the package's own weighted estimator, refuse-not-fallback, stop-early refusal with
  an explicit opt-in, monotonicity default `drop`, the v2 route for Session B). If
  you think one is wrong, one paragraph at the end.
- **Session B's work.** The island, the Pricing tab, the tabs export, the simulator
  extraction and the report retirement are not built. `Generate_Tabs_Export = Y`
  refusing by name is deliberate.
- **The 07/08/09 API tier** (WTP distribution, competitive scenarios, price-volume
  optimisation). Dead code, deliberately left unwired.
- **The classic HTML report's own bugs** (review P1 to P3). Not fixed, by decision;
  the report is being deleted. Only ask whether Session A broke what it renders.
- **The shared stats pack writer's em dashes.** Shared code, logged for Duncan.

---

## 1. The specification

Read these, in this order. They are the specification. The implementation is not.

1. `docs/v2_lift/PRICING_PRODUCTION_REVIEW_2026-07-11.md`: the findings, C1 to C3,
   H1 to H8, M1 to M14, P1 to P3, and section 5 on the suite.
2. `docs/v2_lift/HANDOVER_PRICING_FOR_OPUS.md` section 2: the Session A work orders
   A1 to A9. Still the spec for the correctness work.
3. `docs/v2_lift/HANDOVER_PRICING_V2_FOR_OPUS.md` sections 1 to 3: the amendments
   (refusal codes are `MODEL_*` not `CALC_*`; the Kish helper is shared; the Karoo
   example is A0), and the rules.

Judge the implementation against those. The commit messages are the author's account.

---

## 2. What to look at

The commit range on main is `da7872c2..34078b33` (three commits: the refreshed brief,
Session A, and a follow-up for four findings from an advisor pass). `git diff
3f85abb3..34078b33 -- modules/pricing examples/pricing` is the whole change.

| Area | Files | The claim to test |
|---|---|---|
| Entry point | `modules/pricing/R/00_main.R` top | `source("modules/pricing/R/00_main.R")` loads the module from any working directory; the GUI's own sourcing order still works |
| Config | `R/01_config.R` | Template names reach the engine; one list parser; duplicates refuse, retired names refuse, unknown names warn; `.clean_settings_df()` drops every divider and no setting |
| Validation | `R/02_validation.R` | Binary-domain check on GG columns; `Min_Sample`; `monotonicity_violations` returned; the strict ordering rule |
| VW | `R/03_van_westendorp.R`: `fit_vw_psm()`, `run_van_westendorp()`, `bootstrap_vw_confidence()` | Weighted path is the package's survey-design estimator; `validate` follows the behaviour; bootstrap uses the same routine, flag and weights; `estimate` column is the headline; `n_analysed` |
| GG | `R/04_gabor_granger.R`: `run_gabor_granger()`, `gg_rung_bases()`, `check_gg_rung_bases()`, `impute_gg_no_after_stop()`, `code_gg_response()`, `bootstrap_gg_confidence()` | Bases compared with a 2% tolerance (floor of three); imputation only above the first No; exact coding; PAVA; band around the smoothed curve |
| Monadic | `R/13_monadic.R` | Weights normalised, grossing refusal at mean > 5, weighted cell means, exact intent coding, one bootstrap policy |
| Stats pack | `00_main.R` `generate_pricing_stats_pack()` | Kish from `modules/shared/lib/effective_n.R`; the switch works; the Declaration now says weighted |
| Output | `R/06_output.R` | 130 lines of never-firing sheets deleted; nothing live deleted with them |
| GUI | `run_pricing_gui.R` | Console text survives a crash; stats-pack checkbox defaults on |
| Template | `lib/generate_config_templates.R`, `docs/templates/Pricing_Config_Template.xlsx` | Regenerated; no dead settings; example rows titled `[Example]` and filtered by both loaders |
| Example | `examples/pricing/` | Four configs run through `run_pricing_analysis()`; the truth bands in `karoo_pricing_truth()` are not tuned to the output |
| Tests | `tests/testthat/test_config_honesty.R`, `test_engine_honesty.R`, `test_karoo_example.R` | Each claims to fail on the old code. Check three of them by running them against `git stash` or a checkout of `3f85abb3` |

---

## 3. What has and has not been verified

Verified by the author, by execution:

- The Karoo configs, four ways, headless, plus an unweighted variant in the test.
- `psm_analysis_weighted()` executed; a weight of 2 reproduces duplicating the
  respondent's rows to within 2%.
- The suite from the repo root on merged main: 997 pass / 0 fail / 0 skip / 0 error /
  14 warnings.
- Duncan ran the Karoo config from `launch_turas()` once and it completed.

Not verified by anyone:

- The Excel workbook opened as a reader would. Nobody has looked at the sheets.
- The classic HTML report rendered from the new result objects. The transformer reads
  `confidence_intervals$estimate`, `demand_curve$purchase_intent` and
  `observed_data`; those columns still exist but gained neighbours. Render one.
- Long-format Gabor-Granger data. Every fixture and the Karoo example are wide.
- The NMS extension (`Col_PI_Cheap` etc.) under the weighted path. `fit_vw_psm()`
  passes the columns into the design; no test exercises it.
- `flag_only` on the weighted path.
- The GUI's console capture on an actual crash (it was reasoned about, not crashed).
- Anything with `Segment_Column` beyond the Karoo run: the segment engine calls
  `run_van_westendorp()` per segment and reads `n_analysed`.

---

## 4. Where the author expects to be wrong

Falsify these first; they are the author's own doubts.

- **The strict tie rule.** `check_vw_monotonicity()` now treats `too_cheap == cheap`
  as a violation because pricesensitivitymeter does. Real respondents answer in
  round numbers and tie often. Under the default `drop` this excludes them and the
  base shrinks. The alternative (keep ties, let psm exclude them silently) is what
  the module did before and is worse, but the author did not measure how many
  respondents a real dataset loses this way.
- **The 2% rung-base tolerance.** Three respondents or 2% of the largest base,
  whichever is larger. Chosen, not derived. A full-presentation ladder with modest
  item non-response could trip it and the refusal text would then send the analyst
  towards `NO_AFTER_STOP`, which would be the wrong fix for that data.
- **`NO_AFTER_STOP` on noisy ladders.** Imputation fills NA above the first No. If
  a respondent said No at R80 then Yes at R100 (noise, or a real re-think), the Yes
  stays and nothing after it is touched. The Karoo stop-early copy was built from
  the noisy full ladder, so the imputed curve does not equal the full one there,
  and the test only checks direction. Is the rule right for real ladders?
- **The bootstrap policy.** Equal-probability resampling of respondents carrying
  their weights, then the weighted estimator. This is the usual design-based
  approximation, but the author changed the VW bootstrap from weighted-probability
  resampling and the monadic one from double-weighting without a reference in the
  notes. Check the intervals are not visibly too narrow on the Karoo weights.
- **The grossing threshold of 5.** A mean weight above 5 refuses. A rim weight
  scaled to sum to a population would refuse; a rim weight scaled to mean 1 would
  not. Is there a legitimate weight file with mean between 2 and 5?
- **The divider regex.** `^[A-Z][A-Z0-9 &/]*( \(.*\))?$` on a name with a blank
  value. A real setting typed in capitals with a blank value, say `DK_CODES`, has an
  underscore and survives; one without an underscore, say `ANCHOR`, would be dropped
  as a divider. The author decided that is acceptable. Is it?
- **The H8 fix moved the stats-pack default.** The GUI checkbox is authoritative and
  now defaults on. A headless run reads the config's `Generate_Stats_Pack`, default
  Y. Confirm both paths produce a pack by default and neither produces one when
  told not to.

---

## 5. Deliverable

`docs/v2_lift/REVIEW_FINDINGS_PRICING_SESSION_A_<date>.md`, in the shape of
`REVIEW_FINDINGS_MAXDIFF_SESSION_A_2026-09-03.md`: a verdict (PASS, PASS with fixes,
BLOCK), findings with IDs and file:line, each marked verified-by-execution or
reasoned, what you ran, and what you did not check. Fix nothing on main. If a fix
is small and certain, put it on a branch off main and say so; otherwise list it for
a follow-up session. Update the pricing row in `V2_LIFT_PROGRAM.md` and add a log
line.
