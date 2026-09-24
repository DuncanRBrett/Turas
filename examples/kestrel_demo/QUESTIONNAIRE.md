# Kestrel Bank customer tracker: questionnaire

**Status:** Draft for Duncan's review, 24 Sep 2026.
**Purpose:** The instrument behind the Turas demo. Synthetic data is
generated from it (see `STORY_SHEET.md`). It is written as if it were a real
study so the demo looks and behaves like one, including routing, don't-know
options and quality checks.
**Mode:** Online panel, mobile-first, every battery item by item (no grids).
**Length:** About 14 minutes for the core. Wave 4 adds a deep-dive of about
7 minutes, split across two halves of the sample so no one does more than
about 18 minutes (see section F).

Everything is fictional. Bank names are placeholders to be checked against
real South African banks before anything is shown outside TRL.

---

## 1. Objectives

1. Track recommendation (NPS) and satisfaction for Kestrel and its
   competitors, wave on wave.
2. Explain what drives recommendation, and estimate what improving each
   area could be associated with (key drivers and What-if).
3. Identify who is likely to switch banks, and why (catdriver).
4. Measure Kestrel's mental availability and brand funnel against four
   competitors.
5. Segment banking customers by what they want from a bank.
6. Wave 4 only: rank account features (MaxDiff), test account bundles
   (conjoint), and price a premium account (Van Westendorp and
   Gabor-Granger).
7. Capture customers' own reasons for their scores, in their own words.

## 2. What each section feeds

| Section | Objective | Analysis | Turas module |
|---|---|---|---|
| S Screener | All | Quotas, weighting, main-bank base | Weighting, tabs |
| A Moments (CEPs) | 4 | Mental availability, CEP × brand | Brand (or tabs) |
| B Funnel | 4 | Awareness → consideration → main bank | Brand funnel (or tabs) |
| C Main bank experience | 1, 2 | NPS, satisfaction, drivers, What-if levers | Tabs, tracker, keydriver, What-if |
| D Comments | 7 | Coded themes, verbatims | Comments tab (qual) |
| E Switching | 3 | Switching intent | Catdriver, tabs |
| F Deep-dive (W4) | 6 | MaxDiff, conjoint, pricing | MaxDiff, conjoint, pricing |
| G What matters to you | 5 | Segmentation basis | Segment |
| H About you | All | Banners, weighting, What-if profile | Tabs, weighting, What-if |

## 3. Constructs and how they're measured

| Construct | Measure | Why this way |
|---|---|---|
| Recommendation | NPS, standard 0–10 wording | Comparability with every other NPS the client has seen |
| Overall satisfaction | Single 0–10 rating, endpoints labelled | Duncan's standard anchor question |
| Experience areas | 8 statements, 0–10, item by item, don't-know option | Same scale as NPS, so drivers and What-if work on one metric |
| Problem handling | Had a problem (yes/no), then sorted first time (yes/no/still open) | Behaviour rather than opinion, and only asked of those it applies to |
| Switching intent | 5-point likelihood, fully labelled | Ordered outcome for catdriver |
| Mental availability | Multi-select brands per moment | Ehrenberg-Bass format, as the brand module expects |
| Funnel | Aided awareness, consideration, ever used, main bank | Standard funnel stages |
| Segmentation attitudes | 6 bipolar pairs, 5 points | Balanced stems reduce yes-saying |
| Feature priorities | MaxDiff, 12 features | Forces trade-offs; importance ratings come out flat |
| Bundle preferences | Choice-based conjoint with a none option | Revealed trade-offs, and a real none share for the simulator |
| Price | Van Westendorp (4 questions) and Gabor-Granger (5-rung ladder) | The standard techniques, not improvised |

Nothing in the tracker changes wording between waves. Section F is a one-off
module in wave 4 and does not affect the tracked questions.

---

## 4. The questionnaire

Routing is shown in **[square brackets]**. "Randomise" means per respondent.

### Introduction

> Thanks for taking part. This survey is about banking: which banks you use
> and what you think of them. It takes about 15 minutes. Your answers are
> confidential and are only ever reported in groups, never on their own.

### S. Screener

**S1.** How old are you?
*Numeric, 18–99.* [Under 18: close. Quotas by age band.]

**S2.** Do you have a personal bank account in your own name?
- Yes
- No [close]

**S3.** Which of these banks do you have a personal account with? *Select
all that apply.* *Randomise banks, "Other" and "None" fixed at the end.*
- Kestrel Bank
- Granite Bank
- Meridian Bank
- Harbour Bank
- Lumen Bank
- Another bank (please specify)

**S4.** [If more than one bank at S3] And which one do you think of as your
**main** bank, the one most of your money goes through? *Single select, from
S3 answers.*
[If one bank at S3, it becomes the main bank automatically. The main bank is
piped into section C as [MAIN BANK]. Kestrel customers from the booster
sample qualify here too.]

### A. Moments when you might think of a bank

*Asked before awareness, so awareness questions don't prompt the answers.*

**A1.** Here are some moments when people might think of a bank. For each
one, which banks, if any, come to mind? *Select all that apply, one moment
per page. Randomise moments and banks. "None of these" on every page.*

1. When I want to save for something big
2. When I need to send money to family
3. When I want banking on my phone that just works
4. When I'm worried about paying too much in fees
5. When I need a loan quickly
6. When I want to earn rewards on my spending
7. When I'm starting my first job
8. When I need help from a real person

### B. Banks you know

**B1.** Which of these banks have you heard of, even if only by name?
*Select all. Randomise. Banks from S3 are pre-ticked and cannot be unticked.*

**B2.** [For each bank at B1] If you were choosing a bank today, would you
consider...? *One bank per page.*
- I would definitely consider it
- I might consider it
- I would not consider it

**B3.** [For each bank at B1 not at S3] Have you ever had an account with...?
- Yes, in the past
- No, never

*S3, S4 and B1–B3 together give the funnel: aware → would consider → ever
used → current customer → main bank.*

### C. Your main bank

**C1.** How likely is it that you would recommend [MAIN BANK] to a friend or
colleague?
*0 = Not at all likely … 10 = Extremely likely.*

**C2.** Overall, how satisfied are you with [MAIN BANK]?
*0 = Not at all satisfied … 10 = Completely satisfied.*

**C3.** In the last 3 months, have you had a problem or query that you needed
[MAIN BANK] to sort out?
- Yes
- No [skip C4]

**C4.** Was it sorted out the first time you contacted them?
- Yes, first time
- Yes, but it took more than one try
- No, it's still not sorted

**C5.** How much do you agree with each of these about [MAIN BANK]?
*0 = Strongly disagree … 10 = Strongly agree, with "Don't know / not
applicable" set apart below the scale. One statement per page. Randomise.*

1. The app is easy to use
2. The app works when I need it
3. Fees are fair for what I get
4. I understand what I'm being charged for
5. When I have a problem, it gets sorted out the first time
   [only if C3 = Yes; otherwise recorded as not applicable]
6. It's easy to reach a real person
7. I feel my money is safe with them
8. They reward me for being a customer

*These eight are the key driver inputs and the What-if levers. C5_5 and
C5_6 are expected to overlap, which the What-if halo check reports.*

### D. In your own words

**D1.** You gave [MAIN BANK] a score of [C1] out of 10 for recommending it.
What's the main reason for that score? *Open text, required, minimum 3
characters.*

### E. Staying or switching

**E1.** How likely are you to move your main account to a different bank in
the next 12 months?
- Definitely will not
- Probably will not
- Not sure
- Probably will
- Definitely will

**E2.** Which of these do you currently have with [MAIN BANK]? *Select all.*
- Everyday transaction account
- Savings or notice account
- Credit card
- Personal loan
- Home loan
- Insurance through the bank
- None of these

**E3.** In a typical week, how often do you use your bank's app?
- Every day
- A few times a week
- About once a week
- Less often
- I don't use the app

**E4.** And how often do you go into a branch?
- At least once a month
- A few times a year
- Once a year or less
- Never

### F. Wave 4 deep-dive: designing an account

*Wave 4 only. The sample is split at random into two halves:*
*half 1 gets F1 (MaxDiff) and F3 (pricing); half 2 gets F2 (conjoint).*
*This keeps everyone under about 18 minutes. Each half is about 600 people,
enough for each method.*

**F1. MaxDiff: what matters most in a bank account** [Half 1]

> On the next few screens you'll see four features of a bank account at a
> time. Pick the one that matters **most** to you and the one that matters
> **least**.

*6 screens of 4 features, from the MaxDiff module's own design (balanced,
each feature shown twice).*

1. No surprise fees
2. Fraud refunded within 24 hours
3. A real person when I need one
4. Instant notifications for every transaction
5. A branch near me
6. Interest on my everyday balance
7. Cashback on card spending
8. Free payments to anyone
9. Budgeting tools in the app
10. Choice of card designs
11. Budgeting badges and streaks
12. Easy to open an account on my phone

**F2. Conjoint: choosing an account** [Half 2]

> Imagine you're choosing a new everyday bank account. On each screen you'll
> see three accounts. Pick the one you'd choose, or "none of these" if you
> wouldn't open any of them.

*8 screens of 3 accounts plus "None of these". Design generated by the
conjoint module.*

| Attribute | Levels |
|---|---|
| Monthly fee | R49 / R79 / R99 / R129 |
| Cashback on card spending | None / 1% / 2% |
| Free transactions | 10 a month / Unlimited |
| Branch access | App and phone only / App, phone and branches |
| Interest on savings | Standard rate / Standard plus 1% |

**F3. Pricing Kestrel Plus** [Half 1]

> Kestrel Plus is a premium account from Kestrel Bank. It includes
> unlimited free transactions, 1% cashback, travel insurance and priority
> help from a real person.

*Van Westendorp. Rand amounts, whole numbers, validated so that each answer
is at least the one before.*

**F3a.** At what monthly fee would Kestrel Plus be so cheap that you'd
question its quality?
**F3b.** At what monthly fee would it be a bargain: good value for money?
**F3c.** At what monthly fee would it start to feel expensive, though you'd
still consider it?
**F3d.** At what monthly fee would it be too expensive to consider?

*Gabor-Granger. Start at R99, then step down if "no" or up if "yes" (the
module handles stop-early designs).*

**F3e.** Would you sign up for Kestrel Plus at R[PRICE] a month?
*Ladder: R59 / R79 / R99 / R119 / R149.*
- Yes, I would
- No, I would not

### G. What matters to you in a bank

**G1–G6.** Some people feel one way, others feel the other way. Where would
you put yourself? *5 points between the two statements, fully labelled
("Much closer to the left" … "Much closer to the right"). One pair per page.
Randomise pairs.*

| | Left | Right |
|---|---|---|
| G1 | I'd rather do all my banking on my phone | I'd rather deal with a person |
| G2 | I'll move banks to save on fees | Fees aren't worth the hassle of moving |
| G3 | I want my money to grow, even if slowly | I want my money available, not locked away |
| G4 | Rewards and cashback matter to me | Rewards are a gimmick |
| G5 | I trust the big, established banks more | Newer banks are just as safe |
| G6 | I like to try new apps and services | I stick with what I know |

*These are the segmentation basis. The segment variable is written back to
the data as a banner.*

### H. About you

**H1.** Gender
- Man
- Woman
- I describe myself another way
- Prefer not to say

**H2.** Which province do you live in? *Nine provinces.*

**H3.** Which best describes where you live?
- A big city or its suburbs
- A town
- A rural area

**H4.** What is your household's total monthly income before tax? *Bands,
plus "Prefer not to say".*

**H5.** Which best describes you?
- Working full time
- Working part time
- Self-employed
- Studying
- Not working
- Retired

*Age comes from S1. Age, gender, province (grouped) and area type are the
weighting variables. They also feed the What-if "who is the customer"
profile.*

### Close

> That's everything. Thank you for your time. Your answers will help banks
> understand what their customers want.

---

## 5. Routing summary

| Path | Who | Sees |
|---|---|---|
| 1 | One bank | S1–S3, A, B, C1–C3, C5 (C5_5 not applicable), D, E, G, H |
| 2 | One bank, had a problem | As path 1, plus C4 and C5_5 |
| 3 | Several banks | As path 1 or 2, plus S4 |
| 4 | Wave 4, half 1 | Any path above, plus F1 and F3 |
| 5 | Wave 4, half 2 | Any path above, plus F2 |
| Closed | Under 18, or no personal account | S1 or S2 only |

No path ends early for a qualifying respondent, and no one sees a question
about a bank they don't use.

## 6. Quality controls

- **Speeders:** flag completes faster than a third of the median time.
- **Straightliners:** flag identical answers across all eight C5 items.
- **Open-end check:** flag D1 answers that are gibberish or copied across
  respondents.
- **Consistency:** a main bank at S4 must be among the banks at S3. Main-bank
  customers who say at B2 they "would not consider" their own bank are kept
  but flagged.
- **In the synthetic data:** the generator plants about 3% speeders and 2%
  straightliners, so the cleaning step has something real to remove.

## 7. Length estimate

| Block | Items | Minutes |
|---|---|---|
| S Screener | 4 | 1.0 |
| A Moments | 8 pages | 3.0 |
| B Funnel | 3 (per bank) | 2.5 |
| C Main bank | 12 | 3.5 |
| D Comment | 1 open | 1.5 |
| E Switching | 4 | 1.0 |
| G Attitudes | 6 | 1.5 |
| H About you | 5 | 1.0 |
| **Core total** | | **about 15** |
| F half 1 (MaxDiff 6 screens + pricing 5) | | +4 |
| F half 2 (conjoint 8 screens) | | +3.5 |

This is over the 10-minute ideal for low-interest topics, but banking
customers rating their own bank tolerate more. For a real study, I'd cut
section A to 6 moments first.

## 8. Verification checklist notes

- Every question traces to an objective (table 2).
- NPS uses the standard wording and scale.
- No grids: every battery is one item per page.
- Don't-know options on the C5 opinion items. None on behaviour questions.
- Banks, moments, C5 items and G pairs are randomised. Ordered scales are not.
- Every routing path is listed in section 5.
- Open for Duncan: the brand-module decision in `STORY_SHEET.md`, and the
  weighting targets.
