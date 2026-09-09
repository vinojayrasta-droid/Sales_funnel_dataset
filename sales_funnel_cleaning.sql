/* ============================================================================
   SALES FUNNEL DATASET — DATA CLEANING SCRIPT
   Heavy equipment rental business (synthetic/dummy data)
   Tool: PostgreSQL / DBeaver
   ============================================================================
   Raw data was imported from sales_funnel_data_dirty.csv with ALL columns
   set to TEXT/VARCHAR, since the raw file contains inconsistent formats
   that would break a direct import into DATE/NUMERIC columns.
   Table name used below: sales_funnel_data
   ============================================================================ */


/* ----------------------------------------------------------------------
   1. STANDARDIZE CATEGORICAL COLUMNS
   Fixes inconsistent capitalization and stray whitespace using
   TRIM() + INITCAP().
   ---------------------------------------------------------------------- */

UPDATE sales_funnel_data
SET "Region" = INITCAP(TRIM("Region"));

UPDATE sales_funnel_data
SET "Region" = 'Unknown'
WHERE "Region" IS NULL OR TRIM("Region") = '';

UPDATE sales_funnel_data
SET "City" = 'Unknown'
WHERE "City" IS NULL OR TRIM("City") = '';

UPDATE sales_funnel_data
SET "City" = INITCAP(TRIM("City"))
WHERE "City" IS NOT NULL AND TRIM("City") <> 'Unknown';

-- Company_Name: trim, collapse double spaces, title-case, then restore "PT" in caps
UPDATE sales_funnel_data
SET "Company_Name" = REGEXP_REPLACE(
    INITCAP(REGEXP_REPLACE(TRIM("Company_Name"), '\s+', ' ', 'g')),
    '^Pt ', 'PT '
);


/* ----------------------------------------------------------------------
   2. FIX INCONSISTENT NAMING / ABBREVIATIONS
   Some categories were entered under multiple different spellings
   for the same real-world value (e.g. "WA", "Whats App", "Whatsapp").
   ---------------------------------------------------------------------- */

UPDATE sales_funnel_data
SET "Lead_Source" = CASE
    WHEN "Lead_Source" IN ('Wa', 'Whats App', 'Whatsapp') THEN 'WhatsApp'
    WHEN "Lead_Source" IN ('G-Ads', 'Google Adwords') THEN 'Google Ads'
    WHEN "Lead_Source" IN ('Web', 'Web Site') THEN 'Website'
    WHEN "Lead_Source" IN ('Referal', 'Refferal') THEN 'Referral'
    ELSE "Lead_Source"
END;

UPDATE sales_funnel_data
SET "Equipment_Type" = CASE
    WHEN "Equipment_Type" IN ('Boom Lift', 'Boomlift') THEN 'Boom Lift'
    WHEN "Equipment_Type" IN ('Scissor Lift', 'Scissorlift') THEN 'Scissor Lift'
    WHEN "Equipment_Type" IN ('Sky Lift', 'Skylift') THEN 'Skylift'
    WHEN "Equipment_Type" IN ('Tele Handler', 'Telehandler') THEN 'Telehandler'
    ELSE "Equipment_Type"
END;


/* ----------------------------------------------------------------------
   3. FIX EMPTY STRINGS MASQUERADING AS NULL
   The CSV import stored blank cells as '' rather than true NULL, which
   silently breaks NULL-based logic (COUNT, IS NULL, date casting).
   ---------------------------------------------------------------------- */

UPDATE sales_funnel_data
SET "Quotation_Date" = NULL       WHERE TRIM("Quotation_Date") = '';
UPDATE sales_funnel_data
SET "Negotiation_Date" = NULL     WHERE TRIM("Negotiation_Date") = '';
UPDATE sales_funnel_data
SET "Closing_Date" = NULL         WHERE TRIM("Closing_Date") = '';
UPDATE sales_funnel_data
SET "Lost_At_Stage" = NULL        WHERE TRIM("Lost_At_Stage") = '';
UPDATE sales_funnel_data
SET "Lost_Reason" = NULL          WHERE TRIM("Lost_Reason") = '';

-- Sanity check: blanks should now only exist where a lead genuinely never
-- reached that stage (e.g. Quotation_Date is NULL for "Lead In" rows).
SELECT
    "Current_Stage",
    COUNT(*) AS total,
    COUNT("Quotation_Date")   AS has_quotation,
    COUNT("Negotiation_Date") AS has_negotiation,
    COUNT("Closing_Date")     AS has_closing
FROM sales_funnel_data
GROUP BY "Current_Stage";


/* ----------------------------------------------------------------------
   4. REMOVE DUPLICATE ROWS
   Keeps exactly one row per Lead_ID using PostgreSQL's internal ctid,
   which catches both exact duplicates and near-duplicates that share
   the same Lead_ID.
   ---------------------------------------------------------------------- */

DELETE FROM sales_funnel_data
WHERE ctid NOT IN (
    SELECT MIN(ctid)
    FROM sales_funnel_data
    GROUP BY "Lead_ID"
);


/* ----------------------------------------------------------------------
   5. REMOVE INVALID / MISSING DEAL VALUES
   A "Closed Won" row with no recorded deal value is a data-entry
   error, not a legitimate zero — it's dropped rather than imputed.
   ---------------------------------------------------------------------- */

DELETE FROM sales_funnel_data
WHERE "Current_Stage" = 'Closed Won' AND "Deal_Value_IDR" IS NULL;


/* ----------------------------------------------------------------------
   6. REMOVE OUTLIERS IN DEAL VALUE
   Negative values, and values far outside a plausible range for a
   heavy-equipment rental deal, are treated as entry errors.
   ---------------------------------------------------------------------- */

DELETE FROM sales_funnel_data
WHERE "Current_Stage" = 'Closed Won'
  AND ("Deal_Value_IDR" < 0
       OR "Deal_Value_IDR" < 1000000
       OR "Deal_Value_IDR" > 500000000);


/* ----------------------------------------------------------------------
   7. REMOVE LOGICALLY INVALID ROWS
   A few rows had a Closing_Date earlier than the Lead_Date, which is
   impossible in a real sales process.
   ---------------------------------------------------------------------- */

DELETE FROM sales_funnel_data
WHERE "Closing_Date" IS NOT NULL
  AND "Closing_Date"::DATE < "Lead_Date"::DATE;


/* ----------------------------------------------------------------------
   8. CONVERT COLUMNS TO THEIR PROPER DATA TYPES
   Every column was imported as TEXT to survive the messy raw data.
   Once cleaned, dates and the deal value are cast to DATE / NUMERIC
   so they can be used directly in date math and aggregations
   (and imported cleanly into Power BI).
   ---------------------------------------------------------------------- */

ALTER TABLE sales_funnel_data
ALTER COLUMN "Lead_Date"         TYPE DATE    USING "Lead_Date"::DATE,
ALTER COLUMN "Quotation_Date"    TYPE DATE    USING "Quotation_Date"::DATE,
ALTER COLUMN "Negotiation_Date"  TYPE DATE    USING "Negotiation_Date"::DATE,
ALTER COLUMN "Closing_Date"      TYPE DATE    USING "Closing_Date"::DATE,
ALTER COLUMN "Deal_Value_IDR"    TYPE NUMERIC USING "Deal_Value_IDR"::NUMERIC;


/* ----------------------------------------------------------------------
   FINAL CHECK
   ---------------------------------------------------------------------- */

SELECT COUNT(*) AS total_rows FROM sales_funnel_data;

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'sales_funnel_data';
