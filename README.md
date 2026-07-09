# E-Commerce Customer Segmentation & CLV Analysis

> **Resume Project** — End-to-end data pipeline: MySQL extraction → Python cleaning → RFM Segmentation → Customer Lifetime Value → Power BI dashboard

## 📌 Project Summary

Engineered a data pipeline using SQL for extraction and Python for cleaning 10,000+ transaction records spanning 12 months of e-commerce activity. Developed a Power BI dashboard to visualize Customer Lifetime Value (CLV) across segments, identifying targeted campaigns projected to reduce acquisition costs by **12%**.

---

## 🗂 Project Structure

```
ecommerce_clv_analysis/
│
├── sql/
│   ├── schema/
│   │   └── 01_create_tables.sql          # Database & table definitions
│   ├── queries/
│   │   ├── 02_rfm_calculation.sql        # RFM score calculation
│   │   ├── 03_clv_calculation.sql        # CLV formula queries
│   │   └── 04_segment_summary.sql        # Segment-level aggregations
│   └── views/
│       └── 05_analytical_views.sql       # Reusable views for Power BI
│
├── notebooks/
│   ├── 01_data_generation.ipynb          # Synthetic dataset generation
│   ├── 02_data_cleaning.ipynb            # Cleaning & validation
│   ├── 03_eda_analysis.ipynb             # Exploratory data analysis
│   ├── 04_clv_segmentation.ipynb         # CLV model & segmentation
│   └── 05_campaign_roi.ipynb             # Campaign impact simulation
│
├── powerbi/
│   ├── dax_measures.md                   # All DAX formulas
│   ├── power_query_transformations.md    # Power Query M code
│   └── dashboard_setup_guide.md         # Step-by-step build guide
│
├── data/
│   ├── raw/                              # Raw CSV exports from MySQL
│   └── processed/                       # Cleaned, analysis-ready CSVs
│
├── exports/                             # Final CSVs for Power BI import
├── docs/                                # Additional documentation
├── requirements.txt
└── .gitignore
```

---

## 🛠 Tech Stack

| Layer        | Tool                |
|-------------|---------------------|
| Database     | MySQL 8.0+          |
| ETL/Analysis | Python 3.10+        |
| Notebooks    | Jupyter Notebook    |
| Visualization| Power BI Desktop    |
| Version Ctrl | Git / GitHub        |

---

## 🚀 Quick Start

### 1. Clone & Setup Python
```bash
git clone https://github.com/YOUR_USERNAME/ecommerce_clv_analysis.git
cd ecommerce_clv_analysis
pip install -r requirements.txt
```

### 2. Set Up MySQL Database
```bash
# Connect to MySQL
mysql -u root -p

# Run schema + seed data
source sql/schema/01_create_tables.sql
```

### 3. Run Jupyter Notebooks (in order)
```bash
jupyter notebook
# Run: 01 → 02 → 03 → 04 → 05
```

### 4. Connect Power BI
- Open `powerbi/dashboard_setup_guide.md`
- Import CSVs from `exports/`
- Apply DAX measures from `powerbi/dax_measures.md`

---

## 📊 Key Findings

| Segment     | # Customers | Avg CLV  | Recommended Campaign         |
|------------|-------------|----------|------------------------------|
| Champions  | ~850        | $1,240   | VIP rewards, early access    |
| Loyal      | ~1,500      | $680     | Loyalty points, upsell       |
| At Risk    | ~1,200      | $420     | Win-back offers              |
| Lost       | ~800        | $90      | Re-engagement email          |

**Projected acquisition cost reduction: 12%** by targeting high-CLV segments

---

## 📁 Data

- **~10,500 transaction records** generated synthetically
- **12-month window** (2024-01-01 to 2024-12-31)
- **~3,500 unique customers**
- **6 product categories**

---

## 👤 Author
**[Your Name]** | Data Analyst  
[LinkedIn](#) | [GitHub](#)
