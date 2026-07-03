# Tabs v2 Production Audit — 2026-07-02

Full multi-agent correctness audit of the integrated tabs v2 report system (stats engines,
tracking, patterns, qualitative, hubs, disclosure, exports, filters, R pipeline), anchored
against the real SACS-2025 and SACAP Student Annual 2025 generated reports.

**Method:** 14 code-dimension finders + 2 real-report internal-consistency anchors, every
candidate finding adjudicated by a per-file verifier that had to concretely confirm the
mechanism, reachability, and wrong output (default = refute). 84 candidates -> 63 confirmed,
20 refuted/duplicate.

**Status: OPEN — fixes in progress (Phase B).** Tick findings as they land.

| Severity | Count |
|---|---|
| Critical | 5 |
| High | 31 |
| Medium | 26 |
| Low | 1 |


## CRITICAL

### 1. [ ] modules/tabs/lib/composite_processor.R:657 (filters-composites)

**Summary:** Composite significance tests ALL column pairs globally — including Total-vs-column and cross-banner-group pairs — while letters restart per banner group and Total's letter is '-', producing wrong/ambiguous sig letters on composite rows.

**Failure scenario:** Config with a Composite_Metrics sheet, enable_significance_testing=Y, and two banner questions (e.g. Gender A/B and Region A/B/C). test_composite_significance loops i<j over ALL internal_keys: (1) Male is tested against Region 'A' (overlapping, non-disjoint samples — statistically invalid) and if significant Male's sig cell gains an 'A' that the reader can only interpret as Female; (2) each column is tested against TOTAL::Total, so a column beating Total gets key_to_letter[Total]='-' appended, printing garbage like 'A-' in the Excel Sig. row, and the Total column itself accumulates letters (it should always be '-'). Contrast run_net_difference_tests (weighting.R:1360) which correctly restricts to within-banner-group pairs.

**Fix sketch:** Mirror run_net_difference_tests: loop per banner_info$banner_info group, test only within-group pairs using that group's letters, skip the Total key entirely (leave '-').

<details><summary>Adjudicator verdict</summary>

Confirmed end-to-end. test_composite_significance (composite_processor.R:657-763) loops i<j over ALL banner_info$internal_keys, which includes TOTAL::Total first and every column across all banner groups, then maps results through key_to_letter built from banner_info$letters. banner.R assigns letters per banner question (generate_excel_letters restarts at A for each group, lines 286/342) with Total='-' (line 74). So (a) cross-banner-group pairs (e.g. Gender::Male vs Region::A) are t-tested despi

</details>

### 2. [ ] modules/tabs/lib/html_report_v2/assets/js/22_model.js:499 (disclosure)

**Summary:** applyCompositeSignificance runs after disclosure suppression and writes vs-the-rest arrows back onto suppressed cells unconditionally, and the renderer shows cell.sig even when pct is null, so a blanked below-k composite cell renders '– ▲'.

**Failure scenario:** Census study with low_base_threshold lowered to 5 (reasonable under FPC) and min_reporting_base=10, composite profile banner with a spotlight group of 7 respondents: applyDisclosureSuppression blanks the column, then applyCompositeSignificance sets cell.sig = '▲' (effCol 7 >= threshold 5) on the suppressed cells; 23_render.js line ~262 appends the arrow whenever cell.sig is truthy, so the report shows '– ▲' — telling the reader the hidden 7-person group is significantly higher/lower on each row, direction-by-direction.

**Fix sketch:** In applyCompositeSignificance's cell loop, return early when cell.suppressed (leave sig empty).

<details><summary>Adjudicator verdict</summary>

CONFIRMED by harness. applyCompositeSignificance (called at 22_model.js:641, AFTER applyDisclosureSuppression at :630) recomputes z from microdata — its only gate is effCol >= low_base_threshold (:459), not min_reporting_base — and writes cell.sig = compositeArrow(z) unconditionally at :499, overwriting the suppressed cell's cleared sig. Harness: a spotlight column of 45 respondents with k=100 ends as {pct:null, suppressed:true, sig:'▲'}. The renderer (23_render.js:254-263) appends the arrow whe

</details>

### 3. [ ] modules/tabs/lib/html_report_v2/assets/js/27d_diffs.js:132 (disclosure)

**Summary:** meanFindings on the Differences tab recomputes column means from microdata gated only by low_base_threshold, bypassing the disclosure k-gate that blanks those same columns in the crosstab.

**Failure scenario:** Report configured per the module's own doc to lock down drill-downs with min_reporting_base = N (or any k > low_base_threshold): every crosstab column is suppressed to '–', category findings vanish (their sig/pct are nulled), but meanFindings still pushes 'Engineering mean 3.2 vs rest 4.1 (n=45)' standouts because means[i].k (45) clears threshold=30 — the Differences tab publishes exact subgroup means for columns the k-gate hides everywhere else.

**Fix sketch:** Gate meanFindings arms with Math.max(threshold, TR.disclosure.minBase()) (and skip columns whose model column is flagged suppressed).

<details><summary>Adjudicator verdict</summary>

CONFIRMED. meanFindings (27d_diffs.js:111-153) recomputes per-column means from microdata gated ONLY by threshold = low_base_threshold (default 30, collectFindings line 164); grep confirms zero TR.disclosure references in 27d_diffs.js. Categorical findings are protected because they read model cells that applyDisclosureSuppression (22_model.js:563-587) nulls for any column with base < min_reporting_base — and that function's own comment claims coverage of 'crosstab / dashboard / differences / ex

</details>

### 4. [ ] modules/tabs/lib/html_report_v2/assets/js/27q_qualitative.js:501 (qual-tab)

**Summary:** Collection/hub Excel export recomputes safeDemos from the global audience gate instead of using the hub-specific gate computed in collectionMain, so a below-k hub exports full demographic tags that the screen explicitly hides.

**Failure scenario:** min_reporting_base = 10; reader builds a hub containing comments from 3 distinct respondents; no global filter active. On screen collectionMain sets hubBelowK=true, shows '🛡 tags hidden' and renders cards with dropTags. Clicking ⬇ Export calls exportCollectionXlsx, which sets safeDemos = !audienceTooSmall() = true (full sample ≥ k), so the xlsx contains every demographic tag for the 3-person hub — exactly the identifying detail the k-gate suppressed. Converse mismatch: with a sub-k global cut active and a large hub selected, the screen shows tags+text (hubs are filter-independent) but the export writes '[hidden]' everywhere.

**Fix sketch:** Pass the already-computed gate through: wire()'s data-col-export handler has qual._colview.safeDemos — change exportCollectionXlsx(island, items) to accept/use v.safeDemos instead of recomputing from TR.disclosure.audienceTooSmall().

<details><summary>Adjudicator verdict</summary>

Confirmed. exportCollectionXlsx (27q_qualitative.js:499-504) computes safeDemos solely from the global gate (!TR.disclosure.audienceTooSmall()), while collectionMain (1264-1268) computes the hub-specific gate (hubBelowK -> v.safeDemos) and the export click handler (1432-1436) calls exportCollectionXlsx(v.island, v.items) without passing it. With k>1 (project.min_reporting_base), a hub of <k distinct respondents and a healthy global audience, the screen drops tags (ctx.dropTags) and shows '🛡 tag

</details>

### 5. [ ] modules/tabs/lib/standard_processor.R:1190 (anchor-student)

**Summary:** Q009 silently loses 61% of its respondents: 837/1363 answered "I re-registered" in the data but the structure spells the option "I reregistered", and calculate_row_counts' exact safe_equal match zero-counts every unmatched value while the base still counts them.

**Failure scenario:** In the SACAP report (Q009 'This year did you register for the 1st time or did you re-register?'), the 'I reregistered' row shows 0% / n=0 in all 35 columns while the base row shows n=1363; the single-select column sums to 38% instead of 100%. All sig letters on the surviving row are computed on corrupted proportions (e.g. col H-Certificate shows 'ABDEGHK', col '1st yr' shows 'BCE' — my clean recompute from raw data rejects every one of them). Raw data confirms 837 rows contain 'I re-registered' (hyphen) vs structure OptionText 'I reregistered'. No validation checks data-value coverage against structure options, so the drop is completely silent — same engine feeds the Excel crosstabs.

**Fix sketch:** Add a data-coverage guard: after loading, for each single/multi question compare distinct non-empty data values against structure OptionText (exact + normalised); refuse or loudly warn when >0 respondents carry values that match no option. Optionally reuse micro_normalize_label as a matching fallback in calculate_row_counts.

<details><summary>Adjudicator verdict</summary>

Concretely verified against the real SACAP project, not just the claim text. Raw data (OneDrive SACAP_Student_Annual-2025_Data.xlsx) contains exactly 837 rows 'I re-registered' (hyphen) + 526 'I registered for the 1st time' (n=1363); Survey_Structure Options sheet spells it 'I reregistered' (no hyphen). safe_equal (type_utils.R:43) trims whitespace but is otherwise an exact string compare, so calculate_row_counts (cell_calculator.R:67) zero-counts all 837 while the base keeps them. The actual ge

</details>


## HIGH

### 6. [ ] modules/tabs/lib/banner.R:282 (filters-composites)

**Summary:** Standard banner internal keys are built from DisplayText, so two options sharing a DisplayText collide on the same key and both banner columns silently show the second option's respondents (the first option's data is dropped).

**Failure scenario:** Options sheet gives a banner question two options with the same DisplayText (e.g. two raw codes both relabelled 'Other'). create_banner_structure emits two columns with identical internal_keys ('Q::Other'); create_single_choice_indices then assigns subset_indices[['Q::Other']] once per option, the second overwriting the first, and column_to_banner/key_to_display collapse to one entry. Both 'Other' columns in the workbook and the v2 report display the second raw code's base and percentages; the first code's respondents vanish from the banner with no refusal or warning.

**Fix sketch:** Detect duplicated DisplayText within a banner question and refuse (CFG_BANNER_DUPLICATE_LABEL), or disambiguate keys with the option index/OptionText while keeping the display label.

<details><summary>Adjudicator verdict</summary>

Confirmed end-to-end. banner.R:279-282 builds internal_keys as paste0(banner_code, '::', options$DisplayText), so two options sharing a DisplayText yield identical keys while columns/internal_keys/letters keep both positions. banner_indices.R create_single_choice_indices (lines 194-204) matches rows by the distinct OptionText values but assigns subset_indices[[internal_key]] under the shared key; R's [[<- by name replaces the existing element, so the second option's row set overwrites the first 

</details>

### 7. [ ] modules/tabs/lib/cell_calculator.R:172 (weighted-stats)

**Summary:** create_percentage_row (and create_row_percentage_row at line 246) call calculate_weighted_percentage() without passing decimal_places, so every percentage is pre-rounded to a whole number before format_output_value re-rounds to the configured decimal_places_percent — configured decimals can never appear.

**Failure scenario:** Project config sets decimal_places_percent = 1. calculate_weighted_percentage(457, 1000) returns round(45.7, 0) = 46 (its default decimal_places = 0); format_output_value(46, "percent", decimal_places_percent = 1) then emits 46.0. Every Column % and Row % cell in the Excel tables and the v2 data layer shows X.0 instead of the true 1-dp value — each cell is wrong by up to 0.5 points, and rows stop summing to 100 in a different way than genuine 1-dp rounding would.

**Fix sketch:** Pass a high-precision value through: percentage <- calculate_weighted_percentage(row_counts[key], weighted_base, decimal_places = 10) (or divide directly) and let format_output_value do the single presentation rounding.

<details><summary>Adjudicator verdict</summary>

Confirmed. weighting.R:709 defines calculate_weighted_percentage with decimal_places = 0 default (rounds to whole number); cell_calculator.R:172 and :246 call it with only two args, then format_output_value (excel_utils.R:142 / run_crosstabs.R:523) merely re-rounds the already-integer value to the configured decimal_places_percent. Path is live: run_crosstabs.R sources both files; question_orchestrator.R:353 -> process_standard_question -> create_percentage_row/create_row_percentage_row (standar

</details>

### 8. [ ] modules/tabs/lib/data_layer_writer.R:347 (confidence-fpc)

**Summary:** No R-side validation that a configured population is at least the achieved base (checks only pop > 1), so population_size or a Population-sheet N smaller than the responding n flows through silently and the v2 report renders zero-width intervals, a clamped '100% of N' coverage note beside a visibly larger base, and NaN-erased sig letters.

**Failure scenario:** Analyst types population_size = 500 but 620 respondents answered (stale frame or typo). fpcMul(620, 500) = Infinity: every Total-column range collapses to e.g. '81–81', the base row reads 'n=620 … 100% of 500', the callout declares a near-census, and all sig letters involving that column vanish — an obviously wrong config produces a confidently 'exact' report with no console warning, violating the loud-refusal convention.

**Fix sketch:** In build_dl_columns / build_dl_project, compare each configured N against the column's achieved unweighted base and cat() a boxed WARNING (or drop the population field) when N < base; the existing .warn_unmatched_population pattern is the template.

<details><summary>Adjudicator verdict</summary>

Confirmed. R side gates population only on pop>1 (data_layer_writer.R:141,304,347; crosstabs_config.R:251-255 rejects only n<=1); .warn_unmatched_population checks label spelling only — nothing compares configured N to achieved n. JS fpcMul (21c_confidence.js:178-182) returns Infinity for nActual>=N with no n>N sanity check; wilson(p,Infinity) gives margin 0 so Total ranges render zero-width ('81–81'); coverage clamps to Math.min(n/N,1) and 23_render.js:179-183 prints '100% of N' beside the larg

</details>

### 9. [ ] modules/tabs/lib/data_loader.R:426 (r-pipeline)

**Summary:** The large-Excel CSV cache round-trips data through fwrite/fread, which re-infers column types on reload — text option codes like "01" come back as integer 1, so safe_equal's trimmed-character comparison against OptionText "01" fails and those options silently count zero on every cached run.

**Failure scenario:** A 60MB xlsx with a precoded column stored as text "01".."12" (matching Options OptionText "01".."12"). First run: read_excel keeps "01", tabs are correct, cache written. Second run loads the cache via fread, the column is now integer, as.character(1) == "01" is FALSE, and every option row for that question shows 0 frequency / 0% with the base intact — numbers changed between two runs of identical inputs with no warning.

**Fix sketch:** Write/read the cache with type fidelity: data.table::fread(csv_cache_path, colClasses="character") is not ideal for numerics, so better to persist the readxl column classes alongside the cache (or use fwrite with quote-all + fread colClasses recorded from the first load / saveRDS instead of CSV).

<details><summary>Adjudicator verdict</summary>

Confirmed end-to-end. data_loader.R:417 writes the cache with fwrite and :426 reloads with fread(data.table=FALSE) with no colClasses/keepLeadingZeros, so column types are re-inferred. Empirically reproduced in the repo's renv: fwrite writes text codes '01','02','12' unquoted and fread reads them back as integers 1,2,12, while readxl::read_excel on the first (uncached) run keeps text-stored '01' as character — so run 1 and run 2 load different data. The path is reachable from a real config: cros

</details>

### 10. [ ] modules/tabs/lib/html_report_v2/assets/js/21_stats.js:16 (weighted-stats)

**Summary:** The JS recompute engine hard-codes Z=1.96 / Z=1.2816 and never reads the project's configured alpha or bonferroni_correction, while the published letters it sits next to come from R with Bonferroni-corrected alpha (config default TRUE) — so filtered/custom-banner views and the JS-added lowercase 80% letters systematically disagree with the published/Excel letters on the same data.

**Failure scenario:** Default config (alpha=0.05, bonferroni_correction=TRUE) with a 4-column banner: R tests each pair at 0.05/6=0.0083 (z≈2.64), producing the published uppercase letters. The reader applies any filter (or builds a custom banner): 22_model.js switches to the computed model and sigLetters flags every pair with z>1.96 — a batch of new letters appears that vanish again when the filter is cleared, purely from the methodology fork, not the audience change. Likewise the dual-sig lowercase letters added to the PUBLISHED view (publishedModel low80) use raw z>1.2816 while R's Sig.2 row used 0.20/6, so the HTML shows lowercase letters the Excel deliverable does not. A project with alpha=0.01 is silently tested at 0.05 in every recomputed view while the legend claims 99%.

**Fix sketch:** Emit alpha, alpha_secondary and bonferroni_correction in TR.AGG.project (data_layer_writer already emits alpha); in sigLetters derive the per-banner critical z from alpha/choose(nTestableCols,2) via an inverse-normal helper instead of the fixed Z95/Z80 constants.

<details><summary>Adjudicator verdict</summary>

Confirmed. 21_stats.js:16-17 hard-codes Z=1.96/1.2816 and no v2 JS reads TR.AGG.project.alpha or any bonferroni flag, while the R engine that produces the published letters applies alpha/choose(k,2) when bonferroni_correction=TRUE (run_crosstabs.R:250-260), which is the default in the function signature, generate_config_templates.R:245 and qual_quant_layer.R:163. 22_model.js:604 switches to computedModel for ANY filter or custom/composite banner, so a default-config 4-column study is letter-test

</details>

### 11. [ ] modules/tabs/lib/html_report_v2/assets/js/21_stats.js:147 (filters-composites)

**Summary:** columnsFor has a missing-spec guard for composite banners but none for custom banners: a 'custom:<code>:<mode>' id whose question no longer exists dereferences null (q.net_members / q.rows) and crashes the crosstabs render.

**Failure scenario:** Analyst saves a custom banner on Q5 (28b_banners persists it in localStorage keyed by project name+wave). The report is regenerated for the same wave with Q5 renamed/dropped from the QuestionMap. The saved ★ tab still renders (25_cards.js:370 does not check the question exists); clicking it — or opening a shared URL with #banner=custom:Q5:net — sets state.banner, model.forQuestion → columnsFor → TR.d2.questionByCode('Q5') returns null → TypeError on q.net_members, and renderTab has no try/catch, leaving the tab host broken until the hash/localStorage is manually cleared.

**Fix sketch:** In the custom: branch, if q is null (or TR.MICRO.answers[code] absent) return { columns:[Total], custom:true, missing:true } exactly like the composite missing-token path; optionally filter savedBanners.all() tabs to existing questions.

<details><summary>Adjudicator verdict</summary>

Confirmed. In columnsFor (21_stats.js:143-180) the custom branch dereferences q unconditionally: questionByCode returns null for a missing code (20_data.js:153-159), then q.net_members (line 154, net mode) or TR.d2.catRows(q) -> q.rows.forEach (line 168 / 20_data.js:192, cat mode) throws TypeError. The composite branch directly above (lines 127-130) has exactly the missing-spec guard the custom branch lacks, and decodeHash validates filter question codes but sets banner unchecked (20_data.js:273

</details>

### 12. [ ] modules/tabs/lib/html_report_v2/assets/js/22_model.js:393 (confidence-fpc)

**Summary:** A full-census column (base >= configured population N) gets ciBase = Infinity from conf.fpcMul, and applyFpcSignificance feeds Infinity into propZ, which returns NaN — silently erasing ALL significance letters for that column and for every other column tested against it, after having already overwritten R's published letters.

**Failure scenario:** Unweighted report, Population sheet gives a subgroup N=80 and all 80 responded (the feature's headline 'full census' case, or population_size set equal to/below achieved n). fpcBase(80,80,80)=Infinity; in applyFpcSignificance pcells become {x: p*Infinity (=Infinity, or NaN when p=0), base: Infinity}; propZ computes pooled=Inf/Inf=NaN, z=NaN (verified in node), so no letter is added and no null-guard fires. The default view shows NO sig letters on or against that column, replacing R's published letters with blanks — while the intervals correctly collapse to zero width, telling the reader the numbers are exact but the differences 'not significant'.

**Fix sketch:** In applyFpcSignificance (and sigLetters/propZ), special-case an infinite base: treat SE contribution as 0 (a census column's proportion is exact), or cap fpcMul at a large finite value so z stays finite; add a null/NaN guard in propZ (if (!isFinite(z)) return null) so NaN can never silently drop letters.

<details><summary>Adjudicator verdict</summary>

CONFIRMED by executing the production JS (node harness). publishedModel sets ciBase = fpcBase(base, base, N) = Infinity when base >= N (21c_confidence.js fpcMul is designed to return Infinity). applyFpcSignificance builds pcells {x: p*Infinity, base: Infinity}; propZ(Inf, Inf, ...) computes pooled = NaN, every guard passes NaN, z = NaN — verified propZ returns NaN, and sigLetters adds no letter (NaN > 1.96 is false). Harness shows R's published letter 'B' on the comparison column is erased after

</details>

### 13. [ ] modules/tabs/lib/html_report_v2/assets/js/22_model.js:318 (confidence-fpc)

**Summary:** attachIntervals' mean branch sizes mean/Index/NPS confidence intervals on the raw unweighted base (col.ciBase ?? col.base) with no weighted handling, so on every weighted report mean CIs use n instead of the Kish effective n — systematically too narrow and inconsistent with both the proportion branch (which uses col.baseEff) and the sig tests (Welch on effBase).

**Failure scenario:** Weighted report (e.g. CCS), interval view on, Index/mean row: column has n=400, Kish n_eff=280 (design effect 1.43). CI half-width shown is z·SD/√400 instead of z·SD/√280 — about 16% too tight. Reader sees two columns' mean CIs not overlapping while the sig test (correctly sized on n_eff) prints no letter, an internal contradiction on the same row. On a weighted population report it is doubly wrong: ciBase = fpcBase(unweighted n, unweighted n, N), applying FPC to the wrong base while skipping the design effect entirely.

**Fix sketch:** Mirror the proportion branch: var weighted = !!(col.baseW > 0 && col.baseEff > 0); ciBase = weighted ? col.baseEff : (col.ciBase != null ? col.ciBase : base). For weighted population reports, if FPC is intended, combine: fpcBase(col.baseEff, col.base, N).

<details><summary>Adjudicator verdict</summary>

CONFIRMED by harness. attachIntervals' mean branch (22_model.js:313-319) uses ciBase = col.ciBase ?? col.base with no weighted handling; on a weighted report col.base is the raw unweighted n. Measured mean-CI half-width = z*SD/sqrt(400) exactly, while the proportion row in the SAME table uses baseEff=280 (Wilson on n_eff, verified equal to conf.wilson(p,280)) — so mean/Index/NPS intervals are ~sqrt(deff) too narrow and internally inconsistent with both the proportion intervals and the effBase-si

</details>

### 14. [ ] modules/tabs/lib/html_report_v2/assets/js/22_model.js:634 (confidence-fpc)

**Summary:** applyFpcSignificance runs AFTER applyDisclosureSuppression and recomputes letters treating a suppressed column's nulled cells as 0% (x = 0 with its real base), re-adding letters that suppression had just stripped — visible columns can be flagged 'significantly higher than' a blanked column based on a phantom 0%.

**Failure scenario:** Unweighted population report with min_reporting_base = 50 (above the low_base_threshold of 30). Column D has base 40: disclosure blanks its cells and strips 'D' letters from the other columns. applyFpcSignificance then rebuilds pcells with D as {x: 0.pct·null → 0, base: 40} (>= 30, so it participates); a visible column at 60% vs D's phantom 0% yields a huge z, and 'D' reappears in the visible column's sig string — a significance claim against a column showing only '–', derived from a fabricated 0%.

**Fix sketch:** In applyFpcSignificance, skip suppressed columns (cell.suppressed / col.suppressed) by giving them base 0 in pcells/mean cells, or run the FPC re-letter before applyDisclosureSuppression so the existing letter-stripping covers it.

<details><summary>Adjudicator verdict</summary>

CONFIRMED by harness. In forQuestion, applyDisclosureSuppression (called at :630) nulls a below-k column's cells and strips its letters; applyFpcSignificance (called at :634, unweighted population reports) then rebuilds pcells mapping the suppressed cell's null pct to x=0 with base = sizeAt(ci) (raw or FPC'd base), and sigLetters only excludes columns below low_base_threshold — so with min_reporting_base=50 > threshold=30, a suppressed base-40 column participates as a fabricated 0%. Harness: vis

</details>

### 15. [ ] modules/tabs/lib/html_report_v2/assets/js/22_model.js:244 (model-render)

**Summary:** netRow prefers per-respondent box membership over net_members for EVERY NET row of a boxed question and divides by boxCounts' box-only base, so under a filter or custom banner NET percentages are inflated (or zero) whenever any answered respondent has no box.

**Failure scenario:** A shown 5-pt scale where BoxCategory is defined only for options 4-5 ('Agree (Top 2)'): micro_box_membership gives 1-3 answerers box=NA. Apply any audience filter -> computedModel -> netRow takes the boxes branch; boxCounts base counts only b!==null respondents, so Top-2 = hit/base = 100% instead of the true ~62%. Conversely a members-based NET row (e.g. a Net_Definitions NET whose label is not a BoxCategory) on the same question computes 0% because no respondent's box equals its row index. 27d_diffs restPct (line 78-80) and applyCompositeSignificance both divide the same box hits by the FULL answered base (colTab.wbase), so the crosstab, Differences and composite views show different percentages for the same NET.

**Fix sketch:** Mirror applyCompositeSignificance's precedence: use net_members (netCounts) when the row has members; only fall back to boxCounts for member-less box rows, and take the denominator from the full tabulate base (tabs[i].wbase/effBase) rather than boxCounts' own wbase, matching restPct.

<details><summary>Adjudicator verdict</summary>

CONFIRMED by harness. netRow (22_model.js:244) routes EVERY non-diff NET row of a boxed question through boxCounts, whose base only counts respondents with a non-null box (21_stats.js:282-298). micro_box_membership (microdata_writer.R:407-434) assigns NA to answerers whose option has no BoxCategory — a real shape explicitly documented as occurring on SACS ('Neutral on a shown satisfaction scale', 27d_diffs.js:68-75, where the SAME defect was fixed for restPct and in applyCompositeSignificance bu

</details>

### 16. [ ] modules/tabs/lib/html_report_v2/assets/js/22_model.js:392 (anchor-sacs)

**Summary:** The FPC significance re-letter reconstructs each proportion from the rounded displayed percentage (cell.pct/100) instead of the exact count (cell.n/base) that the model carries, flipping letters on borderline pairs.

**Failure scenario:** In SACS-2025, 12 displayed 95% letters among non-suppressed columns are not supported by the exact counts. Hand-verified example: Q15 'Somewhat Agree' Head Office (n=14/62 = 22.58%, shown 23%) vs Online Campus (n=3/24 = 12.5%, shown 12%) on FPC bases 226.4/70.0 gives z=1.996 from the rounded values (letter F displayed) but z=1.836 from the exact counts — not significant at 95%. The symmetric error also hides ~15 genuinely significant letters (e.g. Q05 'Somewhat Agree' Academic general vs Finance). attachIntervals in the same file already prefers cell.n/base; the sig path does not.

**Fix sketch:** In applyFpcSignificance's pcells (and the mean-row SD pairs), use p = cell.n != null ? cell.n / col.base : cell.pct/100, mirroring attachIntervals (22_model.js:340-341), so the test runs on exact proportions scaled to the FPC base.

<details><summary>Adjudicator verdict</summary>

CONFIRMED. The published Column % values are rounded BEFORE reaching the data layer: create_percentage_row (cell_calculator.R:149-181) formats via format_output_value with config$decimal_places_percent, default 0 (crosstabs_config.R:179, run_crosstabs.R:515-532) — so cell.pct in the v2 model is an integer percent by default. applyFpcSignificance (22_model.js:390-394) reconstructs x = (cell.pct/100)*ciBase from that rounded value even though the exact published count rides in cell.n (r.n carries 

</details>

### 17. [ ] modules/tabs/lib/html_report_v2/assets/js/22w_waves.js:280 (weighted-stats)

**Summary:** sigPair assumes effBase === base implies an unweighted point and then uses p.x as an exact respondent count — but on a weighted report p.x is the published WEIGHTED frequency while base is the UNWEIGHTED base, so any weighted design whose Kish n_eff equals the raw n (constant expansion weights, or n_eff rounding up to n) feeds a weighted count over an unweighted base into propZ.

**Failure scenario:** Project weighted with a constant expansion weight (e.g. every respondent weight = 120 to project to the population — a self-weighting sample scaled to universe totals): Kish n_eff = n exactly, so effBaseOfPoint === base and sigPair returns {x: 120×count, base: n}. attachDeltas' current point (curX = row.cells[0].n, the weighted frequency) then tests 120× the true count against n: pooled p > 1 makes propZ return null and every wave-on-wave sig flag silently disappears (or, for small constant weights, z is inflated and movements over-flagged). The R engine handles the same data correctly.

**Fix sketch:** Don't infer weightedness from eff === base; carry an explicit weighted flag (or compare x against base, or always use the %-times-effBase form when the report is weighted: TR.MICRO.weights present).

<details><summary>Adjudicator verdict</summary>

CONFIRMED. sigPair (22w_waves.js:278-282) treats eff === base as 'unweighted' and passes p.x through as an exact count. On a weighted report the published cell n is the WEIGHTED frequency while columns[0].base is the UNWEIGHTED n (explicit in data_layer_writer.R:577-580: 'published cell counts are WEIGHTED but the base row shows the UNWEIGHTED n'); attachDeltas sets curX = row.cells[0].n and curEff = col0.baseEff (nEff). calculate_effective_n (weighting.R:366-401) normalizes by mean(w) internall

</details>

### 18. [ ] modules/tabs/lib/html_report_v2/assets/js/22w_waves.js:493 (tracking)

**Summary:** The 'Standard Deviation' row (kind 'mean') is tracked as if it were the mean: its wave history resolves to each wave's MEAN (via scores/stats.index) while its current cell holds the SD, producing a huge fake sig-flagged decline.

**Failure scenario:** Tracking report with show_standard_deviation=TRUE on a Rating/Likert/NPS question (standard_processor.R emits RowLabel 'Standard Deviation' as a mean_type row; 22_model puts the SD in cell.mean). attachDeltas builds series via meanValue(): microdata waves return meanOfScores (the wave mean, e.g. 7.9); bridge waves return stats.index (also the mean). Current value = row.cells[0].mean = the SD (e.g. 1.8). row.delta = 1.8 - 7.9 = -6.1 flagged significant by the Welch test; the wave strip (mean-priority top-3 rows) and trend chart plot a line collapsing from ~8 to ~1.8, and 27t_tracking.js metricList('key') (line 129) surfaces 'Standard Deviation' as a key tracking metric. 22_model.js guards this row everywhere with isStdDevRow(); the wave engine and tracking workspace never do.

**Fix sketch:** Exclude std-dev rows from tracking: in attachDeltas/waves.series and 27t metricList, skip rows matching the isStdDevRow test (expose it on TR.model), mirroring 22_model.js lines 164/371/465.

<details><summary>Adjudicator verdict</summary>

CONFIRMED. standard_processor.R:522 emits RowLabel 'Standard Deviation' (RowType 'StdDev') when show_standard_deviation=TRUE; data_layer_writer.R:503 includes 'Std Dev'/'StdDev' in mean_types so the row lands in the v2 payload as kind='mean' with the SD value in the mean slot (publishedModel puts it in cell.mean). 22_model.js guards this row with isStdDevRow at lines 164, 371 and 465, but 22w_waves.js and 27t_tracking.js contain NO such guard (verified by grep). In attachDeltas (22w_waves.js:493

</details>

### 19. [ ] modules/tabs/lib/html_report_v2/assets/js/23y_xlsx.js:54 (exports)

**Summary:** TR.fmt.escapeXml only escapes &<>"' and does not strip XML-1.0-illegal control characters, so a verbatim containing e.g. \x0B or \x1A produces an invalid worksheet/slide part and Excel/PowerPoint reports corrupt content.

**Failure scenario:** A survey open-end pasted from Excel/Word contains a vertical tab (\x0B) or other C0 control char; it survives the R->JSON->JS pipeline. The reader clicks "Export comments" (27q_qualitative.js uses xlsx.download with keepText) or pins a hub exhibit with that quote into the PPTX (para() -> esc() -> <a:t>). The generated xl/worksheets/sheet1.xml or slide XML contains a literal control byte, which is illegal in XML 1.0 — Excel shows "We found a problem with some content" and strips the sheet; PowerPoint demands repair.

**Fix sketch:** In fmt.escapeXml (01_format.js:19), also .replace(/[ --]/g, "") before entity escaping; both the xlsx cell() and all PPTX text runs share it.

<details><summary>Adjudicator verdict</summary>

CONFIRMED end-to-end by running the actual shipped code. (1) TR.fmt.escapeXml (01_format.js:19-23) escapes only &<>"' — no XML-1.0 illegal-char stripping. (2) R side preserves control chars: qual_island_builder.R's PII scrub only replaces email/URL/phone patterns, and serialize_data_layer/qual_report.R call jsonlite::toJSON with no sanitization; verified in R that a \x0B verbatim serialises as  (valid JSON) and round-trips intact, so JSON.parse in the browser restores the raw control char into 

</details>

### 20. [ ] modules/tabs/lib/html_report_v2/assets/js/26_filter.js:223 (filters-composites)

**Summary:** In the value picker, mixing a box grouping with category (or expanded NET) values in one filter sets box=true for the WHOLE row set, so the category row indexes are matched against box membership and those selections are silently dropped.

**Failure scenario:** Real reports never carry net_members (data_layer_writer omits them), so on a shown-scale question with BoxCategory rollups the picker offers both category values ('Very dissatisfied' = c0) and box groupings ('Top-2 box' = b7). Analyst ticks both and applies: filter {q, rows:[0,7], box:true}. stats.mask (21_stats.js:55) then tests boxes[r] ∈ {0,7} — row 0 is a category index, no respondent's box equals it — so the audience is 'Top-2 box' only, not the promised union; every table, base, and sig letter is computed on the wrong audience while the chip claims 'Very dissatisfied / Top-2 box'. On reload, d2.decodeHash's box validation (all rows must be kind 'net') silently drops the filter altogether, so a shared URL shows the unfiltered report.

**Fix sketch:** Split a mixed selection into two filter entries (one box:true with only b-rows, one plain with c/n-rows) — mask already ANDs entries... note that ANDing changes semantics; better: store per-filter row type and let stats.mask OR box hits and answer hits within one filter.

<details><summary>Adjudicator verdict</summary>

Confirmed end-to-end. pickValues (26_filter.js:216-234) merges category ('c') and box ('b') selections into one rows list and sets a single filter-level box=true if any box grouping is ticked. stats.mask (21_stats.js:49-58) then evaluates the WHOLE filter against per-respondent box membership; boxes[r] only ever holds net-row indexes (micro_box_membership builds the map from net-kind rows only), so category row indexes can never match and those selections are silently dropped — audience becomes 

</details>

### 21. [ ] modules/tabs/lib/html_report_v2/assets/js/27d_diffs.js:63 (diffs-sig)

**Summary:** Under an active filter, a finding's group value and its 'rest' value are computed on different denominators for box NET rows on shown scales with partial BoxCategory coverage: restPct uses net_members/full answered base (netCounts, line 63-67) while the model cell it is compared against comes from computedModel netRow which checks boxes FIRST (22_model.js:244) and divides by the box-only base (respondents with any box), silently dropping no-box respondents (e.g. Neutral) from the group's denominator only.

**Failure scenario:** Shown 5-point satisfaction scale where only 'Top 2' (options 4,5) and 'Bottom 2' (1,2) carry a BoxCategory and Neutral carries none (the exact SACS shape the comment at lines 70-75 documents: box base 61% vs 90%). Reader applies any audience filter, opens Where-groups-differ: the group bar shows the box-based % (e.g. 90%-style inflation, hit/box-answered) while 'The rest' bar shows the full-base % (hit/all-answered) — a fabricated 20-30pp gap with a 'statistically ahead' verdict, and the crosstab NET % itself no longer matches the published R convention. The unfiltered view is unaffected (published values), which is why the earlier SACS fix to restPct alone did not surface this.

**Fix sketch:** Make 22_model.js netRow use the same precedence as restPct and applyCompositeSignificance: try net_members first; when only boxes exist, take the numerator from boxCounts but the denominator (wbase/effBase) from stats.tabulate's full answered base. Add a test fixture with a shown scale whose BoxCategory covers only some options.

<details><summary>Adjudicator verdict</summary>

CONFIRMED. The R writer never emits net_members (data_layer_writer.R:11 says 'omitted in this first cut'), so every real-report box NET takes 22_model.js:244 netRow->netRowFromCounts, whose pct = boxCounts.n/boxCounts.wbase — a BOX-ONLY denominator (21_stats.js boxCounts skips boxes[r]==null). micro_box_membership (microdata_writer.R:407-434) maps options with no BoxCategory (e.g. Neutral) to NA, so on a shown scale with partial coverage the box base < full answered base. R publishes box-NET % o

</details>

### 22. [ ] modules/tabs/lib/html_report_v2/assets/js/27d_diffs.js:90 (diffs-sig)

**Summary:** The no-microdata fallback for 'the rest' divides published WEIGHTED counts by UNWEIGHTED bases in a weighted report ((totalCell.n - groupCell.n) / (totalBase - groupBase)), since publishedModel carries weighted frequencies in cell.n but model.columns[i].base is q.bases[ci].n (unweighted); the identity is only exact for unweighted designs.

**Failure scenario:** Weighted project where build_microdata() fails (run_crosstabs.R:732-739 explicitly degrades the report to published-only and still ships it). The Differences view still renders: for a banner column whose respondents are up-weighted (e.g. column Σw=250 over n=200), every 'rest' percentage is scaled by the rest's mean weight — rest can read >100%, gaps and +Xpp verdicts are wrong, and a group genuinely ahead can display as behind. Same wrong rest also feeds the two-bar comparison.

**Fix sketch:** In restPct's fallback, detect a weighted report (TR.AGG.project.weighted or model.columns[i].baseW) and either divide by the weighted bases (baseW) when present, or return null so the line falls back to the overall figure instead of printing a wrong rest.

<details><summary>Adjudicator verdict</summary>

CONFIRMED. In publishedModel, cell.n = r.n[ci] which data_layer_writer.R explicitly documents as the WEIGHTED published Frequency in weighted designs, while columns[].base = q.bases[ci].n (unweighted). restPct's no-microdata fallback (27d_diffs.js:88-90) computes (totalCell.n - groupCell.n)/(totalBase - groupBase), mixing weighted counts with unweighted bases — only exact when weights are all 1 (the comment itself admits 'exact when unweighted'). Path reachable: run_crosstabs.R:727-739 catches b

</details>

### 23. [ ] modules/tabs/lib/html_report_v2/assets/js/27f_takeout_data.js:162 (patterns-takeout)

**Summary:** Census reporting floor reads proj.min_report_base but the data layer emits proj.min_reporting_base, so the analyst's configured disclosure k is silently ignored (also line 242 in gatherCellFamily).

**Failure scenario:** Census study (population_size set) with min_reporting_base = 10: data_layer_writer.R writes proj$min_reporting_base = 10, 27f looks up the non-existent proj.min_report_base, gets undefined, and falls back to MIN_CENSUS_BASE = 5. A department column with n = 6-9 respondents then appears in group portraits, the split pattern, and the Welch/FDR cell family with its mean vs the overall — identifying subgroup detail below the k the qualitative tab and the rest of the report enforce.

**Fix sketch:** Read proj.min_reporting_base (same key as 21d_disclosure.js) in both gatherColumnStrain and gatherCellFamily; treat non-numeric as absent and take max(k, MIN_CENSUS_BASE).

<details><summary>Adjudicator verdict</summary>

CONFIRMED mechanism: data_layer_writer.R:150 writes proj$min_reporting_base; 27f lines 162/242 read proj.min_report_base, a key no R code ever writes (grep: only this JS file references it), so the census floor is always MIN_CENSUS_BASE=5 and the analyst's configured k is silently ignored. The scenario is partially over-claimed: portraits/split/strain go through views._modelFor -> model.forQuestion -> applyDisclosureSuppression (22_model.js:630), which blanks below-k columns using the CORRECT mi

</details>

### 24. [ ] modules/tabs/lib/html_report_v2/assets/js/27f_takeout_data.js:169 (patterns-takeout)

**Summary:** The Patterns tab computes portraits/apex/areas through views._modelFor, which applies the live audience filter, while the FDR/sign-test gate (gatherCellFamily) and bimodality scan run on unfiltered TR.MICRO — and the shell hides the filter bar on this tab claiming it summarises the published view.

**Failure scenario:** Reader applies a filter (e.g. Gender = Female) on Crosstabs, then opens Patterns: the filter bar disappears (24_shell.js:148, 'summarises the published view'), yet every KPI, portrait gap, split and area mean is recomputed on females only — numbers that match no published crosstab total, with no visible filter cue, and the reliability ribbon reports the filtered n/response-rate as if it were the study. Meanwhile the consistency gate is computed on the FULL sample: a group directionally consistent among females but mixed overall gets consistent === false and its portrait is deleted (27e:224), while a full-sample-consistent group passes the gate against filtered evidence it doesn't support.

**Fix sketch:** Pick one frame: pass [] instead of TR.d2.state.filters for all takeout gathering (truly published view, matching the hidden bar), or apply the same TR.stats.mask to gatherCellFamily/gatherBimodality and render the active-filter chips on the tab.

<details><summary>Adjudicator verdict</summary>

CONFIRMED end-to-end. Filters persist in TR.d2.state.filters across tabs; 24_shell.js:147-148 hides the filter bar on takeout with the comment 'summarises the published view'. But 27f's gatherLevels/gatherColumnStrain use views._modelFor (27_views.js:61-65), which passes TR.d2.state.filters, so every KPI, portrait gap, split and area mean — plus gatherReliability's n, moePct and responseRate (n/population) — is computed on the filtered audience with no visible cue. Meanwhile gatherCellFamily (27

</details>

### 25. [ ] modules/tabs/lib/html_report_v2/assets/js/27q_qualitative.js:362 (qual-tab)

**Summary:** When the audience is below the disclosure threshold the drawer withholds the entire comment list (even the count), but the ⬇ Export button is still rendered and emits one row per comment (ID/idx, noteworthy tier, sentiment, themes) for the sub-k cut.

**Failure scenario:** min_reporting_base = 10; reader applies a composite cut isolating 4 respondents ('Finance · female · 10y+'). drawerHtml shows only the disclosure note ('even the comment count could identify'), and the theme crosstab suppresses the column — but controlsHtml still renders Export, and the handler exports visibleRecords over that 4-person audience: the xlsx reveals exactly how many of them commented, each comment's sentiment, noteworthy tier and themes — the per-cell detail the k-gate suppresses on screen (demos/text are '[hidden]' but the row-level metadata is not).

**Fix sketch:** In the data-qual-export handler (or exportXlsx), refuse/no-op when TR.disclosure.audienceTooSmall(), mirroring drawerHtml's gate; optionally hide the Export button in controlsHtml below k.

<details><summary>Adjudicator verdict</summary>

Confirmed. Below k, drawerHtml (1059-1062) withholds the entire list including the count, but controlsHtml (859-894) has no disclosure gate and still renders the ⬇ Export button; the handler (1427-1431) exports visibleRecords over the cut-masked audience. exportRows (341-357) with safeDemos=false hides only demos and verbatim text — each row still carries ID/idx, Noteworthy tier, Sentiment and the Themes list, and the row count reveals how many in the sub-k cut commented. This is per-comment det

</details>

### 26. [ ] modules/tabs/lib/html_report_v2/assets/js/27q_qualitative.js:871 (disclosure)

**Summary:** controlsHtml renders live sentiment-split counts (and the header shows the answered count) for a below-k audience — the prevalence board, crosstab and drawer are all disclosure-gated but the controls row between them is not.

**Failure scenario:** min_reporting_base=10, composite filter 'Finance · female · 10y+' matches 3 respondents: the board, crosstab and comment list all show the 🛡 withheld note (drawerHtml's own comment says even the comment count could identify), yet the sentiment filter row still renders 'All 3 · Positive 1 · Mixed 0 · Negative 2' computed over that 3-person cut, and the header shows '3 of 120 answered' — per-cut sentiment detail on an identifiable named cut.

**Fix sketch:** In mainHtml, when TR.disclosure.audienceTooSmall(), render controlsHtml without the sentiment counts (or suppress the whole controls row alongside the drawer).

<details><summary>Adjudicator verdict</summary>

Confirmed. mainHtml (827-843) assembles headerHtml + chart + controlsHtml + drawerHtml; prevalenceHtml (900-902), crosstabHtml (989-991) and drawerHtml (1059-1062) each gate on audienceTooSmall(), but headerHtml (845-854) renders 'N of M answered' from the cut audience and controlsHtml (870-881) renders live sentiment counts via sentimentCounts(poolBeforeSentiment(q, st, audience)) over the same sub-k audience. On a named below-k composite cut this displays the commenter count and its positive/m

</details>

### 27. [ ] modules/tabs/lib/html_report_v2/assets/js/27t_tracking.js:204 (tracking)

**Summary:** Segment current point for proportion metrics pairs the WEIGHTED published count (segCell.n) with the UNWEIGHTED column base and omits effBase, so weighted-report segment wave-over-wave significance runs on an inconsistent x/n.

**Failure scenario:** Weighted tracker with segment history (bridge sidecars): trk.currentFor(metric, segNorm) returns { base: model.columns[ci].base (unweighted n), x: segCell.n (weighted count — 22_model sets cell.n to the weighted Frequency) } with no effBase. In 22w propLevel, effBaseOfPoint falls back to base, so sigPair takes the eff===base branch and tests x=weightedCount on n=unweightedBase — a proportion that differs from the displayed % (can exceed 1 when the segment's weights average >1). Explorer/Visualise segment sig markers are then wrong (over- or under-flagged) on every weighted study, unlike the Total path which correctly carries effBase (line 188).

**Fix sketch:** Return effBase: (model.columns[ci].baseEff > 0 ? baseEff : base) from the segment branch and null out x when the report is weighted, so sigPair recomputes x = value/100 * n_eff exactly like the Total path.

<details><summary>Adjudicator verdict</summary>

CONFIRMED. On a weighted report the published model's columns[ci].base is the UNWEIGHTED n while cell.n is the WEIGHTED Frequency (data_layer_writer.R:573-576, 22_model.js sigCell comment). trk.currentFor's segment branch (27t_tracking.js:191-206) returns {base: unweighted n, x: weighted count} and omits effBase, unlike the Total branch (line 186-189) which carries m0.baseEff. In 22w_waves.js effBaseOfPoint falls back to base, so sigPair takes the eff===base branch and propLevel z-tests p = weig

</details>

### 28. [ ] modules/tabs/lib/html_report_v2/assets/js/29_export.js:658 (exports)

**Summary:** buildTrendChart sorts the wave axis with years.sort() (lexicographic string sort), so numeric wave_order keys of differing digit lengths plot out of chronological order.

**Failure scenario:** A tracker whose config wave_order values are sequential wave numbers (…, 9, 10, 11) rather than 4-digit years: sort() orders them [10, 11, 9], so the PPTX trend line's categories and connecting segments run out of time order — wave 9 appears after wave 11, making the exported trend read as a spurious drop/spike. (The on-screen trendChart at 23za_trend.js:201 shares the same default sort, so this reproduces in the report too — fix both.)

**Fix sketch:** years.sort(function(a,b){ return a-b; }) in buildTrendChart and in render.trendChart.

<details><summary>Adjudicator verdict</summary>

Confirmed. years elements are genuine numbers (tracking_island.R wave_order_key returns numeric; JS currentYear() parseFloat), and Array.prototype.sort() with no comparator sorts them as strings, so keys crossing a digit-length boundary ([9,10,11] -> [10,11,9]) plot out of chronological order in the native PPTX trend (29_export.js:658) AND on-screen (23za_trend.js:201 uses the same default sort). The R side deliberately orders waves numerically (tracking_island.R:229 waves[order(keys)]); the JS 

</details>

### 29. [ ] modules/tabs/lib/html_report_v2/assets/js/30_story.js:536 (hubs-collection)

**Summary:** A stale 'composite' story pin whose category no longer resolves makes compositeMatrix() return null, which crashes the editable PPTX export (fitMatrix dereferences matrix.body) and present mode (matrixTable dereferences matrix.head) — the null guard exists only for stale question pins.

**Failure scenario:** Analyst pins 'Composite — Perceptions' (kind:'composite'), then the pin travels to a regenerated/next-wave report via the saved-copy story island or 'Import JSON' (the advertised carry-forward path) where that section was renamed or its mean/index rows removed. compositeMatrix() finds no questions and returns null. 'Download .pptx (editable)' then throws in exporter.matrixSlide → fitMatrix (matrix.body.length of null) before downloadDeck's try/catch, so the whole deck silently fails to download (console error only, no toast); '▶ Present' throws in renderPresent → matrixTable (matrix.head.map of null) when reaching that slide, leaving the overlay stuck/blank. itemHtml already guards matrix-null for the tab view, and line 686 explicitly handles stale question pins, so this is an inconsistency, not design.

**Fix sketch:** Guard the null matrix in slidesFor/renderPresent (skip the slide or show the existing 'Unavailable exhibit' body when compositeMatrix/heatmapMatrix returns null), or make matrixSlide/matrixTable tolerate a null matrix.

<details><summary>Adjudicator verdict</summary>

CONFIRMED by reading the full chain and reproducing the mechanism in node. compositeMatrix() (30_story.js:271-292) returns null when no question matches item.category with a mean row (line 280). slidesFor (line 536) passes that null straight into TR.exporter.matrixSlide, which calls fitMatrix(matrix, 15) (29_export.js:885) and dereferences matrix.body.length (29_export.js:367) -> TypeError. Critically, the throw happens while evaluating slidesFor(load()) as the argument at 30_story.js:618, i.e. 

</details>

### 30. [ ] modules/tabs/lib/microdata_writer.R:302 (filters-composites)

**Summary:** micro_banner_vars maps respondents to columns via option DisplayText, but for a BoxCategory banner (BannerBoxCategory='Y') the column labels are BoxCategory names — the lookup never matches, so every respondent gets -1 and the whole banner group tabulates to base 0 under any v2 filter/recompute.

**Failure scenario:** Project with a box-category banner (e.g. Satisfaction grouped into 'Satisfied (4-5)' / 'Dissatisfied (1-2)'). In the v2 report the analyst adds any audience filter — the advertised single audience control. lbl_to_agg is keyed by box-category names ('Satisfied (4-5)') while labels = disp_map[raw] yields option DisplayTexts ('Very satisfied'), so agg is all NA → banner_vars all -1 → stats.columnsFor builds all-zero member arrays → every column of that banner shows base 0 / '–' with no warning, silently claiming nobody in the filtered audience is Satisfied. Multi-mention banner questions whose data lives in slot columns (CODE_1..CODE_k, root column absent) hit the same all -1 path.

**Fix sketch:** For boxcat groups map raw value → BoxCategory (as micro_box_membership does) → column index; for multi-mention groups OR across the slot columns; or at minimum have the JS treat an all -1 banner_vars group as 'not recomputable' instead of rendering base-0 columns.

<details><summary>Adjudicator verdict</summary>

Confirmed. For BannerBoxCategory='Y' banners, banner.R:314-357 sets column labels/key_to_display to BoxCategory names ('Satisfied (4-5)'), while microdata_writer.R:299-303 maps respondents via micro_display_map to option DisplayText and looks that up in lbl_to_agg keyed by BoxCategory names — guaranteed miss, whole group emits -1 for every respondent. Multi-mention banners hit the same all -1 path because only the root column survey_data[[qcode]] is read (slot columns {code}_1..k ignored, and qc

</details>

### 31. [ ] modules/tabs/lib/microdata_writer.R:109 (r-pipeline)

**Summary:** For multi-mention questions the microdata value->row map is keyed by display labels (DisplayText) while the raw data holds OptionText, because micro_display_map matches options with QuestionCode == code exactly but multi-mention options are keyed {code}_1..{code}_N — so raw answers don't resolve whenever DisplayText differs from OptionText.

**Failure scenario:** Multi-mention Q05 has Options rows keyed Q05_1..Q05_4 with OptionText "Brand A (incl. sub-brands)" and DisplayText "Brand A". micro_value_index_map's source-2 lookup (micro_display_map("Q05")) returns NULL (no option row has QuestionCode=="Q05"), leaving only the label map keyed "Brand A". Respondents' stored value "Brand A (incl. sub-brands)" misses both exact and normalised maps, so micro_answers_multi records answered-with-no-displayed-mention (integer(0)). In the v2 report every live filter or "+ Custom…" banner recomputes that option to 0% (base intact) while the published unfiltered view shows the correct figure — a silent display/recompute mismatch the researcher sees as the option collapsing to zero the moment any filter is applied.

**Fix sketch:** In micro_display_map (or micro_value_index_map), also collect option rows whose QuestionCode matches ^{code}_\d+$ so multi-mention OptionText->DisplayText->row-index mapping works, mirroring prepare_question_data's option lookup.

<details><summary>Adjudicator verdict</summary>

Confirmed. The codebase convention is that multi-mention options are keyed under slot codes {code}_1..{code}_N (question_orchestrator.R:93-98 loads them by prefix pattern with the comment 'Multi-mention uses column names as QuestionCode in Options'), so micro_display_map(dl_q$code) with exact QuestionCode==code (microdata_writer.R:49-51) returns NULL for every multi-mention question — source 2 of micro_value_index_map never fires. The exact map then contains only data-layer row labels, which are

</details>

### 32. [ ] modules/tabs/lib/microdata_writer.R:381 (r-pipeline)

**Summary:** micro_scores_for_question feeds the v2 live-mean recompute raw as.numeric values for Numeric questions with no Min_Value/Max_Value filtering, so filtered/custom-banner means include sentinel codes the published mean excludes.

**Failure scenario:** Same 'Hours lost' question with Max_Value=24 and 999 sentinels: published (unfiltered) mean shows 5.1, but as soon as the reader applies any live filter or custom banner in the v2 report, the recomputed mean uses the raw scores including 999s and jumps to e.g. 41.3 — the number visibly contradicts the published figure and is wrong.

**Fix sketch:** In micro_scores_for_question, read Min_Value/Max_Value from survey_structure$questions for Variable_Type=="Numeric" and NA-out out-of-range scores, matching calculate_numeric_statistics.

<details><summary>Adjudicator verdict</summary>

Confirmed. The published Numeric mean applies Min_Value/Max_Value filtering (numeric_processor.R:374-397 drops values outside the range before computing mean/median/sd, optionally also outliers), but micro_scores_for_question (microdata_writer.R:381-382) emits sc <- as.numeric(raw) with no Min/Max filtering. The data layer emits kind='mean' rows for Numeric questions (data_layer_writer.R:540-548), Variable_Type 'Numeric' is explicitly supported (microdata_writer.R:379), and stats.indexMeans (21_

</details>

### 33. [ ] modules/tabs/lib/qual_quant_layer.R:70 (qual-tab)

**Summary:** Theme option rows are keyed <sheetcode>_<i>, and the engine selects Multi_Mention options by the unanchored prefix regex '^<code>_', so a workbook whose sheet codes are prefixes of one another (QUAL_CULTURE vs QUAL_CULTURE_STAFF) leaks one question's theme options into the other's crosstab.

**Failure scenario:** Standalone comment report from a workbook with sheets 'Culture' (→ QUAL_CULTURE) and 'Culture Staff' (→ QUAL_CULTURE_STAFF). Processing QUAL_CULTURE, question_orchestrator.R matches options with grepl('^QUAL_CULTURE_') which also captures QUAL_CULTURE_STAFF_1..m: the Culture table gains the Staff question's themes — a shared label like 'Communication' appears as a duplicated row and a Staff-only theme appears as a phantom 0% row — wrong theme table and sig rows in the shipped report.

**Fix sketch:** Make generated codes prefix-free (e.g. suffix a sheet ordinal: QUAL_01_CULTURE) or tighten the orchestrator's option match to '^<code>_[0-9]+$'.

<details><summary>Adjudicator verdict</summary>

Confirmed end-to-end. qual_sheet_code() (qual_workbook_reader.R:325-330) derives codes by slugging sheet names with no collision check, so 'Culture'→QUAL_CULTURE and 'Culture Staff'→QUAL_CULTURE_STAFF coexist. qual_theme_options() (qual_quant_layer.R:70) keys theme options as <code>_<i> and qual_build_synthetic_inputs() rbinds all options into one shared survey_structure$options. prepare_question_data() (question_orchestrator.R:94-98) selects Multi_Mention options with the unanchored prefix rege

</details>

### 34. [ ] modules/tabs/lib/question_orchestrator.R:234 (r-pipeline)

**Summary:** The live pipeline never routes Variable_Type="Allocation": process_single_question only branches on Ranking/Numeric/else-standard, so Allocation questions (a shipped, validated type with its own processor) fall into process_standard_question.

**Failure scenario:** Config has a CONT_SUM question BUDGET with Variable_Type=Allocation and data columns BUDGET_1..BUDGET_5. Validation passes (structure_validators/data_validators explicitly support Allocation), but analysis_runner.R:253 -> process_all_questions -> process_single_question hits the else branch; process_standard_question looks for a bare column 'BUDGET', doesn't find it, and tabs_refuse(DATA_QUESTION_COLUMN_NOT_FOUND) aborts the ENTIRE run. If a bare 'BUDGET' column happens to exist, the question is silently tabulated as a single-choice instead of mean-allocation-per-option. process_allocation_question is only wired into dispatch_question (question_dispatcher.R:111), which nothing in the live path calls — commit ec5d2595 wired the dead dispatcher, not the orchestrator. Unit tests call process_allocation_question directly, so suites stay green.

**Fix sketch:** Add an `else if (question_info$Variable_Type == "Allocation")` branch in process_single_question that calls process_allocation_question (mirroring the Numeric branch), and extend calculate_weighted_base (weighting.R:622) to compute an any-column-answered base for Allocation like Multi_Mention/Ranking.

<details><summary>Adjudicator verdict</summary>

Confirmed end-to-end. process_single_question (question_orchestrator.R:234/316/347) routes only Ranking/Numeric/else-standard; no Allocation branch. The live pipeline is analysis_runner.R:517 process_questions -> :253 process_all_questions -> process_single_question, so Allocation questions reach process_standard_question. Allocation is reachable from real configs: scripts/alchemer_to_turas.R:73 maps CONT_SUM->Allocation and validation explicitly accepts it (structure_validators.R:114 valid-type

</details>

### 35. [ ] modules/tabs/lib/tracking_island.R:153 (tracking)

**Summary:** In the no-mapping path, wave_contribution keys metrics by tracking_norm(title) with no occurrence suffix, so two questions whose titles normalise identically collide and one question silently shows the other's trend and microdata.

**Failure scenario:** Tracker without a Question_Mapping where two rating questions share a normalised title (e.g. identical grid/loop item text, or titles differing only in punctuation which tracking_norm strips). Both contributions carry the same match_key; in 22w ensureIndexes the wave index keeps only the LAST (index[p.match_key] overwrite), and the AGG-side fallback assigns q1 the unsuffixed key too (its '#1' suffix never matches). Result: q1's Tracking rows, deltas, current-wave SD and sig all display q2's data — wrong numbers with no warning. The JS side explicitly occurrence-suffixes duplicates ('t#1', mirroring extract_waves.py); the R sidecar writer does not, so the two halves of the contract disagree.

**Fix sketch:** Occurrence-suffix duplicate keys in tracking_metrics()/wave_contribution (key, key#1, ...) exactly as 22w_waves.js ensureIndexes does for AGG questions.

<details><summary>Adjudicator verdict</summary>

Confirmed by code trace and by executing the real 22w_waves.js in a node harness. R's no-mapping path keys every metric by tracking_norm(title) with no occurrence suffix (tracking_island.R:150-156), while extract_waves.py and the JS AGG side both suffix duplicates with '#k' — a contract mismatch. With two questions whose titles normalise identically, ensureIndexes' index[p.match_key]=p overwrite keeps only the last question per wave, and the first question's AGG fallback key (unsuffixed, k=0) re

</details>

### 36. [ ] modules/tabs/lib/weighting.R:1330 (weighted-stats)

**Summary:** run_net_difference_tests computes its Bonferroni divisor as choose(#ALL banner columns, 2) while tests only run within each banner group, and while regular rows use a per-group divisor — so BoxCategory net sig letters use a different (much stricter) alpha than the category rows directly above them in the same table.

**Failure scenario:** Banner = Gender (2 cols) + Region (4 cols), bonferroni_correction=TRUE (the template default). Regular category rows test Male vs Female at alpha/choose(2,2)=0.05 (add_significance_row subsets test_data per group before run_significance_tests_for_row computes num_comparisons). The net rows call run_net_difference_tests with net_test_data containing all 6 non-Total columns, so num_comparisons=choose(6,2)=15 and the SAME Male-vs-Female comparison on the 'Satisfied (NET)' row runs at alpha 0.05/15=0.0033. A difference lettered on every category row silently loses its letter on the net row — researchers read that as 'the net movement is not significant' when it is under the report's stated methodology.

**Fix sketch:** Inside the per-banner loop, compute num_comparisons = choose(length(banner_cols with data), 2) per banner group (mirroring run_significance_tests_for_row) instead of once from length(test_data).

<details><summary>Adjudicator verdict</summary>

Confirmed end-to-end. build_net_test_data (standard_processor.R:691) populates net_test_data with ALL banner columns across ALL banner groups (only Total excluded), so run_net_difference_tests (weighting.R:1330) sets num_comparisons = choose(all non-Total cols, 2) even though its loop (weighting.R:1359-1374) only tests pairs WITHIN each banner group. Regular category rows use a different path: add_significance_row (run_crosstabs.R:374) subsets test_data to each banner group's columns before run_

</details>


## MEDIUM

### 37. [ ] modules/tabs/lib/data_layer_writer.R:528 (r-pipeline)

**Summary:** build_dl_question keys rows by unique forward-filled RowLabel, so when a BoxCategory net shares its label with a displayed option (e.g. box "Satisfied" containing options "Satisfied" and "Very satisfied") the two collapse into one v2 row — the first (individual option, per classify_row_labels' first-source-wins) survives and the NET row is silently dropped from the v2 report.

**Failure scenario:** 5-point scale with options ...,"Satisfied","Very satisfied" and BoxCategory "Satisfied" grouping the top two. The classic Excel shows both the option row (say 30%) and the NET row (55%). In the v2 data layer ord_labels dedupes the label; vals_for takes sel[1,] (the option's 30%), cls["Satisfied"] resolves from the first RowSource ("individual") so kind="category" — the 55% NET vanishes from every v2 view, chart and export while remaining in the workbook, an export/display mismatch across deliverables.

**Fix sketch:** Iterate rows by (RowLabel, RowSource) pairs — RowSource already distinguishes individual vs boxcategory after normalize_question_table's forward-fill — instead of unique labels alone; scope vals_for/sig_for lookups to the matching RowSource.

<details><summary>Adjudicator verdict</summary>

Confirmed. Box-summary rows use the raw BoxCategory string as RowLabel (standard_processor.R:248-257, RowSource='boxcategory') and are appended after the individual option rows (question_orchestrator.R:352/372). build_dl_question keys rows by unique(RowLabel) (data_layer_writer.R:528) and vals_for takes sel[1,] (line 511), while classify_row_labels takes the first non-NA RowSource per label (01_data_transformer.R:134-140) — so a box named identically to a displayed option collapses to one row: t

</details>

### 38. [ ] modules/tabs/lib/html_report_v2/assets/js/22_model.js:338 (confidence-fpc)

**Summary:** On a WEIGHTED population report the proportion-CI path ignores col.ciBase entirely (uses col.baseEff, no FPC), yet the UI everywhere claims FPC is applied — the 'PUBLISHED · FPC' badge (25_cards.js:431-438), the base-row worst-case ±MOE (23_render.js:175, sized on the FPC'd ciBase), the footer callout's fpcNote and worked example (21c_confidence.js:255,293), and the code comment at 22_model.js:613-615 ('weighted reports still get the narrower intervals').

**Failure scenario:** Weighted census-style project with population_size set (staff survey, 90% response, rim-weighted): every proportion cell's CI is computed on baseEff with NO narrowing, but the same table's base row prints a much smaller FPC'd ±MOE, the badge says 'PUBLISHED · FPC', and the callout's worked example quotes an FPC-narrowed range (fpcBase(base,base,N)) that is visibly tighter than the ranges actually shown in the cells — the reader sees, e.g., callout '81–83%' vs cell '78–86%'.

**Fix sketch:** Either apply FPC to the weighted path (ciBase = fpcBase(col.baseEff, col.base, N)) or make every annotation (badge, MOE row, callout, worked example) honour the same rule the cells use; today they disagree on the same page.

<details><summary>Adjudicator verdict</summary>

CONFIRMED by harness. On a weighted population report: attachIntervals' proportion branch (22_model.js:338) uses baseEff and never col.ciBase (measured cell CI 52.0-67.5 on baseEff=150, vs 57.7-62.2 had FPC applied), while col.ciBase=1791 (FPC'd) IS set on the model and drives the base-row worst-case ±MOE (23_render.js:175 moeBase = col.ciBase) and model.fpcDefault=true drives the 'PUBLISHED · FPC' badge (25_cards.js:431-438) and the fpcNote/worked-example in 21c_confidence.js (fpcBase(base,base

</details>

### 39. [ ] modules/tabs/lib/html_report_v2/assets/js/22_model.js:361 (confidence-fpc)

**Summary:** applyFpcSignificance replaces R's published letters — computed at the project's configurable alpha (crosstabs_config.R alpha / alpha_secondary) — with letters at the JS engine's hard-coded 1.96/1.2816, so an unweighted population report configured at alpha = 0.10 silently changes its default-view significance level while the sig_note still says 90%.

**Failure scenario:** Project sets alpha = 0.10; the report header/sig_note (build_sig_note) says 'Sig. (90%)'. Because population_size is configured, the default view routes through applyFpcSignificance, which retests everything at fixed z=1.96 (95%): differences that R correctly lettered at 90% lose their letters in the report of record, and the printed methodology note no longer describes the letters actually shown.

**Fix sketch:** Derive the z threshold from TR.AGG.project.alpha (and alpha_secondary for the dual level) in TR.stats instead of the fixed Z95/Z80 constants, at minimum inside applyFpcSignificance where published letters get replaced.

<details><summary>Adjudicator verdict</summary>

CONFIRMED at code level. R's letters honour the configured alpha (standard_processor.R:213/301/556 pass config$alpha into the weighting.R tests, significant = p_value < alpha; alpha_to_confidence_label prints 'Sig. (90%)' for 0.10), and build_sig_note (data_layer_writer.R:60) writes the configured level into the island. applyFpcSignificance re-letters everything via TR.stats.sigLetters at hard-coded Z_CRITICAL=1.96/Z_80=1.2816 (21_stats.js:16-17) with no alpha input, so an alpha=0.10 population 

</details>

### 40. [ ] modules/tabs/lib/html_report_v2/assets/js/22w_waves.js:169 (weighted-stats)

**Summary:** indexFromDistribution silently computes a prior wave's index mean over only the category labels that match, re-normalising over a partial distribution instead of returning null when some scale categories fail to match (unlike netFromMembers, which requires ALL members).

**Failure scenario:** 5-point Likert with index weights; the bottom category was relabelled between waves ('Very dissatisfied' → 'Very unsatisfied'), so norm-matching misses it in the 2023 workbook. The 2023 index is recomputed from the 4 remaining categories with weight renormalised over ~85% of the distribution — dropping the lowest-scored category inflates the 2023 index, so the current wave shows a spurious significant decline (meanLevel Welch test runs on the biased prior value). No warning is shown; the wrong prior point looks exactly like a real published figure.

**Fix sketch:** Mirror netFromMembers: if any label in q.index_scores has no matching row value in the wave (rowValue null), return null rather than renormalising over the subset.

<details><summary>Adjudicator verdict</summary>

CONFIRMED. indexFromDistribution (22w_waves.js:164-172) accumulates only labels where rowValue matches and renormalizes sum/weight over the PARTIAL distribution - unlike netFromMembers directly above it, which returns null if ANY member is missing. Reachable: the path fires when a published history wave has rows but no stats.index (extract_waves.py only captures stats when the workbook carried an Index/Average/Score row - older waves predating the index config lack it), and the cross-wave alias 

</details>

### 41. [ ] modules/tabs/lib/html_report_v2/assets/js/23_render.js:309 (model-render)

**Summary:** render.matrix (the source for Excel, Copy-table and TSV exports) always emits a single base row labelled 'Base (n=)' containing the unweighted base, but on weighted reports the on-screen table labels that row 'Base (unweighted)' and adds Base (weighted) + Effective base rows — the export drops them and mislabels the one it keeps.

**Failure scenario:** Weighted report (e.g. CCS): screen shows Base (unweighted) 412 / Base (weighted) 1 006 / Effective base 371 with weighted percentages. Excel/copy export shows only 'Base (n=)' 412 next to the weighted percentages; a client multiplying n x % reconstructs counts off the wrong base, and nothing in the export says the figures are weighted.

**Fix sketch:** In render.matrix, when TR.AGG.project.weighted mirror tableHtml: label the row 'Base (unweighted)' and append 'Base (weighted)' (col.baseW) and 'Effective base' (col.baseEff) rows subject to the same show_weighted_base/show_effective_n flags.

<details><summary>Adjudicator verdict</summary>

Confirmed in 23_render.js: tableHtml (lines 168-229) branches on TR.AGG.project.weighted, labelling the base row 'Base (unweighted)' and adding 'Base (weighted)' (col.baseW) and 'Effective base' (col.baseEff) rows (both default-on), while render.matrix (line 309) unconditionally emits a single 'Base (n=)' row from col.base and never reads the weighted flag or baseW/baseEff. render.matrix feeds every client-side export: Excel (25_cards.js:842 via rowsFromMatrix in 23y_xlsx.js:99, verbatim pass-th

</details>

### 42. [ ] modules/tabs/lib/html_report_v2/assets/js/23z_charts.js:267 (dashboard-insights)

**Summary:** pieChart draws a zero-length SVG arc when one slice is 100% of the total (sweep = 2π), so the donut renders completely invisible.

**Failure scenario:** Single-option question, or any column where one category holds 100% and the rest 0% (common under a live filter, e.g. filtering an audience to a category of the same question). sweep = v/total*2π = 2π makes p(a2,R) identical to p(angle,R) (cos/sin are periodic), so the path 'M x y A R R 0 1 1 x y …' renders nothing. The researcher picks the Pie chart type and gets a blank chart area with only the centre label and legend — looks like the data is missing.

**Fix sketch:** Clamp sweep to 2π−0.0001 (or special-case a full circle with two half-arcs / a <circle> + inner hole).

<details><summary>Adjudicator verdict</summary>

Confirmed empirically: at modules/tabs/lib/html_report_v2/assets/js/23z_charts.js:260-270, a slice with v/total=1 gives sweep=2*PI, so a2 = angle+2*PI and p(a2,R)/p(a2,r0) produce coordinate strings identical to p(angle,R)/p(angle,r0) after toFixed(2) (verified in node: 'M 170.00 27.00 A 88 88 0 1 1 170.00 27.00 ...'). Per the SVG spec, an arc whose endpoints are identical is rendered as if omitted, so both arcs vanish and the path degenerates to a single radial line with a white stroke — the do

</details>

### 43. [ ] modules/tabs/lib/html_report_v2/assets/js/23za_trend.js:201 (tracking)

**Summary:** years.sort() sorts numeric wave order keys lexicographically, scrambling the trend chart x-axis whenever keys have differing digit counts.

**Failure scenario:** Wave order keys that aren't all the same string length — e.g. write_segment_wave_sidecars defaults year = as.numeric(id) so wave ids '9','10','11' give keys [9,10,11], or a config using wave numbers in wave_order. [9,10,11].sort() → [10,11,9]: x-axis labels appear as 10, 11, 9 and xOf(year)=years.indexOf(year) places wave 9 rightmost, so every series line zig-zags backwards through time and the 'current' point sits mid-chart. The R island assembler sorts the same keys numerically (correct), so summary tables and the chart disagree.

**Fix sketch:** years.sort(function(a,b){return a-b;}).

<details><summary>Adjudicator verdict</summary>

Confirmed. Line 201 is a bare years.sort() over numeric wave order keys (they arrive as JSON numbers via jsonlite auto_unbox), and default Array.sort is lexicographic: [9,10,11] -> [10,11,9]. xOf() positions points by years.indexOf(year), so with mixed digit counts the trend chart's x-axis and every series' point placement scramble while the path is drawn in chronological series order, producing a backwards zig-zag line. The trigger is reachable: write_segment_wave_sidecars (tracking_segment_com

</details>

### 44. [ ] modules/tabs/lib/html_report_v2/assets/js/25_cards.js:444 (model-render)

**Summary:** Hard-coded wave years in visible UI text: the PUBLISHED badge tooltip says 'Published 2025 value, verbatim' (line 444), the no-history badge says 'new in 2025' (line 451), and the dashboard intro says '▲▼ chips show change vs 2024' (27_views.js line 146) — all wrong for any project not fielded 2025-vs-2024.

**Failure scenario:** A 2026 wave-3 tracker: every crosstab card claims its figures are 'Published 2025 value', untracked questions are badged 'new in 2025', and the dashboard tells the reader the change chips compare against 2024 when the prior wave is actually 2025 — factually wrong metadata a client will quote.

**Fix sketch:** Derive the current wave label from TR.AGG.project.wave/year and the comparison year from the latest prior wave (TR.PREV / model.prevWave), as prevBadge's 'tracked since' already does.

<details><summary>Adjudicator verdict</summary>

Confirmed: 25_cards.js:444 hard-codes tooltip 'Published 2025 value, verbatim' on the PUBLISHED badge (default badge for any non-recomputed view), 25_cards.js:451 hard-codes 'new in 2025' for every question without wave history, and 27_views.js:146 unconditionally prints '▲▼ chips show change vs 2024' in the dashboard intro. build_report_v2.R inlines the JS bundle verbatim with no year substitution, so these strings appear in every generated report regardless of fieldwork year. The adjacent trac

</details>

### 45. [ ] modules/tabs/lib/html_report_v2/assets/js/27_views.js:146 (dashboard-insights)

**Summary:** Dashboard intro hardcodes '▲▼ chips show change vs 2024', which misstates the comparison wave on every project whose previous wave is not 2024 and appears even on non-tracking reports.

**Failure scenario:** A tracker with waves 2023 and 2025 (or a monthly tracker) generates the v2 report: the gauge delta chips actually compare against the previous matched wave, but the dashboard tells the researcher the change is 'vs 2024' — a wrong methodological claim in a client-facing view. On a one-wave study the text still promises change chips that cannot exist.

**Fix sketch:** Derive the label from the actual previous-wave year on the delta objects (row.delta.year), and omit the sentence when no question carries wave history.

<details><summary>Adjudicator verdict</summary>

Confirmed. 27_views.js:146 unconditionally hardcodes '▲▼ chips show change vs 2024' in the dashboard intro; no R-side token replacement exists for that string. The chips themselves render row.delta, which 22w_waves.js attachDeltas computes against the latest matched prior wave (dynamic wave/year) — so on any tracker whose previous wave is not 2024 the text misstates the comparison basis, and correct dynamic wording already exists elsewhere (25_cards.js:561 'change vs the most recent'). The intro

</details>

### 46. [ ] modules/tabs/lib/html_report_v2/assets/js/27d_diffs.js:127 (diffs-sig)

**Summary:** When TR.MICRO.scores lacks the question (indexMeans falls back to q.index_scores), meanFindings leaves scaleMin=scaleMax=0, so range collapses to the ||1 fallback: the finding's score is inflated ~10x (gap divided by 1 instead of the true scale range), corrupting the standout ranking and the MAX_FINDINGS cut, and barsHtml divides by (scaleMax-scaleMin)=0 so both comparison bars render at 100% width (Infinity clamped) or width:NaN% when the value is 0, visually erasing the gap.

**Failure scenario:** Report whose microdata island carries answers but no scores entry for a rated question (micro_scores_for_question returns NULL when its value map is empty) while the aggregate carries index_scores — indexMeans still produces means via the documented fallback path. A 0.8-point mean gap on a 10-point scale scores 80·(z/1.96) instead of 8·(z/1.96), so that question's soft findings crowd out genuinely bigger standouts from the top-80 list, and its two-bar comparison shows two identical full-width bars for a 9.3-vs-8.5 gap.

**Fix sketch:** When TR.MICRO.scores[q.code] is absent, derive lo/hi from the q.index_scores values used by the fallback (or from means[..].mean bounds) before computing range, and guard barsHtml against scaleMax===scaleMin.

<details><summary>Adjudicator verdict</summary>

CONFIRMED mechanism: when TR.MICRO.scores lacks the question, 27d_diffs.js:119-128 leaves scaleMin=scaleMax=0 and range=(0-0)||1=1, so score=(az/Z95)*|gap|/1*100 is inflated by the true scale range (~10x on a 0-10 scale), corrupting the standout ranking and the per-severity MAX_FINDINGS cut; barsHtml (line 257) divides by (scaleMax-scaleMin)=0 directly (not the ||1 range), giving Infinity->clamped 100% width for both bars (or width:NaN% at value 0), visually erasing the gap. Reachable: indexMean

</details>

### 47. [ ] modules/tabs/lib/html_report_v2/assets/js/27f_takeout_data.js:199 (patterns-takeout)

**Summary:** The reliability ribbon's worst-case MoE is computed from the unweighted base (model.columns[0].base -> conf.maxMoePct(n)), ignoring the Kish effective n on weighted studies, so the tab overstates precision.

**Failure scenario:** Weighted study with rim weights, n = 800 unweighted, effective n ≈ 570 (deff 1.4): the ribbon prints '±3.5pp worst-case' (from n = 800) when the correct worst case on n_eff is ±4.1pp — inconsistent with the rest of the report, which sizes every significance test on the Kish effective base.

**Fix sketch:** Carry baseEff (already on model columns from 22_model.js) through gatherLevels/gatherReliability and feed conf.maxMoePct the effective n when the project is weighted.

<details><summary>Adjudicator verdict</summary>

CONFIRMED mechanism: gatherReliability (27f:189-206) takes n = model.columns[0].base, which is the UNWEIGHTED base (22_model.js:56-64 carries Kish n_eff separately as baseEff), and prints conf.maxMoePct(n) as '±X.Xpp worst-case' (27g:305-306). On a weighted study (deff 1.4, n=800, n_eff≈570) this overstates precision (~±3.5 vs ~±4.1), while the report's significance tests and Wilson intervals size on baseEff (22_model.js:334-342). Graded medium not high: it is a display-level precision statement

</details>

### 48. [ ] modules/tabs/lib/html_report_v2/assets/js/27h_takeout_read.js:186 (patterns-takeout)

**Summary:** When the odd-one-out or hidden-disagreement scan actually FINDS something, buildPatterns (27e:539-546) stores only counts in the rigor footer and never pushes a card, yet the footer prints 'flagged on the cards above' — the finding is silently dropped and the claim is false.

**Failure scenario:** A survey where one question genuinely splits into two camps (40% bottom-two / 45% top-two, calm mean): bimodalityPattern flags it, rigor.bimodal.found = true, but no card of kind 'bimodal' exists in patterns (cardHtml/bodyHtml branches for odd/bimodal are dead code), so the researcher sees nothing — while the provenance line asserts 'also checked every question for a hidden two-camp split — flagged on the cards above'. Same for a true odd-one-out sign-flip that survives BH correction.

**Fix sketch:** Either push the odd/bimodal pattern objects into patterns when found (the render atoms already exist), or change the footer wording to name the finding inline instead of pointing at nonexistent cards.

<details><summary>Adjudicator verdict</summary>

Confirmed. buildPatterns (27e_takeout_engine.js:539-546) computes oddOnePattern and bimodalityPattern but only records counts/found into t.rigor; it never pushes either result into the patterns array, so no 'odd' or 'bimodal' card can ever render (the cardHtml/headHtml/bodyHtml branches for those kinds in 27h_takeout_read.js:53-59/100-109 are dead code). Yet provHtml (27h:184-188) prints '— flagged on the cards above' whenever rigor.odd.found or rigor.bimodal.found is true. The found=true path i

</details>

### 49. [ ] modules/tabs/lib/html_report_v2/assets/js/27q_qualitative.js:213 (qual-tab)

**Summary:** In a saved copy, un-shortlisting a comment (or removing a highlight) does not survive reload: the store seeds from the embedded island then overlays localStorage per key, and a deletion is key-absence, which cannot override the island seed — the mark resurrects on every reload.

**Failure scenario:** Analyst shortlists 5 comments and uses Save copy (report.saveCopy embeds qualSaved/qualHighlights into the user-state island). A colleague opens the copy, removes 2 stars (toggleSave deletes the keys; savedPersist writes the merged set minus those keys), then reloads: savedStore() re-seeds all 5 from TR.userState.qualSaved and the localStorage overlay cannot remove them — the 2 deleted stars are back, and the collection count/exports include comments the reader explicitly removed. Same mechanic for removeHighlight via hlStore.

**Fix sketch:** Mirror the hubs store: once the reader has any persisted local state, let it win entirely (replace, not per-key merge), or persist explicit tombstones (s[k]=0) instead of deleting keys.

<details><summary>Adjudicator verdict</summary>

Confirmed. savedStore/hlStore (206-217, 252-263) seed from the saved-copy island (TR.userState.qualSaved/qualHighlights — embedded by report.saveCopy at 32_report.js:235-236 and loaded via 24_shell.js:38) then overlay localStorage key-by-key. toggleSave/removeHighlight delete the key and savedPersist writes the merged-minus-deleted set, but on reload the island re-seeds the deleted keys and per-key overlay cannot express an absence — the removed marks resurrect and re-enter collection counts and

</details>

### 50. [ ] modules/tabs/lib/html_report_v2/assets/js/27q_qualitative.js:192 (qual-tab)

**Summary:** The '💬 N comments' affordance on closed/composite cards always shows the UNFILTERED total (commentCount is called without the active filters), while the jump it triggers shows only the comments inside the active cut.

**Failure scenario:** Global filter Campus=Cape Town is active; a linked closed card renders cut-specific stats plus '💬 47 comments'. Clicking jumps to the qual tab, which mask-filters the 47 records to the cut — the reader sees 9 comments (header '9 of 47 answered'), or the disclosure note if the cut is below k. The number on the button never matches what the click reveals whenever a filter is active, so a researcher quotes '47 comments behind this finding' for a cut that only has 9.

**Fix sketch:** Pass the live cut into the count — qual.commentCount(link.qcode, TR.d2.state.filters) — and suppress the count (or show only '💬 comments') when the cut is below the disclosure threshold.

<details><summary>Adjudicator verdict</summary>

Confirmed. affordanceHtml (189-197) calls qual.commentCount(link.qcode) without the filters argument that commentCount(qcode, filters) explicitly supports, so the '💬 N comments' button always shows the unfiltered total. Its call sites — the crosstab card (25_cards.js:468, which shows filter-aware 'COMPUTED · n=' badges and a 'Filtered:' context strip) and dashboard gauges (27_views.js:177) — re-render under the active cut, and jumpTo lands on the mask-filtered qual list (qual.render:772) or the

</details>

### 51. [ ] modules/tabs/lib/html_report_v2/assets/js/27s_notes.js:58 (critic)

**Summary:** Tracking data-point annotations use the tombstone-less island+localStorage merge, so in a saved copy a deleted chart tag resurrects on every reload — the same pattern the audit flagged for insights/story/qual marks but missed for annotations (and for the 27f_takeout_data.js curation store, whose reset() likewise cannot clear island-baked Patterns edits across a reload).

**Failure scenario:** Reader opens an annotated copy whose user-state island bakes the note 'Campaign launched' on metric X / 2024, clicks the note chip's ✕ (notes.set deletes the key and persists localStorage WITHOUT it), then reloads: store() re-seeds the island key first and the localStorage overlay contains no tombstone for the deletion, so the removed tag reappears on the trend chart and in every subsequent pin/saved copy.

**Fix sketch:** Persist deletions as explicit null tombstones (or persist the full merged map including island keys so key-absence after deletion is authoritative).

### 52. [ ] modules/tabs/lib/html_report_v2/assets/js/28_insights.js:74 (dashboard-insights)

**Summary:** In a saved annotated copy, deleting an insight cannot persist: the per-key merge of the embedded user-state island over localStorage has no tombstone, so the author's insight resurrects on every reload.

**Failure scenario:** Reader opens a saved copy whose island carries insights.Q10 = 'old text', clears the insight box (insights.set('Q10','') deletes the key and persist() writes localStorage WITHOUT Q10). On reload, store() re-seeds cache from TR.userState.insights (Q10 present) and the localStorage overlay lacks Q10, so 'old text' reappears — and flows back into story slides, PPTX export and any subsequent Save copy the reader makes. The same mechanism means an updated saved copy from the author is fully shadowed by whatever stale author values persist() previously copied into the reader's localStorage.

**Fix sketch:** Persist deletions as tombstones (e.g. keep key with null/"" and treat it as 'cleared' in get()), or snapshot-replace like 32_report.js does instead of per-key merging.

<details><summary>Adjudicator verdict</summary>

Mechanism fully confirmed. saveCopy (32_report.js:230) embeds insights into the #user-state island; 24_shell.js:38 hydrates it as TR.userState.insights. In 28_insights.js, store() seeds the cache from the island (lines 19-23) then overlays localStorage per-key (lines 26-28); insights.set with empty text deletes the key (line 74) and persist() writes localStorage without it — no tombstone. On reload the island re-seeds the deleted key and the localStorage overlay cannot mask an absent key, so the

</details>

### 53. [ ] modules/tabs/lib/html_report_v2/assets/js/28c_composite.js:44 (critic)

**Summary:** compositeBanners (and identically savedBanners, 28b_banners.js:30) let any pre-existing localStorage array for the same project storeKey wholesale replace the composites/banners embedded in a saved annotated copy — the same defect the audit reported for 32_report.js but missed in these two stores.

**Failure scenario:** Analyst A saves an annotated copy containing a composite profile banner (and a story pin referencing it). Reader B, who earlier opened the ORIGINAL report of the same project+wave on their machine and created-then-deleted a composite (localStorage now holds []), opens A's copy: store() seeds from the island then executes 'if (Array.isArray(own)) cache = own', so A's composites vanish — the banner picker doesn't show them, and A's composite story pin now resolves to null, hitting the already-reported compositeMatrix crash in the PPTX export.

**Fix sketch:** Merge island entries with localStorage by id instead of replacing, or version the localStorage payload against the island the way 27f takeout versions curation.

### 54. [ ] modules/tabs/lib/html_report_v2/assets/js/29_export.js:596 (exports)

**Summary:** buildChart has no branch for chart type "line", so a question pinned while showing the trend-over-waves chart exports in the native PPTX deck as a horizontal bar chart of current-wave values, silently dropping the wave history.

**Failure scenario:** User clicks "full trend chart" (sets chartType="line"), pins the question (pinCurrent stores chartType:"line"), then downloads the native deck. slidesFor -> slideForModel({chartType:"line"}) -> buildChart falls through to the final else (clustered bar). The Story tab and the image deck show the wave trend (render.chartBy dispatches "line" -> trendChart), but the editable client deliverable shows a current-wave bar chart — the tracking story disappears without any warning.

**Fix sketch:** In slideForModel (or buildChart), route type==="line" to exporter.buildTrendChart(model) the way exhibit.slide does, falling back to bar only when the model has no wave history.

<details><summary>Adjudicator verdict</summary>

Confirmed. chartType 'line' is a real pinnable state (CHART_TYPES includes it; 25_cards.js:855 'full trend chart' button sets it; pinCurrent stores chartState.type at 30_story.js:86). slidesFor passes it to slideForModel, which for non-'dot' types calls buildChart (29_export.js:541), whose branches cover column/stacked/stackedcol/pie/dot only — 'line' falls through to the final else (horizontal clustered bar of current-wave chartRows). buildTrendChart is only invoked from the exhibit path (30x_e

</details>

### 55. [ ] modules/tabs/lib/html_report_v2/assets/js/29_export.js:517 (exports)

**Summary:** Series column letters are built with String.fromCharCode(66 + k), so the 26th series onward gets non-letters ('[', '\\', ...) producing invalid embedded-workbook references (Sheet1!$[$1) in the native chart XML.

**Failure scenario:** A single-select with 26+ response options (long brand or occupation list) is pinned as a 100%-stacked chart: chartSeriesStacked makes one series per row with letter String.fromCharCode(66+k); at k=25 the c:tx/c:val formulas become Sheet1!$[$1 and Sheet1!$[$2:$[$27. PowerPoint flags the chart part as unreadable or breaks Edit Data with #REF! for every series past Z. Same defect in chartSeries (line 465) when >25 banner columns are charted.

**Fix sketch:** Replace the single-char letter with a proper base-26 A..Z,AA.. helper (mirror generate_excel_letters) shared by chartSeries, chartSeriesStacked and buildTrendChart.

<details><summary>Adjudicator verdict</summary>

Confirmed mechanism at 29_export.js:517 (chartSeriesStacked, one series per ROW) and :465 (chartSeries, one series per charted column): String.fromCharCode(66+k) at k=25 yields '[' (charCode 91), producing invalid refs Sheet1!$[$1 and Sheet1!$[$2:$[$27 in c:tx/c:val formulas. chartRows (23_render.js:395) has no row cap and stackedChart renders any row count, so a 26+ option single-select (brand/occupation list) pinned as 100%-stacked is reachable from a real report; 26+ charted banner columns vi

</details>

### 56. [ ] modules/tabs/lib/html_report_v2/assets/js/29_export.js:649 (exports)

**Summary:** buildTrendChart takes trendRows(model).slice(0,6) without the mean-scale vs percentage split that the on-screen render.trendChart applies, so a question tracking both a mean and NET rows exports all series on one mismatched axis.

**Failure scenario:** A 0-10 rating question with wave history for both its mean (e.g. 7.8) and a Top2Box NET (e.g. 62%) is pinned as a trend exhibit. On screen (and in the image deck) render.trendChart plots only the dominant scale group and footnotes the dropped rows; the native PPTX chart plots mean and NET together on a 0-70 axis — the mean line is a flat sliver at the bottom, meanScale=false so the fixed-axis/format logic also mislabels it. The editable deck no longer matches the pinned view.

**Fix sketch:** Reuse the small/pct split from render.trendChart (23za_trend.js ~180-195) in buildTrendChart before slicing to 6 series, and emit the same 'different scale, table only' note.

<details><summary>Adjudicator verdict</summary>

Confirmed. render.trendChart (23za_trend.js:181-188) splits ≤10 mean rows from %/index rows, plots only the dominant scale group and footnotes the dropped series; buildTrendChart (29_export.js:649) takes trendRows(model).slice(0,6) with no split, and its meanScale/pctOnly logic (allMean / every non-mean) both go false on a mixed set, giving one 0-to-niceMax(62)≈70 'General' axis with the 7.8 mean as a flat sliver. Reachable: the flagship pinExhibit (flags trend:true) -> exhibit.slide -> buildTre

</details>

### 57. [ ] modules/tabs/lib/html_report_v2/assets/js/30_story.js:30 (hubs-collection)

**Summary:** In a saved annotated copy, clearing the story does not survive a reload: load() ignores an empty localStorage story array ('if (own.length) items = own') and falls back to the story baked into the user-state island, resurrecting every cleared item.

**Failure scenario:** Duncan sends a client a Save-copy HTML with 5 story items baked into TR.userState.story. The client clicks 'Clear' (items=[], persisted as '[]' to localStorage), sees an empty story, closes the file, and reopens it: load() reads the island's 5 items, then parses localStorage '[]', own.length is 0, so the island items win — all 5 'deleted' items are back (same if they removed the last item with ✕ instead of Clear). The deletion silently un-happens; anything they present/export next includes exhibits they believed removed.

**Fix sketch:** Distinguish 'never persisted' from 'persisted empty': treat any successfully parsed localStorage array (including []) as the reader's own state — e.g. 'if (raw) { items = JSON.parse(raw) || []; }' — mirroring how the qual saved/highlight stores let reader edits win.

<details><summary>Adjudicator verdict</summary>

CONFIRMED by reading load() (30_story.js:20-34) and simulating it in node. The island story is loaded first (line 23-25), then localStorage is consulted with 'if (own.length) items = own' (line 30) — an empty persisted array ('[]') is indistinguishable from 'reader never touched the story', so the island baseline wins. The scenario is fully reachable: saveCopy bakes story: TR.story2.items() into the #user-state island (32_report.js:227-249), the island is parsed at boot (24_shell.js:38). A recip

</details>

### 58. [ ] modules/tabs/lib/html_report_v2/assets/js/31_selftest.js:80 (dashboard-insights)

**Summary:** The in-browser #selftest bundled into every production v2 report hardcodes SACAP-prototype golden data, so on any other project most cases crash or fail and the panel falsely reports the stats engine as broken.

**Failure scenario:** Researcher appends #selftest to a CCS/CCPB/IPK v2 report (build_report_v2.R bundles all js including 31_selftest.js; 24_shell.js runs it unconditionally on the hash). Cases assume TR.AGG.questions[3], question Q008, title 'registration process at sacap', segment 'cape town', 7 matched waves, ≥60 tracked questions and TR.MICRO.n: on a non-SACAP report the title lookup yields undefined → TypeError caught and shown as ✗, reports without microdata fail the mask cases, non-tracking reports fail the wave cases — the panel shows e.g. 'Self-test: 4/17 passed' in red on a perfectly healthy report.

**Fix sketch:** Split dataset-agnostic engine cases (z-test, Wilson, MOE, repel/sparkline geometry) from the SACAP goldens and gate the goldens on the SACAP/synthetic dataset (e.g. TR.MICRO.synthetic or a project marker), skipping them with a 'not applicable' note elsewhere.

<details><summary>Adjudicator verdict</summary>

Mechanism fully confirmed: bundle_report_v2_js (build_report_v2.R:48) globs every assets/js/*.js with no exclusion, so 31_selftest.js ships in every production v2 report, and 24_shell.js:43,58 runs it whenever the URL hash contains 'selftest'. The vendored selftest is hardcoded to the SACAP prototype: title lookup 'registration process at sacap' ([0] on filter -> undefined -> TypeError on other projects), segment/column 'cape town'/'Cape Town', history.length==7, matched>=60 tracked questions, T

</details>

### 59. [ ] modules/tabs/lib/html_report_v2/assets/js/32_report.js:46 (dashboard-insights)

**Summary:** Report-tab store() lets ANY pre-existing localStorage report state for the same project wholesale-replace the embedded saved-copy sections, hiding the author's Background/Executive summary/added slides.

**Failure scenario:** Analyst B once typed a single character into a Report-tab section of the original report (localStorage key turas_v2_report:<project-slug> now non-empty). Analyst A sends B a saved annotated copy of the same project+wave (same d2.storeKey). On open, store() sees own.sections non-empty and sets cache = own — A's embedded exec summary, background and imported qual slides are silently invisible to B, and if B clicks Save copy, A's narrative is permanently replaced by B's stale text in the new file.

**Fix sketch:** When TR.userState.report exists (saved copy), prefer the island or merge per-field instead of a wholesale own-wins swap; at minimum only override sections the reader actually edited after opening the copy.

<details><summary>Adjudicator verdict</summary>

Confirmed in 32_report.js store() (lines 34-54): TR.userState.report (the embedded saved-copy island) seeds the cache, but any pre-existing localStorage under turas_v2_report:<slug> with a single non-empty section/about/slide wholesale-replaces it (cache = own), hiding the author's Background, Executive summary AND added slides. d2.storeKey (20_data.js:232) scopes only by project name+wave, and its own comment confirms localStorage is shared across report files on one origin, so a saved annotate

</details>

### 60. [ ] modules/tabs/lib/standard_processor.R:727 (r-pipeline)

**Summary:** insert_net_sig_row locates the box-net's "Column %" row by RowLabel == net_name, but when boxcategory_frequency=Y the Column % row's label is blanked (create_boxcategory_column_percent passes show_label = !config$boxcategory_frequency, and create_percentage_row writes "" for the label), so net-difference significance rows are silently never inserted.

**Failure scenario:** Config sets boxcategory_frequency=Y, boxcategory_percent_column=Y, test_net_differences=Y on a Likert with exactly two BoxCategories (Agree/Disagree). The box tables show frequency + percent rows, run_net_difference_tests computes valid results, but insert_net_sig_row's which(RowLabel=="Agree" & RowType=="Column %") matches nothing (that row's label is "", the label sits on the Frequency row), returns the table unchanged, and the net-vs-net sig letters the analyst enabled just never appear — no warning, in Excel and both HTML reports. Turning frequency rows off makes them reappear.

**Fix sketch:** Match the insertion point on the Frequency-or-Column% row pair: find rows where RowType=="Column %" AND (RowLabel==net_name OR the preceding Frequency row's RowLabel==net_name); or simply always label boxcategory Column % rows and let the HTML/Excel writers dedupe display.

<details><summary>Adjudicator verdict</summary>

Mechanism confirmed by reading the code path end-to-end. standard_processor.R:375 sets show_label <- !config$boxcategory_frequency, and create_percentage_row (cell_calculator.R:155) writes RowLabel="" when show_label=FALSE, leaving the category name on the Frequency row only. insert_net_sig_row (standard_processor.R:727-730) matches existing_table$RowLabel == net_name & RowType == "Column %"; with boxcategory_frequency=Y that row's label is "", so length(net_pct_row)==0 and the function silently

</details>

### 61. [ ] modules/tabs/lib/summary_builder.R:488 (dashboard-insights)

**Summary:** Index_Summary silently drops the metric rows of every question that is a source of a composite whenever that composite's own row is not emitted (ExcludeFromSummary=Y, index_summary_show_composites=FALSE, or the composite missing from composite_results).

**Failure scenario:** Config has composite ENGAGE with SourceQuestions Q5,Q6 and ExcludeFromSummary=Y (or the researcher sets index_summary_show_composites=FALSE). organize_by_composite_groups() builds source_map from ALL composite_defs, then filters remaining_metrics with `!QuestionCode %in% source_question_codes`; since the excluded composite never appears in composite_metrics, the loop that would re-emit Q5/Q6 under it never runs. Result: Q5 and Q6 Average/Index rows vanish from the client-facing Index_Summary sheet with no warning — the doc (06_TEMPLATE_REFERENCE.md) says the flag only hides the composite itself. With show_composites=FALSE, EVERY composite source question disappears from the summary.

**Fix sketch:** Build source_map only from composites that actually emitted a row into composite_metrics (or add orphaned source questions back into remaining_metrics before the final filter).

<details><summary>Adjudicator verdict</summary>

Confirmed. organize_by_composite_groups builds source_map from ALL composite_defs (summary_builder.R:393-406) and filters remaining_metrics with !QuestionCode %in% source_question_codes (line 488), while source questions are only re-emitted under composites present in composite_metrics (loops at 427-484). A composite excluded via ExcludeFromSummary=Y (extract_composite_rows:286-288 'next') or hidden via index_summary_show_composites=N (line 246 empty return) never appears in composite_metrics, s

</details>

### 62. [ ] modules/tabs/lib/tracking_island.R:282 (tracking)

**Summary:** read_wave_contributions/build_tracking_island never dedupe waves by label or year, so a stale sidecar from a renamed re-run of the same wave enters the island as 'history' and wave-over-wave deltas compare the current wave against itself.

**Failure scenario:** Operator re-runs the current wave with a different v2 output filename (e.g. versioned '..._v2.xlsx') with waves_source pointing at the output folder: the old '<oldname>_wave.json' no longer matches exclude_path, so the island contains the same wave twice — once flagged current, once as the latest history wave (same year key sorts adjacent). attachDeltas' row.delta then reports 'vs previous wave' as current-vs-its-own-prior-run (≈0, not significant), masking the genuine movement vs the real previous wave, and the wave appears twice on the trend axis.

**Fix sketch:** In build_tracking_island, drop prior contributions whose wave label (or year key) equals the current contribution's; optionally warn on duplicate year keys among priors.

<details><summary>Adjudicator verdict</summary>

Mechanism confirmed: read_wave_contributions excludes only the current run's exact sidecar path (normalizePath equality, tracking_island.R:283-285) and neither build_tracking_island nor the JS engine dedupes waves by label or year. A stale *_wave.json for the same wave (renamed/versioned output re-run with waves_source at the output folder, or this wave's sidecar already copied into the waves_source history folder before a re-run — the documented forward path requires sidecars to accumulate ther

</details>


## LOW

### 63. [ ] modules/tabs/lib/excel_writer.R:1753 (exports)

**Summary:** create_guide_sheet gates the "BANNER COLUMN LETTERS" legend on banner_info$column_letters, a field that never exists (banner.R builds banner_info$letters), so the letter-to-column legend is silently omitted from every workbook.

**Failure scenario:** Any run with significance testing: the Guide sheet tells the reader "Each banner column is assigned a letter (A, B, C, ...)" but the section that actually maps each letter to its column label never renders because !is.null(banner_info$column_letters) is always FALSE. With letters restarting per banner group (banner.R appends per-group A,B,C…), a client reading sig letters like "BC" in the distributed .xlsx has no in-workbook legend disambiguating which group's B/C is meant.

**Fix sketch:** Use banner_info$letters (and banner_info$column_labels) in create_guide_sheet, skipping the Total's "-" letter.

<details><summary>Adjudicator verdict</summary>

Confirmed: excel_writer.R:1753 gates the Guide sheet's BANNER COLUMN LETTERS section on banner_info$column_letters, but banner.R builds the field as 'letters' (banner.R:140) and no code anywhere assigns column_letters (only docs/05_TECHNICAL_DOCS.md:719 references it, promising the section exists). The gate is always FALSE, so the section is dead code on every run — a real field-name-mismatch defect, and create_guide_sheet is called unconditionally (workbook_builder.R:752). However, the harm sce

</details>

