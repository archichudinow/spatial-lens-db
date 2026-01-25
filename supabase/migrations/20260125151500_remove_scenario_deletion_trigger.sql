-- Migration: Remove scenario deletion trigger
-- Description: Remove the prevent_base_scenario_deletion trigger as it interferes with cascade deletes
--              The protection should be handled at application level instead
-- Date: 2026-01-25

-- =============================================================================
-- Remove the problematic trigger that blocks cascade deletes
-- =============================================================================

DROP TRIGGER IF EXISTS trigger_prevent_base_scenario_deletion ON scenarios;
DROP FUNCTION IF EXISTS prevent_base_scenario_deletion();

COMMENT ON TABLE scenarios IS 
  'Scenarios for project options. Note: Prevent deletion of last scenario at application level, not database level.';
