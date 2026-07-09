# Power Query M Transformations
## E-Commerce CLV Analysis — Real UCI "Online Retail" Dataset

Use these in Power BI Desktop: **Home → Transform Data → Advanced Editor**

> **Note:** The source data is a real UK-based gift retailer (UCI Online Retail, 2010–2011).  
> There are no demographic columns (age, gender, city, state) or acquisition-channel columns  
> — these are intentionally absent, not omitted. Use `country` for geographic segmentation.

---

## 1. Load customer_clv_master.csv

```m
let
    Source = Csv.Document(
        File.Contents("C:\YOUR_PATH\exports\customer_clv_master.csv"),
        [Delimiter=",", Encoding=65001, QuoteStyle=QuoteStyle.None]
    ),
    #"Promoted Headers" = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),
    #"Changed Types" = Table.TransformColumnTypes(#"Promoted Headers", {
        {"customer_id",           type text},
        {"country",               type text},
        {"first_purchase_date",   type date},
        {"last_purchase_date",    type date},
        {"rfm_segment",           type text},
        {"r_score",               Int64.Type},
        {"f_score",               Int64.Type},
        {"m_score",               Int64.Type},
        {"rfm_score",             Int64.Type},
        {"recency_days",          Int64.Type},
        {"frequency",             Int64.Type},
        {"monetary",              type number},
        {"avg_order_value",       type number},
        {"purchase_freq_monthly", type number},
        {"gross_margin_pct",      type number},
        {"churn_rate",            type number},
        {"clv_12m",               type number},
        {"clv_36m",               type number},
        {"clv_segment",           type text}
    }),
    -- Segment Priority for sorting visuals
    #"Add Segment Priority" = Table.AddColumn(#"Changed Types", "segment_priority",
        each if [rfm_segment] = "Champions"          then 1
        else if [rfm_segment] = "Loyal Customers"    then 2
        else if [rfm_segment] = "Potential Loyalists" then 3
        else if [rfm_segment] = "Promising"          then 4
        else if [rfm_segment] = "New Customers"      then 5
        else if [rfm_segment] = "Need Attention"     then 6
        else if [rfm_segment] = "At Risk"            then 7
        else if [rfm_segment] = "Cannot Lose Them"   then 8
        else if [rfm_segment] = "Hibernating"        then 9
        else 10,
        Int64.Type
    ),
    #"Add CLV Tier" = Table.AddColumn(#"Add Segment Priority", "clv_tier",
        each if [clv_segment] = "High"   then 1
        else if [clv_segment] = "Medium" then 2
        else 3,
        Int64.Type
    )
in
    #"Add CLV Tier"
```

---

## 2. Load order_items_enriched.csv

```m
let
    Source = Csv.Document(
        File.Contents("C:\YOUR_PATH\exports\order_items_enriched.csv"),
        [Delimiter=",", Encoding=65001, QuoteStyle=QuoteStyle.None]
    ),
    #"Promoted Headers" = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),
    #"Changed Types" = Table.TransformColumnTypes(#"Promoted Headers", {
        {"item_id",        Int64.Type},
        {"order_id",       type text},
        {"stock_code",     type text},
        {"quantity",       Int64.Type},
        {"unit_price",     type number},
        {"line_total",     type number},
        {"order_date",     type date},
        {"customer_id",    type text},
        {"product_name",   type text},
        {"category",       type text},
        {"order_status",   type text},
        {"net_line_total", type number},
        {"line_profit",    type number}
    }),
    #"Completed Only" = Table.SelectRows(#"Changed Types", each [order_status] = "Completed"),
    #"Add Year Month" = Table.AddColumn(#"Completed Only", "year_month",
        each Date.ToText([order_date], "yyyy-MM"), type text),
    #"Add Quarter" = Table.AddColumn(#"Add Year Month", "quarter",
        each "Q" & Text.From(Date.QuarterOfYear([order_date])), type text),
    #"Add Day of Week" = Table.AddColumn(#"Add Quarter", "day_of_week",
        each Date.DayOfWeekName([order_date]), type text)
in
    #"Add Day of Week"
```

---

## 3. Load monthly_revenue.csv

```m
let
    Source = Csv.Document(
        File.Contents("C:\YOUR_PATH\exports\monthly_revenue.csv"),
        [Delimiter=",", Encoding=65001, QuoteStyle=QuoteStyle.None]
    ),
    #"Promoted Headers" = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),
    #"Changed Types" = Table.TransformColumnTypes(#"Promoted Headers", {
        {"order_date",  type date},
        {"net_revenue", type number},
        {"order_count", Int64.Type},
        {"customers",   Int64.Type},
        {"aov",         type number},
        {"mom_growth",  type number}
    }),
    #"Add Growth Flag" = Table.AddColumn(#"Changed Types", "growth_direction",
        each if [mom_growth] > 0 then "Positive"
             else if [mom_growth] < 0 then "Negative"
             else "Flat", type text)
in
    #"Add Growth Flag"
```

---

## 4. Load campaign_roi.csv

```m
let
    Source = Csv.Document(
        File.Contents("C:\YOUR_PATH\exports\campaign_roi.csv"),
        [Delimiter=",", Encoding=65001, QuoteStyle=QuoteStyle.None]
    ),
    #"Promoted Headers" = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),
    #"Changed Types" = Table.TransformColumnTypes(#"Promoted Headers", {
        {"rfm_segment",   type text},
        {"campaign_name", type text},
        {"customers",     Int64.Type},
        {"total_cost",    type number},
        {"avg_clv",       type number},
        {"total_expected",type number},
        {"roi_pct",       type number}
    }),
    #"Add Profit" = Table.AddColumn(#"Changed Types", "campaign_profit",
        each [total_expected] - [total_cost], type number)
in
    #"Add Profit"
```

---

## 5. Load category_revenue.csv

```m
let
    Source = Csv.Document(
        File.Contents("C:\YOUR_PATH\exports\category_revenue.csv"),
        [Delimiter=",", Encoding=65001, QuoteStyle=QuoteStyle.None]
    ),
    #"Promoted Headers" = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),
    #"Changed Types" = Table.TransformColumnTypes(#"Promoted Headers", {
        {"category",    type text},
        {"net_revenue", type number},
        {"units_sold",  Int64.Type},
        {"orders",      Int64.Type},
        {"margin_pct",  type number}
    })
in
    #"Changed Types"
```

---

## 6. Load country_acquisition.csv

> This table shows customer count by country (replaces the old `channel_acquisition.csv`).  
> There are no acquisition channel fields in the UCI dataset.

```m
let
    Source = Csv.Document(
        File.Contents("C:\YOUR_PATH\exports\country_acquisition.csv"),
        [Delimiter=",", Encoding=65001, QuoteStyle=QuoteStyle.None]
    ),
    #"Promoted Headers" = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),
    #"Changed Types" = Table.TransformColumnTypes(#"Promoted Headers", {
        {"country",        type text},
        {"customer_count", Int64.Type},
        {"pct",            type number}
    })
in
    #"Changed Types"
```

---

## 7. Load top_products.csv

```m
let
    Source = Csv.Document(
        File.Contents("C:\YOUR_PATH\exports\top_products.csv"),
        [Delimiter=",", Encoding=65001, QuoteStyle=QuoteStyle.None]
    ),
    #"Promoted Headers" = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),
    #"Changed Types" = Table.TransformColumnTypes(#"Promoted Headers", {
        {"product_name", type text},
        {"category",     type text},
        {"net_revenue",  type number},
        {"units",        Int64.Type}
    })
in
    #"Changed Types"
```

---

## 8. Load campaign_targets.csv

```m
let
    Source = Csv.Document(
        File.Contents("C:\YOUR_PATH\exports\campaign_targets.csv"),
        [Delimiter=",", Encoding=65001, QuoteStyle=QuoteStyle.None]
    ),
    #"Promoted Headers" = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),
    #"Changed Types" = Table.TransformColumnTypes(#"Promoted Headers", {
        {"customer_id",      type text},
        {"rfm_segment",      type text},
        {"clv_segment",      type text},
        {"campaign_name",    type text},
        {"campaign_cost",    type number},
        {"clv_12m",          type number},
        {"expected_revenue", type number},
        {"priority_tier",    Int64.Type}
    })
in
    #"Changed Types"
```

---

## 9. Date Dimension Table (Auto-generated)

> Set `StartDate` and `EndDate` to match your data range (UCI dataset: Dec 2010 – Dec 2011).

```m
let
    StartDate = #date(2010, 12, 1),
    EndDate   = #date(2011, 12, 31),
    NumDays   = Duration.Days(EndDate - StartDate) + 1,
    DateList  = List.Dates(StartDate, NumDays, #duration(1,0,0,0)),
    DateTable = Table.FromList(DateList, Splitter.SplitByNothing(), {"Date"}),
    #"Changed Type"    = Table.TransformColumnTypes(DateTable, {{"Date", type date}}),
    #"Add Year"        = Table.AddColumn(#"Changed Type",  "Year",      each Date.Year([Date]),          Int64.Type),
    #"Add Month"       = Table.AddColumn(#"Add Year",      "Month",     each Date.Month([Date]),         Int64.Type),
    #"Add Month Name"  = Table.AddColumn(#"Add Month",     "MonthName", each Date.MonthName([Date]),     type text),
    #"Add Quarter"     = Table.AddColumn(#"Add Month Name","Quarter",   each "Q" & Text.From(Date.QuarterOfYear([Date])), type text),
    #"Add Year Month"  = Table.AddColumn(#"Add Quarter",   "YearMonth", each Date.ToText([Date], "yyyy-MM"), type text),
    #"Add Day of Week" = Table.AddColumn(#"Add Year Month","DayOfWeek", each Date.DayOfWeekName([Date]), type text),
    #"Add Is Weekend"  = Table.AddColumn(#"Add Day of Week","IsWeekend",
        each Date.DayOfWeek([Date]) >= 5, type logical),
    #"Add Week Number" = Table.AddColumn(#"Add Is Weekend","WeekNum",   each Date.WeekOfYear([Date]),    Int64.Type)
in
    #"Add Week Number"
```

---

## ⚠️ IMPORTANT: Update File Paths
Replace `C:\YOUR_PATH\` with your actual path to the `exports/` folder:
- Windows: `C:\Users\YourName\ecommerce_clv_analysis\exports\`
- Mac/Linux: `/Users/YourName/ecommerce_clv_analysis/exports/`
