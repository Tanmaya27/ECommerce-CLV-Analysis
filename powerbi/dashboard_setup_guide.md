# Power BI Dashboard Setup Guide
## E-Commerce Customer Segmentation & CLV Analysis

> **Step-by-step instructions** to build the full 4-page dashboard from scratch.

---

## Prerequisites
- Power BI Desktop (free from Microsoft Store)
- All notebooks run (exports/ folder has 8+ CSV files)
- 15–20 minutes

---

## STEP 1: Connect to Data

### 1.1 Open Power BI Desktop → Get Data → Text/CSV

Import these files (from `exports/` folder):

| File | Table Name |
|------|-----------|
| `customer_clv_master.csv`   | `customer_clv_master` |
| `order_items_enriched.csv`  | `order_items_enriched` |
| `monthly_revenue.csv`       | `monthly_revenue` |
| `category_revenue.csv`      | `category_revenue` |
| `campaign_roi.csv`          | `campaign_roi` |
| `campaign_targets.csv`      | `campaign_targets` |
| `country_acquisition.csv`   | `country_acquisition` |
| `top_products.csv`          | `top_products` |

### 1.2 Apply Power Query Transformations
For each table, open **Transform Data** and apply the M code from `power_query_transformations.md`.

### 1.3 Create Date Table
New Query → Blank Query → paste the Date Dimension M code.  
Name it `Dates`. Mark as **Date Table** (Table Tools → Mark as date table → Date column).

---

## STEP 2: Build Data Model

Go to **Model View**.

### Relationships to create:

| From (Many) | To (One) | Cardinality |
|------------|---------|-------------|
| `order_items_enriched[customer_id]` | `customer_clv_master[customer_id]` | Many→One |
| `order_items_enriched[order_date]`  | `Dates[Date]`                       | Many→One |
| `customer_clv_master[first_purchase_date]` | `Dates[Date]`                | Many→One (inactive) |
| `campaign_targets[customer_id]`     | `customer_clv_master[customer_id]` | Many→One |

> Tip: Drag and drop fields in Model View to create relationships.

---

## STEP 3: Add DAX Measures

1. Right-click `customer_clv_master` → New Measure
2. Paste each measure from `dax_measures.md`
3. Or create a `_Measures` blank table and add all there (cleaner)

**Priority measures to add first:**
- `Total Net Revenue`
- `Total Orders`
- `Total Customers`
- `Avg CLV 12M`
- `Total Projected CLV 12M`
- `Avg Order Value`
- `Gross Margin %`
- `Champions Count`
- `CAC Reduction %`

---

## STEP 4: Build the Dashboard (4 Pages)

---

### PAGE 1: Executive Summary

**Page name:** `Executive Summary`  
**Theme colors:** Blue (#2563EB), Green (#16A34A), Red (#DC2626)

#### Layout:
```
┌──────────────────────────────────────────────────────────────┐
│  E-Commerce CLV Analysis  │  2024 Annual Performance        │
├────────────┬────────────┬────────────┬────────────┬──────────┤
│ Total Rev  │ Total Cust │ Avg CLV    │ Avg AOV    │ Margin % │
│ (Card)     │ (Card)     │ (Card)     │ (Card)     │ (Card)   │
├────────────────────────────────────┬─────────────────────────┤
│   Monthly Revenue Bar Chart        │  Revenue by Category    │
│   (Clustered Column)               │  (Donut Chart)          │
│   X: YearMonth  Y: Net Revenue     │  Legend: category       │
│                                    │  Values: net_revenue    │
├────────────────────────────────────┼─────────────────────────┤
│  Top 10 Products Table             │  Customers by Country   │
│  Cols: product_name, revenue, units│  (Bar Chart)            │
│                                    │  X: country Y: customers│
└────────────────────────────────────┴─────────────────────────┘
```

#### Visuals to add:
1. **5 KPI Cards** (top row)
   - Card → Field: `Total Net Revenue` (format: $#,##0)
   - Card → Field: `Total Customers`
   - Card → Field: `Avg CLV 12M`
   - Card → Field: `Avg Order Value`
   - Card → Field: `Gross Margin %`

2. **Clustered Column Chart** (Monthly Revenue)
   - X-axis: `Dates[YearMonth]`
   - Y-axis: `Total Net Revenue`
   - Add trend line: Analytics pane → Trend line

3. **Donut Chart** (Revenue by Category)
   - Legend: `category_revenue[category]`
   - Values: `category_revenue[net_revenue]`
   - Data labels: On, show percentage

4. **Table** (Top Products)
   - From `top_products`: `product_name`, `net_revenue`, `units_sold`
   - Sort by `net_revenue` descending
   - Conditional formatting on `net_revenue`

5. **Bar Chart** (Customers by Country)
   - Y-axis: `country_acquisition[country]`
   - X-axis: `country_acquisition[customer_count]`
   - Data labels: On, show `pct`
   - Filter to Top 10 countries (Visual filters → country, Top N = 10 by customer_count)
   - Note: UK dominates at 90.4% — consider a separate "International" chart for the 9.6% from 37 other countries

---

### PAGE 2: Customer Segmentation

**Page name:** `RFM Segmentation`

#### Layout:
```
┌─────────────────────────────────────────────────────────────────┐
│  Customer Segments     │  Champions │ At Risk │ Lost │ Loyal    │
│  (Slicer: rfm_segment) │  (Cards)                               │
├──────────────────────────┬──────────────────────────────────────┤
│  RFM Segment Treemap     │  Avg CLV by Segment (Bar)            │
│  Group: rfm_segment      │  Y: rfm_segment X: avg_clv_12m       │
│  Size: clv_12m           │                                      │
├──────────────────────────┼──────────────────────────────────────┤
│  Scatter Plot            │  Segment Detail Table                │
│  X: recency_days         │  rfm_segment | customers | avg_clv   │
│  Y: monetary             │  avg_recency | avg_frequency         │
│  Size: clv_12m           │                                      │
│  Color: rfm_segment      │                                      │
└──────────────────────────┴──────────────────────────────────────┘
```

#### Visuals to add:

1. **Segment Slicer** (left panel)
   - Field: `customer_clv_master[rfm_segment]`
   - Style: Dropdown or list

2. **4 KPI Cards** (top right)
   - `Champions Count`
   - `Loyal Customers Count`
   - `At Risk Count`
   - `Lost Count`

3. **Treemap**
   - Category: `rfm_segment`
   - Values: `Total Customers`
   - Tooltips: Add `Avg CLV 12M`

4. **Horizontal Bar Chart** (Avg CLV by Segment)
   - Y-axis: `rfm_segment`
   - X-axis: `Avg CLV 12M`
   - Sort: Descending by CLV
   - Data labels: On
   - Color each bar differently (Format → Data colors → FX → by segment_priority)

5. **Scatter Chart** (RFM scatter)
   - X: `recency_days` (average)
   - Y: `monetary` (average)
   - Size: `clv_12m` (sum)
   - Legend: `rfm_segment`
   - Add quadrant lines (Analytics pane → Constant lines, avg values)

6. **Matrix Table** (Segment Summary)
   - Rows: `rfm_segment`
   - Values: Count of customers, Avg CLV_12m, Avg recency, Avg frequency, Total CLV_12m
   - Conditional formatting on CLV column (gradient: green=high, red=low)

---

### PAGE 3: CLV Analysis

**Page name:** `CLV Deep Dive`

#### Layout:
```
┌─────────────────────────────────────────────────────────────────┐
│  Total Projected 12M │ High CLV % │ Avg CLV High │ CLV Segment │
│  (Card)              │ (Card)     │ (Card)       │ (Slicer)    │
├──────────────────────┬──────────────────────────────────────────┤
│  CLV Distribution    │  CLV by Country (Top 10)                 │
│  (Histogram/Column)  │  (Clustered Bar)                         │
│  X: clv bucket       │  Y: country  X: avg_clv_12m             │
│  Y: customer count   │                                          │
├──────────────────────┼──────────────────────────────────────────┤
│  CLV vs. Frequency   │  CLV Segment Pie                         │
│  Scatter             │  High / Medium / Low split               │
│  X: frequency        │  Size: clv_12m sum                       │
│  Y: clv_12m          │                                          │
│  Color: clv_segment  │                                          │
└──────────────────────┴──────────────────────────────────────────┘
```

#### Key Visuals:

1. **Gauge Visual** (CLV Goal)
   - Value: `Total Projected CLV 12M`
   - Min: 0, Max: Set to 150% of current value
   - Target: Your business goal

2. **CLV Histogram** (using Column Chart with bucketed CLV)
   - Create a calculated column in customer_clv_master:
     ```dax
     CLV Bucket = 
     SWITCH(TRUE(),
         [clv_12m] < 100,  "$0-100",
         [clv_12m] < 300,  "$100-300",
         [clv_12m] < 500,  "$300-500",
         [clv_12m] < 800,  "$500-800",
         [clv_12m] < 1200, "$800-1200",
         "$1200+"
     )
     ```
   - X: CLV Bucket, Y: Count of customers

3. **Scatter: CLV vs Frequency**
   - X: `frequency`
   - Y: `clv_12m`
   - Color: `clv_segment`
   - Play axis: Optional — `first_purchase_date` quarter

4. **Stacked Bar: CLV by Country (Top 10)**
   - Y: `country` (from `customer_clv_master`)
   - X: `Total Projected CLV 12M`
   - Legend: `clv_segment`
   - Filter to Top 10 countries by CLV sum

---

### PAGE 4: Campaign Insights

**Page name:** `Campaign Strategy`

#### Layout:
```
┌─────────────────────────────────────────────────────────────────┐
│  CAC Reduction: 13.6% │ Total Campaign Cost │ Expected ROI       │
│  (KPI Card)           │ (Card)             │ (Card)              │
├──────────────────────────┬──────────────────────────────────────┤
│  Campaign ROI by Segment │  Targeted vs Blanket Comparison      │
│  (Clustered Bar)         │  (Table or Column Chart)             │
│  Y: rfm_segment          │                                      │
│  X: roi_pct              │                                      │
├──────────────────────────┼──────────────────────────────────────┤
│  Campaign Assignment     │  Priority Tier Distribution          │
│  Matrix Table            │  (Donut: High/Med/Low)               │
│  Cols: segment │ campaign │                                      │
│  │ customers │ cost │ roi │                                      │
└──────────────────────────┴──────────────────────────────────────┘
```

#### Methodology Note (add as a text box on this page):
> *CAC Reduction = 13.6%: Comparing a generic blanket campaign (£12/customer applied to all 4,334 customers = £52,008) against CLV-targeted campaigns (segment-specific costs = £44,920). Champions receive VIP Early Access (£15), Lost customers receive Re-Activation Email (£5). Source: Notebook 05 simulation.*

#### Key Visual — Clustered Bar (Campaign ROI):
- From `campaign_roi` table
- Y: `rfm_segment`
- X: `roi_pct`
- Color: conditional (green if >200%, yellow if 100-200%, red if <100%)
- Data labels: Show percentage

#### Key Visual — Campaign Matrix Table:
- Rows: `rfm_segment`
- Columns: `campaign_name`, `customers`, `total_cost`, `avg_clv`, `roi_pct`
- Conditional bar on `total_expected`
- Sort by `roi_pct` descending

---

## STEP 5: Slicers & Cross-Filtering

Add these slicers to each page:

| Slicer | Field | Type |
|--------|-------|------|
| Date range  | `Dates[Date]`                        | Between |
| Segment     | `customer_clv_master[rfm_segment]`   | Dropdown |
| CLV Tier    | `customer_clv_master[clv_segment]`   | List |
| Country     | `customer_clv_master[country]`       | Dropdown |

**Enable cross-filtering:** All visuals on the same page should cross-filter.  
Format → Edit Interactions → set all to "Filter" (not "Highlight").

---

## STEP 6: Formatting Tips

### Theme
- Go to View → Themes → Customize Current Theme
- Primary color: `#2563EB` (blue)
- Accent 1: `#16A34A` (green)
- Accent 2: `#DC2626` (red)
- Background: `#F8FAFC` (light gray)

### KPI Cards
- Turn off category label
- Display unit: Auto
- Large font: 28pt, bold
- Value color: Match chart theme

### Segment Color Coding (apply consistently):
| Segment | Color |
|---------|-------|
| Champions | #2563EB (Blue) |
| Loyal Customers | #16A34A (Green) |
| At Risk | #DC2626 (Red) |
| Lost | #9CA3AF (Gray) |
| New Customers | #0891B2 (Cyan) |
| Potential Loyalists | #7C3AED (Purple) |
| Need Attention | #D97706 (Amber) |
| High CLV | #16A34A (Green) |
| Medium CLV | #D97706 (Amber) |
| Low CLV | #DC2626 (Red) |

---

## STEP 7: Publish

1. Sign in to Power BI Service (app.powerbi.com)
2. File → Publish → Select workspace
3. Share the link

**For GitHub:** Export as PDF:  
File → Export → Export to PDF → save as `powerbi/dashboard_preview.pdf`

---

## Expected Final Dashboard

```
Page 1: Executive Summary
  ✓ 5 KPI cards (revenue, customers, CLV, AOV, margin)
  ✓ Monthly revenue trend
  ✓ Category donut chart
  ✓ Top products table

Page 2: RFM Segmentation
  ✓ Segment treemap
  ✓ CLV by segment bar
  ✓ RFM scatter plot
  ✓ Segment detail table

Page 3: CLV Deep Dive
  ✓ CLV distribution histogram
  ✓ CLV vs frequency scatter
  ✓ CLV by country (Top 10)
  ✓ Gauge visual

Page 4: Campaign Strategy
  ✓ 13.6% CAC reduction KPI card
  ✓ Campaign ROI by segment
  ✓ Campaign assignment table
  ✓ Priority tier donut
```
