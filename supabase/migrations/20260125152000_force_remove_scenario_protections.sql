-- Migration: Force remove all scenario deletion protections
-- Description: Explicitly drop all triggers and functions related to scenario deletion
-- Date: 2026-01-25

-- =============================================================================
-- Force removal of all scenario deletion protection mechanisms
-- =============================================================================

-- Drop all possible trigger variations
DROP TRIGGER IF EXISTS trigger_prevent_base_scenario_deletion ON public.scenarios CASCADE;
DROP TRIGGER IF EXISTS prevent_base_scenario_deletion ON public.scenarios CASCADE;

-- Drop all possible function variations
DROP FUNCTION IF EXISTS public.prevent_base_scenario_deletion() CASCADE;
DROP FUNCTION IF EXISTS prevent_base_scenario_deletion() CASCADE;

-- Verify by checking what's left
DO $$ 
DECLARE
  trigger_count INTEGER;
  function_count INTEGER;
BEGIN
  -- Check for remaining triggers
  SELECT COUNT(*) INTO trigger_count
  FROM pg_trigger
  WHERE tgname LIKE '%scenario%deletion%';
  
  -- Check for remaining functions
  SELECT COUNT(*) INTO function_count
  FROM pg_proc
  WHERE proname LIKE '%scenario%deletion%';
  
  RAISE NOTICE 'Remaining scenario deletion triggers: %', trigger_count;
  RAISE NOTICE 'Remaining scenario deletion functions: %', function_count;
END $$;
