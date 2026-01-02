# Segmentation: Questionnaire Design Guide

**Purpose:** Design surveys that produce meaningful, actionable customer segments

---

## What Segmentation Analysis Needs

Segmentation identifies natural groups within your customer base. To create useful segments, you need:

1. **Segmentation variables** - Attributes, behaviors, or attitudes that differ across groups
2. **Sufficient variation** - Not everyone answers the same
3. **Actionable differences** - Segments you can actually target differently
4. **Adequate sample** - Enough respondents to find stable groups
5. **Outcome variables** - What makes segments valuable (spending, loyalty, etc.)

---

## The Golden Rules

### Rule #1: Choose the Right Segmentation Basis

**Different Segmentation Types:**

**A. Demographic Segmentation (Easiest, Least Insightful)**
```
Segment by:
- Age
- Gender
- Income
- Geography
- Education

Pros: Easy to collect, easy to target
Cons: Doesn't explain WHY groups differ
```

**B. Behavioral Segmentation (Actionable)**
```
Segment by:
- Purchase frequency
- Product usage
- Channel preference
- Features used
- Spending level

Pros: Directly tied to actions
Cons: May miss underlying motivations
```

**C. Attitudinal/Psychographic Segmentation (Most Insightful)**
```
Segment by:
- Needs and motivations
- Values and beliefs
- Lifestyle preferences
- Attitudes toward category
- Benefit priorities

Pros: Explains WHY behavior differs
Cons: Harder to identify in practice
```

**D. Combined Approach (Recommended)**
```
Primary segmentation: Attitudes/Behaviors
Profiling variables: Demographics

Example:
- Find segments based on product needs
- Profile them using demographics for targeting
```

**Choose Based on Business Question:**
- "Who are our different customers?" → Attitudinal
- "How do usage patterns vary?" → Behavioral
- "Can we target by age/income?" → Demographic

---

### Rule #2: Include 8-20 Segmentation Variables

**Too Few (< 5 variables):**
- Might as well use simple cross-tabs
- Limited dimensionality
- Crude segments

**Sweet Spot (10-15 variables):**
```
Example: Financial Services Attitudes

1. Prefer online banking vs. branch
2. Value personal service vs. self-service
3. Risk tolerance (conservative vs. aggressive)
4. Price sensitivity vs. service quality
5. Technology adoption (early vs. late)
6. Brand loyalty vs. switcher
7. Prefer bundled vs. à la carte products
8. Financial planning horizon (short vs. long-term)
9. Trust in financial institutions
10. Importance of local presence
11. Interest in investment products
12. Preference for human vs. digital advice
```

**Too Many (> 25 variables):**
- Respondent fatigue
- Many variables may be redundant
- Overfitting risk
- Hard to interpret segments

**Rule of Thumb:** 10-15 segmentation variables is optimal.

---

### Rule #3: Use Rating Scales for Attitudinal Segmentation

**Best Practice: 1-10 Agreement Scales**

```
Please indicate your level of agreement with each statement:
(1 = Strongly Disagree, 10 = Strongly Agree)

1. I prefer managing my finances online vs. visiting a branch
   1  2  3  4  5  6  7  8  9  10

2. I'm willing to pay more for exceptional customer service
   1  2  3  4  5  6  7  8  9  10

3. I consider myself an early adopter of new technology
   1  2  3  4  5  6  7  8  9  10

[Continue for 10-15 statements]
```

**Why 1-10:**
- More variation than 1-5 scales
- Better for clustering algorithms
- Shows nuanced differences

**Alternative: 1-5 Scales**
- Works but less granular
- OK if survey needs to be shorter

---

### Rule #4: Include Outcome/Value Variables

**Segments Need Business Relevance**

Beyond segmentation variables, collect:

**Behavioral Outcomes:**
```
Q: In the past 12 months, approximately how much have you spent on [category]?

○ Under $500
○ $500-$1,000
○ $1,000-$2,500
○ $2,500-$5,000
○ Over $5,000
```

**Attitudinal Outcomes:**
```
Q: How likely are you to recommend [Brand] to friends/colleagues?
[0-10 NPS scale]

Q: How satisfied are you overall with [Brand]?
[1-10 scale]
```

**Loyalty Indicators:**
```
Q: How long have you been a customer?
○ Less than 6 months
○ 6 months - 1 year
○ 1-2 years
○ 3-5 years
○ More than 5 years
```

**Why:** Segments are only useful if some are more valuable than others. Outcome variables show which segments to prioritize.

---

## Designing Segmentation Variables

### Attitudinal Batteries

**Use Batteries (Grids) for Efficiency:**

```
Below are statements about [product category].
Please rate your agreement with each.
(1 = Strongly Disagree, 10 = Strongly Agree)

                                                    Disagree ← → Agree
1. I always buy the cheapest option                1 2 3 4 5 6 7 8 9 10
2. Brand name is very important to me              1 2 3 4 5 6 7 8 9 10
3. I prefer products with the latest features      1 2 3 4 5 6 7 8 9 10
4. I stick with brands I know and trust            1 2 3 4 5 6 7 8 9 10
5. Environmental impact influences my choices      1 2 3 4 5 6 7 8 9 10
6. I do extensive research before purchasing       1 2 3 4 5 6 7 8 9 10
7. Convenience is more important than price        1 2 3 4 5 6 7 8 9 10
8. I like to be the first among friends to try new things  1 2 3 4 5 6 7 8 9 10
```

**Best Practices:**
- **10-15 statements** in a battery
- **Varied directions** (some pro, some con to prevent straight-lining)
- **Specific, not vague** statements
- **One idea per statement**

---

### Behavioral Variables

**Include Both Frequency and Type:**

**Usage Frequency:**
```
Q: How often do you [behavior]?

○ Daily
○ Several times per week
○ Weekly
○ Monthly
○ Less than monthly
○ Never
```

**Product/Feature Usage:**
```
Q: Which features do you regularly use? (Select all that apply)

☐ Feature A
☐ Feature B
☐ Feature C
☐ Feature D
☐ None of these
```

**Channel Preferences:**
```
Q: Where do you typically make purchases? (Select all that apply)

☐ Company website
☐ Mobile app
☐ Physical store
☐ Phone
☐ Third-party retailer
```

**Convert to Numeric for Clustering:**
- Yes/No becomes 1/0
- Select all becomes count or binary flags
- Frequency becomes ordered scale (1-6)

---

## Common Pitfalls & Solutions

### Pitfall #1: Only Using Demographics

**Problem:**
```
Segmentation based only on:
- Age
- Gender
- Income
- Region

→ Not insightful, doesn't explain behavior
```

**Solution:**
```
Primary segmentation: Attitudes + Behaviors
Profile with demographics

Example segments:
- Price-Conscious Traditionalists (happen to be older, lower income)
- Tech-Savvy Maximizers (happen to be younger, higher income)
- Convenience Seekers (mixed demographics)
```

**Why:** Demographics describe WHO is in segments, but attitudes/behaviors explain WHY they act differently.

---

### Pitfall #2: Not Enough Variation in Responses

**Problem:**
```
Attitudinal Statement:
"I care about product quality"

Results: 95% rate 8-10 (agree)

→ No variation, can't segment on this
```

**Solution:**
```
Use discriminating statements:
"I'm willing to pay 20% more for premium quality vs. acceptable quality"

Results: 25% rate 1-4, 35% rate 5-7, 40% rate 8-10

→ Good variation, useful for segmentation
```

**Test:** If >80% answer the same way, variable won't help segment.

---

### Pitfall #3: Correlated Variables

**Problem:**
```
Three attitudes that are basically the same thing:

1. I prefer low prices
2. I'm price-conscious
3. I always look for the cheapest option

→ All measure same underlying dimension
→ Redundant for clustering
```

**Solution:**
```
Include diverse dimensions:

1. Price sensitivity (keep one)
2. Brand loyalty
3. Feature preferences
4. Channel preference
5. Purchase frequency

→ Each captures different aspect
```

**Why:** Clustering works best with diverse, orthogonal variables.

---

### Pitfall #4: Sample Too Small for Number of Segments

**Problem:**
```
Sample: 200 respondents
Expected segments: 5

200 ÷ 5 = 40 per segment (too small!)
```

**Solution:**
```
Sample: 500 respondents
Expected segments: 4

500 ÷ 4 = 125 per segment ✓
```

**Rule of Thumb:** Minimum 100 per expected segment, preferably 150+.

---

## Sample Size Requirements

**Minimum Sample Sizes:**

| Expected Segments | Minimum Sample | Recommended Sample |
|-------------------|----------------|-------------------|
| 2-3 segments | 300 | 500 |
| 4-5 segments | 500 | 750 |
| 6-7 segments | 750 | 1,000+ |

**Why:** Each segment needs adequate representation for:
- Stable cluster estimates
- Profiling analysis
- Statistical testing of differences

**Rule of Thumb:** Minimum 100 per segment, ideally 150+.

---

## Question Flow & Survey Structure

### Recommended Structure:

**PART 1: Screening & Qualification**
```
- Category usage
- Purchase recency
- Customer status (current/lapsed/never)
```

**PART 2: Behavioral Questions**
```
- Purchase frequency
- Spending levels
- Product/feature usage
- Channel preferences
- Brand choices
```

**PART 3: Attitudinal Batteries**
```
- Needs and motivations (10-15 statements)
- Values and priorities
- Category attitudes
- Shopping preferences
```

**PART 4: Outcome Variables**
```
- Satisfaction
- NPS/Loyalty
- Purchase intent
- Spending
```

**PART 5: Demographics (Profiling Variables)**
```
- Age
- Gender
- Income
- Education
- Geography
- Household composition
```

**Rationale:**
- Behaviors and attitudes first (segmentation basis)
- Outcomes next (segment value)
- Demographics last (profiling)

---

## Real-World Example: Retail Segmentation

**Business Question:**
"Who are our different customer types and how should we target them?"

**Survey Design:**

**PART 1: Shopping Behavior**
```
Q1. How often do you shop at [Retailer]?
[Frequency scale]

Q2. Average monthly spending at [Retailer]:
[Dollar ranges]

Q3. Which departments do you shop in? (Select all)
☐ Clothing
☐ Home goods
☐ Electronics
☐ Groceries
☐ Beauty/Personal care
☐ Sporting goods
```

**PART 2: Shopping Attitudes (Segmentation Basis)**
```
Rate your agreement (1-10):

1. I enjoy browsing stores even when I'm not looking for something specific
2. I only shop when I need something
3. I'm willing to pay more for products from brands I trust
4. I always compare prices before buying
5. I prefer shopping online to shopping in stores
6. I like to be among the first to try new products
7. Sales and promotions strongly influence where I shop
8. I value personalized service and recommendations
9. Sustainability is important in my purchasing decisions
10. I'm loyal to stores that offer good rewards programs
11. I prefer stores with wide selection over specialized shops
12. Shopping is a leisure activity I enjoy
13. I research products extensively before purchasing
14. Convenience is more important than price to me
15. I trust online reviews more than salesperson recommendations
```

**PART 3: Outcome Variables**
```
Q: Overall satisfaction with [Retailer] (1-10)
Q: Likelihood to recommend (0-10 NPS)
Q: Likelihood to shop here in next 3 months (1-10)
```

**PART 4: Demographics**
```
- Age
- Gender
- Household income
- Household size
- Employment status
- Urban/Suburban/Rural
```

**Sample:** 600 customers

**Analysis Reveals 4 Segments:**

1. **Bargain Hunters (28% of sample)**
   - High price sensitivity
   - Promotion-driven
   - Low brand loyalty
   - Profile: Younger, lower income
   - Value: Moderate spenders, low loyalty

2. **Convenience Seekers (25%)**
   - Online preference
   - Time-scarce
   - Willing to pay for convenience
   - Profile: Working professionals, higher income
   - Value: High spenders, moderate loyalty

3. **Experience Shoppers (22%)**
   - Enjoy shopping as activity
   - In-store preference
   - Service-oriented
   - Profile: Older, middle to upper income
   - Value: Moderate spenders, high loyalty

4. **Pragmatic Functionalists (25%)**
   - Need-based shopping
   - Research-oriented
   - Balanced price/quality
   - Profile: Mixed demographics
   - Value: High spenders, high loyalty

**Business Actions by Segment:**
- Bargain Hunters: Weekly deals, email promotions
- Convenience Seekers: Enhanced online/mobile, fast fulfillment
- Experience Shoppers: In-store events, personal shopping
- Pragmatic Functionalists: Product information, reviews, comparisons

---

## Testing Segmentation Variables

### Pre-Launch Pilot (n=50-100)

**Check:**
1. **Variation in responses** - Ensure not everyone answers the same
2. **Comprehension** - Are questions clear?
3. **Straight-lining** - Are people just clicking down the middle?
4. **Survey length** - Is it too long?

**Red Flags:**
- Variables with >80% in one category
- Attitudinal statements where everyone agrees
- Confusion about question meaning

---

## Quick Reference Checklist

**Segmentation Variables:**
- ✓ 10-15 variables selected
- ✓ Mix of attitudinal + behavioral (not just demographics)
- ✓ 1-10 rating scales for attitudes
- ✓ Diverse dimensions covered (not redundant)
- ✓ Expect variation in responses

**Outcome/Value Variables:**
- ✓ Spending/usage included
- ✓ Satisfaction/loyalty measured
- ✓ Other business metrics captured
- ✓ Profiling variables (demographics)

**Sample Size:**
- ✓ Minimum 100 per expected segment
- ✓ Total sample 500+ for 4-5 segments
- ✓ Larger if targeting robust segmentation

**Survey Design:**
- ✓ Behaviors asked first
- ✓ Attitudes in middle (battery format)
- ✓ Outcomes follow
- ✓ Demographics last
- ✓ 15-20 minute survey length

---

## Bottom Line

Segmentation requires thoughtful variable selection and adequate sample:

**Critical Success Factors:**
1. **Segment on attitudes/behaviors** - Not just demographics
2. **10-15 diverse variables** - Capture different dimensions
3. **Include outcome variables** - Show segment value
4. **Minimum 500 respondents** - For 4-5 stable segments
5. **Test for variation** - Pilot to ensure discrimination
6. **Profile with demographics** - For targeting

Follow these guidelines and you'll collect data that produces meaningful, actionable customer segments that drive business strategy.

---

*For questions or support, contact The Research LampPost (Pty) Ltd*
