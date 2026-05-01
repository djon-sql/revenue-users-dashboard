-- Revenue & Users Analysis Project
-- Metrics: MRR, ARPPU, Churn, Net MRR
-- Built using SQL for Tableau dashboard

WITH base AS (
    SELECT 
        gp.user_id,
        DATE(DATE_TRUNC('month', gp.payment_date::date)) AS payment_month,
        SUM(gp.revenue_amount_usd) AS total_revenue,
        gpu.language,
        gpu.age,
        gpu.has_older_device_model,
        gpu.game_name
    FROM project.games_payments gp
    LEFT JOIN project.games_paid_users gpu 
        ON gp.user_id = gpu.user_id
    GROUP BY 
        gp.user_id,
        payment_month,
        gpu.language,
        gpu.age,
        gpu.has_older_device_model,
        gpu.game_name
), metrics1 AS (
SELECT 
    *,
    
    -- previous / next payments
    LAG(payment_month) OVER (PARTITION BY user_id ORDER BY payment_month) AS previous_paid_month,
    LEAD(payment_month) OVER (PARTITION BY user_id ORDER BY payment_month) AS next_paid_month,
    
    date(payment_month + INTERVAL '1 month') AS next_calendar_month,
    date(payment_month - INTERVAL '1 month') AS previous_calendar_month,
    
    LAG(total_revenue) OVER (PARTITION BY user_id ORDER BY payment_month) AS previous_paid_month_revenue
  FROM base
    
  ),metrics2 AS 
    
    (
    SELECT
    	*,
     -- new MRR / new users
    CASE 
        WHEN previous_paid_month IS NULL 
        THEN total_revenue 
    END AS new_MRR,
    
    CASE 
        WHEN previous_paid_month IS NULL 
        THEN 1 
    END AS new_paid_users,
    
    -- churn
    CASE 
        WHEN previous_paid_month IS NULL
        OR next_paid_month != payment_month + INTERVAL '1' month
        THEN total_revenue
    END AS churned_revenue,
    
    CASE 
        WHEN next_paid_month IS NULL
        OR next_paid_month != payment_month + INTERVAL '1' month
        THEN 1
    END AS churned_users,
    
    -- expansion
    CASE 
        WHEN previous_paid_month = payment_month - INTERVAL '1' month
        AND total_revenue > previous_paid_month_revenue
        THEN total_revenue - previous_paid_month_revenue
    END AS expansion_revenue,
    
    -- contraction
    CASE 
        WHEN previous_paid_month  = payment_month - INTERVAL '1' month
        AND total_revenue < previous_paid_month_revenue
        THEN total_revenue - previous_paid_month_revenue
    END AS contraction_revenue

FROM metrics1
), FINAL AS 
(
SELECT 
	payment_month,
	COUNT(DISTINCT user_id) AS paid_users,
        SUM(total_revenue) AS mrr,

        SUM(new_paid_users) AS new_paid_users,
        SUM(new_mrr) AS new_mrr,

        SUM(churned_users) AS churned_users,
        SUM(churned_revenue) AS churned_revenue,

        SUM(expansion_revenue) AS expansion_mrr,
        SUM(contraction_revenue) AS contraction_mrr,

        ROUND(SUM(total_revenue) / NULLIF(COUNT(DISTINCT user_id), 0),2) AS arppu
  FROM metrics2
  GROUP BY payment_month
)
SELECT *
FROM metrics2
ORDER BY payment_month

/*SELECT *
FROM Final
ORDER BY payment_month*/
