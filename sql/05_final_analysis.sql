-- ============================================================
-- Quebec ED Analytics — Final Analysis Queries
-- Data: week of 2026-07-20 to 2026-07-26
-- ============================================================

-- Q1: Which hospitals have the highest average number of patients
--     waiting 24h+ on a stretcher? (chronic capacity overload signal)
-- Finding: Hôpital Royal Victoria is the clear outlier at 33/day avg,
--          well above #2 (Hôpital général du Lakeshore, 28/day).
SELECT
    i.installation_name,
    ROUND(AVG(d.value)) AS avg_patients_24h_plus
FROM dim_installation AS i
JOIN fact_ed_daily AS d ON i.installation_id = d.installation_id
WHERE d.metric = 'patients_24h_plus'
  AND d.is_region_total = 0
GROUP BY i.installation_name
ORDER BY avg_patients_24h_plus DESC
LIMIT 10;


-- Q2: What is the average bed-occupancy rate per region?
-- Finding: 8 of 15 regions average above 100% occupancy for the week;
--          Laval is highest at 166%.
SELECT
    dr.region_name,
    ROUND(AVG(d.value)) AS avg_occupation_pct
FROM fact_ed_daily AS d
JOIN dim_installation AS i ON d.installation_id = i.installation_id
JOIN dim_region AS dr ON i.region_code = dr.region_code
WHERE d.metric = 'taux_occupation'
  AND d.is_region_total = 1
GROUP BY dr.region_name
ORDER BY avg_occupation_pct DESC;


-- Q3: Is there a day-of-week pattern in total provincial ED volume?
-- Finding: Wednesday is the weekly peak (1,871 patients), Saturday
--          the lowest (1,616) -- based on a single week, not yet
--          confirmed as a recurring pattern.
SELECT
    date,
    CASE CAST(strftime('%w', date) AS INTEGER)
        WHEN 0 THEN 'Sunday' WHEN 1 THEN 'Monday' WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday' WHEN 4 THEN 'Thursday' WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END AS week_day,
    SUM(value) AS total_patients_sur_civiere
FROM fact_ed_daily
WHERE metric = 'patients_sur_civiere'
  AND is_region_total = 0
GROUP BY date
ORDER BY date;


-- Q4: How many installations does each region have?
-- Finding: Laval has only 2 -- fewest of any region -- which may
--          partly explain its very high occupancy rate in Q2.
SELECT
    r.region_name,
    COUNT(i.installation_id) AS installations_per_region
FROM dim_installation AS i
JOIN dim_region AS r ON i.region_code = r.region_code
GROUP BY r.region_name
ORDER BY installations_per_region DESC;


-- Q5: Which hospital has the most functional stretchers?
-- Finding: Hôpital Maisonneuve-Rosemont (54), in the Montréal region.
SELECT installation_name, stretchers
FROM dim_installation
WHERE is_region_total = 0
ORDER BY stretchers DESC
LIMIT 1;


-- ============================================================
-- Data quality check (not a business finding, but worth documenting)
-- ============================================================

-- Any hospital reporting 0 stretchers but non-zero patients?
-- Result: none found -- data is internally consistent on this point.
SELECT i.installation_name, i.stretchers
FROM dim_installation AS i
JOIN fact_ed_daily AS d ON i.installation_id = d.installation_id
WHERE i.stretchers = 0
  AND d.metric = 'patients_sur_civiere'
  AND d.value > 0
  AND d.is_region_total = 0;
