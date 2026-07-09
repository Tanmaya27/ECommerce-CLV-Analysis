-- ============================================================
-- Analytical Views for Power BI / Direct Query access
-- Author: [Your Name]
-- Source: UCI "Online Retail" dataset (real UK gift retailer)
-- Description:
--   Pre-built views that Power BI (or any BI tool) can connect
--   to directly via MySQL ODBC / MySQL connector.
--   Run AFTER all notebooks have loaded all tables.
-- ============================================================

USE ecommerce_clv;

-- ─────────────────────────────────────────────
-- VIEW 1: vw_customer_master
--   Full customer profile: RFM + CLV joined.
--   Note: no demographic columns (name, email, age, gender,
--   acquisition channel) — not present in source data.
-- ─────────────────────────────────────────────
CREATE OR REPLACE VIEW vw_customer_master AS
SELECT
    c.customer_id,
    c.country,
    c.first_purchase_date,
    c.last_purchase_date,
    r.rfm_segment,
    r.r_score,
    r.f_score,
    r.m_score,
    r.rfm_score,
    r.recency_days,
    r.frequency                                  AS total_orders,
    ROUND(r.monetary, 2)                         AS historical_revenue,
    clv.clv_segment,
    ROUND(clv.avg_order_value, 2)                AS avg_order_value,
    ROUND(clv.purchase_freq_monthly, 4)          AS monthly_purchase_freq,
    ROUND(clv.gross_margin_pct * 100, 1)         AS gross_margin_pct,
    ROUND(clv.churn_rate, 4)                     AS churn_rate,
    ROUND(clv.clv_12m, 2)                        AS clv_12m,
    ROUND(clv.clv_36m, 2)                        AS clv_36m
FROM customers c
JOIN rfm_scores r   ON c.customer_id = r.customer_id
JOIN clv_scores clv ON c.customer_id = clv.customer_id;

-- ─────────────────────────────────────────────
-- VIEW 2: vw_order_details
--   Transaction-level fact table with all dimension joins.
--   Includes margin-adjusted net_line and per-line profit.
-- ─────────────────────────────────────────────
CREATE OR REPLACE VIEW vw_order_details AS
SELECT
    o.invoice_no                                          AS order_id,
    DATE(o.invoice_date)                                  AS order_date,
    DATE_FORMAT(o.invoice_date, '%Y-%m')                  AS year_month,
    YEAR(o.invoice_date)                                  AS order_year,
    MONTH(o.invoice_date)                                 AS order_month,
    DAYOFWEEK(o.invoice_date)                             AS day_of_week,
    o.customer_id,
    o.country,
    r.rfm_segment,
    clv.clv_segment,
    oi.stock_code,
    p.description                                         AS product_name,
    p.category,
    oi.quantity,
    oi.unit_price,
    ROUND(oi.line_total, 2)                               AS line_total,
    ROUND(oi.line_total * cma.gross_margin_pct, 2)        AS line_profit,
    o.order_status
FROM orders o
JOIN order_items oi  ON o.invoice_no  = oi.invoice_no
JOIN products    p   ON oi.stock_code = p.stock_code
JOIN category_margin_assumptions cma ON p.category = cma.category
LEFT JOIN rfm_scores r   ON o.customer_id = r.customer_id
LEFT JOIN clv_scores clv ON o.customer_id = clv.customer_id;

-- ─────────────────────────────────────────────
-- VIEW 3: vw_monthly_kpi
--   Monthly KPIs — gross revenue and margin-adjusted profit
-- ─────────────────────────────────────────────
CREATE OR REPLACE VIEW vw_monthly_kpi AS
SELECT
    DATE_FORMAT(o.invoice_date, '%Y-%m')          AS year_month,
    COUNT(DISTINCT o.invoice_no)                  AS total_orders,
    COUNT(DISTINCT o.customer_id)                 AS unique_customers,
    ROUND(SUM(oi.line_total), 2)                  AS gross_revenue,
    ROUND(SUM(oi.line_total * cma.gross_margin_pct), 2) AS net_revenue,
    ROUND(SUM(oi.line_total) / COUNT(DISTINCT o.invoice_no), 2) AS avg_order_value,
    ROUND(SUM(oi.line_total * cma.gross_margin_pct), 2)         AS total_profit
FROM orders o
JOIN order_items oi ON o.invoice_no  = oi.invoice_no
JOIN products    p  ON oi.stock_code = p.stock_code
JOIN category_margin_assumptions cma ON p.category = cma.category
WHERE o.order_status = 'Completed'
GROUP BY year_month
ORDER BY year_month;

-- ─────────────────────────────────────────────
-- VIEW 4: vw_segment_kpi
--   Aggregated KPIs per RFM segment — Power BI summary cards
-- ─────────────────────────────────────────────
CREATE OR REPLACE VIEW vw_segment_kpi AS
SELECT
    rfm_segment,
    clv_segment,
    COUNT(DISTINCT customer_id)                    AS customer_count,
    ROUND(AVG(recency_days), 0)                    AS avg_recency_days,
    ROUND(AVG(total_orders), 1)                    AS avg_orders,
    ROUND(AVG(historical_revenue), 2)              AS avg_revenue,
    ROUND(AVG(avg_order_value), 2)                 AS avg_aov,
    ROUND(AVG(clv_12m), 2)                         AS avg_clv_12m,
    ROUND(SUM(clv_12m), 2)                         AS total_projected_clv_12m,
    ROUND(AVG(gross_margin_pct), 1)                AS avg_margin_pct
FROM vw_customer_master
GROUP BY rfm_segment, clv_segment
ORDER BY avg_clv_12m DESC;

-- ─────────────────────────────────────────────
-- VERIFY all views
-- ─────────────────────────────────────────────
SHOW FULL TABLES IN ecommerce_clv WHERE TABLE_TYPE = 'VIEW';

SELECT COUNT(*) AS row_count FROM vw_customer_master;    -- expect 4,334
SELECT COUNT(*) AS row_count FROM vw_order_details;       -- expect ~396,337
SELECT COUNT(*) AS row_count FROM vw_monthly_kpi;         -- expect 13 months
SELECT COUNT(*) AS row_count FROM vw_segment_kpi;
