# VAS 2026 — composite scores and the Turas dataset (plan)

**STATUS 23 July 2026 (evening): BUILT AND VERIFIED.** Stages 0–3 all live: register + input archiving in the fieldwork runner; presence/amount-range/ outlier fixes; all composites (273-column derived table); the Turas builder (`vas_turas_plan/structure/build.R` + `run_vas_turas.R` in the repo, `Run VAS Turas Dataset.command` in the Reporting folder). 398 tests pass; the generated config/data was load-validated through the tabs module's own loaders (379 questions, 34 test rows accepted); the strict register gate verified refusing on Review rows. Decisions in section 4 were built with the recommended defaults — all editable in `vas_derived_config.R` / the register / `vas_turas_columns.csv` — and await Duncan's sign-off. The remainder of this document is the plan as designed, kept for the reasoning.

Written 23 July 2026, planning only — nothing new built yet. Grounded in a verified run this morning: the existing derived-variables engine was run against the first real fieldwork export from build 8929162 (7 respondents, 810 columns) and passed clean — all 196 required aliases present, all consistency checks OK, 229 derived columns written. So the engine built on 22 July carries over to the new build unchanged.

This plan covers the two remaining pieces:

1.  the composite scores not yet produced, and
2.  the export layer that turns raw export + derived table into one stable, manageable dataset for Turas.

------------------------------------------------------------------------

## 1. Where we already are

Duncan's five requirements against what the engine already produces (everything in this table verified by running it today):

| Requirement | Status |
|------------------------------------|------------------------------------|
| 2\. Txn/month, monthly spend, spend/txn — self / others / total, per category | **Built.** 213 columns: `X_Own/Oth/Total_TxnPerMonth / MonthlySpend / SpendPerTxn` for all 33 categories. Annual items (vehicle licence, TV licence) normalised to monthly (1/12 txn, fee/12). |
| 3\. Total VAS wallet | **Built.** `TotalValueTransacted` (everything at face value), `TotalConsumptionSpend` (consumption only), `ValueReceived` (money in, never added to spend), plus share of wallet ×4 (two totals × two income bases). |
| 5\. Detailed formula explanations | **Built, and generated** — the Dictionary sheet and `VAS Derived Calculations.md` are produced from the same map and config the engine runs on, so they cannot drift. New composites get documented the same way automatically. |
| 1\. Number of VAS categories purchased | **Not built.** `CategoriesAsked` / `CategoriesIncomplete` exist (routing and data-quality counts), but there is no count of categories actually *purchased*. Section 2. |
| 4\. Other useful composites | **Partially.** Section 2 proposes the additions. |

Everything is monthly-normalised. An annual figure for any measure is ×12 — no separate annual columns needed.

## 2. Composite scores to add

All computed at the **Total** base (own + for-others combined), joining the existing headline block. Formulas below are the definition; the generated dictionary will carry them verbatim.

**a. Category incidence flags — `Purchased_<Category>`, 33 columns, Yes/No.** "Yes" when the respondent transacts in the category at all: `Total_TxnPerMonth > 0`, **or** status says they buy but a figure is missing (`freq_missing` / `amount_missing` / `partial`) — someone who ticked DSTV but gave no readable amount is still a DSTV payer. `not_asked` (routed past) = No. These are the crosstab workhorses in Turas: incidence of every category by any banner.

**b. `CategoriesPurchased`** = row-count of the 33 flags. Duncan's item 1. Optionally also per spend class (`CategoriesPurchased_Consumption`, `_Bills`) — cheap to add, decide at build.

**c. Spend-class subtotals** — completes the existing pair. Same `sum_available` arithmetic as the headline totals (present values sum; all-missing stays missing): - `TotalBillSpend` = monthly spend over the obligation class (14 bill categories) - `TotalTransferSent` = monthly spend over the transfer class (DomSend + IntlSend) - Identity check for the sense check: `TotalValueTransacted =   TotalConsumptionSpend + TotalBillSpend + TotalTransferSent`.

**d. The for-others block** — buying for others is a core VAS story and it currently only exists per category: - `TotalSpendForOthers` = sum of `X_Oth_MonthlySpend` over the 19 split categories - `TotalTxnForOthers` = same over transactions - `ShareForOthers` = `TotalSpendForOthers / (TotalSpendForOthers + TotalSpendForSelf)` computed over the split categories only (the 14 single-cascade categories cannot be attributed, so they are excluded from both sides — stated in the dictionary) - `BuysForOthers` = Yes/No, any Oth transactions at all

**e. `AvgSpendPerTxn`** = `TotalValueTransacted / TotalTxnPerMonth` — the respondent's overall ticket size.

Explicitly **not** proposed: light/medium/heavy user segments or any tercile-style banding baked into the data — bands are a reporting decision and belong in the Turas config once distributions are visible (see 3d).

## 3. The Turas dataset

### a. What the 810 export columns are

Measured on today's real export:

| Block | Columns | Disposition |
|------------------------|------------------------|------------------------|
| Admin (Response ID, dates, status, IP, geo) | 10 | keep ID/date/status; drop the rest |
| GPS capture machinery | 27 | drop |
| QC fields (Supervisor, Interviewer) | 3 | drop from analysis dataset (QC lives in the field report) |
| Residence orphan | 1 | drop (known 8912114 leftover) |
| Consumed by the derivation (freq cascades, amounts, counts, presence ticks) | 227 | **replaced by** the derived columns — this is the "we don't need multiple columns on times per week" requirement |
| Survey content (demographics, channels, attitudes, awareness, providers, apps…) | 542 | keep, minus PII (`RespCell`, `IntNotes`, `Consent`) |
| Derived + composites (joined on Response ID) | 229 + \~40 new | keep |

Net: a dataset of roughly the same width but with every column directly usable — the 227 raw metric columns nobody can analyse are replaced by analysis-ready measures. Much of the 542 is checkbox option-columns (\~30 multi-select questions at 7–17 columns each), which Turas handles natively.

Optional consolidation, recommended: the nine per-province town questions (`WC_Town`, `EC_Town`, …) merge into one `Town` column (Province already exists separately).

### b. The column plan is a file, not code

A `vas_turas_columns.csv` in this repo — one row per output column: source (raw header or derived name), action (keep / drop / rename / merge), Turas question code, variable type, label. The builder script executes the plan and **refuses to run** if the export contains headers the plan doesn't mention or vice versa — so a mid-field Alchemer change can never silently shift the dataset. Same philosophy as `vas_category_map.csv`: the rules stay visible, editable and auditable; stability comes from the file, not from memory.

### c. Turas structure rows

Turas needs `Survey_Structure` rows and `Data_Headers` cells for every column. For the derived block these are **generated** from the category map + config (same no-drift guarantee as the dictionary). For the raw content block, the normal AlchemerParser flow applies. Whether the builder emits one merged config or the parser output gets the generated block appended is a build-time call, made after reading the parser's current config format — functionally equivalent either way.

### d. Numerics and banding in Turas

Derived measures go in as numeric variables (means in tabs). Banded categorical variants (spend bands, share-of-wallet bands) are wanted for crosstabs but should be cut **after** distributions stabilise — with n=7 today any band edges would be invented. The builder gets a small config table for bands; it starts empty, Duncan fills it once real data accumulates (n≈100+), and banded columns appear on the next run.

### e. The report register — the human gate (Duncan's design, 23 July)

Duncan's call: an Excel step between the raw export and everything downstream, where he traps and excludes invalid records, with a process to update as fieldwork accumulates. Agreed — with one structural choice: it is a **register keyed on Response ID, not a cleaned copy of the export**. Deleting rows in a copied export loses the work on every re-export and leaves no audit trail; a register survives refreshes (the proven `VAS QC Log` persistence pattern) and records *why* every exclusion happened.

`VAS Report Register.xlsx` in the Fieldwork folder, one row per response:

| Block | Columns |
|------------------------------------|------------------------------------|
| Identity (auto) | Response ID, date submitted, status, interviewer, supervisor, respondent name, cell number |
| Auto-flags (refreshed every run, never overwrite Duncan) | `TestPattern` (test-word in respondent name / implausible cell / before field start), `DuplicateCell`, `QCStatus` (joined from VAS QC Log), `OutlierFlag` (from the latest derived run) |
| Duncan (persist across refreshes) | **Disposition** = Include / Exclude / Review, **Reason** |

New responses default to Include; auto-flagged ones default to Review. The refresh appends new Response IDs and re-computes flags but never touches Disposition or Reason.

**Who reads it:** the derived-numbers run derives on Include + Review (monitoring stays complete) and prints the exclusion tally in the sense check; the **Turas builder refuses to run while any row is still Review** — the final dataset requires every record dispositioned. The current 7 test interviews get auto-flagged on the first refresh; Duncan confirms Exclude.

### f. How Duncan runs it

The register refresh folds into the existing `Run VAS Derived Numbers.command` flow (register first, then derive on the dispositioned rows), which also starts archiving the input export it read. The Turas dataset gets its own `Run VAS Turas Dataset.command` — end-of-field or milestone, not monitoring — writing `VAS Turas Data.xlsx` + config sheets, timestamped copies in `Archive/`.

So the pipeline is:

```         
VAS Export.xlsx  (raw, archived per run)
   └─> VAS Report Register.xlsx      Duncan traps/excludes; process re-runnable
         └─> derived engine           composites, on dispositioned records
               └─> VAS Turas Data.xlsx + config   combined dataset for Turas
```

## 4. Decisions needed before building

Carried forward from 22 July plus new ones. **The first two change the numbers; the rest are confirmations.**

1.  **Outliers.** Of the first 7 exported responses one sits at 160% share of wallet — though note all 7 are test interviews (see section 6), so the real evidence remains the 8912114 test export, where 5 respondents hit 129–726%. Recommendation (unchanged from yesterday): per-spend-class plausibility ceilings in the config (30 airtime buys/month is plausible; 30 municipal bills is not), breaches **flagged, never silently capped**, surfaced in the sense check, with an `OutlierFlag` column so Turas reporting can exclude from means. Proposed ceilings tabled at build for Duncan to edit.
2.  **`amount_max` = 200,000 rejects real R1m transfer answers.** Fold into the outlier system: per-spend-class amount ranges (transfers up to R1m, others stay at 200k) instead of one global cap.
3.  **Six no-frequency bills lack a presence alias** (DSTV, municipal, Telkom, insurance, internet, vehicle), so ticked-but-blank currently reads as R0 rather than missing — and would wrongly read as *not purchased* in the new incidence flags. Fix is mechanical: fill `presence_alias` / `presence_option` for those 12 map rows. Will just be done as part of the build unless Duncan objects.
4.  **Purchased definition** (section 2a): txn \> 0 at Total, or buys-but- missing. Confirm.
5.  **Partials**: 30 of 121 responses in the 8912114 test export were partials whose un-reached categories read as genuine zeros. `CategoriesAsked` lets reporting filter. Proposed rule: Turas dataset carries partials, flagged; headline means in reporting use completes only. Confirm.
6.  **Freq4 arithmetic**: implemented as `Freq4/12` (4 a year = 0.333/month); the old plan's worked example said 0.25. Confirm the formula stands.
7.  **Bottom income band** midpoint = its own ceiling (R3,500), so share of wallet is understated for the poorest band. Accept, or set a lower midpoint (e.g. R2,500).
8.  **PII/QC drop list** (RespCell, IntNotes, Consent, Supervisor, Interviewer, GPS, IP): confirm none are wanted as analysis variables. (Supervisor/Interviewer can stay in the QC world.)

## 5. Build order

Each stage ends with something that can fail:

0.  **Report register + input archiving** (section 3e/f) into the fieldwork runner. Gate: refresh twice — dispositions survive; doctor a test-pattern row — it flags; exclusion tally appears in the sense check.
1.  **Map + config fixes** — presence aliases (item 3), per-class amount ranges, outlier ceilings. Gate: existing 282 tests + new tests for the presence path; re-run against the real export and eyeball the sense check.
2.  **Composites** (section 2) into `vas_derive.R` + dictionary generators. Gate: unit tests incl. the new spend-class identity; hand-check 2–3 respondents end to end against raw answers.
3.  **Column plan + Turas builder** (section 3), consuming the register. Gate: builder refuses on a doctored export with an extra/missing header AND on any undispositioned (Review) row; output workbook read back — every column in the plan, every plan row in the output; structure rows match Data_Headers 1:1.
4.  **Turas ingest smoke test** — feed the dataset + config into tabs on the small live sample; Duncan eyeballs via launch_turas (regeneration is Duncan's step, per standing rule).

## 6b. Association maps (input written 23 July; TOOL BUILT the same evening)

**Built:** shared CA engine + renderer in the Turas repo (`modules/shared/lib/ca_engine.R`, `ca_html.R`, 37 tests) and the VAS runner in the Reporting folder (`build_vas_association_map.R` + `Run VAS Association Map.command`), producing `VAS Association Map.html` — aware-base and all-respondent maps with the input matrix under each. Verified on the test dataset; the aware-base map refuses (correctly) until real sample clears the min-base of 30. The guardrails below are implemented.

What the instrument collects: 12 attribute questions (safe, fast, cash, convenient, easy, free/low-cost, transparent, no-bank-account, no-airtime, confirms, help, available), each a multi-select over the same 13 payment channels; an Awareness multi-select over the channels; and AttrTop3 (pick the three attributes that matter most). A textbook channels x attributes association setup.

**In Turas (already done):** every one of these is now a Multi_Mention question in the generated dataset and config, so each attribute crosstabs as channel-% by any banner out of the box.

**The map itself:** Turas has no correspondence-analysis module. Recommendation: a small standalone R script in the Reporting folder that builds the channels x attributes matrix from `VAS_Turas_Data.xlsx` and renders a CA biplot (HTML/PNG) - quick, and gives Duncan the visual to work with; a Turas association-map tab is a later roadmap item alongside the market-size model.

**Guardrails for the map:** - **Base decision (the big one):** associations among ALL respondents just reproduce awareness - the best-known channel wins every attribute. Recommend: % of those AWARE of the channel who associate it with the attribute (with the all-respondents view available as a secondary cut). - Exclude "None of these" and "Other" from the map. - AttrTop3 = stated importance; use it to order or size the attribute points. - Instrument quirks found in the snapshot: **AttrAvailable offers 13 options where the other attributes offer 14** (one channel is missing from its list), and **Awareness does not include the specialist-app channel** that the attribute questions do - so specialist apps cannot be put on an aware-base. Both need a stated handling rule, and a questionnaire check before any 2028 wave. - CA needs the full sample; the current 34 test rows render nothing meaningful. Build the script so it runs against any dataset build.

## 6. Blind spots found on the 23 July pass

Verified by checking, not hypothesised:

1.  **All 7 rows in today's export are test interviews** (Respondent = "Test", "Ggg", "duncan"; RespCell = "0111111111", "Pp00000000") and there is **no systematic flag** separating test from real. Once real interviews mix in, the boundary is guesswork. Needs a rule NOW — e.g. everything up to a named Response ID / before the field-start date is test — enforced in `run_vas_fieldwork.R`, the QC report and the Turas builder, with the excluded count printed in the sense check.
2.  **Tabs medians are unweighted-only** (`show_numeric_median` renders "N/A (weighted)" on weighted runs — `numeric_processor.R`). Spend data is right-skewed, so medians matter; if VAS reporting is weighted, medians vanish from tabs. Forces the weighting decision early. Counter-discovery: the tabs numeric processor advertises **binning via Options and outlier detection** — so banded variants may not need building into the dataset at all (bands could live in the Turas config). Verify at build; would simplify section 3d.
3.  **Raw exports are never archived** — `Archive/` holds outputs only, and `VAS Export.xlsx` gets overwritten. A past deliverable cannot be reproduced. Fix: the runner archives the export it read, same timestamp as the outputs.
4.  **No QC-to-reporting link.** The QC Log carries interview statuses but nothing downstream consumes them — a rejected interview flows into the dataset. Builder should take a disposition input (the QC log itself) and flag duplicate RespCell values.
5.  **Weighting / market sizing undecided.** If Electrum expects "the VAS market is worth R X" projections, that needs weights + population totals and touches the dataset (weight column), the tabs config, and medians (item 2). If reporting is sample-descriptive only, that should be said out loud to the client. Mid-field is the last chance to fix coverage gaps weighting can't rescue.
6.  **Base conventions.** Every spend measure has two honest bases — all adults (zeros in) vs purchasers of the category (via the new incidence flags). Convention per measure must be explicit in the Turas config or decks will mix them.
7.  **Wave comparability.** Duncan (23 July): 2026 WILL be reconciled to 2024 and 2022, but deferred — priority is getting 2026 right first. When it happens: check the 2026 definitions (weeks/month factor, income midpoints, wallet definitions) against what 2024/2022 reported and document divergences. Items 1 and 4 of this list are addressed by the report register (section 3e).
8.  Smaller, for the reporting caveats list: July fieldwork + "last occasion" makes event spend seasonal; household income vs personal spend in share of wallet (already noted); rare categories (theatre, international flights/transfers) will carry tiny bases for spend stats; a high "Decline to answer" rate on Income silently shrinks the share-of-wallet base — worth a line in the sense check.
