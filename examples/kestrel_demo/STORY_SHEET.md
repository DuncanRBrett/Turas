# Kestrel Bank demo: story sheet

**Status:** Draft for Duncan's review, 24 Sep 2026. Nothing has been generated yet.
**Companion:** `QUESTIONNAIRE.md` (the survey the synthetic data is drawn from).

This sheet lists what the synthetic data must show. The data generator is
built to produce these findings. The finished report is then checked against
this sheet, the same way a known-answer test checks a function. If a finding
here does not show up in the report, the generator is wrong. It does not mean
the demo has found something new.

Everything is fictional: the bank, its four competitors, the customers and
the comments. Before anything is shown outside TRL, check that none of the
bank names belongs to a real South African bank or brand.

---

## What gets built

One tabs v2 report, with no Report Hub. The modules arrive as tabs inside it:
tracking, comments, key drivers, catdriver, What-if, conjoint, MaxDiff and
pricing. The conjoint and pricing simulators sit beside the report and are
linked from their tabs, as in the Karoo demo (`examples/integrated_demo/`).

Two modules have no v2 tab, so they come in another way:

- **Segmentation** runs on its own, and its segment variable is joined to the
  data so segments work as a banner in every table.
- **Brand** (mental availability and funnel) still builds its own report.
  **Decision for Duncan:** either build the brand report as a second file
  beside the main one, or leave the brand module out and show awareness,
  consideration and main bank as ordinary tabbed questions. The second is
  simpler and keeps everything in one file.

---

## The setting

Kestrel Bank is a digital-first South African bank, about eight years old,
with roughly one customer in six of the banked adults in its market. Its
customers run young and urban. It competes with four fictional banks:

| Bank | Character |
|---|---|
| **Kestrel** (focal) | App-first challenger. Known for the app and low fees. Weak on human help and lending |
| **Granite** | The biggest traditional bank. Everyone knows it. Under-35s rarely consider it |
| **Meridian** | Traditional, strong in the Western Cape, good branch service |
| **Harbour** | Mid-sized, strong on home loans and older customers |
| **Lumen** | Newer digital rival, rewards-led, growing among under-30s |

The tracker runs quarterly: four waves from Q3 2025 to Q2 2026. Two things
happened to Kestrel during that year, and they drive the whole story:

1. **January 2026 (between waves 2 and 3):** Kestrel raised its monthly
   account fee from R79 to R99.
2. **April 2026 (between waves 3 and 4):** Kestrel relaunched its app,
   fixing the crashes customers had complained about.

Wave 4 also carries a one-off deep-dive: MaxDiff on account features, a
conjoint on account bundles, and pricing questions on a premium account
("Kestrel Plus").

## Sample and weighting

- About 1,000 national interviews per wave from an online panel, plus a
  booster of about 250 Kestrel customers per wave, so Kestrel's customers
  can be read on their own.
- The panel over-represents under-35s and metro areas, as online panels do.
- The weights correct both: the booster is weighted back to Kestrel's real
  share of main-bank customers, and rim weights bring age, gender, region and
  area type in line with the banked-adult population (targets to be set in
  the generator, stated in the stats pack).
- **The weighting finding:** unweighted, Kestrel's wave 4 NPS reads about
  +31. Weighted, it's about +24. Roughly 7 points of the good news comes from
  who answered, not what customers think. Unweighted, Kestrel's share of
  main-bank customers also looks about twice its real size. Switching
  weighting on and off in the report should show both.

## The planted findings

Numbers are targets for the weighted data. The generator should land within
2 to 3 points of each, with ordinary sampling noise on top.

### 1. The tracker: a fee rise, then a recovery for the young only

| Kestrel NPS | W1 (Q3 2025) | W2 (Q4 2025) | W3 (Q1 2026) | W4 (Q2 2026) |
|---|---|---|---|---|
| All Kestrel customers | +28 | +30 | +17 | +24 |
| Under 35 | +34 | +35 | +26 | +38 |
| 50 and over | +24 | +25 | +5 | +8 |

- The W2 to W3 drop is significant overall and among the 50+.
- The W3 to W4 rise is significant among under-35s only. The app relaunch
  won back the young. It did nothing for the older customers who left over
  the fee.
- Competitors stay flat within noise, except Lumen, which gains about 5
  points of consideration among under-30s by W4.

### 2. What drives NPS: service, not fees

Key driver analysis on NPS, all main-bank customers, wave 4:

- **"When I had a problem, it was sorted out the first time"** is the
  strongest driver overall. This is the surprise, because everyone assumes
  fees come first.
- **"Fees are fair for what I get"** is second for the 50+ from W3 onwards,
  and well down the list for under-35s.
- **"The app works when I need it"** is the top driver for under-35s.
- **"It's easy to reach a real person"** overlaps heavily with "problem
  sorted first time". In the What-if tab it should show as caught in the
  halo, with its number kept.

### 3. What if: fix the problem-handling

- In the What-if tab, fixing "problem sorted first time" for the Kestrel
  customers who rate it poorly should show the largest NPS gain of any area:
  about +6 points overall, and more for the 50+.
- Fixing fees for the 50+ shows about +4 for that group.
- The wording must stay association, not cause: "customers who rate this
  well recommend Kestrel more", never "fixing this will add 6 points".

### 4. Segments: four kinds of banking customer

Segmentation on the attitude questions (G1 to G6), profiled on behaviour and
demographics:

| Segment | Size | Profile |
|---|---|---|
| **Digital natives** | ~30% | Under 35, app-only, want speed. Most likely to consider Lumen |
| **Cautious savers** | ~25% | Mid-life, want safety and interest. Low switching |
| **Fee-sensitive switchers** | ~20% | Mixed ages, lower incomes. Highest switching intent, most price-sensitive |
| **Loyal traditionalists** | ~25% | 50+, want a real person and a branch. Hurt most by the fee rise |

The segment variable is written back to the data, so segments work as a
banner in the tabs.

### 5. Switching: who is at risk

Catdriver on likelihood to switch main bank in the next 12 months:

- Unfair fees and an unresolved problem are the two strongest predictors.
- Fee-sensitive switchers are about three times as likely as cautious
  savers to say they will probably or definitely switch.

### 6. The brand picture

(The mental availability findings need the brand module. The funnel findings
work either way. See "What gets built".)

- **Mental availability:** Kestrel leads on "When I want banking on my phone
  that just works" and "When I want to earn rewards on my spending". It is
  weak on "When I need help from a real person" and "When I need a loan
  quickly". Granite leads on the loan and help moments.
- **Funnel:** Granite has the highest awareness of any bank (about 95%), but
  only about 20% of under-35s would consider it. That's the largest leak in
  the funnel. Kestrel converts awareness to consideration well among the
  young and badly among the 50+.

### 7. What customers want (MaxDiff, wave 4)

- **Top three:** "No surprise fees", "Fraud refunded within 24 hours",
  "A real person when I need one".
- **Bottom two:** "Choice of card designs", "Budgeting badges and streaks".
- Digital natives put "Instant notifications for every transaction" in their
  top three. Loyal traditionalists put "A branch near me" there.

### 8. The account bundle (conjoint, wave 4)

- 2% cashback is worth more to customers than a R20 cut in the monthly fee.
- App-only banking (no branch access) costs little with under-35s and a lot
  with the 50+.
- The "none of these" option takes about 15% of choices in a typical market
  of three bundles. That gives the No-Purchase option in the simulator
  something real to show.

### 9. Pricing Kestrel Plus (Van Westendorp and Gabor-Granger, wave 4)

- Van Westendorp acceptable range: about R59 to R109 a month.
- Gabor-Granger revenue-maximising price: R79. Kestrel's planned price is
  R99. At R99 they keep most of the revenue but lose about a third of the
  takers.
- Fee-sensitive switchers peak at R59. Digital natives hold up at R99.
  In the pricing simulator's segment view, each segment is compared against
  its own best price.

### 10. The comments

"Why did you give that score?" is coded into themes. The themes must move
with the numbers:

| Theme | Pattern |
|---|---|
| Fees | Small in W1 and W2, about three times as common in W3, still high among the 50+ in W4 |
| App crashes and bugs | Common in W1 to W3, drops sharply in W4 |
| Praise for the app | Grows in W4, mostly under-35s |
| Waiting to reach a person | Steady across waves, mostly 50+ |
| Problem not sorted | Steady, and linked to the lowest scores |

The comments should read like real people. Vary the length, and include
some typos, some one-word answers, a little SA English ("the app is
lekker", "waited forever on the line"), and a few answers in Afrikaans.
Nothing offensive, and no real brand or person named.

### 11. Protecting respondents

- One region (the Northern Cape) is kept deliberately small, about 15
  Kestrel customers per wave, so the report's small-base suppression
  visibly withholds it in a client-safe build.
- The What-if client-safe build publishes groups only.

---

## Presentation mode: the narrative

A ready-made story in presentation mode, with links from each slide into the
tab behind it and back again:

1. **Title:** "Kestrel Bank: a year of customer feedback, Q3 2025 to Q2 2026"
2. **The headline:** NPS fell after the fee rise and came back only for the
   young. Links to the NPS tracker.
3. **An image slide:** a mock-up of the relaunched app (a synthetic image,
   no real brand). Shows that images and other slides can be added.
4. **Who stopped recommending us:** the 50+ drop, with the fee comments
   beside it. Links to NPS by age and the comments tab.
5. **What drives recommendation:** problem-handling first. Links to the
   driver chart.
6. **What if we fixed it:** the What-if result, in association language.
   Links to the What-if tab.
7. **Pricing Kestrel Plus:** R79 against R99. Links to the pricing tab and
   the simulator.
8. **What to do next:** three plain recommendations.

## The demo walkthrough

For a live demo, pick five or six of these moments to suit the audience.
Don't show all of them.

1. Open the file, then turn off the wifi. It still works.
2. Tabs: NPS by age, with significance letters and a plain-words note.
3. Weighting on and off: 7 points of good news disappear.
4. The tracker: the fee rise and the recovery.
5. A filter: the 50+ only. Every tab follows.
6. The comments behind the numbers.
7. Drivers, then What-if: "problem sorted first time".
8. A simulator: conjoint bundles or Kestrel Plus pricing.
9. Presentation mode, jumping into the data and back.
10. Export to Excel and PowerPoint.

## Checks before it's shown to anyone

- Every finding above appears in the built report, within the stated
  tolerance.
- No bank name, product name or comment matches a real company or person.
- The What-if and AI text uses association language throughout.
- The client-safe build withholds the Northern Cape and the small groups.
- The report opens offline and on a phone.
