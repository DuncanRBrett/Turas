# VAS 2026 — derived variables plan (transactions per month, spend)

Draft plan, 22 July 2026. **Nothing built yet.** Written from the verified
survey structure of 8912114 so the design rests on what the instrument actually
collects, not on what it looks like it collects.

Goal, as stated: for each pay point — transactions per month, total monthly
spend, and spend per transaction, each split self / someone else / total.

---

## 1. The complication: spend is collected on three different bases

This is the thing that shapes the whole design. The amount questions are **not**
asking the same thing across categories:

| Basis | Wording | Categories |
|---|---|---|
| **Per month** | "in a typical month", "each month", "per month" | prepaid electricity (own + other), short-distance bus (own + other), and the 5 monthly bills (DSTV, Municipal, Telkom, Insurance, Internet) |
| **Per transaction** | "how much do you usually spend each time" | airtime, data, digital vouchers, LOTTO, betting, domestic send, domestic receive, international send |
| **Last occasion** | "how much did you pay the last time" | the 7 occasional bills (traffic, clothing, furniture, education, health, retail credit, other), vehicle licence, and all 6 event types |

So the arithmetic runs in **opposite directions** depending on the category:

- per-transaction basis → `monthly spend = txn/month x amount`
- monthly basis → `spend/txn = amount / txn/month`
- last-occasion basis → treat as per-transaction, but it is a single noisy
  observation rather than a typical value

Any single formula applied across all categories would be wrong for two thirds
of them.

## 2. Converting the frequency cascade to transactions per month

Every cascade category follows Freq1 → Freq2/3/4:

| Freq1 answer | Source | Transactions per month |
|---|---|---|
| Once a week or more often | Freq2 (1-7 per week) | `Freq2 x 52/12` (= x 4.333) |
| A few times in a month | Freq3 (1-4 per month) | `Freq3` |
| Once per month | — (no follow-up by design) | `1` |
| Less than once per month | Freq4 (1-11 per year) | `Freq4 / 12` |
| Freq4 = "Don't know" | — | missing |

Duncan's worked example (4 a year → 0.25) is the Freq4 row.

## 3. Category inventory — six structural groups

| Group | Structure | Categories | Self/other split? |
|---|---|---|---|
| **A** | cascade + per-transaction spend | airtime, data, vouchers | **yes** |
| **B** | cascade + per-transaction spend | LOTTO, betting, domestic send, domestic receive, international send | no — single cascade |
| **C** | cascade + monthly spend | prepaid electricity, short-distance bus | **yes** |
| **D** | cascade + last-occasion spend | 7 occasional bills | **yes** |
| **E** | cascade + last-occasion spend | 6 event types (sport watching, sport participation, concerts, cultural, theatre, other) | no — single cascade |
| **F** | count only, **no spend question at all** | flights (domestic + international), long-distance bus | no |
| **G** | **no frequency question**, monthly spend | 5 monthly bills — DSTV, Municipal, Telkom, Insurance, Internet | **yes** |
| **H** | **no frequency question**, annual spend | vehicle licence | **yes** |

Twelve categories carry a genuine self / someone-else split. Eleven do not — for
those, "self vs someone else" cannot be produced at all.

## 3b. Decisions taken (Duncan, 22 July)

- **"Pay point" = service category**, not channel. No spend-per-channel; the
  unit is transactions and spend per respondent per category.
- **Flights and long-distance bus**: Duncan supplies a value to impute per
  ticket, so those get a spend after all.
- **Where only self is asked** → produce self only.
- **Where the question combines** → produce total only. No self/other split
  invented where the instrument doesn't collect one.
- **Bills**: Duncan defines which are annual; last-occasion spend is taken as
  the average per transaction.
- **Output**: one row per respondent — ID, monthly income category, all derived
  fields, a total VAS spend per month, and share of wallet from that.

## 3c. Settled parameters (all confirmed by Duncan, 22 July)

Held in `vas_derived_config.R`; the per-category detail is in
`vas_category_map.csv` (52 rows — 19 Own, 19 Oth, 14 Total — generated from the
survey by `build_category_map.R`, every alias verified to exist).

**Imputed spend, normalised to per leg.** The survey asks whether a respondent's
count is of one-way or return trips, so the count is converted to legs first.

| | per leg | one-way trip | return trip |
|---|---|---|---|
| Domestic flight | R1,500 | R1,500 | R3,000 |
| International flight | R7,500 | R7,500 | R15,000 |
| Long distance bus | R750 | R750 | R1,500 |

**TV licence** — R265 per annum. The survey deliberately collects no amount and
no frequency for it, so presence is read off the "TV License" selection in
`BillOwnWhich` / `BillOthWhich` and the fee is imputed. Annual, so 1/12 of a
transaction and R22.08 of spend per month.

**Annual cadence**: vehicle licence and TV licence. The other four
no-frequency bills (DSTV, municipal, Telkom, insurance, internet) are monthly at
1 transaction per month. The seven occasional bills are unaffected — they carry
real frequency cascades.

**Income**, both variants produced:

| Band | Midpoint | Upper |
|---|---|---|
| Less than R3,500 | 3,500 | 3,500 |
| R3,500 to R7,999 | 5,750 | 7,999 |
| R8,000 to R21,999 | 15,000 | 21,999 |
| R22,000 to R39,999 | 31,000 | 39,999 |
| R40,000 to R74,999 | 57,500 | 74,999 |
| More than R75,000 | 100,000 | 100,000 |
| Decline to answer | excluded | excluded |

**Two headline totals**, both built:
- `TotalValueTransacted` = consumption + obligation + transfer (28 obligation rows will dominate)
- `TotalConsumptionSpend` = consumption only (21 rows)
- `ValueReceived` reported separately — money in, never added to a spend total

## 4. Open decisions — these change the output, so needed before building

1. **What is a "pay point"?** The plan above assumes it means the **service
   category** (electricity, airtime, data, …). If it means the **channel** (bank
   ATM, retailer till point, spaza …) then this cannot be built from the data:
   the survey captures each respondent's main and other channels, but never how
   their transactions divide between them. That would need either an attribution
   rule (e.g. all volume to the main channel) or a questionnaire change.

2. **Weekly-to-monthly factor**: `52/12` (4.333) or a flat `4`?

3. **"Don't know" on Freq4**: leave the respondent missing for that category, or
   impute (e.g. category median)?

4. **Group C and G — deriving spend per transaction by division.** The
   respondent gave a monthly figure and never a per-transaction one. Dividing is
   arithmetically fine but it is a derived estimate, not a reported value. Happy
   with that, and should it be labelled as such in the reporting?

5. **Group G frequency**: assume exactly 1 transaction per month for the five
   monthly bills? And Group H, 1/12 per month for vehicle licence?

6. **Group F has no spend question.** Flights and long-distance bus give
   transaction counts but no rand value at all. Accept transactions-only, or is
   this a gap to close before fieldwork?

7. **"Last occasion" as typical spend** (groups D and E). Acceptable as a proxy?
   It is a single observation, so noisier and more exposed to outliers than a
   "usually" question.

8. **Totals.** Confirm "total" means self + someone else within a category. Do
   you also want a grand total across all categories per respondent — and if so,
   how are the eleven no-split categories folded in?

9. **Outliers and cleaning.** All amounts are free-text boxes. Expect "R150",
   "150,00", "about 200", "150-200", "dont know". Needs a parsing rule and an
   outlier policy (cap, winsorise, or flag-and-exclude).

10. **Where the output goes.** One row per respondent with derived columns
    appended to the data file is the obvious shape. Those columns then need
    Survey_Structure rows and Data_Headers cells to reach Turas — worth deciding
    whether they are generated by the same script.

## 4b. What the total and share of wallet still need settling

**a. Domestic receive is money coming IN, not out.** q209 asks "How much do you
usually *receive* each time?". It must not be added to a spend total. Proposal:
count its transactions in the frequency measures, report its value separately as
"value received", and exclude it from total VAS spend.

**b. Transfers and bills will dominate the total.** DomSend, IntlSend and the
bill payments are captured at face value. Someone sending R2,000 a month and
buying R100 of airtime is 95% transfer. So "total VAS spend" can mean two
different things:

- **Value transacted** — everything at face value, i.e. what share of income
  flows through these rails. Coherent, and probably what share of wallet wants.
- **Spend on the services** — the consumption categories only (airtime, data,
  vouchers, LOTTO, betting, tickets), excluding transfers and bill obligations.

They answer different questions and the numbers differ by an order of magnitude.
Cheapest resolution: build both — `TotalValueTransacted` and
`TotalConsumptionSpend` — and let the reporting choose. Needs a decision either
way because it drives what share of wallet means.

**c. Income is banded, so share of wallet needs midpoints.**

| Band | Proposed midpoint |
|---|---|
| Less than R3,500 | R2,500 (assumed) |
| R3,500 to R7,999 | R5,750 |
| R8,000 to R21,999 | R15,000 |
| R22,000 to R39,999 | R31,000 |
| R40,000 to R74,999 | R57,500 |
| More than R75,000 | **open-ended — needs a value** |
| Decline to answer | no share of wallet; excluded |

Two caveats worth carrying into the reporting: the bottom and top bands are
assumptions, not measurements; and the question asks **household** income while
several spend questions are personal, so share of wallet is
personal-spend-over-household-income unless that is reconciled.

**d. Missing versus zero in the total.** A respondent who does not buy a
category is a genuine **zero** and should total as zero. A respondent who *does*
buy but whose amount is blank or unparseable is genuinely **missing** — folding
them in as zero understates their total and their share of wallet. Proposed
rule: carry a per-respondent completeness flag, compute the total from what is
present, and let the reporting decide whether to exclude incomplete respondents
from share-of-wallet means. Needs confirming.

**e. Which categories are "self only" versus "combined"** — my reading of the
instrument, for confirmation:

| Treatment | Categories |
|---|---|
| Self + other + total | electricity, airtime, data, vouchers, short-distance bus, the 7 occasional bills, the 5 monthly bills, vehicle licence |
| Total only (single cascade) | LOTTO, betting, domestic send, domestic receive, international send, the 6 event types, flights, long-distance bus |

LOTTO and betting are Yes/No and inherently about the respondent, so they are
"self" in meaning but produce a single figure either way.

## 5. Proposed shape once decided

For each category `X` and each base `Own` / `Oth` / `Total`:

```
X_Own_TxnPerMonth      X_Oth_TxnPerMonth      X_Total_TxnPerMonth
X_Own_MonthlySpend     X_Oth_MonthlySpend     X_Total_MonthlySpend
X_Own_SpendPerTxn      X_Oth_SpendPerTxn      X_Total_SpendPerTxn
```

with `X_Total_SpendPerTxn = X_Total_MonthlySpend / X_Total_TxnPerMonth` rather
than the mean of the two sides, so it stays a true weighted figure.

Implementation: a single R script taking the Alchemer export and emitting the
derived columns, driven by a **lookup table** of one row per category giving its
group, its Freq1-4 aliases, its amount alias and that amount's basis. That keeps
the rules visible and checkable rather than buried in code — and makes the
group-by-group differences in section 1 auditable.

## 6. Recommendation on sequencing

Plan here (this session holds the verified survey structure), build in a fresh
session working from this document. The build needs the export, the Turas
integration and a test harness — a different working set from the survey
programming.
