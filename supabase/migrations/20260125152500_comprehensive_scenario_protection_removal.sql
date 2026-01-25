-- Migration: Comprehensive removal of scenario deletion protection
-- Description: Drop function from all schemas and ensure trigger is removed
-- Date: 2026-01-25

-- =============================================================================
-- Complete removal - check all possible locations
-- =============================================================================

-- Drop trigger from scenarios table
DROP TRIGGER IF EXISTS trigger_prevent_base_scenario_deletion ON scenarios CASCADE;

-- Drop function from public schema
DROP FUNCTION IF EXISTS public.prevent_base_scenario_deletion() CASCADE;

-- Try to drop without schema qualification
DROP FUNCTION IF EXISTS prevent_base_scenario_deletion() CASCADE;

-- Drop any remaining triggers on scenarios table that might reference this
DO $$ 
DECLARE
  r RECORD;
BEGIN
  FOR r IN 
    SELECT tgname 
    FROM pg_trigger t
    JOIN pg_class c ON t.tgrelid = c.oid
    WHERE c.relname = 'scenarios' 
    AND tgname LIKE '%prevent%scenario%'
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON scenarios CASCADE', r.tgname);
    RAISE NOTICE 'Dropped trigger: %', r.tgname;
  END LOOP;
END $$;

-- Verify cleanup
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'prevent_base_scenario_deletion'
  ) THEN
    RAISE EXCEPTION 'Function prevent_base_scenario_deletion still exists!';
  END IF;
  
  IF EXISTS (
    SELECT 1 FROM pg_trigger t
    JOIN pg_class c ON t.tgrelid = c.oid
    WHERE c.relname = 'scenarios'
    AND tgname LIKE '%prevent%scenario%'
  ) THEN
    RAISE EXCEPTION 'Trigger for preventing scenario deletion still exists!';
  END IF;
  
  RAISE NOTICE 'Successfully removed all scenario deletion protections';
END $$;
