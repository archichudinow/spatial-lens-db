-- =============================================================================
-- Migration: Fix RPC Functions for Re-uploading - Correct Column References
-- =============================================================================
-- Purpose: Fix reset_option_for_reupload and reset_record_for_reupload to use
--          correct column names (entity_type/entity_id instead of option_id/record_id)
-- Created: 2026-01-28
-- =============================================================================

-- =============================================================================
-- 1. FIX: Reset Option for Re-upload
-- =============================================================================

CREATE OR REPLACE FUNCTION reset_option_for_reupload(p_option_id UUID)
RETURNS JSON
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_status TEXT;
  v_deleted_files_count INT;
  v_project_id UUID;
  v_result JSON;
BEGIN
  -- Get current status and check permissions
  SELECT o.upload_status, o.project_id INTO v_old_status, v_project_id
  FROM project_options o
  INNER JOIN projects p ON o.project_id = p.id
  WHERE o.id = p_option_id
    AND p.user_id = auth.uid();  -- Ensure user owns the project

  -- Check if option exists and user has permission
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Option not found or you do not have permission to modify it';
  END IF;

  -- Only allow reset if currently completed
  IF v_old_status != 'completed' THEN
    RAISE EXCEPTION 'Can only reset completed uploads. Current status: %', v_old_status;
  END IF;

  -- Delete associated upload_files entries (FIX: use entity_type and entity_id)
  WITH deleted AS (
    DELETE FROM upload_files
    WHERE entity_type = 'option' AND entity_id = p_option_id
    RETURNING id
  )
  SELECT COUNT(*) INTO v_deleted_files_count FROM deleted;

  -- Update option: clear model_url and reset status to draft (FIX: use project_options)
  UPDATE project_options
  SET 
    model_url = NULL,
    upload_status = 'draft',
    updated_at = NOW()
  WHERE id = p_option_id;

  -- Build result
  v_result := json_build_object(
    'success', true,
    'option_id', p_option_id,
    'previous_status', v_old_status,
    'new_status', 'draft',
    'deleted_files_count', v_deleted_files_count,
    'message', 'Option reset successfully for re-upload'
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

COMMENT ON FUNCTION reset_option_for_reupload(UUID) IS 
'Resets a completed option back to draft status for re-uploading. Deletes associated upload_files using entity_type/entity_id and clears model_url.';

-- =============================================================================
-- 2. FIX: Reset Record for Re-upload
-- =============================================================================

CREATE OR REPLACE FUNCTION reset_record_for_reupload(p_record_id UUID)
RETURNS JSON
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_status TEXT;
  v_deleted_files_count INT;
  v_project_id UUID;
  v_result JSON;
BEGIN
  -- Get current status and check permissions
  SELECT r.upload_status, r.project_id INTO v_old_status, v_project_id
  FROM records r
  INNER JOIN projects p ON r.project_id = p.id
  WHERE r.id = p_record_id
    AND p.user_id = auth.uid();  -- Ensure user owns the project

  -- Check if record exists and user has permission
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Record not found or you do not have permission to modify it';
  END IF;

  -- Only allow reset if currently completed
  IF v_old_status != 'completed' THEN
    RAISE EXCEPTION 'Can only reset completed uploads. Current status: %', v_old_status;
  END IF;

  -- Delete associated upload_files entries (FIX: use entity_type and entity_id)
  WITH deleted AS (
    DELETE FROM upload_files
    WHERE entity_type = 'record' AND entity_id = p_record_id
    RETURNING id
  )
  SELECT COUNT(*) INTO v_deleted_files_count FROM deleted;

  -- Update record: clear record_url and reset status to draft (FIX: use record_url not model_url)
  UPDATE records
  SET 
    record_url = NULL,
    upload_status = 'draft',
    updated_at = NOW()
  WHERE id = p_record_id;

  -- Build result
  v_result := json_build_object(
    'success', true,
    'record_id', p_record_id,
    'previous_status', v_old_status,
    'new_status', 'draft',
    'deleted_files_count', v_deleted_files_count,
    'message', 'Record reset successfully for re-upload'
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

COMMENT ON FUNCTION reset_record_for_reupload(UUID) IS 
'Resets a completed record back to draft status for re-uploading. Deletes associated upload_files using entity_type/entity_id and clears record_url.';
