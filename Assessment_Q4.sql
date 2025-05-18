-- 4. Customer Lifetime Value (CLV) Estimation

-- 4. Customer Lifetime Value (CLV) Estimation
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