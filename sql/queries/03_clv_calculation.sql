-- ============================================================
-- Customer Lifetime Value (CLV) Calculation
-- Author: [Your Name]
-- Source: UCI "Online Retail" dataset (real UK gift retailer)
-- Description:
--   CLV_12m = AOV × (purchase_freq_monthly × 12) × gross_margin_pct
--   gross_margin_pct is per-customer, weighted by each customer's
--   actual category purchase mix, joined from
--   category_margin_assumptions (Finance-provided blended rates).
-- Expected result: 4,334 customers, avg CLV_12m ~£1,018
-- ============================================================

USE ecommerce_clv;

-- ─────────────────────────────────────────────
-- STEP 1: Dataset span in months (used for purchase frequency)
-- ─────────────────────────────────────────────
SET @total_months = (
    SELECT ROUND(
        DATEDIFF(MAX(invoice_date), MIN(invoice_date)) / 30.5, 2
    )
    FROM orders
    WHERE order_status = 'Completed'
);

SELECT @total_months AS dataset_span_months;   -- expect ~12.3

-- ─────────────────────────────────────────────
-- STEP 2: INSERT CLV scores
-- Note: MySQL does not support WITH ... INSERT.
-- All aggregation is done in a single subquery.
-- gross_margin_pct is derived inline via a weighted-average
-- subquery joining category_margin_assumptions.
-- ─────────────────────────────────────────────
INSERT INTO clv_scores (
    customer_id,
    avg_order_value,
    purchase_freq_monthly,
    churn_rate,
    gross_margin_pct,
    clv_12m,
    clv_36m,
    clv_segment
)
SELECT
    customer_id,
    ROUND(total_revenue / order_count, 2)                             AS avg_order_value,
    ROUND(order_count / @total_months, 4)                             AS purchase_freq_monthly,
    ROUND(1.0 - (1.0 / order_count), 4)                              AS churn_rate,
    ROUND(blended_margin, 4)                                          AS gross_margin_pct,
    -- CLV formula: AOV × (freq_monthly × 12) × margin
    ROUND(
        (total_revenue / order_count)
        * (order_count / @total_months) * 12
        * blended_margin
    , 2)                                                              AS clv_12m,
    ROUND(
        (total_revenue / order_count)
        * (order_count / @total_months) * 36
        * blended_margin
    , 2)                                                              AS clv_36m,
    'Pending'                                                         AS clv_segment
FROM (
    -- Per-customer aggregate: order count, revenue, weighted margin
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.invoice_no)                                   AS order_count,
        ROUND(SUM(oi.line_total), 2)                                   AS total_revenue,
        -- Weighted blended margin: sum(revenue × category_margin) / total_revenue
        ROUND(
            SUM(oi.line_total * cma.gross_margin_pct)
            / NULLIF(SUM(oi.line_total), 0)
        , 4)                                                           AS blended_margin
    FROM orders o
    JOIN order_items oi ON o.invoice_no  = oi.invoice_no
    JOIN products    p  ON oi.stock_code = p.stock_code
    JOIN category_margin_assumptions cma ON p.category = cma.category
    WHERE o.order_status = 'Completed'
    GROUP BY o.customer_id
) base_data
ON DUPLICATE KEY UPDATE
    avg_order_value       = VALUES(avg_order_value),
    purchase_freq_monthly = VALUES(purchase_freq_monthly),
    churn_rate            = VALUES(churn_rate),
    gross_margin_pct      = VALUES(gross_margin_pct),
    clv_12m               = VALUES(clv_12m),
    clv_36m               = VALUES(clv_36m),
    clv_segment           = 'Pending';

-- ─────────────────────────────────────────────
-- STEP 3: Assign CLV segment via NTILE(3)
--   Bottom third = Low | Middle = Medium | Top = High
-- ─────────────────────────────────────────────
UPDATE clv_scores cs
JOIN (
    SELECT
        customer_id,
        NTILE(3) OVER (ORDER BY clv_12m ASC) AS tile
    FROM clv_scores
) ranked ON cs.customer_id = ranked.customer_id
SET cs.clv_segment = CASE
    WHEN ranked.tile = 3 THEN 'High'
    WHEN ranked.tile = 2 THEN 'Medium'
    ELSE                      'Low'
END;

-- ─────────────────────────────────────────────
-- STEP 4: Validation
-- ─────────────────────────────────────────────

-- CLV by segment (expect ~1,445 per segment)
SELECT
    clv_segment,
    COUNT(*)                                  AS customers,
    ROUND(AVG(avg_order_value),        2)     AS avg_aov,
    ROUND(AVG(purchase_freq_monthly),  4)     AS avg_freq_monthly,
    ROUND(AVG(gross_margin_pct) * 100, 1)     AS avg_margin_pct,
    ROUND(AVG(clv_12m), 2)                    AS avg_clv_12m,
    ROUND(AVG(clv_36m), 2)                    AS avg_clv_36m,
    ROUND(SUM(clv_12m), 2)                    AS total_projected_12m
FROM clv_scores
GROUP BY clv_segment
ORDER BY avg_clv_12m DESC;

-- Overall summary
SELECT
    COUNT(*)               AS total_customers,
    ROUND(AVG(clv_12m), 2) AS overall_avg_clv_12m,
    ROUND(SUM(clv_12m), 2) AS total_projected_12m,
    ROUND(MIN(clv_12m), 2) AS min_clv_12m,
    ROUND(MAX(clv_12m), 2) AS max_clv_12m
FROM clv_scores;
