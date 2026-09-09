# Sales Funnel Dashboard: SQL Cleaning & Power BI Analysis

## Project Description
An end-to-end analytics project on a sales funnel dataset (~1,000 leads) for a heavy equipment rental business. The project covers the full pipeline: cleaning messy raw data with SQL (PostgreSQL), then building an interactive Power BI dashboard with custom DAX measures to analyze conversion rates across the sales funnel (Lead → Quotation → Negotiation → Closed Won/Lost).

## Background
Raw sales lead data is rarely analysis-ready. This project simulates a realistic scenario: a synthetic dataset was deliberately generated with common real-world data quality issues (inconsistent capitalization, typos, duplicate rows, missing values, mixed date formats, outliers, and logically invalid dates), then cleaned end-to-end using SQL before being visualized.

## Data Disclaimer
This dataset is **100% synthetic**, generated for portfolio and learning purposes. No real client names, contact details, or actual deal values are included. The business context (heavy equipment rental — boom lifts, scissor lifts, cranes, etc.) is modeled after a real industry, but all records are randomly generated placeholders.

## Dataset
- **Source:** `sales_funnel_data_raw.csv` (synthetic, ~1,050 rows before cleaning)
- **Main columns:** `Lead_ID`, `Lead_Date`, `Company_Name`, `Region`, `City`, `Equipment_Type`, `Lead_Source`, `Sales_Rep`, `Current_Stage`, `Quotation_Date`, `Negotiation_Date`, `Closing_Date`, `Deal_Value_IDR`, `Lost_At_Stage`, `Lost_Reason`

## Tools
- PostgreSQL, DBeaver (data cleaning)
- Power BI Desktop (dashboard, DAX)

---

## 1. Data Cleaning (SQL)

Full script: [`sales_funnel_cleaning.sql`](sales_funnel_cleaning.sql)

Issues identified and fixed:

| Issue | Fix |
|---|---|
| Inconsistent capitalization & stray whitespace (`Region`, `City`, `Company_Name`) | `TRIM()` + `INITCAP()` |
| Multiple spellings for the same category (e.g. `WA` / `Whats App` / `Whatsapp`) | `CASE WHEN ... THEN ... END` to map all variants to one canonical value |
| Blank cells imported as `''` instead of true `NULL` | Explicit `UPDATE ... SET col = NULL WHERE TRIM(col) = ''` |
| Duplicate rows (exact and near-duplicate) | `DELETE` using PostgreSQL's `ctid`, keeping one row per `Lead_ID` |
| "Closed Won" rows with a missing deal value | Removed — a data-entry gap, not a legitimate zero |
| Outliers in `Deal_Value_IDR` (negative, unrealistically low/high) | Removed after inspecting the sorted extremes |
| `Closing_Date` earlier than `Lead_Date` (logically impossible) | Removed |
| All columns imported as `TEXT` to survive messy raw data | Converted to `DATE` / `NUMERIC` via `ALTER TABLE ... USING` once clean |

**Example — standardizing lead source spelling:**
```sql
UPDATE sales_funnel_data
SET "Lead_Source" = CASE
    WHEN "Lead_Source" IN ('Wa', 'Whats App', 'Whatsapp') THEN 'WhatsApp'
    WHEN "Lead_Source" IN ('G-Ads', 'Google Adwords') THEN 'Google Ads'
    WHEN "Lead_Source" IN ('Web', 'Web Site') THEN 'Website'
    WHEN "Lead_Source" IN ('Referal', 'Refferal') THEN 'Referral'
    ELSE "Lead_Source"
END;
```

**Example — removing duplicate rows while keeping one per lead:**
```sql
DELETE FROM sales_funnel_data
WHERE ctid NOT IN (
    SELECT MIN(ctid)
    FROM sales_funnel_data
    GROUP BY "Lead_ID"
);
```

---

## 2. Dashboard (Power BI)

![Dashboard Overview](images/dashboard_overview.png)

The dashboard includes:
- **KPI cards:** Total Leads, Total Closed Won, Overall Win Rate, Total Deal Value, Average Deal Size
- **Funnel chart:** Lead In → Quotation Sent → Negotiation → Closed Won, built on a custom DAX measure (`SWITCH` + a small disconnected stage table) so each stage reflects everyone who *ever reached* it — not just each lead's final status
- **Trend chart:** leads over time
- **Breakdowns:** Lead Source effectiveness, and reasons behind lost deals
- **Slicers:** Region, Equipment Type, Year

**Key DAX measure — funnel stage counts:**
```dax
Funnel Count =
VAR CurrentStage = TRIM(SELECTEDVALUE(Funnel_Stage[Stage_Name]))
RETURN
SWITCH(
    CurrentStage,
    "Lead In", SUM(sales_funnel_data[Reached_Lead]),
    "Quotation Sent", SUM(sales_funnel_data[Reached_Quotation]),
    "Negotiation", SUM(sales_funnel_data[Reached_Negotiation]),
    "Closed Won", SUM(sales_funnel_data[Reached_Closed_Won]),
    BLANK()
)
```

## Key Insight

The leading cause of lost deals was **"No response / went cold"** — well ahead of price objections or losing to a competitor. This points to a follow-up process gap rather than a pricing or product issue, suggesting the clearest lever for improving win rate is faster, more consistent lead follow-up rather than discounting.

---

## File Structure
```
├── sales_funnel_cleaning.sql
├── sales_funnel_data_raw.csv
├── README.md
└── images/
    ├── dashboard_overview.png
    ├── funnel_chart.png
    └── lead_source_lost_reason.png
```
