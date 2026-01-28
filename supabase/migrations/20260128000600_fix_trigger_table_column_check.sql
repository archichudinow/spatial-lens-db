-- =============================================================================
-- Migration: Fix trigger to check correct URL column per table
-- =============================================================================
-- Purpose: validate_status_transition was checking record_url on ALL tables,
--          but options use model_url. Need to check TG_TABLE_NAME.
-- Created: 2026-01-28
-- =============================================================================

CREATE OR REPLACE FUNCTION validate_status_transition()
RETURNS TRIGGER AS $$
BEGIN
  -- Only validate if status is actually changing
  IF OLD.upload_status IS NOT NULL AND NEW.upload_status != OLD.upload_status THEN
    
    -- Special case: Allow completed → draft for re-upload
    -- Check the appropriate URL column based on the table
    IF OLD.upload_status = 'completed' AND NEW.upload_status = 'draft' THEN
      
      -- For project_options table, check model_url
      IF TG_TABLE_NAME = 'project_options' THEN
        IF NEW.model_url IS NOT NULL THEN
          RAISE EXCEPTION 'Cannot reset completed option to draft unless model_url is cleared';
        END IF;
        RETURN NEW;
      END IF;
      
      -- For records table, check record_url
      IF TG_TABLE_NAME = 'records' THEN
        IF NEW.record_url IS NOT NULL THEN
          RAISE EXCEPTION 'Cannot reset completed record to draft unless record_url is cleared';
        END IF;
        RETURN NEW;
      END IF;
      
      -- For projects table (if they have upload status)
      IF TG_TABLE_NAME = 'projects' THEN
        -- Allow the transition for projects
        RETURN NEW;
      END IF;
    END IF;
    
    -- Block all other transitions from completed
    IF OLD.upload_status = 'completed' THEN
      RAISE EXCEPTION 'Cannot change status from completed to %. Completed records are immutable. Use reset function to allow re-upload.', NEW.upload_status;
    END IF;
    
    -- From draft: can only go to uploading or failed
    IF OLD.upload_status = 'draft' AND NEW.upload_status NOT IN ('uploading', 'failed') THEN
      RAISE EXCEPTION 'Invalid transition from draft to %. Must transition to uploading or failed.', NEW.upload_status;
    END IF;
    
    -- From uploading: can only go to completed or failed
    IF OLD.upload_status = 'uploading' AND NEW.upload_status NOT IN ('completed', 'failed') THEN
      RAISE EXCEPTION 'Invalid transition from uploading to %. Must transition to completed or failed.', NEW.upload_status;
    END IF;
    
    -- From failed: can go to uploading (retry) or draft (reset)
    IF OLD.upload_status = 'failed' AND NEW.upload_status NOT IN ('uploading', 'draft') THEN
      RAISE EXCEPTION 'Invalid transition from failed to %. Can only retry (uploading) or reset (draft).', NEW.upload_status;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION validate_status_transition() IS 
'Validates upload status transitions. Uses TG_TABLE_NAME to check correct URL column (model_url for project_options, record_url for records).';
