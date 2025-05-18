-- 1. High-Value Customers with Multiple Products


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
STEP1:
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