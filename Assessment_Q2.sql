-- 2. Transaction Frequency Analysis

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