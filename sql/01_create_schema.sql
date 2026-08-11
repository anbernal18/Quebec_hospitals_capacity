-- ============================================================
-- Quebec Emergency Department Analytics — Schema
-- Star schema: 2 dimension tables + 1 fact table
-- ============================================================

-- Dimension: one row per hospital installation
CREATE TABLE dim_installation (
    installation_id INTEGER PRIMARY KEY AUTOINCREMENT,
    installation_name TEXT NOT NULL UNIQUE,
    region_code TEXT,
    civ INTEGER  -- number of functional stretchers ("civières")
);

-- Dimension: one row per Quebec health region
CREATE TABLE dim_region (
    region_code TEXT PRIMARY KEY,
    region_name TEXT NOT NULL
);

-- Fact table: one row per installation x date x metric
CREATE TABLE fact_ed_daily (
    fact_id INTEGER PRIMARY KEY AUTOINCREMENT,
    installation_id INTEGER NOT NULL,
    date TEXT NOT NULL,            -- format YYYY-MM-DD
    metric TEXT NOT NULL,          -- e.g. 'patients_sur_civiere', 'taux_occupation'
    value REAL,                    -- NULL when source data was 'N/D'
    is_region_total INTEGER DEFAULT 0,  -- 1 if this row is a region-level total row, not a single hospital
    FOREIGN KEY (installation_id) REFERENCES dim_installation(installation_id)
);

-- Helpful indexes for the queries we'll run later
CREATE INDEX idx_fact_installation ON fact_ed_daily(installation_id);
CREATE INDEX idx_fact_date ON fact_ed_daily(date);
CREATE INDEX idx_fact_metric ON fact_ed_daily(metric);
