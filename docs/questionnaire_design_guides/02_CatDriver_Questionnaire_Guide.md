# CatDriver Analysis: Questionnaire Design Guide

**Purpose:** Design surveys for categorical driver analysis (regression-based modeling)

---

## What CatDriver Analysis Needs

CatDriver identifies drivers of **categorical outcomes** like purchase decisions, satisfaction categories, or NPS groups. Unlike KeyDriver (which needs continuous ratings), CatDriver works with:

1. **Categorical outcome** - Distinct groups (Promoter/Passive/Detractor, Will Buy/Won't Buy, etc.)
2. **Driver variables** - Numeric ratings or categorical predictors
3. **Sufficient cases in each category** - Can't predict rare outcomes
4. **Clear category definitions** - Well-defined, mutually exclusive groups

---

## The Golden Rules

### Rule #1: Your Outcome Must Be Categorical

**What Works:**
- **Binary (2 categories):** Purchase/No Purchase, Satisfied/Dissatisfied
- **Ordinal (ordered categories):** Low/Medium/High NPS, Very/Somewhat/Not Satisfied
- **Nominal (unordered):** Brand A/Brand B/Brand C preference

**Examples:**
```
Binary Outcome:
"Did you purchase in the last 30 days?"
○ Yes
○ No

Ordinal Outcome (NPS Categories):
"Based on your experience, would you recommend us?"
○ Promoter (9-10)
○ Passive (7-8)
○ Detractor (0-6)

Ordinal Outcome (Satisfaction):
"How satisfied are you overall?"
○ Very Satisfied
○ Somewhat Satisfied
○ Neither Satisfied nor Dissatisfied
○ Somewhat Dissatisfied
○ Very Dissatisfied
```

**What Doesn't Work:**
- Continuous outcomes (use KeyDriver instead)
- Too many categories (>5-6 becomes unwieldy)
- Unbalanced categories (95% in one group, 5% in another)

---

### Rule #2: Categories Must Be Balanced (Roughly)

**Good Distribution:**
```
Purchase Decision:
- Will Buy: 35%
- Might Buy: 40%
- Won't Buy: 25%
```
→ All categories well-represented

**Bad Distribution:**
```
Purchase Decision:
- Will Buy: 92%
- Might Buy: 6%
- Won't Buy: 2%
```
→ Too few in "Won't Buy" category to model

**Minimum per Category:** At least 30-50 cases in smallest category

**Solutions for Imbalance:**
- Oversample rare categories
- Combine categories ("Might + Won't" = "Not Will Buy")
- Use binary outcome instead of multi-category

---

### Rule #3: Drivers Can Be Ratings OR Categories

Unlike KeyDriver (which needs continuous ratings), CatDriver handles:

**Numeric Drivers (Best):**
```
Rate your satisfaction with each:
- Product quality (1-10)
- Customer service (1-10)
- Value for money (1-10)
```

**Categorical Drivers (Also Work):**
```
Which features do you use? (Select all)
☑ Feature A
☑ Feature B
☑ Feature C
```

**Demographic Drivers:**
```
Age group:
○ 18-34
○ 35-54
○ 55+
```

**Mix is OK:** You can combine numeric and categorical drivers in same model.

---

## Question Design for Binary Outcomes

### Example: Purchase Intent

**Outcome Question:**
```
How likely are you to purchase [Product] in the next 6 months?

○ Definitely will purchase
○ Probably will purchase
○ Might or might not purchase
○ Probably will not purchase
○ Definitely will not purchase
```

**Converting to Binary:**
- **Will Purchase:** Definitely + Probably will
- **Won't Purchase:** All others

**Driver Questions (1-10 scales):**
```
How important is each factor in your purchase decision?

Q1. Price competitiveness (1-10)
Q2. Product features (1-10)
Q3. Brand reputation (1-10)
Q4. Customer reviews (1-10)
Q5. Ease of purchase (1-10)
```

**Why This Works:**
- Clear binary outcome
- Numeric driver ratings
- Measures decision factors directly

---

## Question Design for Ordinal Outcomes

### Example: NPS Driver Analysis

**Outcome Question (Standard NPS):**
```
On a scale of 0-10, how likely are you to recommend [Company] to a friend?

○ 0 - Not at all likely
○ 1
...
○ 10 - Extremely likely
```

**Categorization:**
- Promoters: 9-10
- Passives: 7-8
- Detractors: 0-6

**Driver Questions:**
```
Rate your experience with each:

Q1. Quality of product/service (1-10)
Q2. Customer support experience (1-10)
Q3. Value for the price (1-10)
Q4. Ease of doing business with us (1-10)
Q5. Speed of service delivery (1-10)
Q6. Professionalism of staff (1-10)
```

**Analysis Approach:**
- CatDriver identifies what drives Promoters vs. Passives vs. Detractors
- Shows different drivers for each category
- Individual-level predictions using SHAP

---

## Question Design for Multinomial Outcomes

### Example: Brand Choice

**Outcome Question:**
```
Which brand would you most likely choose for your next purchase?

○ Brand A (Our brand)
○ Brand B (Competitor 1)
○ Brand C (Competitor 2)
○ Other brand
○ Would not purchase in category
```

**Driver Questions:**
```
Rate each brand on the following attributes (1-10):

Brand A:
- Quality perception (1-10)
- Value perception (1-10)
- Brand trust (1-10)

Brand B:
- Quality perception (1-10)
- Value perception (1-10)
- Brand trust (1-10)

[Repeat for Brand C]
```

**Alternative - Comparative Drivers:**
```
Compared to competitors, how does Brand A rate on:

Q1. Product quality (Much Worse / Worse / Same / Better / Much Better)
Q2. Price value (Much Worse / Worse / Same / Better / Much Better)
Q3. Customer service (Much Worse / Worse / Same / Better / Much Better)
```

---

## Common Pitfalls & Solutions

### Pitfall #1: Outcome Too Imbalanced

**Problem:**
```
Customer Churn:
- Stayed: 97%
- Churned: 3%
```

**Why It's Bad:**
- Can't build reliable model with only 3% in one category
- Need at least 30-50 cases in smallest group

**Solutions:**

**Option 1: Oversample rare category**
- Survey more churners deliberately
- Weight analysis to reflect true proportions

**Option 2: Binary outcome instead of multi-category**
```
Bad (imbalanced):
- Very High Churn Risk: 2%
- High Churn Risk: 5%
- Medium Churn Risk: 12%
- Low Churn Risk: 81%

Good (binary):
- At Risk (Top 3 combined): 19%
- Not At Risk: 81%
```

**Option 3: Match controls**
- For every churner, survey 2-3 similar non-churners
- Balanced design, then weight results

---

### Pitfall #2: Too Many Outcome Categories

**Problem:**
```
Satisfaction Level:
○ Extremely Satisfied (8%)
○ Very Satisfied (22%)
○ Satisfied (31%)
○ Somewhat Satisfied (18%)
○ Neutral (11%)
○ Somewhat Dissatisfied (6%)
○ Dissatisfied (3%)
○ Very Dissatisfied (1%)
```

**Why It's Bad:**
- 8 categories is too many
- Bottom 3 categories have tiny samples
- Model complexity explodes

**Solution - Collapse Categories:**
```
Better (3 categories):
○ Satisfied (Extremely + Very + Satisfied): 61%
○ Neutral (Somewhat Satisfied + Neutral): 29%
○ Dissatisfied (All dissatisfied): 10%
```

**Rule of Thumb:** 2-4 outcome categories ideal, max 5-6

---

### Pitfall #3: Unclear Category Boundaries

**Bad:**
```
Purchase Likelihood:
○ High
○ Medium  ← What's the difference between Medium and Low?
○ Low
```

**Good:**
```
Purchase Likelihood:
○ Will definitely purchase (90-100% certain)
○ Will probably purchase (60-89% certain)
○ Might or might not (40-59% certain)
○ Probably won't purchase (10-39% certain)
○ Definitely won't purchase (0-9% certain)
```

**Why:** Clear definitions reduce ambiguity and measurement error.

---

## Sample Size Requirements

**Minimum Sample Sizes by Outcome Type:**

| Outcome Type | Categories | Min Sample | Recommended |
|--------------|-----------|------------|-------------|
| Binary | 2 | 150 (75 per category) | 300+ |
| Ordinal | 3 | 225 (75 per category) | 450+ |
| Ordinal | 4 | 300 (75 per category) | 600+ |
| Multinomial | 3 | 300 (100 per category) | 600+ |

**Driver Variables:**
- Can handle 10-30 drivers
- More flexible than KeyDriver
- Handles categorical + continuous drivers

**Rule of Thumb:** Need at least 50 cases per category, preferably 100+

---

## Question Order Recommendations

**Recommended Flow:**

1. **Behavioral questions** (if relevant)
   - Recent purchases, usage frequency, etc.

2. **Driver rating questions**
   - Satisfaction with attributes
   - Perceptions, experiences

3. **Outcome question**
   - Purchase intent, NPS, satisfaction category
   - Asked AFTER drivers to prevent contamination

4. **Demographics**
   - Can also be used as drivers in model

**Example Structure:**
```
SECTION 1: Your Recent Experience
[Behavioral context questions]

SECTION 2: Rate Your Experience
[Driver questions - 1-10 scales]

SECTION 3: Overall Assessment
[Outcome question - categorical]

SECTION 4: About You
[Demographics - can be model drivers too]
```

---

## Special Considerations for CatDriver

### Can Use Categorical Drivers

Unlike KeyDriver (which needs continuous ratings), CatDriver handles:

**Yes/No Drivers:**
```
Do you currently use:
☑ Mobile app
☐ Website
☑ Phone support
☐ Email support
```

**Multi-Select Drivers:**
```
Which features have you used? (Select all)
☑ Feature A
☑ Feature B
☐ Feature C
☐ Feature D
```

**Ordinal Categories:**
```
How often do you use the product?
○ Daily
○ Weekly
○ Monthly
○ Rarely
```

**These all work in CatDriver!** The model converts them appropriately.

---

### Can Mix Driver Types

**Example - Mixed Drivers:**
```
Outcome: Purchase (Yes/No)

Continuous Drivers:
- Product quality rating (1-10)
- Price satisfaction (1-10)
- Service satisfaction (1-10)

Categorical Drivers:
- Customer type (New/Returning/Loyal)
- Contacted support (Yes/No)
- Uses mobile app (Yes/No)

Demographic Drivers:
- Age group (18-34/35-54/55+)
- Income level (Low/Medium/High)
```

**All of these can go into one CatDriver model!**

---

## Real-World Example: Good Design

### Business Question:
"What drives customers to become Promoters (NPS 9-10) vs. Passives (7-8) vs. Detractors (0-6)?"

### Survey Design:

**SECTION 1: Your Recent Experiences**
```
Q1. How long have you been a customer?
○ Less than 6 months
○ 6 months to 1 year
○ 1-2 years
○ More than 2 years

Q2. In the past 3 months, have you:
☑ Contacted customer service
☑ Made a purchase
☐ Visited a physical location
☑ Used mobile app
☐ Filed a complaint
```

**SECTION 2: Rate Your Satisfaction**
```
On a scale of 1-10, how satisfied are you with:

Q3. Product quality (1-10)
Q4. Value for money (1-10)
Q5. Customer service (1-10)
Q6. Ease of doing business (1-10)
Q7. Speed of service (1-10)
Q8. Problem resolution (1-10)
Q9. Mobile app experience (1-10)
Q10. Product selection (1-10)
```

**SECTION 3: Overall Recommendation**
```
Q11. How likely are you to recommend [Company] to friends/colleagues?
○ 0 - Not at all likely
○ 1
...
○ 10 - Extremely likely
```

**SECTION 4: Demographics**
```
Q12. Age group [dropdown]
Q13. Gender [select]
Q14. Usage frequency [select]
```

**Analysis:**
- Outcome: NPS category (Promoter/Passive/Detractor)
- Drivers: Q1, Q2 (categorical), Q3-Q10 (continuous), Q12-Q14 (categorical)
- CatDriver identifies what distinguishes each group
- SHAP values show individual-level drivers

---

## Testing & Validation

### Pre-Launch Checks:

**Category Balance:**
- [ ] Run n=50-100 pilot
- [ ] Check category distribution
- [ ] Ensure no category < 20% of sample
- [ ] If imbalanced, adjust sampling

**Driver Variation:**
- [ ] Ensure driver ratings vary (not all 8-10)
- [ ] Check for straight-lining
- [ ] Verify drivers are answerable

**Question Clarity:**
- [ ] Categories clearly defined
- [ ] No confusion about which to select
- [ ] Mutually exclusive options

---

## Quick Reference Checklist

**Outcome Design:**
- ✓ 2-4 categories (max 5)
- ✓ Clear, mutually exclusive category definitions
- ✓ Expected 50+ respondents per category
- ✓ Balanced distribution (no category < 10%)

**Driver Design:**
- ✓ Can mix continuous (1-10) and categorical drivers
- ✓ 10-20 drivers recommended
- ✓ Drivers relate to outcome decision
- ✓ Avoid overlapping/redundant drivers

**Survey Structure:**
- ✓ Behavioral/context questions first
- ✓ Driver questions second
- ✓ Outcome question third
- ✓ Demographics last (can also be drivers)

**Sample Size:**
- ✓ Minimum 50 per category
- ✓ Preferably 100+ per category
- ✓ Total sample 200+ for binary, 300+ for ordinal

---

## CatDriver vs. KeyDriver: When to Use Which

**Use CatDriver when:**
- Outcome is categorical (satisfaction levels, purchase intent, NPS categories)
- You want individual-level predictions
- You need to control for multiple factors simultaneously
- Drivers can be mixed (ratings + behaviors + demographics)

**Use KeyDriver when:**
- Outcome is continuous (1-10 satisfaction rating)
- You want simple correlation-based importance
- Faster, simpler analysis preferred
- Audience wants straightforward correlations

**Can Use Both:**
- KeyDriver for continuous overall satisfaction
- CatDriver for categorical segments (Very/Somewhat/Not Satisfied)

---

## Bottom Line

CatDriver is more flexible than KeyDriver but requires careful outcome design:

**Key Principles:**
1. **2-4 outcome categories** (clear, balanced, well-defined)
2. **Minimum 50 cases per category** (preferably 100+)
3. **Drivers can be mixed types** (ratings, behaviors, demographics)
4. **Ask outcome AFTER drivers** (prevent contamination)
5. **Test category balance** before full launch

Follow these guidelines and you'll collect data that produces powerful categorical driver insights with individual-level precision.

---

*For questions or support, contact The Research LampPost (Pty) Ltd*
