WITH 
users_with_both_plans AS ( -- 577 rows
SELECT DISTINCT 
    owner_id,
    SUM(CASE WHEN is_regular_savings = 1 THEN 1 ELSE 0 END) AS savings_count,
    SUM(CASE WHEN is_a_fund = 1 THEN 1 ELSE 1 END) AS investment_count
FROM adashi_staging.plans_plan 
GROUP BY owner_id
HAVING savings_count > 0 AND investment_count > 0
),

savings_invest_plans AS ( -- 3,535
SELECT DISTINCT
	owner_id,
    id AS plan_id
FROM adashi_staging.plans_plan
WHERE owner_id IN (SELECT owner_id FROM users_with_both_plans)
	AND (is_regular_savings = 1 OR is_a_fund = 1)
),

sip_deposits AS ( -- 515
SELECT
	DISTINCT owner_id,
    SUM(confirmed_amount) AS total_deposit
FROM adashi_staging.savings_savingsaccount
WHERE plan_id IN (SELECT plan_id FROM savings_invest_plans)
	AND confirmed_amount > 0
    AND transaction_status IN ('success', 'reward', 'redemption', 'earnings', 'monnify_success', 'successful')
GROUP BY 1
),

sip_deposit_metrics AS ( -- 577
SELECT 
	uwbp.owner_id,
    CONCAT(uc.first_name, ' ', uc.last_name) AS "name",
    uwbp.savings_count,
    uwbp.investment_count,
    FORMAT(sipd.total_deposit, 0) AS total_deposit
FROM users_with_both_plans uwbp
LEFT JOIN adashi_staging.users_customuser uc
	ON uc.id = uwbp.owner_id
LEFT JOIN sip_deposits sipd
	ON sipd.owner_id = uwbp.owner_id
ORDER BY sipd.total_deposit DESC
)

SELECT * 
FROM sip_deposit_metrics