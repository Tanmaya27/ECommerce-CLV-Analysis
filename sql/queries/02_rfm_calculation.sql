-- ============================================================
-- RFM Score Calculation
-- Author: [Your Name]
-- Source: UCI "Online Retail" dataset (real UK gift retailer)
-- Description:
--   Calculates Recency, Frequency, Monetary values per customer,
--   assigns 1-5 scores using NTILE window functions, labels
--   10 named behavioral segments. Only completed orders included.
-- Expected result: 4,334 customers across 10 segments
-- ============================================================

USE ecommerce_clv;

-- ─────────────────────────────────────────────
-- STEP 1: Reference date = day after last invoice
-- ─────────────────────────────────────────────
SET @snapshot_date = (
    SELECT DATE_ADD(DATE(MAX(invoice_date)), INTERVAL 1 DAY)
    FROM orders
    WHERE order_status = 'Completed'
);

SELECT @snapshot_date AS snapshot_date;   -- verify: expect 2011-12-10

-- ─────────────────────────────────────────────
-- STEP 2: Raw RFM metrics per customer
-- ─────────────────────────────────────────────
WITH rfm_base AS (
    SELECT
        o.customer_id,
        DATEDIFF(@snapshot_date, DATE(MAX(o.invoice_date)))  AS recency_days,
        COUNT(DISTINCT o.invoice_no)                         AS frequency,
        ROUND(SUM(oi.line_total), 2)                         AS monetary
    FROM orders o
    JOIN order_items oi ON o.invoice_no = oi.invoice_no
    WHERE o.order_status = 'Completed'
    GROUP BY o.customer_id
),

-- ─────────────────────────────────────────────
-- STEP 3: Assign 1-5 scores using NTILE(5)
--   Recency:  fewer days = better = score 5 (inverted)
--   Frequency: more orders = score 5
--   Monetary:  higher spend = score 5
-- ─────────────────────────────────────────────
rfm_scored AS (
    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary,
        (6 - NTILE(5) OVER (ORDER BY recency_days ASC))  AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)            AS f_score,
        NTILE(5) OVER (ORDER BY monetary  ASC)            AS m_score
    FROM rfm_base
),

-- ─────────────────────────────────────────────
-- STEP 4: Combine scores + assign segment label
-- ─────────────────────────────────────────────
rfm_segmented AS (
    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary,
        r_score,
        f_score,
        m_score,
        (r_score + f_score + m_score)           AS rfm_score,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4
                THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 4 AND m_score >= 3
                THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score <= 2 AND m_score <= 2
                THEN 'New Customers'
            WHEN r_score >= 3 AND f_score >= 2 AND m_score >= 3
                THEN 'Potential Loyalists'
            WHEN r_score >= 3 AND f_score >= 3
                THEN 'Promising'
            WHEN r_score = 2 AND f_score >= 2 AND m_score >= 2
                THEN 'Need Attention'
            WHEN r_score = 2 AND (f_score <= 2 OR m_score <= 2)
                THEN 'At Risk'
            WHEN r_score = 1 AND f_score >= 3 AND m_score >= 3
                THEN 'Cannot Lose Them'
            WHEN r_score = 1
                THEN 'Lost'
            ELSE 'Hibernating'
        END                                     AS rfm_segment
    FROM rfm_scored
)

-- ─────────────────────────────────────────────
-- STEP 5: INSERT / UPDATE rfm_scores table
-- MySQL does not support WITH ... INSERT; the CTE above is used
-- for the SELECT that feeds this INSERT directly.
-- ─────────────────────────────────────────────
INSERT INTO rfm_scores (
    customer_id, recency_days, frequency, monetary,
    r_score, f_score, m_score, rfm_score, rfm_segment
)
SELECT
    customer_id, recency_days, frequency, monetary,
    r_score, f_score, m_score, rfm_score, rfm_segment
FROM rfm_segmented
ON DUPLICATE KEY UPDATE
    recency_days = VALUES(recency_days),
    frequency    = VALUES(frequency),
    monetary     = VALUES(monetary),
    r_score      = VALUES(r_score),
    f_score      = VALUES(f_score),
    m_score      = VALUES(m_score),
    rfm_score    = VALUES(rfm_score),
    rfm_segment  = VALUES(rfm_segment);

-- ─────────────────────────────────────────────
-- STEP 6: Validation
-- ─────────────────────────────────────────────

-- Segment summary (expect ~4,334 total customers)
SELECT
    rfm_segment,
    COUNT(*)                     AS customer_count,
    ROUND(AVG(recency_days), 1)  AS avg_recency_days,
    ROUND(AVG(frequency), 1)     AS avg_frequency,
    ROUND(AVG(monetary),   2)    AS avg_monetary,
    ROUND(SUM(monetary),   2)    AS total_revenue
FROM rfm_scores
GROUP BY rfm_segment
ORDER BY total_revenue DESC;

-- Score distribution (should be ~866 per quintile)
SELECT r_score, COUNT(*) AS cnt FROM rfm_scores GROUP BY r_score ORDER BY r_score;
SELECT f_score, COUNT(*) AS cnt FROM rfm_scores GROUP BY f_score ORDER BY f_score;
SELECT m_score, COUNT(*) AS cnt FROM rfm_scores GROUP BY m_score ORDER BY m_score;
