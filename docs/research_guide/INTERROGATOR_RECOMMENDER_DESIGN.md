# The Insight Guide — Interrogator & Recommender Design

**Status:** Draft 1 for Duncan to argue with. Text and logic only — no HTML yet. **Date:** 2026-07-16 **Source session:** blindspot pass + interview with Duncan + prior-art research (NN/g method landscape, 18F method cards, User Interviews wizard, Sawtooth MaxDiff-vs-conjoint discriminators, Conjointly brief template, Decision-Driven Analytics / De Langhe & Puntoni, YourCX "when not to survey").

------------------------------------------------------------------------

## 1. Canon — decisions locked in the design session

1.  **Blunt honesty.** The verdict engine may say "don't do research". The guide may recommend competitors (Sawtooth, SurveyMonkey, "honestly, Excel"). Turas appears on merit only.
2.  **Teach, don't sell.** Every question teaches while it asks. Register: The Economist meets Duncan meets Bill Bryson — useful, entertaining, crisp. Reference point for generosity and rigour: Romaniuk, *Better Brand Health*. No jargon salad. No overwhelm.
3.  **Genre:** a router, not an argument. Interactivity must be consequential — answers change the recommendation. Accordions are not interactivity.
4.  **Two doors, one knowledge base.** Client door = the wizard (this document). Practitioner door = method reference cards (separate design pass). Plain/Practitioner depth toggle works *within* pages as usual.
5.  **The plan is generous.** Full route + alternative + phasing + scale + trust warnings + next step. The DIY reader was never a client; the corporate reader discovers why help is worth paying for by seeing what a real plan contains. The generosity is the marketing.
6.  **Money:** never ask budget. Ask what the decision is worth. Show cost as
    (a) the cost *model* — drivers and ratios, practice-labelled, evergreen;
    (b) indicative absolute ranges from **publicly sourced benchmarks** — the ESOMAR Global Prices Study is out of reach (paywalled; Duncan won't have access), so ranges come from citable public sources (agency rate publications, GRIT/Quirks, academic costing guides), each with source and vintage on its face, **never above amber/indicative tier**. Model-memory figures do not ship: a figure either has a fetched source, a practice ▲ label calibrated by Duncan, or it stays a slot. Duncan's caveat applies to all published prices: quotes run aspirational — use as shape, not level.
    (c) the value check: if the study costs more than the decision is worth, keep your money.
7.  **Not SA-only.** International by default; local fieldwork realities appear as a labelled layer, not as the frame.
8.  **Recommend a set, hedged.** Route + credible runner-up + what you'd sacrifice. Phased designs are often the honest answer and the guide says so on its face. "This narrows; a researcher decides."
9.  **Every route carries its failure modes** — "when this route lies to you" — specific to the user's population and mode, not generic.
10. **Evidence discipline carries over, rotated:** every recommendation wears its reasoning ("because you said X and Y"); every figure wears its source type (cited / practice-experience ▲ / illustrative).
11. **Maintenance:** all Duncan, regenerated from the skills overview. Skills stay canon; this artefact is authored from them.

------------------------------------------------------------------------

## 2. The brief object

Everything the interrogator collects. This is both the router's input and the skeleton of the draft brief the client walks away with.

| Field | From | Values |
|----|----|----|
| `problem_shape` | Q1 picker | wrong / new / contested / foggy / watching |
| `problem_verbatim` | Q1 free text | client's own words, preserved into the plan |
| `decision_type` | Q2 | choose-between / go-no-go / set-a-number / convince-someone / nothing-specific |
| `alternatives` | Q2 follow-up | the live options, verbatim |
| `action_standard` | Q3 | would-change-course / would-do-it-anyway |
| `gap_type` | Q4 | why / how-many / what-they-do / already-answered / all-of-it |
| `existing_data` | Q5 | sales, CRM, analytics, past research, complaints/reviews, staff (multi) |
| `stakes` | Q6 | reversible / real-money / existential |
| `value_band` | Q7 | order of magnitude, currency-neutral |
| `population` | Q8 | own customers / lapsed / market-at-large / niche-specialist / staff / experts |
| `reach` | Q9 | have-list / walk-through-door / need-finding |
| `incidence` | Q10 | most / some / hardly-any / wait-all-day |
| `deadline` | Q11 | next-week / this-quarter / no-fixed-date |
| `org_size` | Q12 | solo-small / mid / corporate |

One decision per run. If the brief bundles several decisions, the plan says: "That's two projects wearing one trench coat. Run me again for the second one."

------------------------------------------------------------------------

## 3. The Interrogator

Six stages, twelve questions, one teaching line per screen. Exits can fire from stage 2 onward. Exits are well-crafted terminal cards — a legitimate outcome with "what to do instead", never a dead end. The user never names a method; methods are the output, not the input.

Question wording below is draft copy in the target register — argue with it.

### Stage 1 — The problem

**Q1. "What's going on?"** Free text ("in your own words — we'll hand them back to you at the end"), plus a shape picker:

- Something's **wrong** — sales, share or customers are slipping
- Something's **new** — a launch, a price change, a rebrand, a new market
- Something's **contested** — the team disagrees, or the board wants evidence
- Something's **foggy** — we don't understand a market or our customers well enough
- Something needs **watching** — we want to track health over time

*Teach:* "Research can't fix a business problem. It can only fix missing information. The next few questions find out whether missing information is actually your problem."

### Stage 2 — The decision

**Q2. "If the answer landed on your desk tomorrow, what would you do with it?"**

- Choose between things we're already considering → *capture the alternatives verbatim*
- Decide whether to go ahead or not
- Set a number — a price, a budget, a target
- Convince someone — the board, the bank, a partner
- Nothing specific — we'd just understand things better

Notes: "convince someone" is legitimate and the guide says so — you're buying credibility, which is fine, but the rigour bar is now set by *their* scepticism, not yours. "Nothing specific" is legal too — curiosity is a fine reason to learn, but there are cheaper teachers than fieldwork: desk research, a good book, ten honest conversations. (Soft exit toward R1/R2/R4.)

**Q3. "Now imagine the answer comes back against you. Honestly — what happens?"**

- We'd change course. That's why we're asking.
- We'd… probably do it anyway.

*Exit 1 fires on the second answer:* \> **Save your money.** If no result would change the decision, you're not \> buying information — you're buying a receipt. Research bought to bless a \> decision already made is the industry's quietest product line and its least \> useful. (If you need evidence to bring a board along, that's different and \> respectable — go back and pick "convince someone".)

*Teach (on the pass):* the action-standard idea — deciding in advance what result triggers what action is the single cheapest upgrade to any research project, and almost nobody does it.

### Stage 3 — The gap

**Q4. "What exactly don't you know?"**

- **Why** people do what they do — what they really think and feel *(understanding nuance)*
- **How many, how much, or which one** *(quantifying)*
- **What people actually do** — as opposed to what they say *(behaviour)*
- Whether someone has **already answered this** somewhere
- Honestly — **all of it**

*Teach on "all of it":* "That's the most common honest answer, and it's why real projects often run in phases: first understand, then count what you found. Counting things you don't yet understand produces very precise answers to the wrong question."

**Q5. "Before anyone buys new data: what do you already have?"** *(multi-select)* Sales records · CRM / customer database · web or app analytics · past research reports · complaints and reviews · front-line staff who talk to customers all day

*Teach:* "The cheapest research is reading what you already paid for. It's also the most commonly skipped step in the industry, because nobody can bill much for it."

### Stage 4 — The stakes

**Q6. "If you act on a wrong answer, what does it cost you?"**

- Mild embarrassment — we could reverse it in a week
- Real money, but we'd recover
- The company, the year, or somebody's job

*Teach:* this is the rigour dial. Cheap-to-be-wrong questions deserve cheap, fast answers — or no study at all, just try it and watch. Expensive-to-be-wrong questions are the only ones that justify proper sampling and proper money.

**Q7. "And roughly what is getting it right worth — in your money?"** Order-of-magnitude picker (thousands / tens of thousands / hundreds of thousands / millions — currency-neutral).

*Teach:* "Hold that number. Every route we show you comes with a cost tier. If the research costs more than the decision is worth, we'll be the ones to tell you to keep your money."

### Stage 5 — The people

**Q8. "Who has the answer — in their heads or in their behaviour?"** My customers · people who left me · the market at large, including people who've never heard of me · a specific, rare sort of person (specialists, B2B buyers) · my own staff · experts who watch this market

*Teach (on market-at-large):* "Your customers can't tell you why other people aren't your customers. This trips up more studies than any statistical error."

**Q9. "Could you reach these people yourself?"**

- I have their contact details (and permission to use them)
- They walk through my door / visit my site anyway
- Somebody would have to go and find them

**Q10. "Stop 100 random people in the street. How many are your sort of person?"** Most of them · some of them · hardly any · you'd wait all day

*Teach:* "This number quietly runs your fieldwork bill. Rare people are expensive people — halve the incidence and you roughly double the finding cost."

### Stage 6 — Reality

**Q11. "When does the decision actually get made?"** Next week · this quarter · no fixed date

*Teach:* some methods cannot physically deliver in time, and a fast rough answer only beats a slow good one when the stakes are low. If the stakes are high and the deadline is next week, the best research advice is: move the deadline. (High stakes + next-week deadline triggers a blunt callout to exactly that effect.)

**Q12. "How big is your outfit?"** Just me / a handful · a real company, tens to hundreds of people · a corporate, with procurement and everything

------------------------------------------------------------------------

## 4. The Recommender

A constraint narrower over a route space — **not a decision tree**. Each route carries requirements and counter-indications evaluated against the brief object. Output = best route + credible runner-up + the sacrifice line, with the reasoning shown ("because you said X and Y — if Z had mattered more, we'd have pointed you at…").

### 4.1 Route space

| \# | Route | Fires when (primary triggers) | When it lies to you (core entry) |
|----|----|----|----|
| R0 | **Don't do research** | action_standard = do-it-anyway; or value_band below the cheapest adequate route; or gap = none in disguise | Doing it anyway feels rigorous. It isn't — it's expensive reassurance. |
| R1 | **Read what you already have** | existing_data rich + gap answerable internally. Also fires as *Phase 0* of nearly everything when any data is ticked | Internal data describes your customers, never the people who walked past. |
| R2 | **Ask them yourself** (DIY conversations, guided) | reach = list/door + org = solo-small + stakes ≤ real-money + gap = why | You'll hear the articulate and the angry. And people tell owners what owners want to hear. |
| R3 | **Run it live and measure** | stakes = reversible + decision_type = go-no-go or set-a-number + org has traffic/volume | Works only when you can genuinely reverse, and when the measure can't flatter itself. |
| R4 | **Desk research** | gap = already-answered; market-sizing basics; also Phase 0 | Published numbers mix units and vintages. Three sources that all trace to one press release are one source. |
| R5 | **Qual, professionally done** (groups / depths; ethnography rough-guide as a variant) | gap = why + (stakes ≥ real-money or org can't DIY or population ≠ own customers) | Eight people in a room are a source of understanding, not a percentage. The moment someone says "75% of the group…", leave. |
| R6 | **Quant survey** (mode sub-router below) | gap = how-many + population reachable by some mode + value supports cost tier | People misreport what they'll do, especially about money. And a biased sample of 2,000 is worse than an honest 200. |
| R7 | **Observe them** (intercept, observation, mystery shopping) | gap = what-they-do + location-bound population | You see the what, never the why. Pair it with asking, or you'll invent the why yourself. |

R7 discriminator (Duncan's rule): **mystery shopping measures what your staff do, not what your customers think.** It fires only for process compliance — and only when there is a *defined process* to compare against. No defined standard, no mystery shop: you'd be scoring people against a rubric that doesn't exist. Wanting customer attitudes routes to R5/R6 instead. \| RP \| **Phased combinations** \| gap = all-of-it; or R5 triggers + stakes = existential \| Composition rule, not a route: desk → qual → quant is the honest default shape, and the guide says so. \|

Notes: - R0's card is a *well-made outcome*: what to do instead (decide, then use R3 to check; or bank the money). Never a dead end. - "Convince someone" decision_type: rigour dial keys off the audience's scepticism; route as normal but the plan says whose standards the evidence must survive. - Deadline = next-week prunes anything with fieldwork lead times; the plan says what was pruned and why (no silent caps).

### 4.2 Mode sub-router (R6 only)

| Mode | Fires when | Honest warning attached |
|----|----|----|
| Own-list email-to-web | have-list + permission | Cheapest there is. But the happiest and the angriest reply; the middle stays silent. Coverage ≠ your market. |
| Online panel | market-at-large + mainstream + online-reachable | Fast and affordable. Professional respondents and bots are real; in several markets (SA included) panels skew urban, connected, younger. |
| CATI / telephonic | population under-covered online (older, rural, lower-income) | Costs a multiple of online. Questionnaires must shorten. Reaches people panels never will. |
| Face-to-face | needs trust, length, materials, or low-literacy handling | The gold standard for hard populations; priced accordingly — a multiple of CATI. |
| Intercept | location-bound population (shoppers at the point) | You sample a place, not a market. Say so in the report or someone else will. |
| B2B / specialist depths | incidence = wait-all-day + niche | At n=30 specialists, stop pretending it's a survey. Report it as structured judgement, which is what it is. |

Cost ratios (online → CATI → F2F multiples, incidence doubling rule) are practice-labelled ▲, now corroborated by public sources — see §4.9.

### 4.3 Analytics sub-router (R6 only, after mode)

Sawtooth pattern: two or three sharp discriminating questions per technique, each card carrying its failure mode and an honest tool line.

| Need, in client language | Technique | When it lies to you | Honest tool line |
|----|----|----|----|
| "Do groups differ — who buys, who lapses?" | Crosstabs + significance testing | Small bases produce confident nonsense; differences need testing, not eyeballing | Any decent package. Turas if you want the honesty machine-checked (it refuses to sig-test what can't be tested). |
| "Rank a flat list of 8–40 things" | MaxDiff | Wrong list in, beautifully-ranked wrong list out. The list is the design. | Sawtooth or Turas. |
| "Trade-offs between feature bundles, price included" | Conjoint | Unrealistic attribute sets; respondent overload; precision theatre on tiny samples | Sawtooth is the industry reference; Turas runs it too. Needs real sample and real budget. |
| "What drives satisfaction / choice?" | Key drivers | "Drivers" are associations wearing a causal costume. Correlated drivers double-count. | Turas, R, or any stats package — the honesty is in the reporting, not the tool. |
| "Are there distinct types of customer?" | Segmentation | Noise clusters beautifully. Segments must replicate and be reachable, or they're astrology. | Turas or R. Distrust anyone who finds exactly the segments the deck needed. |
| "What price should we charge?" | Pricing methods (VW / Gabor-Granger) | Stated willingness ≠ behaviour. Calibrate or treat as directional. | SurveyMonkey + Excel honestly suffices for basic VW; Turas for the full treatment. |
| "Is it moving over time?" | Tracking | Change the method mid-track and the trend dies with it. | Consistency beats sophistication. Turas trackers if honest wave-on-wave sig matters. |

Rule: **at most one advanced technique per plan** unless corporate + existential stakes. Stacked techniques are how proposals get fat and answers get thin.

**Behavioural economics — the stance (approved by Duncan, sharpened):** BE enters the guide as a *lens*, not a parallel technique menu — but a lens with a strong track record, in the Shotton register (*The Choice Factory*: small, replicated, field-tested effects, plainly told). Where it lives: (a) **design lens** — framing, anchoring and choice architecture shape every questionnaire whether you invited them or not; the guide teaches this in the instrument section ("you are always running a framing experiment; the only question is whether you designed it"); (b) **testable effects** — anchoring, framing, defaults and the like are legitimately *testable in your own setting*, and the honest way to test them is usually **observation and A/B experiments (R3/R7), not questionnaires** — asking people about their biases is asking the one witness who wasn't there. Worked Shotton-style examples of effects that replicated in the field carry this section; (c) **specific methods** — implicit / response-latency testing gets a practitioner card, with the note that commercial "System 1 research" offerings vary wildly in evidential quality; (d) **interpretation lens** — say-do gap, social desirability and hypothetical bias power the trust boxes. The guide's one-line verdict, Duncan's own: **BE is simultaneously under-appreciated and over-claimed** — under-used as a design discipline and a cheap live-test programme, over-sold as a proprietary methodology with a trademark. What BE does *not* get: a "System 1 route" in the recommender pretending to be a distinct methodology.

### 4.4 The landscape map

After routing, show where the user landed on a two-axis map — *understand ↔ count* × *what people say ↔ what people do* — with their route lit and the near-misses visible and clickable. The wizard walks; the map teaches why. (NN/g's landscape, redrawn for a business-decision audience.)

### 4.5 Timing — the honest calendar

"How long will this take?" is answered on every route card and in the plan, as timeline *classes* (practice-labelled ▲, Duncan calibrates the ranges):

| Route / mode | Class | What moves it |
|----|----|----|
| Read what you have / desk | days → a week or two | how messy the data is |
| Ask them yourself | days | your own diary |
| Run it live | as long as the experiment needs | traffic volume; seasonality |
| Qual (groups/depths) | weeks (recruit is the long pole, not the interviews) | incidence; incentives; how rare the people are |
| Online panel survey | days in field; weeks end-to-end (design + soak + analysis) | questionnaire length; incidence |
| CATI | weeks | interviewer capacity; contact rates |
| Face-to-face | multiple weeks → months | geography; logistics |
| Conjoint / MaxDiff add-on | adds design + analysis time up front and at the back | attribute/list development is thinking time, not field time |
| Tracking | forever, by design | — |

Standing teach lines: **the calendar is mostly recruit and thinking, not fieldwork** — clients budget for the field and are ambushed by the design and analysis weeks either side; and the Q11 rule — high stakes + next-week deadline = move the deadline, because rushed high-stakes research is the worst buy in the industry.

### 4.6 Who should run it — the credibility question

The plan's next-step section grows a fourth honest dimension: **provider tier**. Clients trust big brands more than boutiques; the guide says so out loud and prices the difference:

- **Yourself** (with this guide's mini-guides) — free, fast, and fine when stakes are low and the population walks through your door.
- **A platform + your own effort** (SurveyMonkey/Alchemer tier) — cheap; quality rides entirely on your questionnaire, and nobody will stop you making the classic mistakes. The guide's instrument section is the seatbelt.
- **A boutique / independent** — senior brains on your project start to finish, at a price a corporate procurement desk won't believe. The person who pitches is the person who does the work.
- **A big agency (the Kantar tier)** — you are buying board cover, global consistency, norms databases, and a logo nobody gets fired for hiring. Those are real things and sometimes worth every cent — multi-market studies, hostile boardrooms, categories where their norms genuinely have no substitute. ▲ Practice note (Duncan to own the wording): much of the underlying fieldwork is subcontracted to the same suppliers the boutiques use; the premium buys the brand, the norms and the account layer, not different interviewers.

Rule for the tool: recommend the *tier*, not a firm; TRL/Turas appears in the same honest register as everyone else. When board cover is what the client actually needs (decision_type = convince-someone + corporate + existential), the guide is allowed to say "hire the big logo" — that sentence buys more credibility than any pitch.

### 4.7 The new tools — an honest note (mid-2026)

Researched 2026-07-16 (sources below; [fetched] = read at source this session, [2nd] = secondary/search-level, quote with care). Each tool gets the classic treatment: what it is, when it's appropriate, when it lies.

- **AI / bot interviewers** (AI-moderated qual at quant-ish scale; Outset, Listen Labs, Remesh, Yasna; SA's Yazi runs AI-moderated IDIs over WhatsApp). The evidence *for* is real: Chopra & Haaland (CESifo/ifo working paper) [fetched] found AI-led interviews thematically richer than other scaled methods, with responses that predicted behaviour six months later — the mechanism is tireless dynamic probing. Several sources also report freer disclosure on sensitive topics to a non-human. The evidence *against*: documented probing failures (missed cues, talking over participants), no rapport, weakest on emotional/strategic ground — and **no published measurement of hallucination rates in AI-written summaries exists**, so the guide's rule is: never let the model mark its own homework; a human reads transcripts, not just the synthesis. Appropriate: large-n qual (50+ interviews), concept screening, multi-market simultaneous, sensitive topics. Not: board-level strategic qual, grief/health/identity work, anything where the interview is also the relationship. Do NOT cite the "University of Melbourne 78%" claim circulating in vendor decks — the underlying study could not be located. **Adoption, read at source (GRIT 26A, fielded Jan–Mar 2026, n=735 insights professionals):** AI/chatbot-moderated qual is used by 33% of brand-side researchers (down from 45% a year earlier) and 55% of brand-side analytics — while the largest service suppliers went the other way, up 14 points to 61%. GRIT's own read: "brand-side insights professionals are wavering on AI-/chatbot-moderated qual, many suppliers are betting on it." Among brand-analytics users, 62% use it *regularly* — the only qual method where regular users outnumber occasional ones. The guide's translation: the people selling research are adopting it faster than the people buying it are learning to trust it — which is exactly when a buyer needs to know what to ask.
- **Synthetic respondents** ("ask the LLM instead of people"). The bluntest section, now with the receipts. The founding claim (Argyle et al. 2023, *Political Analysis* — "silicon sampling" reproduces subgroup distributions) has been substantially dismantled for decision use: Bisbee et al. 2024 (*Political Analysis*) [fetched] found variance far too small, **48% of estimated coefficients significantly different from the human benchmark, effect signs flipping 32% of the time**, and results changing between runs after silent model updates. Across **285 silicon-vs-human comparisons** reviewed by Sarstedt et al. (NIM MIR, 2026) [fetched], only **\~25% aligned**. Worst for us: LLM answers resemble WEIRD populations, with fidelity falling sharply with cultural distance (Atari et al., "Which Humans?") [2nd] — synthetic "South African respondents" are close to the worst case. Ipsos's own guidance warns of "snake oil salesmen" [fetched]. Legitimate uses: instrument piloting, hypothesis generation, benchmarking beside real data. Illegitimate: substituting for fieldwork, subgroup analysis, tracking, any emerging-market population. Disclosure is the industry direction (ESOMAR's "20 Questions to Help Buyers of AI-Based Services"; MRS AI guidance, 2025) — the buyer's question the guide arms the reader with: *"was any of this data generated rather than collected?"* **Adoption, read at source (GRIT 26A):** synthetic data is, in GRIT's own words, "practically mainstream" — 26% of brand-side researchers use it (up 18 points in a year), 57% of brand-side analytics, and adoption among the largest service suppliers nearly doubled (26%→44%) *while field services as a significant revenue line fell 30%→16% at the same firms*. Caveats GRIT itself states: the question's label widened this wave (2025 "synthetic sample" → 2026 "synthetic data incl. AI personas/digital twins"), so the trend is partly label-driven; and formal governance lags — a formal role in synthetic-data/AI policy is the least-held oversight role in the industry. The guide's translation: the industry is adopting faster than it is governing, and nobody measured disclosure at all — the buyer's question above is genuinely the reader's only protection.
- **WhatsApp / chat panels.** Better evidenced than expected, and the most locally valuable. SA context: 78.9% internet penetration; WhatsApp is the most-used platform — 93.8% of active social users (DataReportal 2025; Global Digital Report 2025) [fetched]. The credible mode experiment (Ndashimye et al., *Social Science Computer Review* 2024 — Senegal & Guinea, 8,446 contacts) [fetched]: WhatsApp response rate 12% vs 20% for voice, **but** higher completion among starters, substantially lower cost, and *no worse sample-selection bias*. Honest caveats: smartphone/data-cost selection against the poorest and oldest; questionnaire brevity; and no published WhatsApp-vs-online-panel quality comparison exists yet — operator quality claims are vendor marketing until shown otherwise. CATI remains the reach benchmark for low-income/rural populations. **The blind-spot proof (GRIT 26A, read at source):** WhatsApp receives *zero mentions* in the industry's flagship practice report, and "Africa & Middle East" contributes n=7 of its 328 brand-side respondents. The global industry literally does not see this terrain — which is the guide's moat, stated as a sourced fact rather than a boast.
- **AI in analysis and reporting** (including Turas's own use). One disclosure register for everybody, TRL included: say what touched the data and what touched only the prose. The guide practises what it preaches — its own AI-usage note sits in the footer.

### 4.8 Why research lies — bias and fraud, the honest taxonomy

Feeds the trust boxes (route-specific) and gets its own reference section. Plain layer carries the big five with Bryson-grade examples; practitioner layer carries the full table.

**The big five (plain layer):** 1. **Coverage / sampling bias** — you asked the reachable, not the relevant. 2. **Self-selection** — the happiest and the angriest reply; the middle stays silent. 3. **Leading instruments** — the question wrote the answer. 4. **Social desirability / say-do gap** — people report the person they'd like to be. Especially about money, virtue, and vegetables. 5. **Interpretation bias** — the analyst found what the deck needed.

**Practitioner-layer additions:** non-response bias, order and context effects, acquiescence ("yes is easier"), recall error, interviewer effects (mode-specific), survivorship (you surveyed survivors), small-base overconfidence, and the quiet killer in trackers: method change mid-series.

**Fraud (quant-specific):** bots and click-farms, professional respondents, straightlining and speeding, geo-spoofing. The figures, traced 2026-07-16:

- **The scary number:** \~40% of nonprobability online interviews in 2025 likely fraudulent (\~2 billion interviews) — Insights Association webinar, Jan 2026, reported by NORC [fetched]. An estimate presented in a webinar, not a peer-reviewed measurement; the majority of that fraud is **human click-farms, not AI** (AI fraud "in its infancy", detection currently effective).
- **The careful number:** Pew Research Center, 60,000+ interviews (2020) [fetched]: bogus respondents were **4–7% of opt-in panels, \~1% of probability panels** — and they bias results *positively* (they approve of everything), not randomly.
- **The teach:** the gulf between 40% and 4–7% is definitional, not dishonesty — one counts everything discarded (speeders, straightliners, duplicates, fails), the other counts confirmed fakes. Published academic fraud rates range 9%–78% by study [2nd]. The guide presents the pair and teaches the reader to ask any panel provider: *what do you remove, and how much did you remove last month?*

Standing teach line: *a biased sample of 2,000 beats an honest 200 in confidence and loses to it in truth.*

### 4.9 Figure inventory — researched cost & timing benchmarks

Researched 2026-07-16, replacing the unreachable ESOMAR GPS. Everything below ships at **amber/indicative tier** with source + vintage on its face; Duncan's aspirational-quote caveat applies to all published prices. No SA rand rate cards exist publicly — SA-specific levels stay ▲ practice territory or slots.

**The durable ratios (lead with these — they age well):**

| Ratio | Value | Source status |
|----|----|----|
| CATI vs online panel, per complete | ≈ 2–4× | Drive Research project bands [fetched]; IntoTheMinds [2nd] |
| F2F vs web, developed markets | ≈ 2.7–4× | Belgian Health Interview Survey mode study, peer-reviewed [2nd] |
| F2F vs remote modes, developing markets | up to \~10× per household | IPA/World Bank-adjacent syntheses [2nd] |
| In-person vs online focus group | ≈ 2× | Greenbook [2nd] |
| Incidence 70% → 3%, cost per complete | ≈ 7× (\$7 → \$50) | CleverX/userintuition [2nd] |
| Specialist (healthcare) vs consumer CPI | up to \~50× (\$20–1,000) | Conjointly [2nd] |

**Absolute anchors (amber, USD-centric, quote as ranges):** online survey project \~400 completes \$5–15k+; CATI project \~400 completes \$15–30k+; in-person project \$20–50k+; IDIs \$5–15k per 10–15; US in-person focus group \~\$6–15k/group all-in (Drive Research, Nov 2025 [fetched]). Academic probability panels publish per-minute rates: GESIS €1.00, LISS €1.30 per respondent-minute [2nd] — a rare citable "what honest data costs" anchor. Prolific publishes its floor/fee structure [fetched]. African F2F per interview: \$25 (Burkina Faso) to \$150 (Malawi), peer-reviewed compilation [2nd] — the best citable anchor for African fieldwork.

**Timeline anchors (corroborate §4.5):** online panel days-to-4-weeks in field; focus-group project 3–5 weeks end-to-end; qual recruitment is the long pole (agencies 1–2 weeks, niche B2B adds more); B2B/exec IDI studies 6–8 weeks [all 2nd, convergent across sources].

**South African figures (researched 2026-07-16 — the citable ones live in academic and public-sector documents, not agency marketing):**

| Figure | Value | Source | Status |
|----|----|----|----|
| F2F multi-topic household survey, cost per household, Africa | avg \~US\$323 (Africa "at least \$300"); global avg \$170; Nigeria \$406, Malawi \$199. **SA not in sample** — an upper-bound anchor (multi-hour questionnaires) | World Bank Policy Research WP 7951 (2017), Table 1 | [fetched] |
| F2F interviewer floor rate, Afrobarometer network | US\$25/day minimum at 4 interviews/day; standard country survey = 1,200 interviews, 4 teams, \~19 field days | Afrobarometer R9 Survey Manual (2022), §3.6 | [fetched] |
| Ad-hoc "comprehensive market research study", SA practitioner range | R50,000–R200,000; desk research R10,000–R30,000 | J.T. Burger, LinkedIn (2023) — one practitioner's published range, the only public ZAR project range found | [fetched, low-med reliability] |
| SMS survey floor, Africa incl. SA | "\$3.00 per completed survey" | GeoPoll (2016) — dated; use as floor/shape | [fetched] |
| Mode ratios, Nigeria (nearest African comparison) | IVR ≈ 43% of CATI cost; SMS ≈ 24% of CATI | Lau et al., *Survey Research Methods* | [fetched, abstract] |
| CATI respondent incentive norm, SA academic | R20–R40 airtime per \~20-min complete (NIDS-CRAM, \~7,000 completes/wave) | SALDRU/UCT cramsurvey.org | [fetched] |
| Qual session incentive norm, SA academic | R150 grocery voucher + travel | UKZN trial protocol (2025) | [fetched] |
| Census 2022 anchors | R4bn total (≈R224/enumerated household, computed); enumerators \~R264/day | GroundUp (2024); Bloem Express (2022) | [fetched / 2nd] |

Confirmed unfindable in public (stays ▲ practice territory — Duncan buys this fieldwork; his ranges are better sourced than any blog): SA commercial CATI per-complete, online-panel CPI in ZAR, commercial focus-group per-group rates, omnibus per-question rates (all quote-only), NIDS/HSRC/SADHS project budgets. The guide can say this out loud: *in South Africa, research prices are a quote-only market — which is itself worth knowing before you brief.*

**Five strongest citable sources for the guide's references section:** Bisbee et al. 2024 (*Political Analysis*) — synthetic-respondent perils; Pew Research Center 2020 — bogus-respondent baseline; NORC 2026 — the fraud landscape and the 40% provenance; Sarstedt et al. 2026 (NIM MIR) — the 285-comparison silicon scorecard; Chopra & Haaland — AI interviewing works, with predictive validation. All fetched this session.

------------------------------------------------------------------------

## 5. The Plan — terminal output contract

Every completed run produces, on screen and as a clean printable/emailable page:

1.  **Your brief, replayed** — their verbatim problem, the decision, the alternatives, the action standard they committed to. (This alone is worth the visit: most companies have never seen their own problem written down decision-first.)
2.  **The route** — what and why, reasoning traced to their answers.
3.  **The runner-up** — and exactly what you'd sacrifice choosing either way.
4.  **Phasing** — if fired, with the teach line on why phases beat one big study.
5.  **Indicative scale** — order-of-magnitude sample with what each buys (n≈100: a directional read; n≈400: ±5 points overall, subgroups shaky; n≈1,000: subgroup cuts hold — practice-labelled, standard theory), timeline class, cost tier, and the value check against Q7.
6.  **The trust box** — the two or three ways *this* route lies, given *their* population and mode. Not generic warnings.
7.  **Next step** — DIY routes get the mini-guide; professional routes get: "Take this brief to a researcher — any good one will respect you more for arriving with it. If it's the counting sort and you want the honesty machine-checked, Turas is ours. Heavy trade-off work: Sawtooth. Simple pulse-taking: SurveyMonkey and a spreadsheet, and we'll die on that hill."
8.  **The map** — where you landed, what was nearby.

------------------------------------------------------------------------

## 6. Open items

- [ ] Duncan: argue with the question wording (§3) — register, order, anything a real client would balk at.
- [ ] Duncan: route-space completeness check against 30 years of briefs — what arrives in practice that this can't route? (Known candidates: brand-health tracking entry, employee research, public-sector/citizen work.)
- [ ] Duncan: anything you'd *never* recommend (mystery shopping? gut check).
- [ ] Duncan: gut-check the BE stance (§4.3), the provider-tier wording (§4.6 — especially the subcontracting practice note, which must be *his* claim), and the new-tools stances (§4.7).
- [x] Integrate the new-tools + cost-benchmark research pass into §4.7, §4.8 and §4.9 — done 2026-07-16.
- [x] GRIT read at source (Duncan supplied the 2026 unabridged PDF; mined 2026-07-16). **Four circulating claims checked and refuted for this edition — banned from the guide:** "72% GenAI adoption" (question was dropped from the 2026 wave); "median AI-qual sample 312 vs 17" (no such data in the report); "data-quality concerns up 40% YoY" (not present; GRIT's buzz coding moved the *opposite* way); "13% satisfaction with AI tools" (no satisfaction measure exists — nearest true figure: 13% of brand-side researchers are *completely confident* their organisation minimises AI-misuse risk). Replaced with at-source figures in §4.7. **Cite GRIT honestly as:** GRIT Insights Practice Report 26A, Greenbook, fielded Jan–Mar 2026, n=735 insights professionals, non-probability opt-in sample, small segment bases (n=39–176), label changes on the synthetic-data and AI-qual questions this wave — the guide applies its own evidence discipline to its own sources.
- [ ] ESOMAR "20 Questions" and MRS AI guidance: cite existence and purpose only (full texts gated).
- [ ] Known unciteables (leave as slots or ▲): SA commercial rate cards (none public — confirmed by dedicated SA pass, see §4.9); WhatsApp-vs-online- panel quality comparison (none published); AI-summary hallucination rates (commentary only, no measurement).
- [ ] Duncan, one-click verify: the CoCT/Kantar R3.3m tender award PDF was geo-blocked to the research agent but should open from an SA IP — confirm before it appears client-facing. Same for the R264/day census enumerator figure (Bloem Express, snippet-only).
- [ ] Duncan: calibrate the ▲ SA commercial ranges (CATI/panel/group costs) from fieldwork buying experience — the only honest source that exists.
- [ ] Second design pass: the practitioner door (method reference cards) — separate document.
- [ ] Later: the SA fieldwork layer as labelled local content; the threaded fictional case; the trust meter; the spot-the-broken-question quiz.

## 7. Build pivots (2026-07-17, Duncan review of v1)

- **Pricing figures removed entirely** — the researched ranges/ratios didn't resonate. Replaced by "the bill": six stages you pay for (design, sample, collection, programming, analysis, presentation), what drives each stage's cost, and the danger of skimping on each, plus "reading a quote" guidance. The value check survives. The §4.9 figure inventory stays in this doc as research record, but does not ship in the guide.
- **New sampling section** (guide §04): how a sample represents a population (stirred-pot), the precision ladder, random vs quota vs online opt-in as three honest trades, weighting explained with its two limits (fixes shape not soul; heavy weights are borrowed confidence / n_eff), and mode-as- sampling-decision callout.
- **Analytics widened**: "the wider toolkit" table — TURF, factor analysis, perceptual mapping, regression, CHAID, Kano, importance–performance, NPS, open-end coding, brand funnel — each with the question it answers and the caveat.
- Q1 fixed: free-text alone unlocks Next (shape picker optional).

## 8. Deviations & session notes

- Advisor consult attempted twice (before design commit); unavailable both times — design is on session judgment, flagged.
- ESOMAR Global Prices Study 2025: existence verified via web search this session; contents unverified.
- Multi-decision briefs: decided one-decision-per-run without asking (noted §2); cheap to revisit.
