# Power BI DAX Measures
## E-Commerce CLV Analysis Dashboard
### Based on Real UCI "Online Retail" Dataset (2010–2011)

All DAX measures to paste into Power BI **Model View → New Measure**.  
Create a dedicated `_Measures` table (Home → Enter Data, name it `_Measures`) to keep them organized.

> **Currency note:** Source data is a UK retailer. All monetary values are in British Pounds (£). Adjust FORMAT() currency symbol if needed.

---

## 1. BASE REVENUE MEASURES

```dax
Total Net Revenue = 
SUM(order_items_enriched[line_profit])

Total Gross Revenue = 
SUM(order_items_enriched[line_total])

Total Profit = 
SUM(order_items_enriched[line_profit])

Gross Margin % = 
DIVIDE(
    [Total Profit],
    [Total Gross Revenue],
    0
)

Total Orders = 
DISTINCTCOUNT(order_items_enriched[order_id])

Total Customers = 
DISTINCTCOUNT(customer_clv_master[customer_id])

Avg Order Value = 
DIVIDE(
    [Total Gross Revenue],
    [Total Orders],
    0
)
```

---

## 2. CLV MEASURES

```dax
Avg CLV 12M = 
AVERAGE(customer_clv_master[clv_12m])

Total Projected CLV 12M = 
SUM(customer_clv_master[clv_12m])

Avg CLV 36M = 
AVERAGE(customer_clv_master[clv_36m])

Total Projected CLV 36M = 
SUM(customer_clv_master[clv_36m])

High CLV Customers = 
CALCULATE(
    [Total Customers],
    customer_clv_master[clv_segment] = "High"
)

High CLV Revenue Share = 
DIVIDE(
    CALCULATE(
        SUM(customer_clv_master[clv_12m]),
        customer_clv_master[clv_segment] = "High"
    ),
    [Total Projected CLV 12M],
    0
)

CLV to AOV Ratio = 
DIVIDE(
    [Avg CLV 12M],
    [Avg Order Value],
    0
)
```

---

## 3. RFM SEGMENT MEASURES

```dax
Champions Count = 
CALCULATE(
    [Total Customers],
    customer_clv_master[rfm_segment] = "Champions"
)

At Risk Count = 
CALCULATE(
    [Total Customers],
    customer_clv_master[rfm_segment] = "At Risk"
)

Lost Count = 
CALCULATE(
    [Total Customers],
    customer_clv_master[rfm_segment] = "Lost"
)

Loyal Customers Count = 
CALCULATE(
    [Total Customers],
    customer_clv_master[rfm_segment] = "Loyal Customers"
)

Segment Revenue % = 
DIVIDE(
    SUM(customer_clv_master[clv_12m]),
    CALCULATE(
        SUM(customer_clv_master[clv_12m]),
        ALL(customer_clv_master[rfm_segment])
    ),
    0
)
```

---

## 4. CAMPAIGN & CAC MEASURES

```dax
Total Campaign Cost = 
SUM(campaign_roi[total_cost])

Total Expected Revenue = 
SUM(campaign_roi[total_expected])

Campaign ROI = 
DIVIDE(
    [Total Expected Revenue] - [Total Campaign Cost],
    [Total Campaign Cost],
    0
)

Campaign ROI % = 
[Campaign ROI] * 100

CAC Targeted = 
DIVIDE(
    [Total Campaign Cost],
    DISTINCTCOUNT(campaign_targets[customer_id]),
    0
)

CAC Reduction % = 
-- Blanket baseline: £12/customer (generic campaign applied to all)
-- Targeted: per-segment cost from CAMPAIGN_MATRIX
-- Real computed value from notebook 05: 13.6%
VAR BaselineCac = 12
RETURN
DIVIDE(
    BaselineCac - [CAC Targeted],
    BaselineCac,
    0
) * 100
```

---

## 5. TREND & TIME INTELLIGENCE MEASURES

```dax
Revenue MoM Growth = 
VAR CurrentMonth = [Total Gross Revenue]
VAR PreviousMonth = 
    CALCULATE(
        [Total Gross Revenue],
        DATEADD(Dates[Date], -1, MONTH)
    )
RETURN
DIVIDE(
    CurrentMonth - PreviousMonth,
    PreviousMonth,
    0
)

Revenue MoM Growth % = 
[Revenue MoM Growth] * 100

Monthly Active Customers = 
CALCULATE(
    DISTINCTCOUNT(order_items_enriched[customer_id]),
    DATESMTD(Dates[Date])
)
```

---

## 6. KPI CARD MEASURES (formatted)

```dax
Revenue Display = 
VAR Rev = [Total Gross Revenue]
RETURN
IF(
    Rev >= 1000000,
    FORMAT(Rev / 1000000, "£#,##0.0") & "M",
    IF(
        Rev >= 1000,
        FORMAT(Rev / 1000, "£#,##0.0") & "K",
        FORMAT(Rev, "£#,##0")
    )
)

Avg CLV Display = 
FORMAT([Avg CLV 12M], "£#,##0")

Margin Display = 
FORMAT([Gross Margin %], "0.0%")

CAC Reduction Display = 
FORMAT([CAC Reduction %], "0.0") & "% Reduction"
```

---

## 7. CONDITIONAL FORMATTING MEASURES

```dax
CLV Segment Color = 
SWITCH(
    SELECTEDVALUE(customer_clv_master[clv_segment]),
    "High",   "#16A34A",
    "Medium", "#D97706",
    "Low",    "#DC2626",
    "#64748B"
)

RFM Segment Color = 
SWITCH(
    SELECTEDVALUE(customer_clv_master[rfm_segment]),
    "Champions",          "#2563EB",
    "Loyal Customers",    "#16A34A",
    "At Risk",            "#DC2626",
    "Lost",               "#9CA3AF",
    "Need Attention",     "#D97706",
    "Cannot Lose Them",   "#7C3AED",
    "Potential Loyalists","#0891B2",
    "Promising",          "#059669",
    "#64748B"
)
```
