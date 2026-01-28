-- =============================================================================
-- Migration: Allow completed → draft transition for re-uploads
-- =============================================================================
-- Purpose: Update validate_status_transition trigger to allow resetting
--          completed uploads back to draft when model_url is being cleared
-- Created: 2026-01-28
-- =============================================================================

CREATE OR REPLACE FUNCTION validate_status_transition()
RETURNS TRIGGER AS $$
BEGIN
  -- Only validate if status is actually changing
  IF OLD.upload_status IS NOT NULL AND NEW.upload_status != OLD.upload_status THEN
    
    -- Completed state is immutable EXCEPT when resetting for re-upload
    -- Allow completed → draft when model_url is being cleared (indicates intentional reset)
    IF OLD.upload_status = 'completed' THEN
      IF NEW.upload_status = 'draft' AND NEW.model_url IS NULL AND OLD.model_url IS NOT NULL THEN
        -- Allow: This is an intentional reset for re-upload
        RETURN NEW;
      ELSIF NEW.upload_status = 'draft' AND NEW.record_url IS NULL AND OLD.record_url IS NOT NULL THEN
        -- Allow: This is an intentional reset for re-upload (for records)
        RETURN NEW;
      ELSE
        RAISE EXCEPTION 'Cannot change status from completed to %. Completed records are immutable. Use reset function to allow re-upload.', NEW.upload_status;
      END IF;
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
'Validates upload status transitions. Allows completed → draft when model_url/record_url is cleared (for re-uploads).';
