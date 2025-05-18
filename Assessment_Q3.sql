-- 3. Account Inactivity Alert

-- STEP 1
WITH
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
	plan_id,
    owner_id,
    type,
    last_transaction_date,
    inactivity_days
FROM account_inactivity_metric 
WHERE no_of_txn = 0 AND (inactivity_days > 365 OR inactivity_days IS NULL)
ORDER BY inactivity_days IS NULL, inactivity_days


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