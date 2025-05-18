# Data Analyst Assessment Solutions

This repository contains SQL solutions for the Data Analyst Assessment, with four tasks covering customer segmentation, transaction analysis, inactivity alerts, and Customer Lifetime Value (CLV) estimation.

## Table of Contents

* [Prerequisites](#prerequisites)
* [File Structure](#file-structure)
* [Task 1: High-Value Customers with Multiple Products](#task-1-high-value-customers-with-multiple-products)
* [Task 2: Transaction Frequency Analysis](#task-2-transaction-frequency-analysis)
* [Task 3: Account Inactivity Alert](#task-3-account-inactivity-alert)
* [Task 4: Customer Lifetime Value (CLV) Estimation](#task-4-customer-lifetime-value-clv-estimation)

---

## Prerequisites

* MySQL
* Access to the following tables:

  * `users_customuser`
  * `plans_plan`
  * `savings_savingsaccount`

Ensure your MySQL connection is configured properly and you have read permissions on these tables.

---

## File Structure

```text
├── README.md
├── Assessment_Q1.sql   # Task 1 solution
├── Assessment_Q2.sql   # Task 2 solution
├── Assessment_Q3.sql   # Task 3 solution
└── Assessment_Q4.sql   # Task 4 solution
```

---

## Task 1: High-Value Customers with Multiple Products

**Scenario:** The business wants to identify customers who have both a savings and an investment plan (cross-selling opportunity).

**Description:** Write a query to find customers with at least one funded savings plan AND one funded investment plan, sorted by total deposits.

**Solution File:** `Assessment_Q1.sql`

```sql
WITH 
-- STEP 1
users_with_both_plans AS ( -- 195 rows
    SELECT DISTINCT 
        owner_id,
        SUM(CASE WHEN is_regular_savings = 1 THEN 1 ELSE 0 END) AS savings_count,
        SUM(CASE WHEN is_a_fund = 1 THEN 1 ELSE 0 END) AS investment_count
    FROM adashi_staging.plans_plan 
    GROUP BY owner_id
    HAVING savings_count > 0 AND investment_count > 0
),

-- STEP 2
savings_invest_plans AS ( -- 3,030 rows
    SELECT DISTINCT
        owner_id,
        id AS plan_id
    FROM adashi_staging.plans_plan
    WHERE owner_id IN (SELECT owner_id FROM users_with_both_plans)
        AND (is_regular_savings = 1 OR is_a_fund = 1)
),

-- STEP 3
sip_deposits AS ( -- 191 rows
    SELECT
        DISTINCT owner_id,
        SUM(confirmed_amount)/100 AS total_deposit -- converting from kobo to naira
    FROM adashi_staging.savings_savingsaccount
    WHERE plan_id IN (SELECT plan_id FROM savings_invest_plans)
        AND confirmed_amount > 0
        AND transaction_status IN ('success', 'reward', 'redemption', 'earnings', 'monnify_success', 'successful')
    GROUP BY owner_id
),

-- STEP 4
sip_deposit_metrics AS ( -- 195 rows
    SELECT 
        uwbp.owner_id,
        CONCAT(uc.first_name, ' ', uc.last_name) AS "name",
        uwbp.savings_count,
        uwbp.investment_count,
        ROUND(sipd.total_deposit, 2) AS total_deposit
    FROM users_with_both_plans uwbp
    LEFT JOIN adashi_staging.users_customuser uc
        ON uc.id = uwbp.owner_id
    LEFT JOIN sip_deposits sipd
        ON sipd.owner_id = uwbp.owner_id
)

-- Sort by total deposits to identify our highest-value cross-sell customers
SELECT * 
FROM sip_deposit_metrics
ORDER BY total_deposit DESC;

/*
STEP 1:
Find users who have both types of plans (cross-selling targets)
We need to identify people with at least one savings AND one investment plan

STEP 2:
Get all relevant plans for the users we identified
This gives us the plan IDs we need to look up transactions 

STEP 3:
Calculate total deposits for each user's plans
Making sure to only count successful transactions and convert from kobo to naira

STEP 4:
Pull everything together to get our final dataset
Joining user info with plan counts and deposit totals
*/
```

### Approach
To identify customers with both savings and investment plans, I took a methodical approach that prioritized accuracy in measuring their total deposit value.

First, I identified all users who have at least one savings plan AND one investment plan by counting each type per user. This gave me the foundation for finding true cross-sell customers.

Then, I gathered all relevant plan IDs associated with these customers, making sure to include only savings and investment plans. This step was crucial because some customers might have other plan types that we're not interested in for this analysis.

Next came the deposit calculation - I aggregated all successful transactions tied to these plans, being careful to filter for positive inflows only. I made sure to convert the amounts from kobo to naira as specified in the requirements.

Finally, I brought everything together by joining this deposit data with user information and plan counts, presenting a complete picture of our high-value cross-sell customers ordered by their total deposit amount.

### Challenges
Task 1 presented several analytical challenges that required careful consideration of the data model:

The primary difficulty was determining the correct approach for calculating total deposits. Initially, I summed the `confirmed_amount` for all transactions associated with each user. However, I realized this approach would include transactions from accounts that weren't savings or investment plans, potentially skewing the results. I refined my methodology to explicitly link deposits to only the relevant plan types.

Another significant challenge was identifying which transactions should qualify as "deposits." The database contained approximately 27 distinct transaction statuses, making it difficult to determine which represented actual customer deposits. After analyzing the data, I filtered for transactions with `confirmed_amount > 0`, which narrowed the field to 12 status types. 

From these, I identified six status types that appeared to represent genuine inflows (`'success'`, `'reward'`, `'redemption'`, `'earnings'`, `'monnify_success'`, `'successful'`). This required examining transaction patterns and making informed judgments based on the available data.

With proper domain knowledge from someone familiar with the business operations, I could further refine these filters for even greater accuracy. This highlights the importance of business context when performing financial data analysis.

---

## Task 2: Transaction Frequency Analysis
**Scenario:** The finance team wants to analyze how often customers transact to segment them (e.g., frequent vs. occasional users).

**Description:** Calculate the average number of transactions per customer per month and categorize them:
* "High Frequency" (≥10 transactions/month)
* "Medium Frequency" (3-9 transactions/month)
* "Low Frequency" (≤2 transactions/month)s

**Solution File:** `Assessment_Q2.sql`

```sql
WITH 
-- STEP 1
monthly_user_txns AS ( -- 8,210
SELECT
    owner_id,
	DATE_FORMAT(transaction_date, '%Y-%m-01') AS month,
    COUNT(*) AS total_transaction
FROM adashi_staging.savings_savingsaccount
GROUP BY month, owner_id
),

-- STEP 2
avg_monthly_txns_per_user AS (
SELECT 
	owner_id,
    AVG(total_transaction) AS avg_txn_per_month,
    CASE
		WHEN AVG(total_transaction) < 3 THEN 'Low Frequency'
        WHEN AVG(total_transaction) >= 3 AND AVG(total_transaction) < 10 THEN 'Medium Frequency'
        ELSE 'High Frequency'
	END AS frequency_category
FROM monthly_user_txns
GROUP BY owner_id
)

-- STEP 3
SELECT
	frequency_category,
    COUNT(owner_id) AS customer_count,
    ROUND(AVG(avg_txn_per_month), 1) AS avg_transactions_per_month
FROM avg_monthly_txns_per_user
GROUP BY frequency_category;

/*
STEP 1:
Get monthly transaction counts for each user
Shows basic activity patterns by month
Counting all transaction attempts to measure overall customer engagement
Alternative approach would be to filter for successful transactions only

STEP 2:
Calculate average transactions and assign frequency categories
Segments users based on their monthly activity levels

STEP 3:
Summarize results by frequency category
Provides finance team with customer segments overview
*/
```

### Approach
For the transaction frequency analysis, I decided to take a holistic view of customer activity by considering all transaction attempts, not just successful ones, since even failed transactions indicate engagement intent.

I started by breaking down transaction counts by month for each customer. This monthly grouping is critical because seasonal patterns can significantly impact financial activity, and we need a standardized time unit for fair comparison.

With these monthly counts established, I calculated the average number of transactions per month for each customer and categorized them according to the specified frequency bands. This segmentation transforms raw numbers into actionable customer categories.

The final step aggregated these categories to produce the overview statistics needed by the finance team. This gives them a clear picture of how the customer base is distributed across activity levels and what the typical transaction volume is within each segment.

### Challenges
This task was straightforward due to my prior experience with frequency analysis. I chose to analyze all transactions rather than just successful ones to provide a complete picture of user engagement patterns.

---

## Task 3: Account Inactivity Alert

**Scenario:** The ops team wants to flag accounts with no inflow transactions for over one year.

**Description:** Find all active accounts (savings or investments) with no transactions in the last 1 year (365 days) .

**Solution File:** `Assessment_Q3.sql`

```sql
WITH
-- STEP 1
users_with_either_plans AS ( -- 3,153
SELECT DISTINCT
	owner_id,
    id AS plan_id,
    CASE
		WHEN is_regular_savings = 1 THEN 'Savings'
        WHEN is_a_fund = 1 THEN 'Investment'
        ELSE 'Other Plans'
	END AS type
FROM adashi_staging.plans_plan
WHERE (is_regular_savings = 1 OR is_a_fund = 1)
  AND (is_deleted = 0 OR is_deleted IS NULL)
  AND (is_archived = 0 OR is_archived IS NULL)
),

-- STEP 2
users_with_either_plans_but_no_txs AS ( -- 523
SELECT * 
FROM users_with_either_plans
WHERE plan_id NOT IN (SELECT DISTINCT plan_id FROM adashi_staging.savings_savingsaccount)
),

-- STEP 3
user_txns_last_1_year AS ( -- 1,073
SELECT DISTINCT
	owner_id,
    plan_id,
	COUNT(id) OVER (PARTITION BY plan_id) AS no_of_txns
FROM adashi_staging.savings_savingsaccount
WHERE plan_id IN (SELECT plan_id FROM users_with_either_plans)
	AND confirmed_amount > 0 -- Only consider positive inflow transactions
    AND transaction_date >= CURRENT_DATE() - INTERVAL 365 DAY
),

-- STEP 4
user_last_txn_date AS ( -- 2,630
SELECT DISTINCT 
	owner_id,
    plan_id,
    MAX(transaction_date) OVER (PARTITION BY plan_id) AS last_transaction_date,
    DATEDIFF(CURDATE(), MAX(transaction_date) OVER (PARTITION BY plan_id)) AS inactivity_days
FROM adashi_staging.savings_savingsaccount
WHERE plan_id IN (SELECT plan_id FROM users_with_either_plans)
),

-- STEP 5
account_inactivity_metric As ( -- 3,153
SELECT
	uwep.owner_id,
    uwep.plan_id,
    uwep.type,
    ultd.last_transaction_date,
    ultd.inactivity_days,
    COALESCE(utly.no_of_txns, 0) AS no_of_txn
FROM users_with_either_plans uwep
LEFT JOIN user_last_txn_date ultd
	ON uwep.plan_id = ultd.plan_id
LEFT JOIN user_txns_last_1_year utly
	ON uwep.plan_id = utly.plan_id
)

-- STEP 6
SELECT -- 1,976
	owner_id,
    plan_id,
    type,
    last_transaction_date,
    inactivity_days
FROM account_inactivity_metric 
WHERE no_of_txn = 0 AND (inactivity_days > 365 OR inactivity_days IS NULL)
ORDER BY inactivity_days IS NULL, inactivity_days;

/*
STEP 1:
Identify all active savings and investment accounts
Excludes deleted and archived accounts as they're not relevant for this analysis

STEP 2:
Identify which plans have never had any transactions
Helps handle completely new accounts with no history

STEP 3:
Check if each plan had any transactions in the last year
Only counts positive inflow transactions to match business requirements

STEP 4:
Find when the last transaction occurred for each plan
Calculates inactivity period to measure dormancy

STEP 5:
Combine all metrics into a single view of account activity
Joins plan information with transaction history

STEP 6:
Filter for accounts with no activity in over a year
Includes both long-dormant accounts and new accounts with no transactions
*/
```

### Approach
Identifying dormant accounts required careful consideration of what "inactivity" truly means in the context of financial accounts.

I began by isolating only active savings and investment accounts, deliberately excluding deleted or archived accounts since these aren't relevant to the ops team's retention efforts. This filtering ensures we're only looking at accounts that should be active.

To properly measure inactivity, I approached the problem from two angles: first, I identified plans with absolutely no transaction history (completely unused accounts), and second, I found plans with past activity but no recent transactions.

For plans with transaction history, I calculated both the last transaction date and the exact number of days since that activity. I also specifically checked for any positive inflow transactions within the past year.

By combining these metrics, I created a comprehensive inactivity profile for each account. The final filter identifies truly dormant accounts - those with no transactions in over a year or with no transaction history at all, ordered by inactivity duration to prioritize the longest-dormant accounts.

### Challenges
One of the significant challenges I encountered in Task 3 was reconciling what appeared to be contradictory requirements between the scenario and task descriptions. The scenario stated: "The ops team wants to flag accounts with no inflow transactions for over one year," while the task instructed: "Find all active accounts with no transactions in the last 1 year (365 days)."

This subtle wording difference created ambiguity - was I looking for accounts with absolutely no activity in the past year, or accounts whose last activity was more than a year ago? After careful consideration, I determined that the business intent was likely to identify dormant accounts with extended inactivity periods (over 365 days). These accounts would represent potential churn risks and re-engagement opportunities for the operations team.

To properly identify "active" accounts (as specified in the task), I examined the table structure and found the `is_deleted` and `is_archived` fields, which allowed me to filter out accounts that had been intentionally deactivated. Additionally, I implemented a filter for `confirmed_amount > 0` to specifically address the "no inflow transactions" requirement mentioned in the scenario.

---

## Task 4: Customer Lifetime Value (CLV) Estimation

**Scenario:** Marketing wants to estimate CLV based on account tenure and transaction volume (simplified model).

**Description:** For each customer, assuming the profit_per_transaction is 0.1% of the transaction value, calculate:
* Account tenure (months since signup) 
* Total transactions
* Estimated CLV (Assume: CLV = (total_transactions / tenure) * 12 * avg_profit_per_transaction)
* Order by estimated CLV from highest to lowest

**Solution File:** `Assessment_Q4.sql`

```sql
WITH
-- STEP 1
user_txn_details AS (
SELECT DISTINCT 
    owner_id,
    COUNT(id) AS total_transactions,
    AVG(confirmed_amount) / 100 AS avg_amount,
    AVG(confirmed_amount) / 100 * 0.001 AS avg_profit_per_txn
FROM adashi_staging.savings_savingsaccount
WHERE confirmed_amount > 0
    AND transaction_status IN ('success', 'reward', 'redemption', 'earnings', 'monnify_success', 'successful')
GROUP BY owner_id
),

-- STEP 2
clv_metrics AS (
SELECT 
    uc.id AS customer_id,
    CONCAT(uc.first_name, ' ', uc.last_name) AS name,
    uc.created_on,
    timestampdiff(MONTH, uc.created_on, NOW()) AS tenure_months,
    utd.total_transactions,
    utd.avg_amount,
    utd.avg_profit_per_txn,
    CASE 
        WHEN timestampdiff(MONTH, uc.created_on, NOW()) > 0 
        THEN ROUND((COALESCE(utd.total_transactions, 0) / timestampdiff(MONTH, uc.created_on, NOW())) * 12 * COALESCE(utd.avg_profit_per_txn, 0), 2)
        ELSE 0
    END AS estimated_clv
FROM adashi_staging.users_customuser uc
LEFT JOIN user_txn_details utd
    ON utd.owner_id = uc.id
)

-- STEP 3
SELECT
    customer_id,
    name,
    tenure_months,
    total_transactions,
    estimated_clv
FROM clv_metrics
ORDER BY estimated_clv DESC;

/*
STEP 1:
Aggregate transaction data for each customer
Calculate key metrics including total transactions and average profit per transaction
Convert amounts from kobo to naira by dividing by 100
Apply 0.1% profit margin as specified in requirements

STEP 2:
Join user account information with transaction metrics
Calculate tenure in months based on account creation date
Handle edge cases like new accounts and customers with no transactions
Apply the CLV formula: (transactions per month × 12 months × avg profit per transaction)

STEP 3:
Present the final results with only the required columns
Sort by CLV from highest to lowest to identify most valuable customers
*/
```

### Approach
Calculating Customer Lifetime Value required balancing mathematical precision with business reality.

I started by aggregating all transaction data by customer, focusing on metrics that contribute to profit generation. This meant filtering for successful transactions and converting amounts from kobo to naira. The 0.1% profit margin was applied to calculate the average profit per transaction.

Next, I joined this transaction data with user account information to determine each customer's tenure. The CLV formula requires understanding how long each customer has been with us relative to their transaction volume.

The CLV calculation itself required careful handling of edge cases - protecting against division by zero for new customers and properly handling NULL values for customers without transaction history. I implemented a CASE statement to ensure these scenarios were managed gracefully.

The final result ranks customers by their estimated lifetime value, providing marketing with a powerful tool for prioritizing customer relationships and tailoring retention strategies based on demonstrated financial value.

### Challenges
The primary challenge I faced with the Customer Lifetime Value (CLV) calculation was determining which transactions actually generate profit for the business. Without detailed domain knowledge of the financial model, I had to make reasoned assumptions based on the data patterns and my understanding of similar fintech platforms.

Looking at Cowrywise's business model (focusing on Plans, Savings, and Investments), I hypothesized that the company likely doesn't profit when users withdraw funds from the platform. I observed transactions with status "circle" in the savings table that appeared to be withdrawal-related, despite the existence of a dedicated withdrawals table. This suggested complex transaction flows that would benefit from business context.

Additionally, I determined that failed transactions should be excluded from profit calculations since they don't represent completed financial activities. After careful consideration, I decided to apply the same transaction filters I used in Task 1 for identifying deposits (`'success'`, `'reward'`, `'redemption'`, `'earnings'`, `'monnify_success'`, `'successful'`), as these appeared to represent genuine inflows that would generate the 0.1% profit margin mentioned in the requirements.

---

## Conclusion

This analysis explores multiple dimensions of customer activity and value within the financial application:

Task 1 identified 195 high-value cross-sell customers who are already engaged with both savings and investment products. These customers represent prime opportunities for deeper product engagement and loyalty programs.

Task 2 revealed distinct transaction frequency patterns, with high-frequency users (141 customers) averaging nearly 45 transactions monthly, medium-frequency users (181 customers) averaging about 5 transactions monthly, and the majority falling into the low-frequency category (551 customers) with just over 1 transaction per month. This distribution suggests potential for targeted activation campaigns for the lower-frequency segments.

Task 3 identified 1,976 dormant accounts that haven't had inflow transactions in over a year. This represents a concerning proportion of the account base that may require targeted re-engagement strategies to prevent churn.

Task 4's CLV calculation highlighted variance in customer lifetime value. This analysis enables the company to identify and prioritize high-value customers for retention efforts while developing strategies to increase the value of lower-tier customers.

Together, these analyses provide a comprehensive view of customer engagement, value, and potential risk areas that can inform targeted marketing initiatives, product development, and customer success strategies.