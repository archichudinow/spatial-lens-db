-- Migration: Fix cascade delete for scenarios
-- Description: Allow scenario deletion when parent option/project is being deleted
-- Date: 2026-01-25

-- =============================================================================
-- Fix: Update prevent_base_scenario_deletion to allow cascade deletes
-- =============================================================================

-- Drop the existing trigger and function
DROP TRIGGER IF EXISTS trigger_prevent_base_scenario_deletion ON scenarios;
DROP FUNCTION IF EXISTS prevent_base_scenario_deletion();

-- Recreate with improved logic that allows deletion during cascade
CREATE OR REPLACE FUNCTION prevent_base_scenario_deletion()
RETURNS TRIGGER AS $$
DECLARE
  scenario_count INTEGER;
  option_exists BOOLEAN;
BEGIN
  -- Check if the parent option still exists
  -- If the option is being deleted, allow scenario deletion (cascade)
  SELECT EXISTS(SELECT 1 FROM project_options WHERE id = OLD.option_id) INTO option_exists;
  
  -- If option doesn't exist, it's being deleted as part of cascade - allow it
  IF NOT option_exists THEN
    RETURN OLD;
  END IF;
  
  -- Option exists, so check if this is the only non-archived scenario
  SELECT COUNT(*) INTO scenario_count
  FROM scenarios
  WHERE option_id = OLD.option_id 
    AND is_archived = false
    AND id != OLD.id; -- Exclude the current scenario being deleted
  
  -- If this would leave no scenarios, block the deletion
  IF scenario_count = 0 THEN
    RAISE EXCEPTION 'Cannot delete base scenario. Each option must have at least one scenario.';
  END IF;
  
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION prevent_base_scenario_deletion() IS 
  'Prevents deletion of the last scenario for an option, but allows cascade deletes when option/project is being deleted';

-- Reattach the trigger
CREATE TRIGGER trigger_prevent_base_scenario_deletion
  BEFORE DELETE ON scenarios
  FOR EACH ROW
  EXECUTE FUNCTION prevent_base_scenario_deletion();
