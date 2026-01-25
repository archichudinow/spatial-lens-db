-- Migration: Remove base option deletion protection
-- Description: Remove prevent_base_option_deletion trigger to allow cascade deletes
-- Date: 2026-01-25

-- =============================================================================
-- Remove base option deletion protection
-- =============================================================================

-- Drop trigger
DROP TRIGGER IF EXISTS trigger_prevent_base_option_deletion ON project_options CASCADE;

-- Drop function from public schema
DROP FUNCTION IF EXISTS public.prevent_base_option_deletion() CASCADE;

-- Try to drop without schema qualification
DROP FUNCTION IF EXISTS prevent_base_option_deletion() CASCADE;

-- Drop any remaining triggers on project_options table that might reference this
DO $$ 
DECLARE
  r RECORD;
BEGIN
  FOR r IN 
    SELECT tgname 
    FROM pg_trigger t
    JOIN pg_class c ON t.tgrelid = c.oid
    WHERE c.relname = 'project_options' 
    AND tgname LIKE '%prevent%option%'
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON project_options CASCADE', r.tgname);
    RAISE NOTICE 'Dropped trigger: %', r.tgname;
  END LOOP;
END $$;

-- Verify cleanup
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'prevent_base_option_deletion'
  ) THEN
    RAISE EXCEPTION 'Function prevent_base_option_deletion still exists!';
  END IF;
  
  IF EXISTS (
    SELECT 1 FROM pg_trigger t
    JOIN pg_class c ON t.tgrelid = c.oid
    WHERE c.relname = 'project_options'
    AND tgname LIKE '%prevent%option%'
  ) THEN
    RAISE EXCEPTION 'Trigger for preventing option deletion still exists!';
  END IF;
  
  RAISE NOTICE 'Successfully removed all base option deletion protections';
END $$;

COMMENT ON TABLE project_options IS 
  'Project options. Note: Prevent deletion of base option at application level, not database level.';
