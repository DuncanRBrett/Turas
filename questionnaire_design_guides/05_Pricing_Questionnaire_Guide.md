# Pricing Analysis: Questionnaire Design Guide

**Purpose:** Design price sensitivity studies using Van Westendorp and Gabor-Granger methods

---

## What Pricing Analysis Needs

Pricing studies measure willingness-to-pay and price sensitivity. Different methods have different requirements:

**Van Westendorp Price Sensitivity Meter (PSM):**
- 4 price perception questions
- Open-ended price inputs
- No specific product configuration needed

**Gabor-Granger:**
- Series of purchase intent questions at different prices
- Typically 4-6 price points tested
- Can test multiple product configurations

**Conjoint-Based Pricing:**
- See Conjoint guide
- Price as one attribute in choice tasks

---

## Van Westendorp PSM Design

### The Four Standard Questions

**Van Westendorp asks price perceptions, NOT purchase intent:**

```
We'd like to understand your perception of [Product/Service] pricing.

Q1. At what price would you consider [Product] to be so expensive
    that you would not consider buying it? (Too expensive)

    $ ________

Q2. At what price would you consider [Product] to be priced so low
    that you would feel the quality couldn't be very good? (Too cheap)

    $ ________

Q3. At what price would you consider [Product] starting to get
    expensive, so that it is not out of the question, but you would
    have to give some thought to buying it? (Expensive/Getting expensive)

    $ ________

Q4. At what price would you consider [Product] to be a bargain—
    a great buy for the money? (Cheap/Good value)

    $ ________
```

**Key Points:**
- **Open-ended numeric entry** (not multiple choice)
- **All 4 questions required** for Van Westendorp analysis
- **Exact wording matters** - use standard phrasing
- **Order matters** - ask in this sequence

---

### Van Westendorp: Best Practices

#### ✅ DO: Describe the Product Clearly First

**Before asking price questions:**
```
We're researching a new smartphone with these specifications:

- 6.1" display
- 2-day battery life
- Premium camera with night mode
- 5G connectivity
- Water resistant

Please answer the following questions about pricing for this product.
```

**Why:** Respondents need clear reference point for price evaluations.

---

#### ✅ DO: Use Product Category Context

**Good:**
```
At what price would you consider this smartphone to be too expensive?

$ ________

(For reference, similar phones range from $600-$1,200)
```

**Why:** Context helps respondents give realistic answers.

---

#### ❌ DON'T: Pre-Load Price Expectations

**Bad:**
```
Our premium smartphone costs about $999.
At what price would it be too expensive?
```

**Good:**
```
At what price would this smartphone be too expensive?
(No mention of intended price)
```

**Why:** Mentioning a specific price anchors responses around that number.

---

#### ✅ DO: Allow Reasonable Range

**Input Validation:**
```
Price entry field:
- Minimum: $1
- Maximum: $99,999
- Accepts whole dollars only
- Shows $ symbol automatically
```

**Don't Over-Restrict:**
- Some people will give extreme answers
- That's OK - Van Westendorp handles outliers
- Don't force answers into narrow range

---

### Common Van Westendorp Pitfalls

**Pitfall #1: Questions Out of Order**

**Wrong Order:**
```
Q1. Too cheap
Q2. Good value
Q3. Too expensive
Q4. Getting expensive
```
→ Confusing sequence

**Correct Order:**
```
Q1. Too expensive (start with upper bound)
Q2. Too cheap (then lower bound)
Q3. Getting expensive (then upper threshold)
Q4. Good value (then lower threshold)
```
→ Logical progression

---

**Pitfall #2: Modified Wording**

**Bad - Changed Wording:**
```
"At what price would you think it's overpriced?" ❌
```

**Good - Standard Wording:**
```
"At what price would you consider it to be so expensive that
you would not consider buying it?" ✓
```

**Why:** Van Westendorp analysis depends on specific question interpretations. Changing wording invalidates the methodology.

---

**Pitfall #3: Multiple Choice Instead of Open-End**

**Bad:**
```
At what price would it be too expensive?

○ Under $500
○ $500-$750
○ $750-$1,000
○ Over $1,000
```

**Good:**
```
At what price would it be too expensive?

$ ________
```

**Why:** Van Westendorp needs actual price points, not ranges.

---

## Gabor-Granger Design

### Basic Structure

**Gabor-Granger shows different prices sequentially and asks purchase intent:**

```
Q1. If this product were priced at $899, would you:

    ○ Definitely buy it
    ○ Probably buy it
    ○ Might or might not buy it
    ○ Probably not buy it
    ○ Definitely not buy it

[If "Might not" or "Definitely not," ask lower price]
[If "Definitely" or "Probably," ask higher price]

Q2. What if the price were $699, would you:
    [Same scale]

Q3. What if the price were $1,099, would you:
    [Same scale]
```

**Key Features:**
- **Sequential pricing** - Next price depends on previous answer
- **4-6 price points** tested per respondent
- **Purchase intent scale** - Not yes/no
- **Adaptive** - Price increases if interested, decreases if not

---

### Gabor-Granger: Best Practices

#### ✅ DO: Test Realistic Price Range

**Good Range Design:**
```
Current price: $799
Competitor range: $650-$1,100

Test prices:
- $599 (aggressive low)
- $699 (competitive low)
- $799 (current)
- $899 (premium)
- $999 (super-premium)
- $1,199 (maximum)
```

**Why:** Covers realistic competitive range plus extremes.

---

#### ✅ DO: Show Product Clearly

**Before Price Questions:**
```
[Show product image]

Product: [Name]
Features:
- Feature 1
- Feature 2
- Feature 3

Now we'll ask about different price points for this product.
```

**Why:** Respondents need consistent mental model while prices change.

---

#### ✅ DO: Use 5-Point Purchase Intent

**Recommended Scale:**
```
If priced at $X, would you:

○ Definitely buy (top 2 box)
○ Probably buy (top 2 box)
○ Might or might not buy
○ Probably not buy
○ Definitely not buy
```

**Analysis:**
- **"Definitely" + "Probably"** = Likely buyers
- Used to create demand curve
- Shows price elasticity

---

#### ❌ DON'T: Test Too Many Prices

**Bad - Too Many:**
```
Testing 10 different prices
→ 10 questions per respondent
→ Fatigue, pattern responses
```

**Good - Right Amount:**
```
Testing 4-6 prices
→ Sufficient for demand curve
→ Not exhausting
```

---

#### ❌ DON'T: Start With Unrealistic Extremes

**Bad Starting Price:**
```
First price shown: $5,000
(When category range is $500-$1,500)
→ Loses credibility
```

**Good Starting Price:**
```
First price shown: $999
(Mid-range for category)
→ Realistic, neutral anchor
```

---

### Common Gabor-Granger Pitfalls

**Pitfall #1: Same Price Sequence for Everyone**

**Less Effective:**
```
Everyone sees prices in this order:
$699 → $799 → $899 → $999
```

**Better:**
```
Randomize starting price across respondents:
- Group 1 starts at $699
- Group 2 starts at $899
- Group 3 starts at $1,099

Then ask adaptive follow-ups
```

**Why:** Reduces order/anchoring effects.

---

**Pitfall #2: Asking About Price Alone**

**Bad:**
```
Would you pay $899?

○ Yes
○ No
```

**Good:**
```
If this product [describe fully] were priced at $899, how likely
are you to purchase it?

○ Definitely would purchase
○ Probably would purchase
○ Might or might not purchase
○ Probably would not purchase
○ Definitely would not purchase
```

**Why:** Need purchase intent scale, not just yes/no. Context matters.

---

## Combined Approach: PSM + Purchase Intent

**Many studies use BOTH methods in same survey:**

**Structure:**
```
SECTION 1: Product Introduction
[Describe product, show images]

SECTION 2: Van Westendorp
[4 price perception questions - open-ended]

SECTION 3: Purchase Intent at Specific Prices
[Gabor-Granger style questions]

SECTION 4: Competitive Context
[Compare to competitor pricing]

SECTION 5: Demographics
```

**Why Both:**
- Van Westendorp: Acceptable price range
- Gabor-Granger: Actual demand at specific prices
- Together: Comprehensive pricing insight

---

## Sample Size Requirements

**Van Westendorp PSM:**
- **Minimum:** 150 respondents
- **Recommended:** 300 respondents
- **Why:** Need smooth distribution curves

**Gabor-Granger:**
- **Minimum:** 200 respondents
- **Recommended:** 400 respondents
- **Why:** Each price point needs 50+ evaluations

**Combined Study:**
- **Recommended:** 300-500 respondents
- Provides reliable estimates for both methods

---

## Product Description Guidelines

### ✅ DO: Be Specific About What They're Pricing

**Good:**
```
Premium Noise-Cancelling Headphones

Features:
- Active noise cancellation
- 30-hour battery life
- Premium sound quality (40mm drivers)
- Comfortable over-ear design
- Foldable with carrying case
- Bluetooth 5.0 with multipoint connection

Please answer the following price questions for this product.
```

**Bad:**
```
Headphones

How much would you pay for headphones?
```

**Why:** Generic "headphones" could mean anything from $20 to $500. Specific features ground the pricing questions.

---

### ✅ DO: Include Relevant Comparisons

**Helpful Context:**
```
This product is similar to:
- Sony WH-1000XM4 (currently $350)
- Bose QuietComfort 45 (currently $329)
- Apple AirPods Max (currently $549)

[Then ask pricing questions]
```

**Why:** Competitive context helps respondents give realistic answers.

---

### ❌ DON'T: Oversell or Undersell

**Bad - Overselling:**
```
Our revolutionary, award-winning, industry-leading product...
```
→ Inflates price expectations

**Bad - Underselling:**
```
This basic, entry-level product...
```
→ Deflates price expectations

**Good - Neutral:**
```
This product offers [list features objectively]
```

---

## Question Flow & Survey Structure

### Recommended Structure:

**PART 1: Introduction & Screening**
```
- Study purpose
- Category usage screening
- Recent purchase behavior
```

**PART 2: Product Familiarization**
```
- Show product images
- Describe features clearly
- Provide competitive context
- No price mentioned yet!
```

**PART 3: Price Perception (Van Westendorp)**
```
Q1. Too expensive price
Q2. Too cheap price
Q3. Getting expensive price
Q4. Good value price

All open-ended dollar amounts
```

**PART 4: Purchase Intent at Specific Prices (Gabor-Granger)**
```
Show product again (reminder)

Q5. At $X, would you purchase? (5-point scale)
Q6. At $Y, would you purchase? (5-point scale)
[4-6 price points total]
```

**PART 5: Competitive Pricing**
```
Q7. How does this compare to [Competitor A] at $Z?
Q8. How does this compare to [Competitor B] at $Z?

○ Much better value
○ Somewhat better value
○ About the same
○ Somewhat worse value
○ Much worse value
```

**PART 6: Demographics & Segmentation**
```
- Income (often relevant for pricing studies)
- Age, gender
- Usage frequency
- Price sensitivity scale
```

---

## Special Considerations for Pricing Studies

### Consider Income/Affordability

**Optional Income-Adjusted Analysis:**
```
Q: What is your annual household income?

○ Under $50,000
○ $50,000-$75,000
○ $75,000-$100,000
○ $100,000-$150,000
○ Over $150,000
○ Prefer not to say
```

**Why:** Pricing perceptions often vary by income segment. Can analyze separately.

---

### Include Price Sensitivity Scale

**Helpful Context Variable:**
```
Which statement best describes you when shopping for [category]?

○ I always buy the cheapest option
○ I'm very price-conscious and look for deals
○ I balance price with quality
○ I'm willing to pay more for better quality
○ Price is not a major factor for me
```

**Use:** Segment price-sensitive vs. quality-focused buyers.

---

### Test Multiple Product Tiers (If Relevant)

**For Products with Good/Better/Best Tiers:**

Run pricing for each tier separately:

```
Tier 1: Basic Model
[Van Westendorp + Gabor-Granger]

Tier 2: Premium Model
[Van Westendorp + Gabor-Granger]

Tier 3: Pro Model
[Van Westendorp + Gabor-Granger]
```

**Why:** Optimal price differs by tier. Can inform tiering strategy.

---

## Real-World Example: SaaS Subscription Pricing

**Business Question:**
"What should we charge for our project management software subscription?"

**Survey Design:**

**SECTION 1: Qualification**
```
Q1. Do you currently use project management software?
○ Yes, personally pay for it
○ Yes, company pays for it
○ No, but interested
○ No, not interested [TERMINATE]

Q2. How many team members would use it?
[Dropdown: 1-5, 6-10, 11-25, 26-50, 50+]
```

**SECTION 2: Product Demo**
```
[Show screenshots, key features]

OurProject includes:
- Unlimited projects and tasks
- Team collaboration tools
- Gantt charts and timelines
- File storage (100GB)
- Integrations (Slack, Google, etc.)
- Mobile apps (iOS/Android)
- Email support

Price is per user per month, billed annually.
```

**SECTION 3: Van Westendorp**
```
For context, similar tools range from $8-$25 per user/month.

Q3. At what price per user/month would this be too expensive?
$ _______ per user/month

Q4. At what price per user/month would you question the quality?
$ _______ per user/month

Q5. At what price would it be getting expensive?
$ _______ per user/month

Q6. At what price would it be a good value?
$ _______ per user/month
```

**SECTION 4: Purchase Intent**
```
If OurProject were priced at $15 per user/month, would you:

○ Definitely subscribe
○ Probably subscribe
○ Might or might not
○ Probably not subscribe
○ Definitely not subscribe

[Repeat for $10, $20, $25]
```

**SECTION 5: Competitive Comparison**
```
How does OurProject at $15/user/month compare to:

Asana ($11/user/month): [Better/Same/Worse value]
Monday.com ($16/user/month): [Better/Same/Worse value]
Basecamp ($99/month flat): [Better/Same/Worse value]
```

**Sample:** 400 potential customers

**Deliverables:**
- Van Westendorp optimal price point ($17/month)
- Acceptable range ($12-$24)
- Demand curve at different prices
- Revenue optimization recommendation
- Competitive positioning insights

---

## Quick Reference Checklist

**Van Westendorp PSM:**
- ✓ All 4 standard questions included
- ✓ Exact wording used (no modifications)
- ✓ Open-ended dollar entry (not ranges)
- ✓ Product clearly described first
- ✓ No price anchor mentioned beforehand

**Gabor-Granger:**
- ✓ 4-6 price points tested
- ✓ 5-point purchase intent scale
- ✓ Realistic price range
- ✓ Product shown consistently
- ✓ Randomized starting prices

**General:**
- ✓ Minimum 200-300 respondents
- ✓ Product features clearly described
- ✓ Competitive context provided
- ✓ Income/segmentation variables included
- ✓ Mobile-friendly number entry

---

## Bottom Line

Pricing studies require clear product descriptions and standardized questions:

**Critical Success Factors:**
1. **Describe product specifically** - Features, not generic category
2. **Use standard Van Westendorp wording** - Don't modify questions
3. **Test realistic price range** - Cover competitive landscape
4. **Minimum 300 respondents** - For stable demand curves
5. **Don't anchor responses** - Avoid mentioning target price
6. **Provide context** - Competitive pricing helps ground responses

Follow these guidelines and you'll collect reliable price sensitivity data that informs optimal pricing decisions.

---

*For questions or support, contact The Research LampPost (Pty) Ltd*
