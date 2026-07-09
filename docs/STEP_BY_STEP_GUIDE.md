# Complete Step-by-Step Execution Guide
## E-Commerce Customer Segmentation & CLV Analysis
### Based on Real UCI "Online Retail" Dataset (UK Gift Retailer, Dec 2010 – Dec 2011)

---

## ✅ PRE-REQUISITES

| Tool | Download | Version |
|------|---------|---------|
| MySQL 8.0+ | https://dev.mysql.com/downloads/ | 8.0+ |
| Python 3.10+ | https://python.org/downloads/ | 3.10+ |
| Jupyter Notebook | `pip install jupyter` | Latest |
| Power BI Desktop | Microsoft Store (free) | Latest |
| Git | https://git-scm.com/downloads | Latest |

---

## PHASE 1: PROJECT SETUP

### 1.1 Clone / Download the project
```bash
git clone https://github.com/YOUR_USERNAME/ecommerce_clv_analysis.git
cd ecommerce_clv_analysis
```

### 1.2 Create Python virtual environment
```bash
python -m venv venv
# Mac/Linux:
source venv/bin/activate
# Windows:
venv\Scripts\activate

pip install -r requirements.txt
```

### 1.3 Verify raw data is present
```bash
ls data/raw/
# Should show: online_retail.csv  (46MB — 541,909 real transactions)
```

### 1.4 Verify Python packages
```bash
python -c "import pandas, sqlalchemy, pymysql, matplotlib, seaborn; print('All packages OK')"
```

---

## PHASE 2: MySQL SETUP

### 2.1 Start MySQL server
```bash
# Mac (Homebrew):
brew services start mysql

# Windows: Open MySQL Workbench or start from Services

# Connect to verify:
mysql -u root -p
```

### 2.2 Run the schema file
```bash
# In MySQL terminal (after connecting):
source /full/path/to/sql/schema/01_create_tables.sql

# OR in MySQL Workbench:
# File → Open SQL Script → select 01_create_tables.sql → Execute
```

### 2.3 Verify schema created
```sql
USE ecommerce_clv;
SHOW TABLES;
-- Expected tables:
--   raw_transactions
--   category_margin_assumptions  (pre-populated with 9 rows)
--   customers
--   products
--   orders
--   order_items
--   rfm_scores
--   clv_scores
```

---

## PHASE 3: RUN JUPYTER NOTEBOOKS

### 3.1 Start Jupyter
```bash
# From project root:
jupyter notebook
# Opens in browser at http://localhost:8888
```

### 3.2 Update Database Credentials
**Before running ANY notebook**, update in each notebook:
```python
DB_USER     = 'root'          # your MySQL username
DB_PASSWORD = 'your_password' # ← YOUR ACTUAL PASSWORD HERE
DB_HOST     = 'localhost'
DB_PORT     = 3306
DB_NAME     = 'ecommerce_clv'
```

### 3.3 Run notebooks IN ORDER

#### Notebook 01: Data Ingestion (~3-5 min)
- `notebooks/01_data_generation.ipynb`
- Loads `data/raw/online_retail.csv` into MySQL `raw_transactions` table
- ✅ Expected: "Raw transactions loaded: 541,909 rows ✓"
- ✅ Expected: "Unique customers: 4,372 | Unique invoices: 25,900"

#### Notebook 02: Data Cleaning (~2-3 min)
- `notebooks/02_data_cleaning.ipynb`
- Applies data quality filters, derives categories, builds normalized tables
- ✅ Expected:
  ```
  Data Quality Audit:
    Non-merchandise rows removed:   2,995
    Cancelled invoices removed:     8,704
    Guest checkouts excluded:     133,840
    Zero/negative price/qty:           33
    Clean rows for analysis:      396,337
  ```
- ✅ Expected: "Customers loaded: 4,334 | Products: 3,659 | Orders: 18,402 | Order items: 396,337 ✓"

#### Notebook 03: EDA (~2-3 min)
- `notebooks/03_eda_analysis.ipynb`
- Exploratory analysis, 5 charts, exports CSVs
- ✅ Expected: 5 chart PNG files + 5 CSVs saved to `exports/`
- ✅ Expected: Total net revenue ~£4.5M across 13 months

#### Notebook 04: CLV Segmentation (~3-5 min)
- `notebooks/04_clv_segmentation.ipynb`
- RFM scoring, CLV calculation, segment assignment
- ✅ Expected: "RFM: 4,334 customers scored | CLV: avg £1,018 | Champions=945, Lost=758"
- ✅ Expected: 5 chart PNG files + 3 CSVs saved to `exports/`
- ✅ Expected: MySQL tables `rfm_scores` and `clv_scores` populated

#### Notebook 05: Campaign ROI (~1 min)
- `notebooks/05_campaign_roi.ipynb`
- Campaign simulation, CAC comparison
- ✅ Expected: "CAC reduction (targeted vs blanket): **13.6%**"
- ✅ Expected: `campaign_roi.csv` + `campaign_targets.csv` saved

---

## PHASE 4: SQL ANALYSIS VERIFICATION

Run in MySQL Workbench or terminal to verify results:

```bash
# In MySQL Workbench: File → Open SQL Script
source sql/queries/02_rfm_calculation.sql      # Verify RFM scores
source sql/queries/03_clv_calculation.sql      # Verify CLV scores
source sql/queries/04_segment_summary.sql      # Business summary queries
source sql/views/05_analytical_views.sql       # Create Power BI views
```

### Quick Verification Queries
```sql
USE ecommerce_clv;

-- Check data quality
SELECT COUNT(*) FROM raw_transactions;    -- expect 541,909
SELECT COUNT(*) FROM customers;           -- expect 4,334
SELECT COUNT(*) FROM products;            -- expect 3,659
SELECT COUNT(*) FROM orders;              -- expect 18,402
SELECT COUNT(*) FROM order_items;         -- expect 396,337

-- Check RFM segments
SELECT rfm_segment, COUNT(*) cnt, ROUND(AVG(monetary),2) avg_rev
FROM rfm_scores
GROUP BY rfm_segment
ORDER BY avg_rev DESC;
-- Champions should have highest avg_rev (~£6,463)

-- Check CLV
SELECT clv_segment, COUNT(*) cnt, ROUND(AVG(clv_12m),2) avg_clv
FROM clv_scores
GROUP BY clv_segment;
-- High: ~1,445 customers, avg ~£2,593

-- Verify category margin assumptions
SELECT * FROM category_margin_assumptions ORDER BY gross_margin_pct DESC;
-- Should show 9 rows (Christmas 0.60 → Garden 0.45)
```

---

## PHASE 5: POWER BI DASHBOARD

### 5.1 Verify exports folder has these files:
```
exports/
  ├── customer_clv_master.csv     ← 4,334 customers with CLV + RFM
  ├── order_items_enriched.csv    ← 396,337 transaction lines
  ├── monthly_revenue.csv         ← 13 months Dec2010–Dec2011
  ├── category_revenue.csv        ← 9 categories with net revenue
  ├── campaign_roi.csv            ← ROI by segment
  ├── campaign_targets.csv        ← Per-customer campaign assignment
  ├── country_acquisition.csv     ← 38 countries, customer counts
  └── top_products.csv            ← Top 20 products by net revenue
```

### 5.2 Open Power BI Desktop → Follow `powerbi/dashboard_setup_guide.md`
- 4 pages: Executive Summary, RFM Segmentation, CLV Deep Dive, Campaign Strategy
- Use `powerbi/power_query_transformations.md` for M-code
- Use `powerbi/dax_measures.md` for all calculated measures

### 5.3 Expected Dashboard Numbers (from real data)
| KPI | Value |
|-----|-------|
| Total Gross Revenue | £8,761,067 |
| Total Net Revenue (margin-adjusted) | £4,498,812 |
| Total Customers | 4,334 |
| Total Completed Invoices | 18,402 |
| Avg CLV 12-Month | £1,018 |
| Avg Order Value | £417 |
| Blended Gross Margin | 51.2% |
| Total Projected CLV 12M | £4,414,410 |
| Champions count | 945 |
| CAC Reduction (targeted vs blanket) | **13.6%** |

### 5.4 Save as `powerbi/ecommerce_clv_dashboard.pbix`

---

## PHASE 6: PUBLISH TO GITHUB

### 6.1 Initialize Git repo
```bash
cd ecommerce_clv_analysis
git init
git add .
git commit -m "Initial commit: E-Commerce CLV Analysis — real UCI Online Retail data"
```

> **Note:** `data/raw/online_retail.csv` (46MB) IS tracked by git (exception in .gitignore).
> All processed/export CSVs are gitignored — they regenerate when you run the notebooks.

### 6.2 Create GitHub repository
1. Go to github.com → New repository
2. Name: `ecommerce_clv_analysis`
3. Public ✓, NO README (already have one)

### 6.3 Push to GitHub
```bash
git remote add origin https://github.com/YOUR_USERNAME/ecommerce_clv_analysis.git
git branch -M main
git push -u origin main
```

> If git rejects the push due to file size, use Git LFS for the raw CSV:
> ```bash
> git lfs install
> git lfs track "data/raw/online_retail.csv"
> git add .gitattributes
> git commit -m "Add Git LFS tracking for raw data"
> git push
> ```

---

## TROUBLESHOOTING

### MySQL Connection Error
```python
# "Can't connect to MySQL server"
# Mac: brew services start mysql
# Win: Start MySQL in Services or MySQL Workbench

# "Access denied for user 'root'"
# ALTER USER 'root'@'localhost' IDENTIFIED BY 'new_password';
```

### Python Import Error
```bash
# ModuleNotFoundError: No module named 'pymysql'
pip install -r requirements.txt
```

### Power BI File Not Found
```
# Error: File path not found
# Fix: Transform Data → right-click query → Edit → change Source path
```

### Data doesn't match expected counts
```python
# Check if you're in the right DB
USE ecommerce_clv;
SHOW TABLES;
# If tables are empty, re-run notebooks 01 and 02
```

---

## EXPECTED FINAL OUTPUTS

| Output | Location |
|--------|----------|
| MySQL database with 8 tables | `ecommerce_clv` DB |
| 5 Jupyter notebooks | `notebooks/` |
| 8+ Python chart exports | `exports/*.png` |
| 8 CSV analysis files | `exports/*.csv` |
| 4-page Power BI dashboard | `powerbi/*.pbix` |
| Interactive HTML preview | `docs/dashboard_preview.html` |

---

## RESUME BULLET POINTS (Ready to copy-paste)

✅ **Designed an end-to-end data pipeline** on the real UCI "Online Retail" dataset (541,909 raw transactions), performing multi-step data quality filtering (cancellations, guest checkouts, non-merchandise items) to produce 396,337 clean records across 4,334 customers

✅ **Implemented RFM segmentation** (Recency, Frequency, Monetary) using SQL window functions (NTILE) and Python (qcut), categorizing 4,334 customers into 10 behavioral segments — identifying 945 Champions generating 63% of projected CLV

✅ **Projected Customer Lifetime Value (CLV)** using a multi-variable formula (AOV × purchase frequency × blended gross margin %) with Finance-standard per-category margin assumptions, producing 12-month (avg £1,018) and 36-month forecasts per customer

✅ **Built a 4-page Power BI dashboard** with DAX measures, Power Query M transformations, and country/category/segment slicers — visualizing £4.41M projected CLV and real Q4 seasonal revenue surge (Sep–Nov 2011)

✅ **Simulated targeted campaign strategy** across 10 RFM segments, projecting 13.6% cost reduction versus a generic blanket campaign and £763,927 in expected incremental revenue from CLV-based targeting

✅ **Derived product categories** from unstructured Description text using regex keyword rules on 3,659 unique stock codes, enabling category-level margin and revenue analysis (top: Home Decor £1.06M, Kitchen & Dining £696K)
