-- ============================================================
-- Step 2: Populate the star-schema tables from the raw staging tables
-- Run these in order: dim_region → dim_installation → fact_ed_daily
-- ============================================================

-- 1) dim_region: one row per unique region
--    (using raw_installation as the source, since raw_region only has
--     a single combined "region" text column, not separate code/name)
INSERT INTO dim_region (region_code, region_name)
SELECT DISTINCT region_code, region_name
FROM raw_installation;

-- 2) dim_installation: one row per unique installation
--    (from raw_installation, which has installation-level detail;
--     raw_region only has region totals, so it's not used here)
INSERT INTO dim_installation (installation_name, region_code, stretchers)
SELECT DISTINCT installation, region_code, CAST(civ AS INTEGER)
FROM raw_installation;

-- 3) fact_ed_daily: join raw_installation back to dim_installation
--    to look up the numeric installation_id, instead of repeating
--    the hospital name in every row.
INSERT INTO fact_ed_daily (installation_id, date, metric, value, is_region_total)
SELECT
    di.installation_id,
    r.date,
    r.metric,
    CASE WHEN r.value = '' THEN NULL ELSE CAST(r.value AS REAL) END,
    CASE WHEN r.is_region_total = 'True' THEN 1 ELSE 0 END
FROM raw_installation r
JOIN dim_installation di ON r.installation = di.installation_name;

-- ============================================================
-- Sanity checks -- run these after the inserts above to confirm
-- everything landed correctly
-- ============================================================

-- Should be 16 (16 health regions in Quebec)
SELECT COUNT(*) AS n_regions FROM dim_region;

-- Should be around 109 (unique hospitals/installations)
SELECT COUNT(*) AS n_installations FROM dim_installation;

-- Should match the row count of raw_installation (around 3815)
SELECT COUNT(*) AS n_fact_rows FROM fact_ed_daily;

-- Spot check: see the data joined back together, human-readable
SELECT
    di.installation_name,
    dr.region_name,
    f.date,
    f.metric,
    f.value
FROM fact_ed_daily f
JOIN dim_installation di ON f.installation_id = di.installation_id
JOIN dim_region dr ON di.region_code = dr.region_code
LIMIT 20;
