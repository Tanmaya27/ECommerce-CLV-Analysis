-- ============================================================
-- Segment Summary & Business Intelligence Queries
-- Author: [Your Name]
-- Source: UCI "Online Retail" dataset (real UK gift retailer)
-- Description:
--   Business-level aggregations used for Power BI reports.
--   Run AFTER notebooks 01-04 have populated all tables.
-- ============================================================

USE ecommerce_clv;

-- ─────────────────────────────────────────────
-- QUERY 1: Combined RFM + CLV Segment Summary
-- ─────────────────────────────────────────────
SELECT
    r.rfm_segment,
    c.clv_segment,
    COUNT(DISTINCT r.customer_id)           AS customer_count,
    ROUND(AVG(r.recency_days), 1)           AS avg_recency_days,
    ROUND(AVG(r.frequency), 1)              AS avg_orders,
    ROUND(AVG(r.monetary), 2)              AS avg_historical_revenue,
    ROUND(AVG(c.avg_order_value), 2)        AS avg_order_value,
    ROUND(AVG(c.clv_12m), 2)               AS avg_clv_12m,
    ROUND(AVG(c.clv_36m), 2)               AS avg_clv_36m,
    ROUND(SUM(c.clv_12m), 2)               AS total_projected_12m,
    ROUND(AVG(c.gross_margin_pct) * 100, 1) AS avg_margin_pct
FROM rfm_scores r
JOIN clv_scores c ON r.customer_id = c.customer_id
GROUP BY r.rfm_segment, c.clv_segment
ORDER BY avg_clv_12m DESC;

-- ─────────────────────────────────────────────
-- QUERY 2: Monthly Revenue Trend
--   → MySQL-side verification (cross-check against exports/monthly_revenue.csv)
--   NOTE: monthly_revenue.csv is written by notebook 03 using margin-adjusted
--   net_revenue. This query shows gross line_total; use notebook CSV for Power BI.
-- ─────────────────────────────────────────────
SELECT
    DATE_FORMAT(o.invoice_date, '%Y-%m')          AS year_month,
    COUNT(DISTINCT o.invoice_no)                  AS order_count,
    COUNT(DISTINCT o.customer_id)                 AS unique_customers,
    ROUND(SUM(oi.line_total), 2)                  AS gross_revenue,
    ROUND(AVG(oi.unit_price), 2)                  AS avg_unit_price,
    ROUND(SUM(oi.line_total) / COUNT(DISTINCT o.invoice_no), 2) AS avg_order_value,
    ROUND(
        (SUM(oi.line_total)
         - LAG(SUM(oi.line_total)) OVER (ORDER BY DATE_FORMAT(o.invoice_date, '%Y-%m')))
        / NULLIF(
            LAG(SUM(oi.line_total)) OVER (ORDER BY DATE_FORMAT(o.invoice_date, '%Y-%m')), 0
          ) * 100
    , 2)                                          AS mom_growth_pct
FROM orders o
JOIN order_items oi ON o.invoice_no = oi.invoice_no
WHERE o.order_status = 'Completed'
GROUP BY year_month
ORDER BY year_month;

-- ─────────────────────────────────────────────
-- QUERY 3: Revenue by Product Category
--   Includes margin-adjusted net_revenue using Finance-provided blended rates.
-- ─────────────────────────────────────────────
SELECT
    p.category,
    cma.gross_margin_pct                            AS blended_margin_pct,
    COUNT(DISTINCT o.invoice_no)                    AS order_count,
    SUM(oi.quantity)                                AS units_sold,
    ROUND(SUM(oi.line_total), 2)                   AS gross_revenue,
    ROUND(SUM(oi.line_total) * cma.gross_margin_pct, 2) AS net_revenue,
    ROUND(AVG(oi.unit_price), 2)                   AS avg_unit_price
FROM order_items oi
JOIN orders  o   ON oi.invoice_no  = o.invoice_no
JOIN products p  ON oi.stock_code  = p.stock_code
JOIN category_margin_assumptions cma ON p.category = cma.category
WHERE o.order_status = 'Completed'
GROUP BY p.category, cma.gross_margin_pct
ORDER BY gross_revenue DESC;

-- ─────────────────────────────────────────────
-- QUERY 4: Revenue by Country (replaces channel acquisition)
--   Top 10 countries by customer count and gross revenue.
-- ─────────────────────────────────────────────
SELECT
    c.country,
    COUNT(DISTINCT c.customer_id)                  AS total_customers,
    ROUND(
        COUNT(DISTINCT c.customer_id)
        / (SELECT COUNT(*) FROM customers) * 100, 1
    )                                              AS customer_pct,
    ROUND(SUM(oi.line_total), 2)                   AS gross_revenue,
    ROUND(AVG(clv.clv_12m), 2)                    AS avg_clv_12m,
    ROUND(SUM(clv.clv_12m), 2)                    AS total_clv_12m
FROM customers c
LEFT JOIN orders      o   ON c.customer_id = o.customer_id
                          AND o.order_status = 'Completed'
LEFT JOIN order_items oi  ON o.invoice_no  = oi.invoice_no
LEFT JOIN clv_scores  clv ON c.customer_id = clv.customer_id
GROUP BY c.country
ORDER BY gross_revenue DESC
LIMIT 15;

-- ─────────────────────────────────────────────
-- QUERY 5: Cohort Retention Analysis
-- ─────────────────────────────────────────────
WITH customer_cohort AS (
    SELECT
        customer_id,
        DATE_FORMAT(MIN(invoice_date), '%Y-%m') AS cohort_month
    FROM orders
    WHERE order_status = 'Completed'
    GROUP BY customer_id
),
cohort_orders AS (
    SELECT
        cc.cohort_month,
        DATE_FORMAT(o.invoice_date, '%Y-%m') AS order_month,
        COUNT(DISTINCT o.customer_id)         AS active_customers
    FROM orders o
    JOIN customer_cohort cc ON o.customer_id = cc.customer_id
    WHERE o.order_status = 'Completed'
    GROUP BY cc.cohort_month, order_month
),
cohort_size AS (
    SELECT cohort_month, MAX(active_customers) AS cohort_size
    FROM cohort_orders
    GROUP BY cohort_month
)
SELECT
    co.cohort_month,
    co.order_month,
    co.active_customers,
    cs.cohort_size,
    ROUND(co.active_customers / cs.cohort_size * 100, 1) AS retention_rate_pct,
    TIMESTAMPDIFF(
        MONTH,
        STR_TO_DATE(CONCAT(co.cohort_month, '-01'), '%Y-%m-%d'),
        STR_TO_DATE(CONCAT(co.order_month,  '-01'), '%Y-%m-%d')
    ) AS month_number
FROM cohort_orders co
JOIN cohort_size   cs ON co.cohort_month = cs.cohort_month
ORDER BY co.cohort_month, month_number;

-- ─────────────────────────────────────────────
-- QUERY 6: Top 20 Customers by CLV
-- ─────────────────────────────────────────────
SELECT
    c.customer_id,
    c.country,
    r.rfm_segment,
    clv.clv_segment,
    r.frequency                             AS total_orders,
    ROUND(r.monetary, 2)                   AS total_revenue,
    ROUND(clv.avg_order_value, 2)          AS avg_order_value,
    ROUND(clv.clv_12m, 2)                  AS projected_clv_12m,
    ROUND(clv.clv_36m, 2)                  AS projected_clv_36m
FROM customers c
JOIN rfm_scores r   ON c.customer_id = r.customer_id
JOIN clv_scores clv ON c.customer_id = clv.customer_id
ORDER BY clv.clv_12m DESC
LIMIT 20;

-- ─────────────────────────────────────────────
-- QUERY 7: Campaign Targeting Preview
--   NOTE: This is a MySQL-side preview only.
--   Full campaign cost/ROI simulation is in notebook 05;
--   use exports/campaign_targets.csv for Power BI Page 4.
-- ─────────────────────────────────────────────
SELECT
    c.customer_id,
    c.country,
    r.rfm_segment,
    clv.clv_segment,
    ROUND(clv.clv_12m, 2)                   AS projected_clv_12m,
    CASE
        WHEN r.rfm_segment = 'Champions'
            THEN 'VIP Early Access'
        WHEN r.rfm_segment = 'Loyal Customers'
            THEN 'Loyalty Rewards Upsell'
        WHEN r.rfm_segment = 'Potential Loyalists'
            THEN 'Membership Offer'
        WHEN r.rfm_segment = 'At Risk'
            THEN 'Win-Back Discount'
        WHEN r.rfm_segment IN ('Cannot Lose Them', 'Need Attention')
            THEN 'Personalized Re-Engagement'
        WHEN r.rfm_segment = 'Lost'
            THEN 'Re-Activation Email'
        WHEN r.rfm_segment = 'New Customers'
            THEN 'Onboarding Series'
        WHEN r.rfm_segment = 'Promising'
            THEN 'Cross-Sell Campaign'
        WHEN r.rfm_segment = 'Hibernating'
            THEN 'General Newsletter'
        ELSE 'General Newsletter'
    END                                     AS recommended_campaign,
    CASE
        WHEN clv.clv_segment = 'High'   THEN 1
        WHEN clv.clv_segment = 'Medium' THEN 2
        ELSE 3
    END                                     AS priority_tier
FROM customers c
JOIN rfm_scores r   ON c.customer_id = r.customer_id
JOIN clv_scores clv ON c.customer_id = clv.customer_id
ORDER BY priority_tier, clv.clv_12m DESC;
