-- =============================================================================
-- Migration: Add Function to Clean Up Incomplete Uploads
-- =============================================================================
-- Purpose: Provide a function to delete incomplete/failed upload_files entries
--          before starting a new upload, preventing "X of Y files not completed" errors
-- Created: 2026-01-28
-- =============================================================================

-- =============================================================================
-- 1. RPC FUNCTION: Clean Up Incomplete Uploads for Option
-- =============================================================================

CREATE OR REPLACE FUNCTION cleanup_incomplete_option_uploads(p_option_id UUID)
RETURNS JSON
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted_count INT;
  v_result JSON;
BEGIN
  -- Delete incomplete/failed upload_files entries for this option
  -- Keep only 'completed' uploads
  WITH deleted AS (
    DELETE FROM upload_files
    WHERE entity_type = 'option' 
      AND entity_id = p_option_id
      AND upload_status != 'completed'
    RETURNING id
  )
  SELECT COUNT(*) INTO v_deleted_count FROM deleted;

  -- Build result
  v_result := json_build_object(
    'success', true,
    'option_id', p_option_id,
    'deleted_incomplete_files', v_deleted_count,
    'message', 'Incomplete uploads cleaned up successfully'
  );

  RETURN v_result;
EXCEPTION
  WHEN OTHERS THEN
    -- Return error details
    RETURN json_build_object(
      'success', false,
      'error', SQLERRM,
      'option_id', p_option_id
    );
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION cleanup_incomplete_option_uploads(UUID) IS 
'Deletes incomplete/failed upload_files entries for an option, keeping only completed uploads. Call before starting a new upload to prevent stale entries from blocking finalization.';

-- =============================================================================
-- 2. RPC FUNCTION: Clean Up Incomplete Uploads for Record
-- =============================================================================

CREATE OR REPLACE FUNCTION cleanup_incomplete_record_uploads(p_record_id UUID)
RETURNS JSON
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted_count INT;
  v_result JSON;
BEGIN
  -- Delete incomplete/failed upload_files entries for this record
  -- Keep only 'completed' uploads
  WITH deleted AS (
    DELETE FROM upload_files
    WHERE entity_type = 'record' 
      AND entity_id = p_record_id
      AND upload_status != 'completed'
    RETURNING id
  )
  SELECT COUNT(*) INTO v_deleted_count FROM deleted;

  -- Build result
  v_result := json_build_object(
    'success', true,
    'record_id', p_record_id,
    'deleted_incomplete_files', v_deleted_count,
    'message', 'Incomplete uploads cleaned up successfully'
  );

  RETURN v_result;
EXCEPTION
  WHEN OTHERS THEN
    -- Return error details
    RETURN json_build_object(
      'success', false,
      'error', SQLERRM,
      'record_id', p_record_id
    );
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION cleanup_incomplete_record_uploads(UUID) IS 
'Deletes incomplete/failed upload_files entries for a record, keeping only completed uploads. Call before starting a new upload to prevent stale entries from blocking finalization.';

-- =============================================================================
-- 3. GRANT PERMISSIONS
-- =============================================================================

GRANT EXECUTE ON FUNCTION cleanup_incomplete_option_uploads(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION cleanup_incomplete_record_uploads(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION cleanup_incomplete_option_uploads(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION cleanup_incomplete_record_uploads(UUID) TO service_role;
