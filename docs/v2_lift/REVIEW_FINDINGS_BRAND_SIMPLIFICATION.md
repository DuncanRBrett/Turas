# Brand report simplification: independent pre-merge review findings

**Date:** 7 September 2026.
**Reviewed:** main at `33000b28`, in the detached checkout `/Users/duncan/Dev/Turas-review`.
**Brief:** `docs/v2_lift/BRAND_SIMPLIFICATION_HANDOVER_FOR_REVIEW.md`.
**Reviewer stance:** independent of the six build sessions. Their logs were treated as claims and every claim below was tested by running something. Where a claim could not be tested it is marked unverified, next to the claim.

Nothing was changed in `modules/`. No code fix was made: the two blocking findings change what a client sees, and Duncan should read them described before they land. This document is the only file added, committed on the branch `review/brand-simplification-findings`. Not merged, not pushed.

---

## 1. Verdict

**Do not merge yet. Two findings block, and both were introduced by the programme.** Each has a small, local fix. Everything else the handover claims about the shell, the anchors, the numbers and the gates holds, and holds well: every gate the handover names was rerun here and every count matched.

1. **The insight number check pools the wrong funnel view on an ungated report** (F1). On the report Duncan's real study will produce, a correct analyst sentence gets a client-visible amber "Number check" box saying its figure could not be found, and a sentence quoting figures the page never shows passes.
2. **The two Stage 6 pin-title commits regressed the Advanced-drawer pins** (F2). At the Stage 6 base a drawer pin produced distinct, category-suffixed card titles. At the tip, seven cards come out titled "Branded Reach", five titled "Audience Lens", and every Category Buying drawer card has lost its category. On a four-category report that is four indistinguishable "Dirichlet Norms" cards, which is the problem the handover says Stage 5 solved.

Ranked after those: the gating statement over-claims from one row (F3), the fixture workbooks the whole verification chain rests on are not in git (F4), and "Funnel" still names the leaf on an ungated report (F5).

---

## 2. What was run

All from `/Users/duncan/Dev/Turas-review` with `TURAS_ROOT` set to it. Reports and scratch fixtures went to the session scratchpad only. The real IPK config was not touched, nothing was written into OneDrive or TurasProjects, and `preview_start` was not used.

| Gate | Result here | Handover claim | Holds |
|---|---|---|---|
| `testthat::test_dir("modules/brand/tests/testthat")` at tip | FAIL 0, WARN 1, SKIP 2, PASS 3593, 117 s | 3593 / 0 / 2 / 1 | yes |
| Same suite at the Stage 6 base `e94c2b30` (scratch worktree) | FAIL 0, WARN 1, SKIP 2, PASS 3560 | 3560 | yes |
| `generate_qa_reports.R` | 4,047,002 / 4,156,971 / 4,156,994 bytes | same three figures | yes |
| `drive_element_flags.R` committed / extras / ungated | 81, 89, 89 checks, 0 failed | 81 / 89 / 89 | yes |
| `drive_destinations.py` x3 | 353 / 384 / 384, 0 failed | same | yes |
| `drive_chrome.py` x3 | 125 / 150 / 152, 0 failed | same | yes |
| `drive_save_roundtrip.py` x3 | 113 / 117 / 117, 0 failed | same | yes |
| `drive_overview.py` x3 | 60 / 60 / 58, 0 failed | same | yes |
| `drive_funnel_base.py` x3 | 99 / 99 / 79, 0 failed | same | yes |
| `drive_two_categories.py` x3 | 15 / 15 / 15, 0 failed | same | yes |
| `count_chrome.py` committed | pin 25, PNG 17, Excel 16, textarea 14, visible sig text 5, toolbars 5, drawers 5 | same | yes |
| `count_chrome.py` extras / ungated | 38 / 30 / 18 / 17 / 7 / 6; ungated sig markers in DOM 311 vs 276 | same | yes |
| `reachability_check.py` base `e94c2b30` to tip | PASS, every island's numeric content identical | PASS | yes |
| `anchor_resolution.py` base `e94c2b30` to tip, committed | 41 of 41 | 41 of 41 | yes |
| `anchor_resolution.py` base `e94c2b30` to tip, extras | 69 of 69 | 69 of 69 | yes |
| `reachability_check.py` **pre-programme** `7074e887` to tip | PASS. 29 `data-section` values, 13 section ids and 5 `data-subpanel` values identical; every JSON island numerically identical except `brsum-data`, which grew by the 65 Overview values Stage 4 declared | not claimed | holds, and is the stronger test |
| `anchor_resolution.py` pre-programme to tip | 41 of 41 | not claimed | holds |
| Funnel data island, pre-programme to tip, numbers compared directly | 1311 numbers, 0 lost, 0 gained; keys added: `gating`, `gated`, `mode`, `breach_stages`, `statement` | "no numeric change except the funnel default" | yes |
| `capture_artifacts.py` committed | pinned card titled "Brand Funnel", picker offers Brand Funnel, Category Context, Brand Summary; one defect recorded, the PNG is JPEG bytes | same | yes |

`7074e887` is the parent of the Stage 1 impact map commit, so it is the report as it stood before any of this programme's code. Two scratch worktrees were added under the session scratchpad for the two baselines and removed afterwards.

---

## 3. Findings, ranked

### F1. HIGH. The insight number check reads an ungated funnel against a view the page does not show

**What happens.** `.bin_funnel_pool()` in `modules/brand/lib/html_report/03b_insight_number_check.R` builds its pool from `.fn_chain_pct(cell, n_weighted)` for every cell, which is the nested chain. It never reads `funnel$meta$gating`. On an ungated report the panel withholds the nested view entirely (`03_funnel_panel_table.R` line 52 sets `chain_denom` to `NA`, and `.fn_table_controls()` does not render the "Funnel, % of all" button), so the page opens on "Each stage on its own", the absolute view. The check therefore pools numbers the reader cannot see and misses the numbers the reader is looking at.

**Verified by execution** (`probe_insight_ungated.R`, on the ungated fixture the QA scripts build). IPK's on-screen absolute figures are 87, 67, 62, 45; the nested chain the pool holds is 87, 63, 41, 30.

| Sentence anchored to `funnel-dss` | Result |
|---|---|
| "IPK is known to 87%, considered by 67%, bought in the past 12 months by 62% and in the past 3 months by 45%." (what the page shows) | **flagged**, figure 62 |
| "IPK is known to 87%, considered by 63%, bought in the past 12 months by 41% and in the past 3 months by 30%." (figures the page never shows) | **passes** |

On the gated committed fixture the same probe behaves correctly: the absolute sentence is flagged (62 is not on the opening view) and the nested one passes. So this is a gating blind spot in an otherwise sound check, not a broken check.

**Why it matters.** The brief says the check must not cry wolf. `brand_insight_check_note()` renders the flag as an amber box inside the insight container of the client HTML, not only in the console. The questionnaire in the fixture folder (`IPK_Brand_Health_Wave_1-2.doc`, converted with `textutil`) shows `BRANDPEN1_DSS` asked about all fifteen brands with no routing line, so Duncan's real study is ungated on the purchase pair, as the handover says. Every correct authored funnel insight on that report would carry the box.

**Fix shape.** In `.bin_funnel_pool()`, read `funnel$meta$gating$gated`. When false, pool each cell's absolute percentage and its own unweighted base instead of the chain, and set `view` to "each stage on its own, the view this page opens on". `test_insight_number_check.R` has no ungated case; add one built from the probe above. The `.bin_prepare_text()` masks were probed with age bands, "17-point gap", CI ranges and "3-5x" and none fired wrongly.

### F2. HIGH. The Stage 6 pin-title fix regressed every pin taken from an Advanced drawer

**What happens.** Commits `932c18dc` and `33000b28` made `captureFromRoot()` (`js/brand_pins.js`) and `sectionsIn()` (`js/brand_report.js`) skip hidden headings and fall back to `data-leaf-label`. Two consequences the harness does not see because `drive_chrome.py` expands every drawer before it captures:

1. A drawer is collapsed when a reader opens the picker. Every heading under it has `offsetParent === null`, so every anchor inside the same leaf falls back to the same leaf label. The picker offers identical names and the cards carry identical names.
2. `pinnableContent()` applies the picker's category-suffixed `title` only when `content.title` is empty or equals the key. The fallback now fills `content.title` with the bare leaf label, so the suffix Stage 5 added (adversarial item 8) is discarded.

**Verified by execution on both sides** (`probe_hidden_pin.py`, headless Chrome, extras report, drawers left collapsed, `brSectionsIn()` then `brPinFrom()` per item, then the card titles read from `#br-pinned-cards-container`):

| | Stage 6 base `e94c2b30` | Tip `33000b28` |
|---|---|---|
| Brand Meaning drawer, picker labels | "Branded Reach: Dry Seasonings & Spices", "QA synthetic asset A (not asked in IPK Wave 1)", "QA synthetic asset B ...", and so on, seven distinct | **seven entries all "Branded Reach"** |
| Audience drawer | "Audience Lens: Dry Seasonings & Spices", "Audience banner: ...", "IPK among Bought the focal brand ...", five distinct | **five entries all "Audience Lens"** |
| Category Buying drawer cards | "Dirichlet Norms: Dry Seasonings & Spices" and four more with the category | "Dirichlet Norms", no category, all five |
| Cards produced | 18, all with content | 18, all with content |

Content survives, so no card is empty. Expanding the drawers first recovers only two of the seven Branded Reach names at the tip; the misattribution and media anchors stay "Branded Reach" because their headings sit in the panel's own hidden sub-tabs.

**Why it matters.** The Brand Funnel card fix was right and is confirmed (the card reads "Brand Funnel", the picker matches). But the handover's gap 4 says leaf pins were solved by putting the category in the title, and at the tip they are not. Branded Reach and Audience Lens are synthetic on this fixture; they are real elements in the module.

**Fix shape.** In `pinnableContent()`, prefer the passed `title` whenever it is non-empty, since the picker has already resolved the best name. In `sectionsIn()` and `captureFromRoot()`, when the first visible heading search finds nothing, look for the first heading that is hidden only because an ancestor `.br-advanced-body` or `.br-adv-body` is collapsed, before falling to the leaf label. Then run `probe_hidden_pin.py` against the result; it should reproduce the base column above.

### F3. MEDIUM. The gating statement claims more than one row can prove

**What happens.** `detect_instrument_gating()` reports ungated on the first respondent who is at a later stage without the earlier one, for any brand, on any checked pair. That threshold is Duncan's ruling and `test_funnel_gating.R` locks it ("A single impossible row is enough"); this review does not reopen it. What is actionable is the wording built on it. `.funnel_gating_sentence()` puts on the page: "The questionnaire did not route these questions: it asked every one of them about every brand." The console box says "The questionnaire asked the funnel questions of everyone." Both are claims about the instrument that the code cannot make from the data, and both are emitted verbatim whether the evidence is one row on one pair or hundreds of rows on every pair.

**Verified by execution** (`probe_gating_flip.R`). On a copy of the committed fixture, 1,200 respondents:

| Edit | Result |
|---|---|
| Respondent 24: one `BRANDAWARE_DSS` slot holding ROB cleared; nothing else touched | `gated = FALSE`, mode separate, console: "asked the funnel questions of everyone ... bought_long not aware, 1 respondent rows across 1 brands" |
| One respondent: one `BRANDPEN1_DSS` slot holding IPK cleared | `gated = FALSE`, breach stage `bought_target` |
| Control, unchanged | `gated = TRUE`, nested |

So a single cleaning artefact or one mis-keyed cell removes the funnel from the whole category and tells the client the questionnaire was unrouted. Also, the sentence says "every one of them" even when only one pair breached and the others nested cleanly.

**Fix shape.** Keep the decision; change the claim. State what was observed: which pairs breached, and that the other pairs nested. Something like "Respondents gave [breach phrases], which routing would have made impossible, so the stages are shown as separate measures." Drop "it asked every one of them about every brand" and the console's "of everyone". The breach counts are already in `gating$breaches`; the page text is kept digit-free for the island gate, so name the pairs rather than the counts.

**Not verifiable here.** Whether the real IPK attitude questions were routed. The `.doc` prints "Show/hide trigger exists" on each `BRANDATT1_DSS_*` question without the condition. `BRANDPEN1_DSS` carries no logic line at all, which is enough to make the real study ungated on the purchase pair.

### F4. MEDIUM. The fixture workbooks every gate depends on are not in git

`modules/brand/tests/fixtures/ipk_wave1/Brand_Config.xlsx`, `Survey_Structure.xlsx` and `ipk_wave1_data.xlsx` are matched by `.gitignore` line 22 (`*.xlsx`). `git ls-files` lists only the generator scripts and the questionnaire; `git log --all` on the three workbooks is empty, so they have never been tracked. The handover calls them "the committed fixture workbooks" and its item 11 says they are "one cosmetic commit behind their generator", which cannot be true of untracked files. Eighteen test files reference `ipk_wave1`, and `modules/brand/tests/fixtures/README.md` does not say the workbooks must be generated. A fresh clone cannot run the brand suite, the reachability baseline or any byte count in the handover without first discovering `00_generate.R`, and if item 11 is right the regenerated workbooks differ from the ones every number above was measured on.

Verified by `git ls-files`, `git check-ignore -v`, `git log --all`, and by having to copy the three files into both scratch worktrees before either baseline would build.

**Fix shape.** Either force-add the three workbooks with a `!` rule in `.gitignore` for that directory, or make the suite's setup regenerate them when absent and say so in the README. The first keeps every baseline byte-stable, which is what the gates assume.

### F5. MEDIUM. "Funnel" still names the leaf on a report that says there is no funnel

Acceptance criterion in `HANDOVER_BRAND_SIMPLIFICATION_FOR_OPUS.md` section 8: "Funnel appears only on a nested view." On `ungated.html` the nav leaf is still `data-leaf-label="Brand Funnel"`, the pinned card takes that name, and the view then explains that the nested funnel is not offered. The only other visible "Funnel" strings on the ungated page are the hidden `.fn-subnav` buttons, the hidden Summary cards, and an Audience Lens banner group label "Funnel & Equity". Verified by grepping the rendered `ungated.html` with scripts and styles stripped. Minor on its own; it reads oddly next to the gating notice. A leaf label that follows the mode ("Brand Funnel" when gated, "Aware to Purchase" or similar when not) would close it, but that touches the picker and pin names and should wait for F2.

### F6. LOW. Handover 3.1 describes one export path and the workbook a reader gets from the other

The panel-native `fn-export-btn` path is garbled exactly as the handover says: the on-screen `fn-table` category-average cell's `textContent` is `61%51%72%`, which `_brTablesToWorkbook()` parses to 615172 (simulated on the rendered markup; 241731, 10515 and 629 follow for the other three stages). But the destination-toolbar workbook `capture_artifacts.py` produced (`dss-buying.xls`) has a clean `funnel-dss` sheet: IPK 92 / 67 / 45 / 32, category average 61 / 24 / 10 / 6, with the CI bounds on two separate rows, and only the focal brand, not eighteen. The purchase bands come through as "1×", "2×", "3–5×", "6+×" text, not 1, 2, 3, 6. So the defect is real on the panel path and does not reproduce on the destination path here. Being fixed on `fix/brand-excel-export`; not this review's to fix. Worth telling that branch which path to test.

### F7. LOW. Console note misdescribes a six-level survey with no OptionMap

`.funnel_resolve_consideration()` was probed with sixteen scale shapes (`probe_consideration.R`). Five-level scale: Love plus Prefer, price dropped and reported. Six-level scale, by code or by label: Love plus Prefer plus Price-conditional. Operator naming price on a five-level scale: refuses `CFG_CONSIDERATION_ROLE_ABSENT`. Unknown role: refuses `CFG_CONSIDERATION_ROLE_UNKNOWN`. Synonyms, legacy codes, `attitude.*` and `attitude_scale.*` spellings, `reject` to `avoid`: all resolve as documented. The role resolution holds.

One wording issue. With no OptionMap the resolver falls to the built-in five-level convention and prints "The attitude scale carries no price level", which on a six-level survey whose operator simply omitted the OptionMap is false: the scale has the level, the config does not declare it. Say "no price level is declared for this scale; add it to the OptionMap if the survey asked one". Pre-existing convention, new sentence.

---

## 4. Things the handover asked the reviewer to check, and what was found

**3.2, the category tab now decided by `.br_cat_renderable()`.** Holds by reading, not by execution on a differing config. Every element that can put a result on `cat_results` is inside a `cat_depth == "full"` guard in `R/00_main.R`: Mental Availability line 418, funnel 575, repertoire 587 / 614 / 665, WOM 796, Branded Reach 819, Audience Lens 850, drivers 897, demographics 926, ad hoc 950. An awareness-only category therefore cannot produce a renderable result. The fixture's eight awareness-only categories still produce no tab (drive_two_categories 15 / 15).

**3.3, controls only driven through handlers.** `drive_chrome.py` at the tip clicks Pin, PNG and Excel on every destination toolbar (23 click checks, "clicking pin opens the picker or acts" per view). The probe for F2 shows the remaining gap: the harness expands every drawer before capturing, so the collapsed state a reader actually opens the picker in is never driven.

**3.4, hidden headings and the collapsed drawer.** Found; it is F2.

**3.5, acceptance criteria.** Five destinations: yes, `.BR_DESTINATIONS` has five and the nav shows five. Position, reasons and actions on the Overview without the methodology panel: drive_overview 60 / 60, and the hero rank clause now renders ("Rank 1 of 15 in the category"). MA Metrics, CEPs and Mental Advantage not peers: they are four leaves in one destination. Category Buying no longer six peer sub-tabs: two main leaves and five in the drawer. Every output reachable: 41 of 41 and 69 of 69 anchors, 29 `data-section` values and 13 section ids identical since before the programme. No metric relabelled to misstate its computation: the four base-toggle labels each describe their own arithmetic; the "Consider" relabel matches the new membership. "Funnel" only on a nested view: **not met**, F5. Pin, export, focal and category switching, commentary, Save: every drive passes; F2 qualifies pin titles. Missing optional sections hide cleanly: the flag matrix, 81 / 89 / 89. No numeric change except the funnel default: the funnel island's 1311 numbers are identical to the pre-programme report; every other island is numerically identical.

---

## 5. Every handover claim, marked

| # | Claim | Holds | How checked |
|---|---|---|---|
| 1 | Suite at tip 3593 / 0 / 2 / 1 | yes | run |
| 2 | Stage 6 baseline 3560 | yes | run at `e94c2b30` |
| 3 | Intermediate baselines 2542, 2740, 3047, 3077, 3247, 3486, 3560 | unverified | not run at those commits |
| 4 | Report bytes 4,047,002 / 4,156,971 / 4,156,994 | yes | run |
| 5 | Report at `e94c2b30` is 4,044,194 bytes | yes | run |
| 6 | "Before Stage 2" report 3,870,211 bytes | close, not exact | report at `7074e887` is 3,871,604; the handover's commit for that figure is not named |
| 7 | Control counts, all three reports | yes | `count_chrome.py` |
| 8 | Eight QA gates, all three reports | yes | all 24 runs plus the flag matrix |
| 9 | Reachability PASS, numbers identical | yes | run against both baselines |
| 10 | 41 of 41 and 69 of 69 anchors | yes | run |
| 11 | 3.1 Excel garble 615172 | yes on the panel path, not reproduced on the destination path | F6 |
| 12 | 3.2 category tab safety | holds by reading | section 4 |
| 13 | 3.3 harness now clicks all three controls | yes | log |
| 14 | 3.4 card titled "Brand Funnel", picker matches | yes, and the same change caused F2 | screenshot and probe |
| 15 | Gap 2, PNG is JPEG bytes | yes | capture log |
| 16 | Gap 3, comparison set unwired for Branded Reach and Ad Hoc | yes | drive_destinations "unwired" checks pass |
| 17 | Gap 4, anchored pins carry no category, leaf pins do | leaf half **no longer holds** at tip | F2 |
| 18 | Gap 7, the three examples call a function that exists nowhere | **no** | `test_examples_generators.R` (`15095dc9`, 6 Sep 13:57, before the handover) runs the generators and passes in the suite; the old name survives only in a comment |
| 19 | Gap 8, funnel Summary cards unreachable | yes | hidden `.fn-subnav` and `data-fn-subtab="summary" hidden` in the rendered HTML |
| 20 | Gap 9, comparison set does not survive Save | unverified | not driven |
| 21 | Gap 10, PackSizeCode vs PackCode | yes | `08e_shopper_behaviour.R` 429 vs `07_structure_writers.R` 462 |
| 22 | Gap 11, committed workbooks one cosmetic commit behind | misframed | the workbooks are not committed, F4; the regeneration diff itself was not run |
| 23 | Gap 12, nothing run weighted | not checked | out of scope here |
| 24 | Gap 13, Portfolio wording untouched | yes | `09_portfolio_panel.R` 999 |
| 25 | Gap 14, two extras invented and labelled | yes | labels visible in the F2 probe output |
| 26 | Gap 15, no real `launch_turas()` run | still true | not done here either, by instruction |
| 27 | Duncan's ruling: IPK instrument did not gate | supported | `BRANDPEN1_DSS` has no routing line in the questionnaire; attitude routing condition not printed |

---

## 6. Out-of-scope observations, unverified as bugs

- The Category Context table reads "Purchases in window: 1× 0.0%, 2× 0.0%, 3–5× 0.0%, 6+× 100.0%" on the fixture. The `cb-panel-data` island is numerically identical to the pre-programme report, so this predates the programme. It may be a fixture artefact (the KPI strip says 10.1 mean purchases per buyer in three months). Nobody has said it is wrong; it looks worth one glance.
- The rendered report carries 36 em dashes, all inside script blocks; two are user-facing toast strings in the shared `TurasPins` export code (the "Export failed" toast in `turas_pins_export.js`, which joins its two clauses with the character). Shared module, not brand.
- The two test files that contain an em dash (`test_funnel_nested_default.R` 341, `test_insight_number_check.R` 440) construct the character in order to assert it is absent. Not a violation.

---

## 7. What Duncan owes, unchanged from the handover, plus one line

The `launch_turas()` run on the real four-category project, the Excel export ruling, and the merge. Added: decide whether F1 and F2 are fixed on this branch before merging or as the first commits after. Both are small; F1 is one function and a test, F2 is two title-selection paths and the probe already exists to prove it.

## 8. Reproducing this review

Scratch scripts were written in the session scratchpad and are not committed: `probe_insight_ungated.R`, `probe_consideration.R`, `probe_gating_flip.R`, `probe_hidden_pin.py`. Each is described closely enough above to rewrite in a few minutes; the F2 probe needs headless Chrome, a copy of `extras.html`, and the harness boot pattern from `drive_chrome.py` (inject before the last `</body>`, wait for `load`, 1.5 s timer, 40 s virtual time budget, `--dump-dom`).
