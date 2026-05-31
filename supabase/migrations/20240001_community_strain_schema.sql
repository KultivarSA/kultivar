-- ============================================================================
-- Kultivar — Community strain benchmark schema
-- Migration: 20240001_community_strain_schema
--
-- Tables
--   strain_benchmarks   — one row per anonymous harvest submission
--   grow_diary_entries  — richer grow-context submission (optional second step)
--
-- Views (materialised for read performance)
--   strain_community_stats  — p25/median/p75 yield + avg grow days  (min 5 samples)
--   strain_grow_stats       — medium/light/technique popularity + quality rating
--
-- RLS: anonymous inserts are allowed; reads are public (views only expose
--      aggregates, never individual rows).
-- ============================================================================

-- ── 1. Raw harvest benchmarks ─────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS strain_benchmarks (
  id              BIGSERIAL PRIMARY KEY,
  strain_name     TEXT        NOT NULL CHECK (length(trim(strain_name)) > 0),
  dry_weight_g    NUMERIC(8,2) NOT NULL CHECK (dry_weight_g > 0),
  grow_days       SMALLINT    CHECK (grow_days BETWEEN 30 AND 600),
  veg_days        SMALLINT    CHECK (veg_days BETWEEN 0 AND 300),
  flower_days     SMALLINT    CHECK (flower_days BETWEEN 0 AND 300),
  medium          TEXT        CHECK (medium IN ('soil','coco','hydro','living_soil','other')),
  light_type      TEXT        CHECK (light_type IN ('led','hps','cmh','fluorescent','natural','other')),
  training        TEXT,          -- comma-separated technique tags
  is_autoflower   BOOLEAN     NOT NULL DEFAULT FALSE,
  is_clone        BOOLEAN     NOT NULL DEFAULT FALSE,
  app_version     TEXT,
  submitted_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for the aggregate view filter
CREATE INDEX IF NOT EXISTS idx_sb_strain_name
  ON strain_benchmarks (lower(strain_name));

-- Index for pruning old rows
CREATE INDEX IF NOT EXISTS idx_sb_submitted_at
  ON strain_benchmarks (submitted_at);

-- ── 2. Grow diary entries (richer context, optional) ──────────────────────────

CREATE TABLE IF NOT EXISTS grow_diary_entries (
  id              BIGSERIAL PRIMARY KEY,
  strain_name     TEXT        NOT NULL CHECK (length(trim(strain_name)) > 0),
  medium          TEXT        CHECK (medium IN ('soil','coco','hydro','living_soil','other')),
  light_type      TEXT        CHECK (light_type IN ('led','hps','cmh','fluorescent','natural','other')),
  techniques      TEXT,          -- comma-separated (e.g. 'LST,Topping')
  is_autoflower   BOOLEAN     NOT NULL DEFAULT FALSE,
  is_clone        BOOLEAN     NOT NULL DEFAULT FALSE,
  dry_weight_g    NUMERIC(8,2) CHECK (dry_weight_g > 0),
  veg_days        SMALLINT    CHECK (veg_days BETWEEN 0 AND 300),
  flower_days     SMALLINT    CHECK (flower_days BETWEEN 0 AND 300),
  quality_rating  SMALLINT    CHECK (quality_rating BETWEEN 1 AND 5),
  app_version     TEXT,
  submitted_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_gde_strain_name
  ON grow_diary_entries (lower(strain_name));

-- ── 3. RLS — allow anonymous inserts, no reads on raw tables ──────────────────

ALTER TABLE strain_benchmarks    ENABLE ROW LEVEL SECURITY;
ALTER TABLE grow_diary_entries   ENABLE ROW LEVEL SECURITY;

-- Anonymous inserts (anon role = public API key, not service key)
CREATE POLICY "anon_insert_benchmarks"
  ON strain_benchmarks FOR INSERT
  TO anon
  WITH CHECK (true);

CREATE POLICY "anon_insert_diary"
  ON grow_diary_entries FOR INSERT
  TO anon
  WITH CHECK (true);

-- Service role gets full access (admin / cron jobs only)
CREATE POLICY "service_all_benchmarks"
  ON strain_benchmarks FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY "service_all_diary"
  ON grow_diary_entries FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ── 4. strain_community_stats view ────────────────────────────────────────────
--
-- Aggregates the last 2 years of strain_benchmarks submissions.
-- Only returns rows with >= 5 samples.
-- Exposed as a VIEW (not MATERIALIZED) so it's always fresh; add a
-- MATERIALIZED VIEW + cron refresh if query latency becomes a concern.

CREATE OR REPLACE VIEW strain_community_stats AS
  SELECT
    lower(trim(strain_name))                           AS strain_name,
    COUNT(*)                                           AS sample_count,
    PERCENTILE_CONT(0.25) WITHIN GROUP
      (ORDER BY dry_weight_g)                          AS p25_g,
    PERCENTILE_CONT(0.50) WITHIN GROUP
      (ORDER BY dry_weight_g)                          AS median_g,
    PERCENTILE_CONT(0.75) WITHIN GROUP
      (ORDER BY dry_weight_g)                          AS p75_g,
    ROUND(AVG(grow_days))::INT                         AS avg_grow_days,
    ROUND(AVG(veg_days))::INT                          AS avg_veg_days,
    ROUND(AVG(flower_days))::INT                       AS avg_flower_days
  FROM strain_benchmarks
  WHERE submitted_at >= NOW() - INTERVAL '2 years'
  GROUP BY lower(trim(strain_name))
  HAVING COUNT(*) >= 5;

-- Public read access on the view (aggregate only — no raw rows exposed)
GRANT SELECT ON strain_community_stats TO anon, authenticated;

-- ── 5. strain_grow_stats view ─────────────────────────────────────────────────
--
-- Aggregates grow_diary_entries: medium/light popularity, avg quality rating,
-- avg stage durations.  Min 5 samples (same gate as yield stats).

CREATE OR REPLACE VIEW strain_grow_stats AS
  WITH base AS (
    SELECT
      lower(trim(strain_name))                         AS strain_name,
      medium,
      light_type,
      quality_rating,
      veg_days,
      flower_days
    FROM grow_diary_entries
    WHERE submitted_at >= NOW() - INTERVAL '2 years'
  ),
  counts AS (
    SELECT
      strain_name,
      COUNT(*)                                         AS sample_count,
      -- Most common medium
      MODE() WITHIN GROUP (ORDER BY medium)            AS top_medium,
      -- Most common light
      MODE() WITHIN GROUP (ORDER BY light_type)        AS top_light_type,
      -- Medium %
      ROUND(100.0 * COUNT(*) FILTER
        (WHERE medium = 'soil')    / COUNT(*), 1)      AS pct_soil,
      ROUND(100.0 * COUNT(*) FILTER
        (WHERE medium = 'coco')    / COUNT(*), 1)      AS pct_coco,
      ROUND(100.0 * COUNT(*) FILTER
        (WHERE medium = 'hydro')   / COUNT(*), 1)      AS pct_hydro,
      -- Light %
      ROUND(100.0 * COUNT(*) FILTER
        (WHERE light_type = 'led') / COUNT(*), 1)      AS pct_led,
      ROUND(100.0 * COUNT(*) FILTER
        (WHERE light_type = 'hps') / COUNT(*), 1)      AS pct_hps,
      -- Stage averages
      ROUND(AVG(veg_days))::INT                        AS avg_veg_days,
      ROUND(AVG(flower_days))::INT                     AS avg_flower_days,
      -- Quality
      ROUND(AVG(quality_rating), 2)                    AS avg_quality_rating
    FROM base
    GROUP BY strain_name
    HAVING COUNT(*) >= 5
  )
  SELECT * FROM counts;

GRANT SELECT ON strain_grow_stats TO anon, authenticated;

-- ── 6. Automatic data-retention — keep only last 2 years ─────────────────────
--
-- Run via pg_cron (enable the pg_cron extension in the Supabase dashboard):
--   SELECT cron.schedule('prune-benchmarks', '0 3 * * 0',
--     $$DELETE FROM strain_benchmarks  WHERE submitted_at < NOW() - INTERVAL '2 years'$$);
--   SELECT cron.schedule('prune-diary',      '0 3 * * 0',
--     $$DELETE FROM grow_diary_entries WHERE submitted_at < NOW() - INTERVAL '2 years'$$);
--
-- Or add a Supabase Edge Function on a schedule if pg_cron is not available.

-- ── 7. Optional: seed data for local dev / preview ────────────────────────────
--
-- Uncomment and run in your local dev Supabase instance to have benchmark
-- data available without waiting for real user submissions.
--
-- INSERT INTO strain_benchmarks (strain_name, dry_weight_g, grow_days, veg_days, flower_days, medium, light_type, is_autoflower)
-- VALUES
--   ('gorilla glue #4', 85,  112, 49, 63, 'coco',  'led', false),
--   ('gorilla glue #4', 102, 119, 56, 63, 'coco',  'led', false),
--   ('gorilla glue #4', 74,  105, 42, 63, 'soil',  'hps', false),
--   ('gorilla glue #4', 93,  115, 49, 63, 'soil',  'led', false),
--   ('gorilla glue #4', 67,  108, 42, 63, 'hydro', 'led', false),
--   ('gorilla glue #4', 115, 126, 63, 63, 'coco',  'led', false),
--   ('og kush',         72,  112, 49, 63, 'soil',  'hps', false),
--   ('og kush',         68,  112, 49, 63, 'coco',  'led', false),
--   ('og kush',         81,  119, 56, 63, 'coco',  'led', false),
--   ('og kush',         59,  105, 42, 63, 'soil',  'hps', false),
--   ('og kush',         77,  112, 49, 63, 'hydro', 'led', false),
--   ('gorilla glue auto', 48, 77, 0, 77, 'coco',  'led', true),
--   ('gorilla glue auto', 55, 77, 0, 77, 'soil',  'led', true),
--   ('gorilla glue auto', 42, 77, 0, 77, 'coco',  'led', true),
--   ('gorilla glue auto', 61, 84, 0, 84, 'coco',  'led', true),
--   ('gorilla glue auto', 38, 70, 0, 70, 'soil',  'hps', true);
