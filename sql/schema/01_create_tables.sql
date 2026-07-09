-- ============================================================
-- Schema: ecommerce_clv
-- Source: UCI "Online Retail" dataset (real UK gift retailer,
--         Dec 2010 – Dec 2011, 541,909 raw transaction rows)
-- Author: [Your Name]
-- ============================================================

DROP DATABASE IF EXISTS ecommerce_clv;
CREATE DATABASE ecommerce_clv
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE ecommerce_clv;

-- ─────────────────────────────────────────────────────────────
-- RAW STAGING TABLE
-- Loaded by notebook 01 directly from data/raw/online_retail.csv
-- Full raw dump — cleaning happens in notebook 02.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE raw_transactions (
    id           BIGINT        AUTO_INCREMENT PRIMARY KEY,
    InvoiceNo    VARCHAR(20)   NOT NULL,
    StockCode    VARCHAR(20)   NOT NULL,
    Description  TEXT,
    Quantity     INT           NOT NULL,
    InvoiceDate  DATETIME      NOT NULL,
    UnitPrice    DECIMAL(10,4) NOT NULL,
    CustomerID   VARCHAR(10),
    Country      VARCHAR(60)   NOT NULL
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
-- CATEGORY MARGIN ASSUMPTIONS
-- Finance-provided blended gross margin % per product category.
-- True per-unit cost is not in the source transactional system;
-- this reference table mirrors standard BI practice of using
-- Finance-approved blended margin rates for profitability calc.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE category_margin_assumptions (
    category         VARCHAR(60)  NOT NULL PRIMARY KEY,
    gross_margin_pct DECIMAL(5,4) NOT NULL,
    notes            VARCHAR(200)
) ENGINE=InnoDB;

INSERT INTO category_margin_assumptions (category, gross_margin_pct, notes) VALUES
('Christmas & Seasonal',  0.6000, 'Higher seasonal premium'),
('Bags & Accessories',    0.5500, 'Fashion accessories blended rate'),
('Kitchen & Dining',      0.5000, 'Standard homeware rate'),
('Home Decor',            0.5500, 'Decorative items blended rate'),
('Stationery & Gifts',    0.5200, 'Gift/paper products rate'),
('Toys & Games',          0.4800, 'Competitive category, lower margin'),
('Garden & Outdoor',      0.4500, 'Volume-driven, lower margin'),
('Bath & Body',           0.5000, 'Standard health/beauty rate'),
('Other / Miscellaneous', 0.4800, 'Conservative blended default');

-- ─────────────────────────────────────────────────────────────
-- CUSTOMERS
-- One row per unique CustomerID from the source data.
-- No demographic data (name, email, age, gender, acquisition
-- channel) exists in this transactional dataset — those fields
-- are intentionally absent, not fabricated.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE customers (
    customer_id         VARCHAR(10)  NOT NULL,
    country             VARCHAR(60)  NOT NULL,
    first_purchase_date DATE         NOT NULL,
    last_purchase_date  DATE         NOT NULL,
    is_active           TINYINT(1)   NOT NULL DEFAULT 1,
    created_at          TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (customer_id)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
-- PRODUCTS
-- One row per unique StockCode (merchandise only).
-- Description is the most-frequent value observed for that code.
-- Category is derived via keyword rules in notebook 02.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE products (
    stock_code      VARCHAR(20)   NOT NULL,
    description     VARCHAR(255)  NOT NULL,
    category        VARCHAR(60)   NOT NULL,
    avg_unit_price  DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (stock_code),
    CONSTRAINT fk_prod_category
        FOREIGN KEY (category) REFERENCES category_margin_assumptions(category)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
-- ORDERS  (invoice-level)
-- One row per unique InvoiceNo — completed orders only.
-- Invoices prefixed with 'C' are cancellations; excluded here.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE orders (
    invoice_no    VARCHAR(20)  NOT NULL,
    customer_id   VARCHAR(10)  NOT NULL,
    invoice_date  DATETIME     NOT NULL,
    country       VARCHAR(60)  NOT NULL,
    order_status  VARCHAR(20)  NOT NULL DEFAULT 'Completed',
    PRIMARY KEY (invoice_no),
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
) ENGINE=InnoDB;

CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_date     ON orders(invoice_date);

-- ─────────────────────────────────────────────────────────────
-- ORDER ITEMS  (transaction line-item grain)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE order_items (
    item_id      BIGINT         AUTO_INCREMENT PRIMARY KEY,
    invoice_no   VARCHAR(20)    NOT NULL,
    stock_code   VARCHAR(20)    NOT NULL,
    quantity     SMALLINT       NOT NULL,
    unit_price   DECIMAL(10,2)  NOT NULL,
    line_total   DECIMAL(14,2)  GENERATED ALWAYS AS
                     (quantity * unit_price) STORED,
    CONSTRAINT fk_items_invoice
        FOREIGN KEY (invoice_no) REFERENCES orders(invoice_no),
    CONSTRAINT fk_items_product
        FOREIGN KEY (stock_code) REFERENCES products(stock_code)
) ENGINE=InnoDB;

CREATE INDEX idx_items_invoice ON order_items(invoice_no);
CREATE INDEX idx_items_product ON order_items(stock_code);

-- ─────────────────────────────────────────────────────────────
-- RFM SCORES
-- Populated by notebook 04 / sql/queries/02_rfm_calculation.sql
-- NTILE-style 1-5 scores; 10 named segments.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE rfm_scores (
    customer_id   VARCHAR(10)    NOT NULL,
    recency_days  INT            NOT NULL,
    frequency     INT            NOT NULL,
    monetary      DECIMAL(14,2)  NOT NULL,
    r_score       TINYINT        NOT NULL,
    f_score       TINYINT        NOT NULL,
    m_score       TINYINT        NOT NULL,
    rfm_score     TINYINT        NOT NULL,
    rfm_segment   VARCHAR(30)    NOT NULL,
    updated_at    TIMESTAMP      DEFAULT CURRENT_TIMESTAMP
                                 ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (customer_id),
    CONSTRAINT fk_rfm_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
-- CLV SCORES
-- Populated by notebook 04 / sql/queries/03_clv_calculation.sql
-- Formula: CLV_12m = AOV × (purchase_freq_monthly × 12) × gross_margin_pct
-- gross_margin_pct = per-customer blended rate, weighted by the
-- customer's actual category purchase mix, sourced from
-- category_margin_assumptions.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE clv_scores (
    customer_id           VARCHAR(10)    NOT NULL,
    avg_order_value       DECIMAL(14,2)  NOT NULL,
    purchase_freq_monthly DECIMAL(8,4)   NOT NULL,
    churn_rate            DECIMAL(5,4)   NOT NULL,
    gross_margin_pct      DECIMAL(5,4)   NOT NULL,
    clv_12m               DECIMAL(14,2)  NOT NULL,
    clv_36m               DECIMAL(14,2)  NOT NULL,
    clv_segment           VARCHAR(10)    NOT NULL,
    updated_at            TIMESTAMP      DEFAULT CURRENT_TIMESTAMP
                                         ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (customer_id),
    CONSTRAINT fk_clv_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
) ENGINE=InnoDB;
