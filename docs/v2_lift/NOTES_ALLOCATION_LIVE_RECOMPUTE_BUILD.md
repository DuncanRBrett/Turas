# Allocation live recompute: what was built, and what it was checked against

Built 2026-09-03 on `feature/allocation-live-recompute`, off `main` at
`3f85abb3`, from `HANDOVER_ALLOCATION_LIVE_RECOMPUTE_FOR_OPUS.md`. All nine
rulings D1 to D9 were proceeded on as the recommended option. Read the handover
for the reasoning; this file records what shipped and what proves it.

## 1. The one ruling that did not survive contact with the code

**D7's first bullet is wrong about the mechanism, right about the outcome.** It
says `meanFindings` (`27d_diffs.js`) "takes the first headline mean row" and so
needs a change to return `[]` for an Allocation. It already returns `[]`: it
calls `indexMeans`, which is null when a question has no `scores` and no usable
`index_scores`, and an Allocation has neither, because `d2.catRows` finds no
category rows to hang `index_scores` on. The exclusion was already there by
construction.

An explicit guard was added anyway, which is what D7's own rationale asks for.
Step 2 makes the reader series-aware, and a later change teaching `indexMeans`
to read `series` would otherwise re-enable Differences on Allocation questions
silently. The guard is on the question carrying `series` and no `scores`, so it
holds independently of what `indexMeans` does, and `diffs_tests.mjs` test 39
proves that by stubbing `indexMeans` to return a working answer.

The other eight rulings hold. Several are more exact than claimed: rows are
built `i = 1..n_cols` with label `option_labels[i]` and column `{code}_{i}`, so
D2's pairing is exact; `calculate_allocation_base` is `Reduce(|)` over the slot
columns, which is D3 verbatim; and `pair_ids` deduplicates on RowLabel plus
RowSource, which is D8's premise.

## 2. Two corrections to the handover's own figures

- Section 6 says the node gate is 40 `*_tests.mjs` files. On `3f85abb3` it was
  **39**. The 1,003 assertions was exact. (It is 40 now, with the new suite.)
- The three `21_stats.js` score reads D1 lists at 482, 517 and 550 are at
  **483, 518 and 551**.

## 3. Section 4 item 8, which the design session could not verify, is real

`published_wave_contribution()` (`tracking_island.R`) keeps any question
satisfying `tracking_has_mean_row()`, and `tracking_metrics()` lists every
question when there is no `question_mapping`. An Allocation has k mean rows, so
on a confidential (no-microdata) build it is listed as a wave metric with one
base and no clear value. Pre-existing, not caused by this work, left for the
tracking follow-up as the handover directed.

## 4. Payload, measured (D6)

The Karoo integrated demo, rebuilt into a scratchpad (nothing was written into
`examples/*/Output`):

| | before | after | change |
|---|---|---|---|
| Report | 1,255,689 | 1,359,797 | +104,108 (+8.3%) |
| Micro island | 37,502 | 137,522 | +100,020 |

15 series were added: MDSHARE 10 items, CJIMP 5, each a length-600 array. D6
predicted about 99 KB and 8%. No rounding rule was added; `serialize_microdata`
keeps `digits = 8`.

VAS 2026 is on OneDrive and was **not** measured this session. D6's estimate
for it (about 448 KB, 7.6%) stands unverified.

## 5. The rendered-report proof (step 4)

The demo's tabs config was copied to the scratchpad and run there. The report
was served locally and driven in a browser: filter `Q009: Subscription`,
n = 166 of 600. MDSHARE's card, which said "n/a under filter" before this work,
now reads `COMPUTED · n=166`.

Each recomputed mean was compared against the same 166 respondents computed
independently in R from the MaxDiff export's own DATA sheet
(`Karoo_MaxDiff_Results_tabs_shares.xlsx`), joined on RespID:

| item | R | browser | diff |
|---|---|---|---|
| MDSHARE_1 | 31.2268945912 | 31.2268945911 | 3.4e-11 |
| MDSHARE_2 | 20.8147944827 | 20.8147944830 | 2.8e-10 |
| MDSHARE_3 | 10.7928191608 | 10.7928191608 | 9.3e-11 |
| MDSHARE_4 | 9.0968641911 | 9.0968641910 | 7.4e-11 |
| MDSHARE_5 | 6.2398747737 | 6.2398747738 | 1.3e-10 |
| MDSHARE_6 | 4.7674896031 | 4.7674896033 | 2.0e-10 |
| MDSHARE_7 | 9.0506507095 | 9.0506507096 | 1.2e-10 |
| MDSHARE_8 | 1.4112758018 | 1.4112758020 | 2.7e-10 |
| MDSHARE_9 | 4.5013424285 | 4.5013424281 | 3.8e-10 |
| MDSHARE_10 | 2.0979942578 | 2.0979942572 | 5.3e-10 |

The residuals are the `digits = 8` serialisation, not a method difference. The
conjoint twin was checked the same way against
`Karoo_Conjoint_Results_tabs_importance.xlsx` and agrees to the same precision
on all five attributes.

### What Duncan should try on VAS 2026

Regenerate through `launch_turas()`, open the crosstabs report, and filter to
one segment. **WalletSectionPct** is the question to watch: 13 items, and it
said "n/a under filter" before. The base under the filter should be the count
of respondents who filled at least one wallet slot, and every item row should
move. WalletLoc, WalletLocPct, WalletLocTxn and WalletLocTxnPct get the same
lift.

## 6. The parity fixture gained an Allocation question (D9)

`generate_parity_project.R` now builds **Q6**, three items published as three
mean rows. Both islands were regenerated. The two engineered separations D9
asked for:

- **Bank**, Gamma 30 against Beta 50 and Delta 50 on sd about 10.1. A 95%
  letter in both engines.
- **Retailer**, Beta 37 against Delta 30 on sd about 17.1. An **80%-only**
  letter in both engines: the case a single-alpha report shows as no difference
  at all.

The Retailer spread is 17 and not a rounder 15 for a reason worth keeping. R
runs a Welch t and the reader runs a z on the same means and bases, so their
adjusted critical values differ (about 2.68 against 2.638). At spread 15 the
pair computed to about 2.665, which falls **between** them: R carried no letter
and the reader computed one, and the parity gate could only log the
disagreement instead of pinning it. At 17 the statistic sits clear of both
thresholds in the same direction. Do not round it back.

`expected_sig_cells()` in `test_cross_engine_stats.R` also had to learn the
multi-block case: it assumed one summary Sig. row per question, and an
Allocation has one per item. It now mirrors `mean_sig_for()` in
`data_layer_writer.R`, which already handled it.

## 7. Suites, quoted from the run

| | baseline (`3f85abb3`) | after |
|---|---|---|
| Tabs R suite | 5,294 pass / 0 fail / 1 skip / 0 error | **5,369 / 0 / 1 / 0** |
| Node gate | 39 files, 1,003 passed, 0 failed | **40 files, 1,026 passed, 0 failed** |

Both baselines were run this session before the first edit, not taken from a
note. Both halves of the cross-engine parity gate are green
(`test_cross_engine_stats.R` 346 pass / 0 fail, `parity_stats_tests.mjs` 25
pass / 0 fail).

Every new test was run against the code as found first:

- `test_microdata_numeric.R`: 17 pass / 5 fail / 7 error on the original
  writer, 47 / 0 / 0 with it.
- `allocation_series_tests.mjs`: 6 passed / 8 failed on the original reader,
  14 / 0 with it.
- `diffs_tests.mjs` test 39 fails without the guard.

Three of the four D7 exclusion tests (`takeout_tests.mjs`, `composite_tests.mjs`
and the `test_tracking_island.R` one) pass on the code as found. That is the
point of them: section 1 above explains why those exclusions already hold, and
the tests exist so a later change cannot quietly undo them.

## 8. Not done, and out of scope

Everything in the handover's section 5 remains a follow-up: row-aware
Differences findings, per-item wave tracking, series-based intervals, the head
to head and segments panels, and `n_excluded` on the card. The pre-existing
tracking oddity in section 3 above was left alone.
