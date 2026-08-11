-- ============================================================
-- Arreglo: agregar is_region_total también en dim_installation,
-- no solo en fact_ed_daily, para no depender de filtros de texto
-- tipo LIKE 'Total%' cada vez que se consulta.
-- ============================================================

-- 1) Agregar la columna nueva, con default 0 (asumimos "no es total"
--    hasta que la actualicemos abajo)
ALTER TABLE dim_installation ADD COLUMN is_region_total INTEGER DEFAULT 0;

-- 2) Marcar como 1 las filas que sí son totales de región
UPDATE dim_installation
SET is_region_total = 1
WHERE installation_name LIKE 'Total%';

-- 3) Verificación: deberías ver 15 filas marcadas como total
--    (una por cada una de las 15 regiones con datos)
SELECT COUNT(*) AS n_totales FROM dim_installation WHERE is_region_total = 1;

-- 4) Ahora la consulta del hospital con más camillas, ya sin LIKE
SELECT installation_name, stretchers
FROM dim_installation
WHERE is_region_total = 0
ORDER BY stretchers DESC
LIMIT 1;
